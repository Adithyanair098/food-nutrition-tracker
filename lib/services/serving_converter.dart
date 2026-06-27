import '../models/serving_unit.dart';

/// Converts a user-entered quantity and unit into grams.
///
/// [foodName] is accepted now so future milestones can introduce
/// food-specific lookup (e.g. 1 piece of banana ≠ 1 piece of watermelon)
/// without changing any call sites.
///
/// All conversion factors in this milestone are generic defaults.
/// Extend [_toGramsPerUnit] or [_pieceWeightFor] to improve accuracy later.
class ServingConverter {
  const ServingConverter();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the weight in grams for [quantity] of [unit].
  ///
  /// Always returns a positive value. Returns 0 only if [quantity] ≤ 0.
  double toGrams({
    required double quantity,
    required ServingUnit unit,
    String? foodName,
  }) {
    if (quantity <= 0) return 0;

    if (unit == ServingUnit.grams) return quantity;

    if (unit == ServingUnit.pieces) {
      return quantity * _pieceWeightFor(foodName);
    }

    return quantity * _toGramsPerUnit(unit);
  }

  // ---------------------------------------------------------------------------
  // Volume-based conversions (generic water density: 1 ml ≈ 1 g)
  // ---------------------------------------------------------------------------

  /// Returns grams-per-unit for volume-based units.
  /// Pieces are handled separately via [_pieceWeightFor].
  double _toGramsPerUnit(ServingUnit unit) {
    switch (unit) {
      case ServingUnit.cup:
        return 240; // 240 ml
      case ServingUnit.bowl:
        return 350; // 350 ml
      case ServingUnit.katori:
        return 150; // 150 ml
      case ServingUnit.tablespoon:
        return 15; // 15 ml
      case ServingUnit.teaspoon:
        return 5; // 5 ml
      case ServingUnit.grams:
      case ServingUnit.pieces:
        // These two are handled before this method is called.
        return 1;
    }
  }

  // ---------------------------------------------------------------------------
  // Piece-weight lookup
  // ---------------------------------------------------------------------------

  /// Returns the estimated weight in grams for a single piece of [foodName].
  ///
  /// Falls back to 100 g when the food is unknown.
  /// Keywords are matched case-insensitively against the food name.
  double _pieceWeightFor(String? foodName) {
    if (foodName == null || foodName.trim().isEmpty) return 100;

    final name = foodName.toLowerCase();

    // Common fruits
    if (_matches(name, ['banana'])) return 120;
    if (_matches(name, ['apple'])) return 182;
    if (_matches(name, ['orange'])) return 131;
    if (_matches(name, ['mango'])) return 200;
    if (_matches(name, ['egg', 'anda'])) return 50;

    // Bread / roti / chapati
    if (_matches(name, ['roti', 'chapati', 'chapatti', 'phulka'])) return 30;
    if (_matches(name, ['paratha', 'parantha'])) return 60;
    if (_matches(name, ['bread', 'slice', 'toast'])) return 30;
    if (_matches(name, ['idli'])) return 40;
    if (_matches(name, ['dosa'])) return 80;

    // Biscuits / snacks
    if (_matches(name, ['biscuit', 'cookie'])) return 10;

    // Generic fallback
    return 100;
  }

  bool _matches(String name, List<String> keywords) {
    return keywords.any((k) => name.contains(k));
  }
}