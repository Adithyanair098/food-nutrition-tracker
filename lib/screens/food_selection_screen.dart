import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/food_prediction.dart';
import '../services/gemini_service.dart';
import 'nutrition_result_screen.dart';

class FoodSelectionScreen extends StatefulWidget {
  final File imageFile;
  final double weightG;
  final GeminiAnalysisResult geminiResult;

  const FoodSelectionScreen({
    super.key,
    required this.imageFile,
    required this.weightG,
    required this.geminiResult,
  });

  @override
  State<FoodSelectionScreen> createState() => _FoodSelectionScreenState();
}

class _FoodSelectionScreenState extends State<FoodSelectionScreen> {
  int _selectedIndex = 0;   // default to top prediction
  bool _noneOfThese = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (_noneOfThese) {
      return _manualController.text.trim().isNotEmpty;
    }
    return true;
  }

  String get _confirmedFoodName {
    if (_noneOfThese) return _manualController.text.trim();
    return widget.geminiResult.predictions[_selectedIndex].name;
  }

  void _onConfirm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionResultScreen(
          imageFile: widget.imageFile,
          confirmedFoodName: _confirmedFoodName,
          weightG: widget.weightG,
          // M3: Gemini's estimate for the top prediction.
          // M4: Replace with USDA SQLite lookup for _confirmedFoodName.
          nutritionPer100g: widget.geminiResult.nutritionPer100g,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Food')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Food image thumbnail
                    _FoodImageThumbnail(imageFile: widget.imageFile),
                    const SizedBox(height: 20),

                    Text(
                      'AI identified your food as:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the correct option or choose "None of these."',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    // Prediction cards
                    ...List.generate(
                      widget.geminiResult.predictions.length,
                      (i) => _PredictionCard(
                        prediction: widget.geminiResult.predictions[i],
                        isSelected: !_noneOfThese && _selectedIndex == i,
                        onTap: () => setState(() {
                          _selectedIndex = i;
                          _noneOfThese = false;
                        }),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // "None of these" card
                    _NoneOfTheseCard(
                      isSelected: _noneOfThese,
                      controller: _manualController,
                      onTap: () => setState(() => _noneOfThese = true),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Fixed bottom button ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.divider)),
              ),
              child: ElevatedButton(
                onPressed: _canConfirm ? _onConfirm : null,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  disabledBackgroundColor: AppTheme.divider,
                  disabledForegroundColor: AppTheme.textSecondary,
                ),
                child: const Text('Confirm Food  →'),
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

class _FoodImageThumbnail extends StatelessWidget {
  final File imageFile;
  const _FoodImageThumbnail({required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.file(
        imageFile,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final FoodPrediction prediction;
  final bool isSelected;
  final VoidCallback onTap;

  const _PredictionCard({
    required this.prediction,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (prediction.confidence * 100).toStringAsFixed(0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppTheme.primary : Colors.transparent,
                border: Border.all(
                  color:
                      isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),

            // Food name + confidence bar
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prediction.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: prediction.confidence,
                            minHeight: 5,
                            backgroundColor: AppTheme.divider,
                            color: isSelected
                                ? AppTheme.primary
                                : AppTheme.primaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$percent%',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoneOfTheseCard extends StatelessWidget {
  final bool isSelected;
  final TextEditingController controller;
  final VoidCallback onTap;
  final ValueChanged<String> onChanged;

  const _NoneOfTheseCard({
    required this.isSelected,
    required this.controller,
    required this.onTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF8E1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppTheme.accent : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),
                const Text(
                  'None of these',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                onChanged: onChanged,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Type food name, e.g. "Pav Bhaji"',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}