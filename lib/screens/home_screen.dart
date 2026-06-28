import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/daily_goals_progress.dart';
import '../models/daily_nutrition_summary.dart';
import '../repositories/goals_repository.dart';
import '../repositories/local_goals_repository.dart';
import '../repositories/local_meal_repository.dart';
import '../repositories/meal_repository.dart';
import '../services/meal_events.dart';
import '../services/nutrition_aggregator.dart';
import 'goal_settings_screen.dart';

/// Home tab — shows today's nutrition progress against the user's daily goals.
///
/// Lives as a kept-alive sibling tab inside [IndexedStack] so it never reruns
/// [initState] on tab switches. Post-save refresh is driven by [MealEvents].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository, this.goalsRepository});

  final MealRepository? repository;
  final GoalsRepository? goalsRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MealRepository _repository;
  late final GoalsRepository _goalsRepository;
  late final NutritionAggregator _aggregator;
  late final StreamSubscription<void> _mealChangesSubscription;

  DailyNutritionSummary? _summary;
  DailyGoalsProgress? _progress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository      = widget.repository      ?? LocalMealRepository();
    _goalsRepository = widget.goalsRepository ?? LocalGoalsRepository();
    _aggregator      = NutritionAggregator(repository: _repository);
    _loadData();
    _mealChangesSubscription =
        MealEvents.instance.changes.listen((_) => _loadData());
  }

  @override
  void dispose() {
    _mealChangesSubscription.cancel();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    try {
      final summaryFuture = _aggregator.getSummaryForDay(DateTime.now());
      final goalsFuture   = _goalsRepository.loadGoals();

      final summary  = await summaryFuture;
      final goals    = await goalsFuture;
      final progress = NutritionAggregator.calculateProgress(summary, goals);

      if (!mounted) return;
      setState(() {
        _summary   = summary;
        _progress  = progress;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not load today's summary.")),
      );
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _openGoalSettings() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GoalSettingsScreen(repository: _goalsRepository),
      ),
    );
    if (saved == true && mounted) _loadData();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calivio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_rounded),
            color: AppTheme.textSecondary,
            tooltip: 'Daily Goals',
            onPressed: _openGoalSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildDashboard(),
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final progress = _progress!;
    final summary  = _summary!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _DashboardHeader(
          mealCount: summary.mealCount,
          onGoalsTap: _openGoalSettings,
        ),
        const SizedBox(height: 20),

        // Calories — full-width card with circular ring
        _CaloriesProgressCard(progress: progress),
        const SizedBox(height: 12),

        // Macros — three equal-width cards with circular rings
        Row(
          children: [
            Expanded(
              child: _MacroProgressCard(
                label: 'Protein',
                consumedG: progress.proteinConsumedG,
                goalG: progress.proteinGoalG,
                progressValue: progress.proteinProgress,
                percentage: progress.proteinPercentage,
                isExceeded: progress.isProteinExceeded,
                color: const Color(0xFF1565C0),
                icon: Icons.fitness_center_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MacroProgressCard(
                label: 'Carbs',
                consumedG: progress.carbsConsumedG,
                goalG: progress.carbsGoalG,
                progressValue: progress.carbsProgress,
                percentage: progress.carbsPercentage,
                isExceeded: progress.isCarbsExceeded,
                color: const Color(0xFFF57F17),
                icon: Icons.grain_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MacroProgressCard(
                label: 'Fat',
                consumedG: progress.fatConsumedG,
                goalG: progress.fatGoalG,
                progressValue: progress.fatProgress,
                percentage: progress.fatPercentage,
                isExceeded: progress.isFatExceeded,
                color: const Color(0xFFC62828),
                icon: Icons.water_drop_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _EditGoalsRow(onTap: _openGoalSettings),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Ring Painter — shared by both card types
// ═══════════════════════════════════════════════════════════════════════════

/// Draws a circular track + a progress arc starting from 12 o'clock.
class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc — clockwise from 12 o'clock
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweepAngle,
        false,
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.progressColor != progressColor;
}

/// Wraps [_RingPainter] in a fixed-size box and centres any [child] inside.
class _CircularProgress extends StatelessWidget {
  final double progress;
  final double size;
  final double strokeWidth;
  final Color trackColor;
  final Color progressColor;
  final Widget? child;

  const _CircularProgress({
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.trackColor,
    required this.progressColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          trackColor: trackColor,
          progressColor: progressColor,
          strokeWidth: strokeWidth,
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Private Sub-Widgets
// ═══════════════════════════════════════════════════════════════════════════

/// Today's date and a meal count badge.
class _DashboardHeader extends StatelessWidget {
  final int mealCount;
  final VoidCallback onGoalsTap;

  const _DashboardHeader({
    required this.mealCount,
    required this.onGoalsTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final months   = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    final dateLabel =
        '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$mealCount ${mealCount == 1 ? 'meal' : 'meals'} today',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width calories card — text on the left, large progress ring on the right.
class _CaloriesProgressCard extends StatelessWidget {
  final DailyGoalsProgress progress;

  const _CaloriesProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final exceeded   = progress.isCaloriesExceeded;
    final ringColor  = exceeded ? Colors.orange.shade300 : Colors.white;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // ── Left: labels & values ──────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Calories',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  progress.caloriesConsumed.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const Text(
                  'kcal consumed',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'of ${progress.caloriesGoal.toStringAsFixed(0)} kcal goal',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                if (exceeded) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Goal exceeded',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 16),

          // ── Right: large circular ring ─────────────────────────────────
          _CircularProgress(
            progress: progress.caloriesProgress,
            size: 96,
            strokeWidth: 9,
            trackColor: Colors.white24,
            progressColor: ringColor,
            child: Text(
              '${progress.caloriesPercentage}%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact macro card — circular ring at top, amounts below.
class _MacroProgressCard extends StatelessWidget {
  final String label;
  final double consumedG;
  final double goalG;
  final double progressValue;
  final int percentage;
  final bool isExceeded;
  final Color color;
  final IconData icon;

  const _MacroProgressCard({
    required this.label,
    required this.consumedG,
    required this.goalG,
    required this.progressValue,
    required this.percentage,
    required this.isExceeded,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = isExceeded ? Colors.orange : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          // Circular ring with percentage inside
          _CircularProgress(
            progress: progressValue,
            size: 64,
            strokeWidth: 7,
            trackColor: AppTheme.divider,
            progressColor: ringColor,
            child: Text(
              '$percentage%',
              style: TextStyle(
                color: ringColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Icon + label
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Consumed
          Text(
            '${consumedG.toStringAsFixed(1)}g',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),

          // Goal
          Text(
            'of ${goalG.toStringAsFixed(0)}g',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable row nudging the user to review or edit their goals.
class _EditGoalsRow extends StatelessWidget {
  final VoidCallback onTap;

  const _EditGoalsRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Row(
          children: [
            Icon(Icons.flag_rounded, color: AppTheme.primaryLight, size: 18),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Edit daily goals',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}