import 'package:flutter/foundation.dart';

/// Immutable snapshot of a user's nutrition progress against their daily goals.
///
/// Every field is pre-computed by [NutritionAggregator.calculateProgress].
/// The UI layer receives this object and renders it directly — no arithmetic
/// is performed inside any widget.
///
/// Progress values ([caloriesProgress], [proteinProgress], etc.) are
/// pre-clamped to [0.0, 1.0] and are ready to pass directly to
/// [LinearProgressIndicator.value].
@immutable
class DailyGoalsProgress {
  const DailyGoalsProgress({
    required this.caloriesConsumed,
    required this.caloriesGoal,
    required this.caloriesProgress,
    required this.proteinConsumedG,
    required this.proteinGoalG,
    required this.proteinProgress,
    required this.carbsConsumedG,
    required this.carbsGoalG,
    required this.carbsProgress,
    required this.fatConsumedG,
    required this.fatGoalG,
    required this.fatProgress,
  });

  // ── Calories ──────────────────────────────────────────────────────────────

  /// Total kilocalories consumed today.
  final double caloriesConsumed;

  /// User's daily calorie target in kcal.
  final double caloriesGoal;

  /// Consumed ÷ goal, clamped to [0.0, 1.0].
  final double caloriesProgress;

  // ── Protein ───────────────────────────────────────────────────────────────

  /// Total protein consumed today in grams.
  final double proteinConsumedG;

  /// User's daily protein target in grams.
  final double proteinGoalG;

  /// Consumed ÷ goal, clamped to [0.0, 1.0].
  final double proteinProgress;

  // ── Carbohydrates ─────────────────────────────────────────────────────────

  /// Total carbohydrates consumed today in grams.
  final double carbsConsumedG;

  /// User's daily carbohydrate target in grams.
  final double carbsGoalG;

  /// Consumed ÷ goal, clamped to [0.0, 1.0].
  final double carbsProgress;

  // ── Fat ───────────────────────────────────────────────────────────────────

  /// Total fat consumed today in grams.
  final double fatConsumedG;

  /// User's daily fat target in grams.
  final double fatGoalG;

  /// Consumed ÷ goal, clamped to [0.0, 1.0].
  final double fatProgress;

  // ── Convenience: integer percentages ─────────────────────────────────────
  //
  // These are display-formatting helpers, not business rules.
  // They prevent every label widget from independently writing
  // `(progress * 100).round()`.

  /// Calories progress as a whole percentage, e.g. 65.
  int get caloriesPercentage => (caloriesProgress * 100).round();

  /// Protein progress as a whole percentage.
  int get proteinPercentage => (proteinProgress * 100).round();

  /// Carbohydrates progress as a whole percentage.
  int get carbsPercentage => (carbsProgress * 100).round();

  /// Fat progress as a whole percentage.
  int get fatPercentage => (fatProgress * 100).round();

  // ── Convenience: exceeded flags ───────────────────────────────────────────
  //
  // Used by the UI to optionally render an over-goal colour state.
  // True only when consumed strictly exceeds the goal.

  bool get isCaloriesExceeded => caloriesConsumed > caloriesGoal;
  bool get isProteinExceeded  => proteinConsumedG  > proteinGoalG;
  bool get isCarbsExceeded    => carbsConsumedG    > carbsGoalG;
  bool get isFatExceeded      => fatConsumedG      > fatGoalG;

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyGoalsProgress &&
          other.caloriesConsumed == caloriesConsumed &&
          other.caloriesGoal     == caloriesGoal &&
          other.proteinConsumedG == proteinConsumedG &&
          other.proteinGoalG     == proteinGoalG &&
          other.carbsConsumedG   == carbsConsumedG &&
          other.carbsGoalG       == carbsGoalG &&
          other.fatConsumedG     == fatConsumedG &&
          other.fatGoalG         == fatGoalG);

  @override
  int get hashCode => Object.hash(
        caloriesConsumed,
        caloriesGoal,
        proteinConsumedG,
        proteinGoalG,
        carbsConsumedG,
        carbsGoalG,
        fatConsumedG,
        fatGoalG,
      );

  @override
  String toString() =>
      'DailyGoalsProgress('
      'calories: ${caloriesConsumed.toStringAsFixed(0)}/${caloriesGoal.toStringAsFixed(0)} kcal, '
      'protein: ${proteinConsumedG.toStringAsFixed(1)}/${proteinGoalG.toStringAsFixed(1)}g, '
      'carbs: ${carbsConsumedG.toStringAsFixed(1)}/${carbsGoalG.toStringAsFixed(1)}g, '
      'fat: ${fatConsumedG.toStringAsFixed(1)}/${fatGoalG.toStringAsFixed(1)}g)';
}