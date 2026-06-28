import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_goals.dart';
import 'goals_repository.dart';

/// SharedPreferences-backed implementation of [GoalsRepository].
///
/// ── Why SharedPreferences, not SQLite ─────────────────────────────────────
/// Goals are a single document of four scalar values that the user
/// occasionally overwrites. SharedPreferences is the correct tool for
/// this shape of data. Extending the SQLite schema would add relational
/// infrastructure to solve a key-value problem.
///
/// ── Key ownership ──────────────────────────────────────────────────────────
/// SharedPreferences key strings are defined on [DailyGoals] (via toMap /
/// allKeys), not here. This ensures a key rename is always a one-file change.
///
/// ── Firebase migration ─────────────────────────────────────────────────────
/// Create [FirebaseGoalsRepository] implementing [GoalsRepository] and
/// update the binding site. This class remains untouched.
class LocalGoalsRepository implements GoalsRepository {
  // SharedPreferences instance is cached after the first load to avoid
  // repeated async initialisation on every read/write call.
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _resolvedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  @override
  Future<DailyGoals> loadGoals() async {
    final prefs = await _resolvedPrefs;

    // Build a map from stored keys. Missing keys return null, which
    // DailyGoals.fromMap replaces with the appropriate default value.
    final map = {
      for (final key in DailyGoals.allKeys)
        key: prefs.getDouble(key),
    }.cast<String, double?>();

    // Filter out null entries before passing to fromMap so the type
    // resolves cleanly to Map<String, double>.
    final presentValues = <String, double>{
      for (final entry in map.entries)
        if (entry.value != null) entry.key: entry.value!,
    };

    return DailyGoals.fromMap(presentValues);
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  @override
  Future<void> saveGoals(DailyGoals goals) async {
    final prefs = await _resolvedPrefs;
    final map = goals.toMap();

    // Write each key individually. SharedPreferences does not support
    // batch writes, so this is the idiomatic approach.
    for (final entry in map.entries) {
      await prefs.setDouble(entry.key, entry.value);
    }
  }

  @override
  Future<void> clearGoals() async {
    final prefs = await _resolvedPrefs;
    for (final key in DailyGoals.allKeys) {
      await prefs.remove(key);
    }
  }
}