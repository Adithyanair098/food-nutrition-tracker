import '../models/daily_goals.dart';

/// Contract for all goals persistence backends.
///
/// Screens and services depend only on this interface.
/// The current implementation uses SharedPreferences.
/// A future Firebase implementation requires zero screen changes —
/// only the binding site in the widget tree is updated.
abstract class GoalsRepository {
  /// Loads the user's saved daily goals.
  ///
  /// Returns [DailyGoals.defaults] if no goals have been saved yet,
  /// so callers always receive a valid, non-null object.
  Future<DailyGoals> loadGoals();

  /// Persists [goals], replacing any previously saved values.
  Future<void> saveGoals(DailyGoals goals);

  /// Removes all stored goal values, reverting to [DailyGoals.defaults]
  /// on the next [loadGoals] call. Primarily useful in tests.
  Future<void> clearGoals();
}