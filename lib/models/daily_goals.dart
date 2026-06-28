import 'package:flutter/foundation.dart';

/// Immutable model representing the user's daily nutrition targets.
///
/// All values are in the same units used throughout the app:
///   - [calories]  → kcal
///   - [proteinG]  → grams
///   - [carbsG]    → grams
///   - [fatG]      → grams
///
/// Persistence is handled by [GoalsRepository]. This model is pure data.
@immutable
class DailyGoals {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const DailyGoals({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  /// Sensible starting targets for a moderately active adult.
  ///
  /// Returned by [GoalsRepository] when no goals have been saved yet,
  /// so the dashboard always has a valid baseline to render against.
  const DailyGoals.defaults()
      : calories = 2000,
        proteinG = 120,
        carbsG = 250,
        fatG = 70;

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Key constants used by [LocalGoalsRepository] when reading and writing
  /// individual SharedPreferences entries. Defined here so a key rename
  /// never requires touching two files.
  static const String _keyCalories = 'goals_calories';
  static const String _keyProteinG = 'goals_protein_g';
  static const String _keyCarbsG   = 'goals_carbs_g';
  static const String _keyFatG     = 'goals_fat_g';

  /// All four keys in declaration order.
  /// Used by [LocalGoalsRepository.clear] and tests.
  static const List<String> allKeys = [
    _keyCalories,
    _keyProteinG,
    _keyCarbsG,
    _keyFatG,
  ];

  Map<String, double> toMap() => {
        _keyCalories: calories,
        _keyProteinG: proteinG,
        _keyCarbsG: carbsG,
        _keyFatG: fatG,
      };

  /// Returns [DailyGoals.defaults] for any key that is absent from [map].
  ///
  /// This makes reading safe even if a future migration adds a new field
  /// and an older SharedPreferences store is missing that key.
  factory DailyGoals.fromMap(Map<String, double> map) {
    const fallback = DailyGoals.defaults();
    return DailyGoals(
      calories: map[_keyCalories] ?? fallback.calories,
      proteinG: map[_keyProteinG] ?? fallback.proteinG,
      carbsG:   map[_keyCarbsG]   ?? fallback.carbsG,
      fatG:     map[_keyFatG]     ?? fallback.fatG,
    );
  }

  // ── Mutation ──────────────────────────────────────────────────────────────

  DailyGoals copyWith({
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) =>
      DailyGoals(
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        carbsG:   carbsG   ?? this.carbsG,
        fatG:     fatG     ?? this.fatG,
      );

  // ── Validation ────────────────────────────────────────────────────────────

  /// Returns true if all goals are positive numbers.
  ///
  /// Used by [GoalSettingsScreen] to gate the Save button.
  bool get isValid =>
      calories > 0 && proteinG > 0 && carbsG > 0 && fatG > 0;

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyGoals &&
          other.calories == calories &&
          other.proteinG == proteinG &&
          other.carbsG == carbsG &&
          other.fatG == fatG);

  @override
  int get hashCode => Object.hash(calories, proteinG, carbsG, fatG);

  @override
  String toString() =>
      'DailyGoals(calories: $calories, protein: ${proteinG}g, '
      'carbs: ${carbsG}g, fat: ${fatG}g)';
}