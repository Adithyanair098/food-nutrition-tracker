import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models/daily_goals.dart';
import '../repositories/goals_repository.dart';

class GoalSettingsScreen extends StatefulWidget {
  /// Abstract repository — never coupled to a concrete implementation.
  final GoalsRepository repository;

  const GoalSettingsScreen({
    super.key,
    required this.repository,
  });

  @override
  State<GoalSettingsScreen> createState() => _GoalSettingsScreenState();
}

class _GoalSettingsScreenState extends State<GoalSettingsScreen> {
  // ── Controllers ───────────────────────────────────────────────────────────

  final _caloriesController  = TextEditingController();
  final _proteinController   = TextEditingController();
  final _carbsController     = TextEditingController();
  final _fatController       = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────

  bool _isLoading = true;
  bool _isSaving  = false;

  /// True when all four fields contain a positive number.
  bool get _isValid {
    return _parsePositive(_caloriesController.text) != null &&
        _parsePositive(_proteinController.text)     != null &&
        _parsePositive(_carbsController.text)       != null &&
        _parsePositive(_fatController.text)         != null;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadGoals() async {
    try {
      final goals = await widget.repository.loadGoals();
      if (!mounted) return;
      _caloriesController.text = goals.calories.toStringAsFixed(0);
      _proteinController.text  = goals.proteinG.toStringAsFixed(0);
      _carbsController.text    = goals.carbsG.toStringAsFixed(0);
      _fatController.text      = goals.fatG.toStringAsFixed(0);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not load goals. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGoals() async {
    if (!_isValid || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      final goals = DailyGoals(
        calories: _parsePositive(_caloriesController.text)!,
        proteinG: _parsePositive(_proteinController.text)!,
        carbsG:   _parsePositive(_carbsController.text)!,
        fatG:     _parsePositive(_fatController.text)!,
      );

      await widget.repository.saveGoals(goals);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Goals saved!'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Return true so HomeScreen knows to reload goals.
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _showError('Could not save goals. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Parses [text] as a positive double. Returns null if invalid or ≤ 0.
  double? _parsePositive(String text) {
    final value = double.tryParse(text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Goals')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ─────────────────────────────────────────────
                    const _SectionHeader(
                      icon: Icons.flag_rounded,
                      title: 'Set your daily targets',
                      subtitle:
                          'These goals will be used to track your daily progress.',
                    ),
                    const SizedBox(height: 28),

                    // ── Goal fields ────────────────────────────────────────
                    _GoalField(
                      label: 'Calories',
                      unit: 'kcal',
                      icon: Icons.local_fire_department_rounded,
                      color: AppTheme.primary,
                      controller: _caloriesController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    _GoalField(
                      label: 'Protein',
                      unit: 'g',
                      icon: Icons.fitness_center_rounded,
                      color: const Color(0xFF1565C0),
                      controller: _proteinController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    _GoalField(
                      label: 'Carbohydrates',
                      unit: 'g',
                      icon: Icons.grain_rounded,
                      color: const Color(0xFFF57F17),
                      controller: _carbsController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 14),

                    _GoalField(
                      label: 'Fat',
                      unit: 'g',
                      icon: Icons.water_drop_rounded,
                      color: const Color(0xFFC62828),
                      controller: _fatController,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 36),

                    // ── Save button ────────────────────────────────────────
                    ElevatedButton(
                      onPressed: _isValid && !_isSaving ? _saveGoals : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        disabledBackgroundColor: AppTheme.divider,
                        disabledForegroundColor: AppTheme.textSecondary,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white),
                              ),
                            )
                          : const Text('Save Goals'),
                    ),

                    // ── Restore defaults ───────────────────────────────────
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSaving ? null : _restoreDefaults,
                      child: const Text('Restore Defaults'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  /// Fills all fields with [DailyGoals.defaults] values without saving.
  /// The user must still tap Save to persist.
  void _restoreDefaults() {
    const defaults = DailyGoals.defaults();
    setState(() {
      _caloriesController.text = defaults.calories.toStringAsFixed(0);
      _proteinController.text  = defaults.proteinG.toStringAsFixed(0);
      _carbsController.text    = defaults.carbsG.toStringAsFixed(0);
      _fatController.text      = defaults.fatG.toStringAsFixed(0);
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private Sub-Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single labelled numeric input field for a nutrition goal.
class _GoalField extends StatelessWidget {
  final String label;
  final String unit;
  final IconData icon;
  final Color color;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _GoalField({
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          // Coloured icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),

          // Label
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Numeric input
          SizedBox(
            width: 88,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                suffix: Text(
                  unit,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}