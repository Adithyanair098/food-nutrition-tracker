import '../models/daily_goals.dart';
import '../models/daily_goals_progress.dart';
import '../models/daily_nutrition_summary.dart';
import '../models/meal_entry.dart';
import '../repositories/meal_repository.dart';

/// Converts logged [MealEntry] records into a [DailyNutritionSummary].
///
/// This class contains the only place in the app where "today's totals"
/// are calculated. Keeping it separate from both [MealRepository] (data
/// access) and any screen (presentation) means:
///
/// - The repository stays a thin data-access layer with no business rules.
/// - The math can be unit-tested with plain [MealEntry] lists — no
///   database, no async setup, no mocking required.
/// - Future features (weekly summaries, goal tracking, analytics charts)
///   can reuse [summarize] without duplicating the sum logic.
/// 
class NutritionAggregator {
  final MealRepository _repository;

  const NutritionAggregator({
    required this._repository,
  });
  
  /// Fetches all entries logged on [date] and returns their aggregated
  /// totals as a [DailyNutritionSummary].
  ///
  /// This is the method screens call directly. It performs I/O via the
  /// injected [MealRepository] — for a pure, testable version of just the
  /// math, see [summarize].
  Future<DailyNutritionSummary> getSummaryForDay(DateTime date) async {
    final entries = await _repository.getEntriesForDay(date);
    return summarize(entries, date);
  }

  /// Aggregates [entries] into a single [DailyNutritionSummary] for [date].
  ///
  /// Pure function — no database access, no side effects. [date] is
  /// normalised to midnight so the resulting summary always represents
  /// a whole calendar day regardless of the time component passed in.
  ///
  /// Returns [DailyNutritionSummary.empty] if [entries] is empty, so
  /// callers never need a null check for "no meals today".
  DailyNutritionSummary summarize(List<MealEntry> entries, DateTime date) {
    final normalisedDate = DateTime(date.year, date.month, date.day);

    if (entries.isEmpty) {
      return DailyNutritionSummary.empty(normalisedDate);
    }

    var totalCalories = 0.0;
    var totalProteinG = 0.0;
    var totalCarbsG = 0.0;
    var totalFatG = 0.0;
    var totalFiberG = 0.0;

    for (final entry in entries) {
      totalCalories += entry.calories;
      totalProteinG += entry.proteinG;
      totalCarbsG += entry.carbsG;
      totalFatG += entry.fatG;
      totalFiberG += entry.fiberG;
    }

    return DailyNutritionSummary(
      date: normalisedDate,
      totalCalories: totalCalories,
      totalProteinG: totalProteinG,
      totalCarbsG: totalCarbsG,
      totalFatG: totalFatG,
      totalFiberG: totalFiberG,
      mealCount: entries.length,
    );
  }

  /// Computes progress of [summary] against [goals].
  ///
  /// Pure static function — requires no repository, no instance, no async.
  /// All progress values in the returned [DailyGoalsProgress] are
  /// pre-clamped to [0.0, 1.0] and ready to pass directly to
  /// [LinearProgressIndicator.value].
  ///
  /// ── Clamp rationale ───────────────────────────────────────────────────
  /// Progress is clamped here (business layer) rather than in the widget.
  /// The rule "never render above 100%" is a business rule, not a display
  /// choice. The exceeded flags on [DailyGoalsProgress] let the UI
  /// independently signal an over-goal colour state.
  ///
  /// ── Zero-goal guard ───────────────────────────────────────────────────
  /// Division by a zero goal would produce NaN, which crashes
  /// [LinearProgressIndicator]. [_progress] returns 0.0 in that case.
  static DailyGoalsProgress calculateProgress(
    DailyNutritionSummary summary,
    DailyGoals goals,
  ) {
    return DailyGoalsProgress(
      caloriesConsumed: summary.totalCalories,
      caloriesGoal:     goals.calories,
      caloriesProgress: _progress(summary.totalCalories, goals.calories),
      proteinConsumedG: summary.totalProteinG,
      proteinGoalG:     goals.proteinG,
      proteinProgress:  _progress(summary.totalProteinG, goals.proteinG),
      carbsConsumedG:   summary.totalCarbsG,
      carbsGoalG:       goals.carbsG,
      carbsProgress:    _progress(summary.totalCarbsG, goals.carbsG),
      fatConsumedG:     summary.totalFatG,
      fatGoalG:         goals.fatG,
      fatProgress:      _progress(summary.totalFatG, goals.fatG),
    );
  }

  /// Divides [consumed] by [goal], clamped to [0.0, 1.0].
  ///
  /// Returns 0.0 if [goal] is zero or negative to prevent NaN / infinity.
  static double _progress(double consumed, double goal) {
    if (goal <= 0) return 0.0;
    return (consumed / goal).clamp(0.0, 1.0);
  }
}