/// Supported quantity units for meal entry.
///
/// Each unit carries its own display label and short symbol.
/// Adding a new unit here is the only change needed at the enum level —
/// [ServingConverter] must also be updated with the corresponding conversion.
enum ServingUnit {
  grams,
  pieces,
  cup,
  bowl,
  katori,
  tablespoon,
  teaspoon;

  /// Human-readable label shown in the dropdown.
  String get label {
    switch (this) {
      case ServingUnit.grams:
        return 'Grams';
      case ServingUnit.pieces:
        return 'Pieces';
      case ServingUnit.cup:
        return 'Cup';
      case ServingUnit.bowl:
        return 'Bowl';
      case ServingUnit.katori:
        return 'Katori';
      case ServingUnit.tablespoon:
        return 'Tablespoon';
      case ServingUnit.teaspoon:
        return 'Teaspoon';
    }
  }

  /// Short symbol shown next to the quantity field.
  String get symbol {
    switch (this) {
      case ServingUnit.grams:
        return 'g';
      case ServingUnit.pieces:
        return 'pc';
      case ServingUnit.cup:
        return 'cup';
      case ServingUnit.bowl:
        return 'bowl';
      case ServingUnit.katori:
        return 'katori';
      case ServingUnit.tablespoon:
        return 'tbsp';
      case ServingUnit.teaspoon:
        return 'tsp';
    }
  }
}