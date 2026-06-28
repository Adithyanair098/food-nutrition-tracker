import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/meal_entry.dart';
import '../repositories/meal_repository.dart';
import '../services/meal_events.dart';
import 'edit_meal_screen.dart';

class HistoryScreen extends StatefulWidget {
  /// Abstract repository — swap to FirebaseMealRepository in a future
  /// milestone with zero changes to this screen.
  final MealRepository repository;

  const HistoryScreen({super.key, required this.repository});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  List<MealEntry> _entries = [];
  bool _isLoading = true;

  late final StreamSubscription<void> _mealChangesSubscription;

  @override
  void initState() {
    super.initState();
    _loadEntries();

    // Picks up changes made outside this screen's own delete flow —
    // principally a save from EditMealScreen, which has no direct
    // callback back into HistoryScreen since it's a separately pushed
    // route. Reuses the same MealEvents stream HomeScreen listens to,
    // rather than introducing a second refresh mechanism.
    _mealChangesSubscription = MealEvents.instance.changes.listen((_) {
      _loadEntries();
    });
  }

  @override
  void dispose() {
    _mealChangesSubscription.cancel();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      final entries =
          await widget.repository.getEntriesForDay(_selectedDate);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Could not load meals. Please try again.');
    }
  }

  Future<void> _deleteEntry(String id) async {
    try {
      await widget.repository.deleteEntry(id);
      if (!mounted) return;
      // Local splice keeps the swipe-to-delete exit animation smooth.
      // This is independent of MealEvents: repository.deleteEntry already
      // fires that event for other listeners (HomeScreen, and this
      // screen's own subscription above, which will simply re-confirm
      // the same state on its next tick).
      setState(() => _entries.removeWhere((e) => e.id == id));
    } catch (_) {
      if (!mounted) return;
      _showError('Could not delete meal. Please try again.');
    }
  }

  /// Shared confirm-then-delete flow used by both the swipe gesture and
  /// the explicit delete button, so there is exactly one place that
  /// decides what "deleting a meal" means.
  Future<void> _confirmAndDelete(String id) async {
    final confirmed = await _confirmDelete(context);
    if (!confirmed) return;
    await _deleteEntry(id);
  }

  /// Pushes [EditMealScreen] for [entry]. No result-handling is needed
  /// here: a successful save calls MealRepository.updateEntry, which
  /// fires MealEvents — this screen's subscription (see initState)
  /// handles the refresh automatically, whether the user saved or
  /// cancelled.
  Future<void> _navigateToEdit(MealEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditMealScreen(
          entry: entry,
          repository: widget.repository,
        ),
      ),
    );
  }

  // ── Date navigation ───────────────────────────────────────────────────────

  void _selectPreviousDay() {
    setState(
        () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _loadEntries();
  }

  void _selectNextDay() {
    if (_isToday) return;
    setState(
        () => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _loadEntries();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  // ── Daily totals ──────────────────────────────────────────────────────────

  double get _totalCalories =>
      _entries.fold(0.0, (sum, e) => sum + e.calories);
  double get _totalProteinG =>
      _entries.fold(0.0, (sum, e) => sum + e.proteinG);
  double get _totalCarbsG =>
      _entries.fold(0.0, (sum, e) => sum + e.carbsG);
  double get _totalFatG =>
      _entries.fold(0.0, (sum, e) => sum + e.fatG);

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Meal?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _DateNavigator(
            selectedDate: _selectedDate,
            onPrevious: _selectPreviousDay,
            onNext: _isToday ? null : _selectNextDay,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadEntries,
                // RefreshIndicator requires a scrollable descendant.
                // Both branches satisfy this: _EmptyHistoryState uses a
                // ListView, and _buildMealList uses an Expanded ListView.
                child: _entries.isEmpty
                    ? _EmptyHistoryState(isToday: _isToday)
                    : _buildMealList(),
              ),
      ),
    );
  }

  Widget _buildMealList() {
    return Column(
      children: [
        // Aggregated daily totals
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _DailySummaryCard(
            mealCount: _entries.length,
            calories: _totalCalories,
            proteinG: _totalProteinG,
            carbsG: _totalCarbsG,
            fatG: _totalFatG,
          ),
        ),
        // Meal list — Expanded fills remaining height so Column
        // is fully constrained and Expanded works correctly.
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: _entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return Dismissible(
                key: ValueKey(entry.id),
                direction: DismissDirection.endToStart,
                background: const _DismissBackground(),
                // confirmDismiss gates the animation; returning false
                // snaps the card back without calling onDismissed.
                confirmDismiss: (_) => _confirmDelete(context),
                // onDismissed updates _entries after the exit animation
                // completes, keeping the list consistent with the DB.
                onDismissed: (_) => _deleteEntry(entry.id),
                child: _MealEntryCard(
                  entry: entry,
                  onEdit: () => _navigateToEdit(entry),
                  onDelete: () => _confirmAndDelete(entry.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private Sub-Widgets
// ═══════════════════════════════════════════════════════════════════════════

/// Date navigation bar rendered at the bottom of the AppBar.
class _DateNavigator extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPrevious;

  /// Null when already on today — disables the forward arrow.
  final VoidCallback? onNext;

  const _DateNavigator({
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppTheme.primary,
            onPressed: onPrevious,
          ),
          Text(
            _formatDate(selectedDate),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            // Visually dim the icon when disabled to signal the boundary.
            color: onNext != null ? AppTheme.primary : AppTheme.divider,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// Green summary card showing total calories and macros for the day.
class _DailySummaryCard extends StatelessWidget {
  final int mealCount;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const _DailySummaryCard({
    required this.mealCount,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Calories row
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                '${calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '$mealCount ${mealCount == 1 ? 'meal' : 'meals'}',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          // Macro totals row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MacroSummaryItem(label: 'Protein', valueG: proteinG),
              _MacroSummaryItem(label: 'Carbs', valueG: carbsG),
              _MacroSummaryItem(label: 'Fat', valueG: fatG),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroSummaryItem extends StatelessWidget {
  final String label;
  final double valueG;

  const _MacroSummaryItem({required this.label, required this.valueG});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${valueG.toStringAsFixed(1)}g',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

/// Card for a single logged meal.
///
/// Supports two equally functional delete paths — swipe-to-dismiss
/// (handled by the parent's Dismissible) and the explicit delete icon
/// button below — plus an edit action. Both buttons delegate entirely to
/// callbacks; this widget owns no business logic of its own.
class _MealEntryCard extends StatelessWidget {
  final MealEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MealEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MealThumbnail(imagePath: entry.imagePath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Meal type + time
                Row(
                  children: [
                    Text(
                      '${entry.mealType.emoji} ${entry.mealType.displayName}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(entry.loggedAt),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Food name
                Text(
                  entry.foodName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Weight + calorie + protein chips
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _InfoChip(
                      icon: Icons.scale_rounded,
                      label: '${entry.weightGrams.toStringAsFixed(0)}g',
                    ),
                    _InfoChip(
                      icon: Icons.local_fire_department_rounded,
                      label: '${entry.calories.toStringAsFixed(0)} kcal',
                      color: AppTheme.primary,
                    ),
                    _InfoChip(
                      icon: Icons.fitness_center_rounded,
                      label: '${entry.proteinG.toStringAsFixed(0)}g protein',
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Edit / Delete actions. Compact density keeps the card height
          // unchanged from before this milestone.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: AppTheme.textSecondary,
                visualDensity: VisualDensity.compact,
                tooltip: 'Edit meal',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.red.shade700,
                visualDensity: VisualDensity.compact,
                tooltip: 'Delete meal',
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Square thumbnail showing the meal image, or a fallback icon when the
/// image path is null or the file has been deleted from disk.
class _MealThumbnail extends StatelessWidget {
  final String? imagePath;

  const _MealThumbnail({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final file = imagePath != null ? File(imagePath!) : null;
    final fileExists = file?.existsSync() ?? false;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 64,
        height: 64,
        child: fileExists
            ? Image.file(file!, fit: BoxFit.cover)
            : Container(
                color: const Color(0xFFE8F5E9),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
      ),
    );
  }
}

/// Icon + label chip used for weight, calorie, and protein display.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color = AppTheme.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Shown when no meals exist for the selected date.
/// Wrapped in a ListView so RefreshIndicator's scroll detection works
/// even when the list is empty.
class _EmptyHistoryState extends StatelessWidget {
  final bool isToday;

  const _EmptyHistoryState({required this.isToday});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Meals Logged',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                isToday
                    ? 'Tap + to log your first meal today.'
                    : 'No meals were logged on this day.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Red delete hint revealed during swipe-to-delete.
class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.delete_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Helpers  (file-private — not exported)
// ═══════════════════════════════════════════════════════════════════════════

/// Returns "Today", "Yesterday", or "Jan 15, 2024".
/// No intl dependency — avoids adding a package for three display strings.
String _formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;

  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Returns "2:30 PM". No intl dependency.
String _formatTime(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}