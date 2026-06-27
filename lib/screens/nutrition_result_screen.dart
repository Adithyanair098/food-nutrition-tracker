import 'dart:io';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/nutrition_info.dart';

class NutritionResultScreen extends StatelessWidget {
  final File imageFile;
  final String confirmedFoodName;
  final double weightG;
  final NutritionInfo nutritionPer100g;

  const NutritionResultScreen({
    super.key,
    required this.imageFile,
    required this.confirmedFoodName,
    required this.weightG,
    required this.nutritionPer100g,
  });

  @override
  Widget build(BuildContext context) {
    // Scale all values from per-100 g to the user's actual weight
    final scaled = nutritionPer100g.scaledTo(weightG);

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition Result')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Food Image ─────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  imageFile,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),

              // ── Food Name + Weight Badge ───────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      confirmedFoodName,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _WeightBadge(weightG: weightG),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'AI-estimated values · Exact USDA data added in next update',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),

              // ── Calories Card ──────────────────────────────────────────
              _CalorieCard(calories: scaled.calories),
              const SizedBox(height: 14),

              // ── Macros Row ─────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _MacroCard(
                      label: 'Protein',
                      value: scaled.proteinG,
                      color: const Color(0xFF1565C0),
                      icon: Icons.fitness_center_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MacroCard(
                      label: 'Carbs',
                      value: scaled.carbsG,
                      color: const Color(0xFFF57F17),
                      icon: Icons.grain_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MacroCard(
                      label: 'Fat',
                      value: scaled.fatG,
                      color: const Color(0xFFC62828),
                      icon: Icons.water_drop_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Fiber Card ─────────────────────────────────────────────
              _FiberRow(fiberG: scaled.fiberG),
              const SizedBox(height: 36),

              // ── Actions ────────────────────────────────────────────────
              ElevatedButton(
                onPressed: () {
                  // TODO M5: Save meal to SQLite database here.
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Meal saving will be implemented in Milestone 5.'),
                      backgroundColor: AppTheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: const Text('Save Meal'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  // Pop all pushed routes back to MainScaffold
                  Navigator.of(context)
                      .popUntil((route) => route.isFirst);
                },
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                child: const Text('Discard & Start Over'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private Sub-Widgets
// ═══════════════════════════════════════════════════════════════════════════

class _WeightBadge extends StatelessWidget {
  final double weightG;
  const _WeightBadge({required this.weightG});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${weightG.toStringAsFixed(0)} g',
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _CalorieCard extends StatelessWidget {
  final double calories;
  const _CalorieCard({required this.calories});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Calories',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                '${calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _MacroCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${value.toStringAsFixed(1)} g',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiberRow extends StatelessWidget {
  final double fiberG;
  const _FiberRow({required this.fiberG});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.grass_rounded,
              color: AppTheme.primaryLight, size: 20),
          const SizedBox(width: 10),
          const Text(
            'Dietary Fiber',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const Spacer(),
          Text(
            '${fiberG.toStringAsFixed(1)} g',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}