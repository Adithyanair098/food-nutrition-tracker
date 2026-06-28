import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/daily_nutrition_summary.dart';
import '../repositories/local_meal_repository.dart';
import '../repositories/meal_repository.dart';
import '../services/meal_events.dart';
import '../services/nutrition_aggregator.dart';

/// Analytics tab — shows a 7-day calorie bar chart, average macros,
/// and a total meal count for the week.
///
/// Mirrors the same data-loading pattern as HomeScreen: kept alive by
/// IndexedStack, refreshed via MealEvents, pull-to-refresh supported.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.repository});

  final MealRepository? repository;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final MealRepository _repository;
  late final NutritionAggregator _aggregator;
  late final StreamSubscription<void> _mealChangesSubscription;

  /// One entry per day, index 0 = 6 days ago, index 6 = today.
  List<DailyNutritionSummary> _weekSummaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalMealRepository();
    _aggregator = NutritionAggregator(repository: _repository);
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
      final today = DateTime.now();

      // Fetch all 7 days in parallel — all local SQLite reads.
      final summaries = await Future.wait(
        List.generate(7, (i) {
          final day = today.subtract(Duration(days: 6 - i));
          return _aggregator.getSummaryForDay(day);
        }),
      );

      if (!mounted) return;
      setState(() {
        _weekSummaries = summaries;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load weekly data.')),
      );
    }
  }

  // ── Derived stats ─────────────────────────────────────────────────────────

  List<DailyNutritionSummary> get _activeDays =>
      _weekSummaries.where((s) => s.mealCount > 0).toList();

  double get _avgCalories {
    if (_activeDays.isEmpty) return 0;
    return _activeDays.fold(0.0, (sum, s) => sum + s.totalCalories) /
        _activeDays.length;
  }

  double get _avgProtein {
    if (_activeDays.isEmpty) return 0;
    return _activeDays.fold(0.0, (sum, s) => sum + s.totalProteinG) /
        _activeDays.length;
  }

  double get _avgCarbs {
    if (_activeDays.isEmpty) return 0;
    return _activeDays.fold(0.0, (sum, s) => sum + s.totalCarbsG) /
        _activeDays.length;
  }

  double get _avgFat {
    if (_activeDays.isEmpty) return 0;
    return _activeDays.fold(0.0, (sum, s) => sum + s.totalFatG) /
        _activeDays.length;
  }

  int get _totalMeals =>
      _weekSummaries.fold(0, (sum, s) => sum + s.mealCount);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final hasData = _activeDays.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'Last 7 Days',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Calories & macros overview',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        if (!hasData)
          _EmptyState()
        else ...[
          _CaloriesBarChart(
            summaries: _weekSummaries,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Avg Calories',
                  value: '${_avgCalories.toStringAsFixed(0)} kcal',
                  icon: Icons.local_fire_department_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Meals This Week',
                  value: '$_totalMeals',
                  icon: Icons.restaurant_rounded,
                  color: const Color(0xFF1565C0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MacroAveragesCard(
            avgProtein: _avgProtein,
            avgCarbs: _avgCarbs,
            avgFat: _avgFat,
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sub-Widgets
// ═══════════════════════════════════════════════════════════════════════════

/// 7-bar chart — one bar per day, today highlighted in primary green.
class _CaloriesBarChart extends StatelessWidget {
  final List<DailyNutritionSummary> summaries;

  const _CaloriesBarChart({required this.summaries});

  @override
  Widget build(BuildContext context) {
    final maxCal = summaries
        .map((s) => s.totalCalories)
        .fold(0.0, (a, b) => a > b ? a : b);
    // Always show a reasonable y-axis even if data is low.
    final chartMax = maxCal < 100 ? 500.0 : (maxCal * 1.3).ceilToDouble();
    final yInterval = (chartMax / 4).ceilToDouble();

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 20, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 16),
            child: Text(
              'Daily Calories',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: chartMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppTheme.divider,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: yInterval,
                      getTitlesWidget: (value, _) {
                        if (value == 0) return const SizedBox.shrink();
                        final label = value >= 1000
                            ? '${(value / 1000).toStringAsFixed(1)}k'
                            : value.toInt().toString();
                        return Text(
                          label,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= summaries.length) {
                          return const SizedBox.shrink();
                        }
                        final day =
                            today.subtract(Duration(days: 6 - idx));
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            weekdays[day.weekday - 1],
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(summaries.length, (i) {
                  final cal = summaries[i].totalCalories;
                  // index 6 = today
                  final isToday = i == 6;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        // Show a tiny stub for empty days so the bar is visible.
                        toY: cal == 0 ? 0.5 : cal,
                        color: isToday
                            ? AppTheme.primary
                            : AppTheme.primaryLight.withAlpha(160),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single summary metric card.
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Average daily macros — protein, carbs, fat side by side.
class _MacroAveragesCard extends StatelessWidget {
  final double avgProtein;
  final double avgCarbs;
  final double avgFat;

  const _MacroAveragesCard({
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Average Daily Macros',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MacroColumn(
                  label: 'Protein',
                  value: avgProtein,
                  color: const Color(0xFF1565C0),
                ),
              ),
              Expanded(
                child: _MacroColumn(
                  label: 'Carbs',
                  value: avgCarbs,
                  color: const Color(0xFFF57F17),
                ),
              ),
              Expanded(
                child: _MacroColumn(
                  label: 'Fat',
                  value: avgFat,
                  color: const Color(0xFFC62828),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroColumn extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(
          '${value.toStringAsFixed(1)}g',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

/// Shown when no meals have been logged in the past 7 days.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 56,
            color: AppTheme.textSecondary.withAlpha(80),
          ),
          const SizedBox(height: 16),
          const Text(
            'No data yet',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Log some meals and your weekly\ntrends will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}