import 'package:flutter/foundation.dart';

/// A single logged meal with nutrition values already scaled to [weightGrams].
///
/// All macro fields represent **actual amounts consumed**, not per-100 g values.
/// Scaling is performed once in [NutritionResultScreen] before calling
/// [MealEntry.create], so no screen ever needs to repeat that calculation.
@immutable
class MealEntry {
  const MealEntry({
    required this.id,
    required this.foodName,
    required this.weightGrams,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG = 0.0,
    this.imagePath,
    required this.loggedAt,
    this.mealType = MealType.snack,
  });

  final String id;
  final String foodName;
  final double weightGrams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final String? imagePath;
  final DateTime loggedAt;
  final MealType mealType;

  // ── Factory ───────────────────────────────────────────────────────────────

  /// Creates a new entry with [id] and [loggedAt] set automatically.
  ///
  /// Use this factory in all production code. The primary constructor
  /// is reserved for [MealEntry.fromMap] and tests.
  factory MealEntry.create({
    required String foodName,
    required double weightGrams,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    double fiberG = 0.0,
    String? imagePath,
    MealType mealType = MealType.snack,
  }) {
    final now = DateTime.now();
    return MealEntry(
      id: now.millisecondsSinceEpoch.toString(),
      foodName: foodName,
      weightGrams: weightGrams,
      calories: calories,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      fiberG: fiberG,
      imagePath: imagePath,
      loggedAt: now,
      mealType: mealType,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  /// Column names follow SQLite snake_case conventions.
  /// The same map keys are reused as Firestore field names in a future
  /// milestone — no second serialisation format needed.
  Map<String, dynamic> toMap() => {
        'id': id,
        'food_name': foodName,
        'weight_grams': weightGrams,
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'fiber_g': fiberG,
        'image_path': imagePath,
        'logged_at': loggedAt.toIso8601String(),
        'meal_type': mealType.name,
      };

  factory MealEntry.fromMap(Map<String, dynamic> map) => MealEntry(
        id: map['id'] as String,
        foodName: map['food_name'] as String,
        weightGrams: (map['weight_grams'] as num).toDouble(),
        calories: (map['calories'] as num).toDouble(),
        proteinG: (map['protein_g'] as num).toDouble(),
        carbsG: (map['carbs_g'] as num).toDouble(),
        fatG: (map['fat_g'] as num).toDouble(),
        fiberG: (map['fiber_g'] as num?)?.toDouble() ?? 0.0,
        imagePath: map['image_path'] as String?,
        loggedAt: DateTime.parse(map['logged_at'] as String),
        mealType: MealType.fromName(map['meal_type'] as String? ?? 'snack'),
      );

  // ── Mutation ──────────────────────────────────────────────────────────────

  MealEntry copyWith({
    String? id,
    String? foodName,
    double? weightGrams,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    String? imagePath,
    DateTime? loggedAt,
    MealType? mealType,
  }) =>
      MealEntry(
        id: id ?? this.id,
        foodName: foodName ?? this.foodName,
        weightGrams: weightGrams ?? this.weightGrams,
        calories: calories ?? this.calories,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        fiberG: fiberG ?? this.fiberG,
        imagePath: imagePath ?? this.imagePath,
        loggedAt: loggedAt ?? this.loggedAt,
        mealType: mealType ?? this.mealType,
      );
  /// Returns a new [MealEntry] with all nutrition values proportionally
  /// rescaled to [newWeightGrams].
  ///
  /// This performs a pure ratio scale against the values already stored on
  /// this entry — it never re-derives or reconstructs the original
  /// per-100g AI prediction, and never contacts Gemini or any other
  /// service. It is the only sanctioned way to change a saved meal's
  /// weight: [FoodSelectionScreen] / [NutritionResultScreen] are never
  /// invoked during an edit.
  ///
  /// [id] and [loggedAt] are deliberately never overridden here — editing
  /// must update the existing record in place, never create a new one.
  ///
  /// Throws [ArgumentError] if [newWeightGrams] is not positive, or if the
  /// current [weightGrams] is zero (which would make the scale ratio
  /// undefined and silently corrupt saved values with NaN).
  MealEntry recalculatedForWeight(double newWeightGrams) {
    if (newWeightGrams <= 0) {
      throw ArgumentError.value(
        newWeightGrams,
        'newWeightGrams',
        'Weight must be greater than zero.',
      );
    }
    if (weightGrams <= 0) {
      throw StateError(
        'Cannot rescale MealEntry "$id": current weightGrams is zero.',
      );
    }

    final ratio = newWeightGrams / weightGrams;

    return copyWith(
      weightGrams: newWeightGrams,
      calories: calories * ratio,
      proteinG: proteinG * ratio,
      carbsG: carbsG * ratio,
      fatG: fatG * ratio,
      fiberG: fiberG * ratio,
    );
  }
  // ── Computed ──────────────────────────────────────────────────────────────

  /// Sum of the three tracked macros in grams.
  double get totalMacrosG => proteinG + carbsG + fatG;

  // ── Equality ──────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is MealEntry && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MealEntry(id: $id, food: $foodName, ${weightGrams}g, '
      '${calories.toStringAsFixed(1)} kcal, type: ${mealType.name})';
}

// ── MealType ──────────────────────────────────────────────────────────────────

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  /// Falls back to [snack] for any unrecognised string — prevents crashes
  /// if a future DB migration adds a new type and an older build reads it.
  static MealType fromName(String name) => MealType.values.firstWhere(
        (e) => e.name == name,
        orElse: () => MealType.snack,
      );

  String get displayName => switch (this) {
        MealType.breakfast => 'Breakfast',
        MealType.lunch     => 'Lunch',
        MealType.dinner    => 'Dinner',
        MealType.snack     => 'Snack',
      };

  String get emoji => switch (this) {
        MealType.breakfast => '🌅',
        MealType.lunch     => '☀️',
        MealType.dinner    => '🌙',
        MealType.snack     => '🍎',
      };
}