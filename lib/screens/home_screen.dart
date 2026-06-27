import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/daily_nutrition_summary.dart';
import '../repositories/local_meal_repository.dart';
import '../repositories/meal_repository.dart';
import '../services/meal_events.dart';
import '../services/nutrition_aggregator.dart';
import '../widgets/daily_summary_card.dart';

/// Home tab — shows today's aggregated nutrition summary.
///
/// Lives as a kept-alive sibling tab inside `main_scaffold.dart`'s
/// [IndexedStack], so it never reruns [State.initState] on tab switches.
/// Refreshing after a meal is saved elsewhere (a different tab's
/// navigation stack) is handled via [MealEvents] — see that file for why.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository});

  /// Optional override for tests. Defaults to the production
  /// [LocalMealRepository] when null.
  final MealRepository? repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final MealRepository _repository;
  late final NutritionAggregator _aggregator;
  late final StreamSubscription<void> _mealChangesSubscription;

  DailyNutritionSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalMealRepository();
    _aggregator = NutritionAggregator(repository: _repository);

    _loadSummary();

    // Bridges the gap between this tab and the Add Meal tab's save flow.
    // See meal_events.dart for the full rationale.
    _mealChangesSubscription = MealEvents.instance.changes.listen((_) {
      _loadSummary();
    });
  }

  @override
  void dispose() {
    _mealChangesSubscription.cancel();
    super.dispose();
  }

  /// Fetches and aggregates today's entries. Used for initial load,
  /// post-save refresh (via [MealEvents]), and manual pull-to-refresh.
  Future<void> _loadSummary() async {
    try {
      final summary = await _aggregator.getSummaryForDay(DateTime.now());
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load today\'s summary.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NutriLens'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              Icons.notifications_none_outlined,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSummary,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  // Required so the pull-to-refresh gesture works even
                  // when the content is shorter than the viewport.
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    DailySummaryCard(summary: _summary!),
                  ],
                ),
        ),
      ),
    );
  }
}