class NutritionInfo {
  final double calories;  // kcal
  final double proteinG;  // grams
  final double carbsG;    // grams
  final double fatG;      // grams
  final double fiberG;    // grams

  const NutritionInfo({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: (json['calories'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      carbsG:   (json['carbs_g']   as num).toDouble(),
      fatG:     (json['fat_g']     as num).toDouble(),
      fiberG:   (json['fiber_g']   as num).toDouble(),
    );
  }

  /// Returns a new NutritionInfo scaled from per-100 g to [weightG] grams.
  NutritionInfo scaledTo(double weightG) {
    final factor = weightG / 100.0;
    return NutritionInfo(
      calories: calories * factor,
      proteinG: proteinG * factor,
      carbsG:   carbsG   * factor,
      fatG:     fatG     * factor,
      fiberG:   fiberG   * factor,
    );
  }
}