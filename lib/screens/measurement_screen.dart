import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/nutrition_info.dart';
import '../models/serving_unit.dart';
import '../repositories/local_meal_repository.dart';
import '../services/serving_converter.dart';
import 'nutrition_result_screen.dart';

class MeasurementScreen extends StatefulWidget {
  final File imageFile;
  final String confirmedFoodName;
  final NutritionInfo nutritionPer100g;

  const MeasurementScreen({
    super.key,
    required this.imageFile,
    required this.confirmedFoodName,
    required this.nutritionPer100g,
  });

  @override
  State<MeasurementScreen> createState() => _MeasurementScreenState();
}

class _MeasurementScreenState extends State<MeasurementScreen> {
  // false = weight mode (grams), true = quantity mode (pieces / cups / etc.)
  bool _useQuantityMode = false;

  final TextEditingController _gramsController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  // Grams excluded from the quantity dropdown — that's what weight mode is for.
  static final List<ServingUnit> _quantityUnits =
      ServingUnit.values.where((u) => u != ServingUnit.grams).toList();

  ServingUnit _selectedUnit = ServingUnit.pieces;

  @override
  void dispose() {
    _gramsController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // ── Derived state ──────────────────────────────────────────────────────

  bool get _canProceed {
    if (_useQuantityMode) {
      final qty = double.tryParse(_quantityController.text.trim());
      return qty != null && qty > 0;
    }
    final g = double.tryParse(_gramsController.text.trim());
    return g != null && g > 0;
  }

  /// Resolves the user's input to grams.
  /// ServingConverter now has the confirmed food name, so piece-weight
  /// lookup is accurate (e.g. "Egg" → 50 g, "Idli" → 40 g).
  double get _resolvedWeightG {
    if (_useQuantityMode) {
      return const ServingConverter().toGrams(
        quantity: double.parse(_quantityController.text.trim()),
        unit: _selectedUnit,
        foodName: widget.confirmedFoodName,
      );
    }
    return double.parse(_gramsController.text.trim());
  }

  /// Live preview shown below the quantity field while the user types.
  String get _conversionPreview {
    final qty = double.tryParse(_quantityController.text.trim());
    if (qty == null || qty <= 0) return '';
    final g = const ServingConverter().toGrams(
      quantity: qty,
      unit: _selectedUnit,
      foodName: widget.confirmedFoodName,
    );
    return '≈ ${g.toStringAsFixed(0)} g';
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  void _onContinue() {
    if (!_canProceed) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionResultScreen(
          imageFile: widget.imageFile,
          confirmedFoodName: widget.confirmedFoodName,
          weightG: _resolvedWeightG,
          nutritionPer100g: widget.nutritionPer100g,
          repository: LocalMealRepository(),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Amount')),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Food image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        widget.imageFile,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Confirmed food name
                    Text(
                      widget.confirmedFoodName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 28),

                    // Mode toggle
                    Text(
                      'How would you like to measure?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Weight (g)'),
                          icon: Icon(Icons.scale_rounded),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Quantity'),
                          icon: Icon(Icons.format_list_numbered_rounded),
                        ),
                      ],
                      selected: {_useQuantityMode},
                      onSelectionChanged: (s) =>
                          setState(() => _useQuantityMode = s.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 28),

                    // Input area — swaps based on mode
                    if (!_useQuantityMode)
                      _WeightInputField(
                        controller: _gramsController,
                        onChanged: (_) => setState(() {}),
                      )
                    else
                      _QuantityInputField(
                        controller: _quantityController,
                        selectedUnit: _selectedUnit,
                        units: _quantityUnits,
                        conversionPreview: _conversionPreview,
                        onChanged: (_) => setState(() {}),
                        onUnitChanged: (unit) =>
                            setState(() => _selectedUnit = unit),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Fixed bottom button — same pattern as FoodSelectionScreen
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: ElevatedButton(
                onPressed: _canProceed ? _onContinue : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  disabledBackgroundColor: AppTheme.divider,
                  disabledForegroundColor: AppTheme.textSecondary,
                ),
                child: const Text('Continue  →'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private Sub-Widgets
// ═══════════════════════════════════════════════════════════════════════════

/// Simple grams input — identical to the original weight field from Milestone 2.
class _WeightInputField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _WeightInputField(
      {required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Weight in grams',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'e.g. 150',
            suffixText: 'g',
            suffixStyle: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Weigh your food first, then enter the value above.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

/// Quantity + unit row with a live gram conversion preview below.
class _QuantityInputField extends StatelessWidget {
  final TextEditingController controller;
  final ServingUnit selectedUnit;
  final List<ServingUnit> units;
  final String conversionPreview;
  final ValueChanged<String> onChanged;
  final ValueChanged<ServingUnit> onUnitChanged;

  const _QuantityInputField({
    required this.controller,
    required this.selectedUnit,
    required this.units,
    required this.conversionPreview,
    required this.onChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantity', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Number field (40% of row)
            Expanded(
              flex: 4,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: 'e.g. 2',
                  suffixText: selectedUnit.symbol,
                  suffixStyle: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Unit dropdown (60% of row)
            Expanded(
              flex: 6,
              child: DropdownButtonFormField<ServingUnit>(
                value: selectedUnit,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                items: units
                    .map((unit) => DropdownMenuItem(
                          value: unit,
                          child: Text(unit.label),
                        ))
                    .toList(),
                onChanged: (unit) {
                  if (unit != null) onUnitChanged(unit);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Shows live gram estimate while the user types
        if (conversionPreview.isNotEmpty)
          Text(
            conversionPreview,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          )
        else
          const Text(
            'Enter quantity and select the unit.',
            style:
                TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
      ],
    );
  }
}