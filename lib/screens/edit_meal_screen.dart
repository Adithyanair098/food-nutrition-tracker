import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/meal_entry.dart';
import '../repositories/meal_repository.dart';

/// Edits the name, weight, and meal type of an already-saved [MealEntry].
///
/// ── Scope ─────────────────────────────────────────────────────────────────
/// This screen never contacts Gemini, [FoodSelectionScreen], or
/// [NutritionResultScreen]. It only ever reads and rewrites fields on a
/// [MealEntry] that has already been saved. Nutrition values are
/// recalculated locally via [MealEntry.recalculatedForWeight] — a pure
/// proportional scale against the values already stored on the entry,
/// never a re-derivation of the original AI prediction.
///
/// ── Identity preservation ────────────────────────────────────────────────
/// [MealEntry.id] and [MealEntry.loggedAt] are never passed to
/// [MealEntry.copyWith] or [MealEntry.recalculatedForWeight] in this file,
/// so they cannot be accidentally regenerated. Saving always calls
/// [MealRepository.updateEntry] — never [MealRepository.saveEntry] — so the
/// existing row is updated in place, never duplicated.
class EditMealScreen extends StatefulWidget {
  const EditMealScreen({
    super.key,
    required this.entry,
    required this.repository,
  });

  /// The meal entry being edited. Treated as the source of truth for all
  /// fields not explicitly changed by the user.
  final MealEntry entry;

  /// Abstract repository — swap to FirebaseMealRepository in a future
  /// milestone with zero changes to this screen.
  final MealRepository repository;

  @override
  State<EditMealScreen> createState() => _EditMealScreenState();
}

class _EditMealScreenState extends State<EditMealScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late MealType _selectedMealType;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.foodName);
    _weightController = TextEditingController(
      text: widget.entry.weightGrams.toStringAsFixed(0),
    );
    _selectedMealType = widget.entry.mealType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final newWeight = double.parse(_weightController.text.trim());

      // recalculatedForWeight is safe to call unconditionally: when
      // newWeight equals the current weightGrams the scale ratio is 1.0,
      // so macro values are unchanged. This avoids a separate branch for
      // "weight changed vs. didn't."
      final updatedEntry = widget.entry
          .recalculatedForWeight(newWeight)
          .copyWith(
            foodName: _nameController.text.trim(),
            mealType: _selectedMealType,
          );

      await widget.repository.updateEntry(updatedEntry);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not save changes. Please try again.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Food name cannot be empty.';
    }
    return null;
  }

  String? _validateWeight(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Weight is required.';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return 'Enter a valid number.';
    }
    if (parsed <= 0) {
      return 'Weight must be greater than zero.';
    }
    return null;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Meal'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _isSaving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Food name',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const OutlineInputBorder().let((border) =>
                    InputDecoration(
                      hintText: 'e.g. Grilled Chicken Breast',
                      border: border,
                    )),
                validator: _validateName,
              ),
              const SizedBox(height: 24),
              Text(
                'Weight (grams)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'e.g. 150',
                  suffixText: 'g',
                  border: OutlineInputBorder(),
                ),
                validator: _validateWeight,
              ),
              const SizedBox(height: 4),
              Text(
                'Nutrition values will be recalculated proportionally.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              Text(
                'Meal type',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              SegmentedButton<MealType>(
                segments: MealType.values
                    .map(
                      (type) => ButtonSegment<MealType>(
                        value: type,
                        label: Text(type.displayName),
                        icon: Text(type.emoji),
                      ),
                    )
                    .toList(),
                selected: {_selectedMealType},
                onSelectionChanged: (selection) {
                  setState(() => _selectedMealType = selection.first);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny local extension used once above purely to keep the InputDecoration
/// construction readable inline. Not exported, not part of the public API.
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}