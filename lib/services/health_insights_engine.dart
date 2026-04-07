// Health Insights Engine - Rule-Based Pattern Detection
// Analyzes user health data and generates actionable insights
// No ML, no diagnoses - pattern detection only

import '../models/food_log_model.dart';
import '../models/health_insights_models.dart';
import '../models/health_metric_model.dart';
import '../models/hydration_model.dart';
import '../models/mood_log_model.dart';
import '../models/workout_model.dart';
import '../models/period_cycle_model.dart';

class HealthInsightsEngine {
  static const int _baselineDays = 90;
  static const int _trendWindowDays = 14;
  static const int _minimumDataDays = 2; // Show insights earlier with sparse logs

  /// Generate comprehensive health insights from user data
  UserHealthInsights generateInsights({
    required List<HealthMetricModel> healthMetrics,
    required List<WorkoutModel> workouts,
    required List<HydrationModel> hydrationLogs,
    required List<MoodLogModel> moodLogs,
    required List<FoodLogModel> foodLogs,
    List<PeriodCycleModel>? periodCycles,
  }) {
    final insights = <HealthInsight>[];

    final daysOfData = _calculateDaysOfData(
      healthMetrics,
      workouts,
      hydrationLogs,
      moodLogs,
      foodLogs,
    );

    if (daysOfData < _minimumDataDays) {
      return UserHealthInsights(
        insights: [
          HealthInsight(
            id: 'insufficient_data',
            title: 'More Data Needed',
            severity: InsightSeverity.info,
            category: InsightCategory.activity,
            explanation: 'Keep logging your health data for at least $_minimumDataDays days to receive personalized insights.',
            contributingFactors: ['Current data: $daysOfData days'],
            recommendations: ['Log your meals, workouts, mood, and water intake daily'],
          ),
        ],
        daysOfDataAvailable: daysOfData,
      );
    }

    // Run all analysis modules
    insights.addAll(_analyzeWeightAndActivity(healthMetrics, workouts));
    insights.addAll(_analyzeSleep(healthMetrics));
    insights.addAll(_analyzeHydration(hydrationLogs, workouts));
    insights.addAll(_analyzeStress(healthMetrics));
    insights.addAll(_analyzeMood(moodLogs));
    insights.addAll(_analyzeNutrition(foodLogs));
    insights.addAll(_analyzeExerciseConsistency(workouts));
    insights.addAll(_analyzeRecovery(workouts, healthMetrics));
    insights.addAll(_analyzeMoodActivityCorrelation(moodLogs, workouts));
    insights.addAll(_analyzeHydrationMoodCorrelation(hydrationLogs, moodLogs));

    if (periodCycles != null && periodCycles.isNotEmpty) {
      insights.addAll(_analyzeMenstrualPatterns(periodCycles, healthMetrics));
    }

    // Sort by severity (critical first)
    insights.sort((a, b) => b.severity.index.compareTo(a.severity.index));

    return UserHealthInsights(
      insights: insights,
      daysOfDataAvailable: daysOfData,
    );
  }

  // ================= WEIGHT & ACTIVITY ANALYSIS =================

  List<HealthInsight> _analyzeWeightAndActivity(
    List<HealthMetricModel> metrics,
    List<WorkoutModel> workouts,
  ) {
    final insights = <HealthInsight>[];

    final weightTrend = _calculateMetricTrend(
      metrics: metrics,
      getValue: (m) => m.weight,
      metricName: 'Weight',
    );

    final activityTrend = _calculateActivityTrend(workouts);

    // Weight increasing + activity decreasing
    if (weightTrend != null &&
        activityTrend != null &&
        weightTrend.trendDirection == TrendDirection.increasing &&
        activityTrend.trendDirection == TrendDirection.decreasing &&
        weightTrend.percentChange > 3) {
      insights.add(
        HealthInsight(
          id: 'weight_activity_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Weight Increase with Reduced Activity',
          severity: InsightSeverity.attention,
          category: InsightCategory.weight,
          explanation: 'Your weight has increased while your activity level has decreased over recent weeks.',
          contributingFactors: [
            'Weight change: +${weightTrend.percentChange.toStringAsFixed(1)}%',
            'Workout frequency trending down',
          ],
          recommendations: [
            'Try to maintain consistent workout schedule',
            'Consider adding 10-minute walks to your daily routine',
            'Review your calorie intake',
          ],
          iconName: 'scale',
        ),
      );
    }

    // Rapid weight loss warning
    if (weightTrend != null &&
        weightTrend.trendDirection == TrendDirection.decreasing &&
        weightTrend.percentChange.abs() > 5) {
      insights.add(
        HealthInsight(
          id: 'rapid_weight_loss_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Rapid Weight Change Detected',
          severity: InsightSeverity.warning,
          category: InsightCategory.weight,
          explanation: 'Your weight has decreased significantly in a short period. Rapid weight loss can affect your health.',
          contributingFactors: [
            'Weight change: ${weightTrend.percentChange.toStringAsFixed(1)}%',
          ],
          recommendations: [
            'Ensure you are eating enough calories',
            'Consider consulting a healthcare provider',
            'Monitor for fatigue or weakness',
          ],
          iconName: 'warning',
        ),
      );
    }

    return insights;
  }

  // ================= SLEEP ANALYSIS =================

  List<HealthInsight> _analyzeSleep(List<HealthMetricModel> metrics) {
    final insights = <HealthInsight>[];

    final sleepTrend = _calculateMetricTrend(
      metrics: metrics,
      getValue: (m) => m.sleepMinutes == null ? null : m.sleepMinutes! / 60,
      metricName: 'Sleep Duration',
    );

    if (sleepTrend != null &&
        sleepTrend.trendDirection == TrendDirection.decreasing &&
        sleepTrend.percentChange.abs() > 10) {
      insights.add(
        HealthInsight(
          id: 'sleep_decrease_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Reduced Sleep Duration',
          severity: InsightSeverity.attention,
          category: InsightCategory.sleep,
          explanation: 'Your average sleep duration has decreased compared to your baseline.',
          contributingFactors: [
            'Change: ${sleepTrend.percentChange.toStringAsFixed(1)}%',
            'Current avg: ${sleepTrend.currentValue.toStringAsFixed(1)} hours',
          ],
          recommendations: [
            'Aim for 7-9 hours of sleep per night',
            'Establish a consistent bedtime routine',
            'Limit screen time before bed',
            'Avoid caffeine after 2 PM',
          ],
          iconName: 'bedtime',
        ),
      );
    }

    // Check for consistently low sleep
    final recentMetrics = metrics.where((m) =>
      DateTime.now().difference(m.date).inDays <= 7 && m.sleepMinutes != null
    ).toList();

    if (recentMetrics.isNotEmpty) {
      final avgSleep = recentMetrics.map((m) => m.sleepMinutes! / 60).reduce((a, b) => a + b) / recentMetrics.length;
      if (avgSleep < 6) {
        insights.add(
          HealthInsight(
            id: 'low_sleep_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Insufficient Sleep',
            severity: InsightSeverity.warning,
            category: InsightCategory.sleep,
            explanation: 'You are consistently getting less than 6 hours of sleep, which can impact your health and performance.',
            contributingFactors: [
              'Average sleep: ${avgSleep.toStringAsFixed(1)} hours',
              'Recommended: 7-9 hours',
            ],
            recommendations: [
              'Prioritize sleep as part of your health routine',
              'Create a dark, quiet sleep environment',
              'Consider sleep tracking to identify patterns',
            ],
            iconName: 'nights_stay',
          ),
        );
      }
    }

    return insights;
  }

  // ================= HYDRATION ANALYSIS =================

  List<HealthInsight> _analyzeHydration(
    List<HydrationModel> logs,
    List<WorkoutModel> workouts,
  ) {
    final insights = <HealthInsight>[];

    final hydrationTrend = _calculateHydrationTrend(logs);
    final activityTrend = _calculateActivityTrend(workouts);

    // Low hydration with high activity
    if (hydrationTrend != null &&
        activityTrend != null &&
        hydrationTrend.currentValue < 1500 &&
        activityTrend.currentValue > 2) {
      insights.add(
        HealthInsight(
          id: 'hydration_activity_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Low Hydration with High Activity',
          severity: InsightSeverity.attention,
          category: InsightCategory.hydration,
          explanation: 'Your hydration levels appear low relative to your activity level.',
          contributingFactors: [
            'Avg daily intake: ${hydrationTrend.currentValue.toStringAsFixed(0)} ml',
            'Workouts per week: ${activityTrend.currentValue.toStringAsFixed(1)}',
          ],
          recommendations: [
            'Drink 500ml of water before workouts',
            'Carry a water bottle throughout the day',
            'Aim for at least 2000ml daily',
            'Increase intake on workout days',
          ],
          iconName: 'water_drop',
        ),
      );
    }

    // Consistently low hydration
    if (hydrationTrend != null && hydrationTrend.currentValue < 1200) {
      insights.add(
        HealthInsight(
          id: 'dehydration_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Dehydration Risk',
          severity: InsightSeverity.warning,
          category: InsightCategory.hydration,
          explanation: 'Your water intake is consistently below recommended levels.',
          contributingFactors: [
            'Current avg: ${hydrationTrend.currentValue.toStringAsFixed(0)} ml/day',
            'Minimum recommended: 1500-2000 ml/day',
          ],
          recommendations: [
            'Set hourly water reminders',
            'Start your day with a glass of water',
            'Eat water-rich foods (fruits, vegetables)',
          ],
          iconName: 'local_drink',
        ),
      );
    }

    return insights;
  }

  // ================= STRESS ANALYSIS =================

  List<HealthInsight> _analyzeStress(List<HealthMetricModel> metrics) {
    final insights = <HealthInsight>[];

    final recentMetrics = metrics.where((m) =>
      DateTime.now().difference(m.date).inDays <= 14
    ).toList();

    final highStressDays = recentMetrics
        .where((m) => m.stressLevel != null && m.stressLevel! >= 8)
        .length;

    final moderateStressDays = recentMetrics
        .where((m) => m.stressLevel != null && m.stressLevel! >= 6 && m.stressLevel! < 8)
        .length;

    if (highStressDays >= 5) {
      insights.add(
        HealthInsight(
          id: 'chronic_stress_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Chronic High Stress',
          severity: InsightSeverity.critical,
          category: InsightCategory.stress,
          explanation: 'You have experienced high stress levels for an extended period. Chronic stress can significantly impact your health.',
          contributingFactors: [
            'High stress days (last 2 weeks): $highStressDays',
          ],
          recommendations: [
            'Consider speaking with a mental health professional',
            'Practice daily relaxation techniques',
            'Identify and address stress triggers',
            'Ensure adequate sleep and exercise',
          ],
          iconName: 'psychology',
        ),
      );
    } else if (highStressDays >= 3) {
      insights.add(
        HealthInsight(
          id: 'elevated_stress_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Elevated Stress Levels',
          severity: InsightSeverity.warning,
          category: InsightCategory.stress,
          explanation: 'Multiple recent days show high stress levels.',
          contributingFactors: [
            'High stress days: $highStressDays',
            'Moderate stress days: $moderateStressDays',
          ],
          recommendations: [
            'Try meditation or deep breathing exercises',
            'Take short breaks during work',
            'Engage in physical activity',
            'Connect with friends or family',
          ],
          iconName: 'self_improvement',
        ),
      );
    }

    return insights;
  }

  // ================= MOOD ANALYSIS =================

  List<HealthInsight> _analyzeMood(List<MoodLogModel> moods) {
    final insights = <HealthInsight>[];

    if (moods.length < 3) return insights;

    final recent = moods.where((m) =>
      DateTime.now().difference(m.timestamp).inDays <= 7
    ).toList();

    if (recent.isEmpty) return insights;

    final lowMoodCount = recent.where((m) =>
      m.mood == 'bad' || m.mood == 'terrible' || m.intensity <= 3
    ).length;

    final veryLowMoodCount = recent.where((m) =>
      m.mood == 'terrible' || m.intensity <= 2
    ).length;

    if (veryLowMoodCount >= 3) {
      insights.add(
        HealthInsight(
          id: 'very_low_mood_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Persistent Low Mood',
          severity: InsightSeverity.critical,
          category: InsightCategory.mood,
          explanation: 'Your mood has been very low for several days. Your mental health is important.',
          contributingFactors: [
            'Very low mood entries: $veryLowMoodCount in past week',
          ],
          recommendations: [
            'Consider reaching out to a mental health professional',
            'Talk to someone you trust about how you are feeling',
            'Maintain basic self-care routines',
            'Remember that it is okay to ask for help',
          ],
          iconName: 'support',
        ),
      );
    } else if (lowMoodCount >= 3) {
      insights.add(
        HealthInsight(
          id: 'low_mood_pattern_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Low Mood Pattern Detected',
          severity: InsightSeverity.attention,
          category: InsightCategory.mood,
          explanation: 'Recent mood logs indicate a recurring low mood pattern.',
          contributingFactors: [
            'Low mood entries: $lowMoodCount in past week',
          ],
          recommendations: [
            'Engage in activities you enjoy',
            'Spend time outdoors in natural light',
            'Exercise can help improve mood',
            'Practice gratitude journaling',
          ],
          iconName: 'mood',
        ),
      );
    }

    return insights;
  }

  // ================= NUTRITION ANALYSIS =================

  List<HealthInsight> _analyzeNutrition(List<FoodLogModel> foodLogs) {
    final insights = <HealthInsight>[];

    final recentLogs = foodLogs.where((f) =>
      DateTime.now().difference(f.timestamp).inDays <= 7
    ).toList();

    if (recentLogs.length < 5) return insights;

    // Calculate averages
    final totalCalories = recentLogs.map((f) => f.calories).reduce((a, b) => a + b);
    final totalProtein = recentLogs.map((f) => f.protein).reduce((a, b) => a + b);
    final totalCarbs = recentLogs.map((f) => f.carbs).reduce((a, b) => a + b);
    final totalFats = recentLogs.map((f) => f.fats).reduce((a, b) => a + b);

    final days = recentLogs.map((f) =>
      DateTime(f.timestamp.year, f.timestamp.month, f.timestamp.day)
    ).toSet().length;

    if (days == 0) return insights;

    final avgCalories = totalCalories / days;
    final avgProtein = totalProtein / days;

    // Very low calorie warning
    if (avgCalories < 1200) {
      insights.add(
        HealthInsight(
          id: 'low_calories_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Very Low Calorie Intake',
          severity: InsightSeverity.warning,
          category: InsightCategory.nutrition,
          explanation: 'Your average daily calorie intake is below recommended minimum levels.',
          contributingFactors: [
            'Average: ${avgCalories.toStringAsFixed(0)} kcal/day',
            'Minimum recommended: 1200+ kcal/day',
          ],
          recommendations: [
            'Ensure you are eating enough to support your body',
            'Add nutrient-dense snacks between meals',
            'Consult a nutritionist if intentionally restricting',
          ],
          iconName: 'restaurant',
        ),
      );
    }

    // Low protein warning
    if (avgProtein < 40) {
      insights.add(
        HealthInsight(
          id: 'low_protein_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Low Protein Intake',
          severity: InsightSeverity.attention,
          category: InsightCategory.nutrition,
          explanation: 'Your protein intake may be insufficient for optimal health and muscle maintenance.',
          contributingFactors: [
            'Average: ${avgProtein.toStringAsFixed(0)}g/day',
            'Recommended: 50-60g+ per day',
          ],
          recommendations: [
            'Include protein in every meal',
            'Good sources: eggs, chicken, fish, legumes, dairy',
            'Consider protein-rich snacks like Greek yogurt or nuts',
          ],
          iconName: 'egg',
        ),
      );
    }

    // Check for meal skipping
    final breakfastCount = recentLogs.where((f) => f.mealType == 'breakfast').length;
    if (breakfastCount < days / 2) {
      insights.add(
        HealthInsight(
          id: 'skipping_breakfast_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Frequently Skipping Breakfast',
          severity: InsightSeverity.info,
          category: InsightCategory.nutrition,
          explanation: 'You seem to skip breakfast often. Eating breakfast can help maintain energy levels.',
          contributingFactors: [
            'Breakfasts logged: $breakfastCount out of $days days',
          ],
          recommendations: [
            'Try quick breakfast options like overnight oats',
            'Prepare breakfast items the night before',
            'Even a small breakfast is better than none',
          ],
          iconName: 'free_breakfast',
        ),
      );
    }

    return insights;
  }

  // ================= EXERCISE CONSISTENCY ANALYSIS =================

  List<HealthInsight> _analyzeExerciseConsistency(List<WorkoutModel> workouts) {
    final insights = <HealthInsight>[];

    final recentWorkouts = workouts.where((w) =>
      DateTime.now().difference(w.date).inDays <= 14
    ).toList();

    final olderWorkouts = workouts.where((w) =>
      DateTime.now().difference(w.date).inDays > 14 &&
      DateTime.now().difference(w.date).inDays <= 28
    ).toList();

    // No workouts in 2 weeks
    if (recentWorkouts.isEmpty && olderWorkouts.isNotEmpty) {
      insights.add(
        HealthInsight(
          id: 'no_exercise_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Exercise Gap Detected',
          severity: InsightSeverity.attention,
          category: InsightCategory.activity,
          explanation: 'You have not logged any workouts in the past 2 weeks.',
          contributingFactors: [
            'Previous 2-week workouts: ${olderWorkouts.length}',
            'Recent 2-week workouts: 0',
          ],
          recommendations: [
            'Start with short, manageable workout sessions',
            'Even a 15-minute walk counts as exercise',
            'Schedule workouts like appointments',
          ],
          iconName: 'fitness_center',
        ),
      );
    }

    // Great consistency
    if (recentWorkouts.length >= 6) {
      insights.add(
        HealthInsight(
          id: 'great_consistency_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Great Exercise Consistency!',
          severity: InsightSeverity.info,
          category: InsightCategory.activity,
          explanation: 'You have been working out consistently. Keep up the great work!',
          contributingFactors: [
            'Workouts in past 2 weeks: ${recentWorkouts.length}',
          ],
          recommendations: [
            'Consider increasing intensity gradually',
            'Add variety to prevent plateaus',
            'Ensure adequate rest between sessions',
          ],
          iconName: 'emoji_events',
        ),
      );
    }

    return insights;
  }

  // ================= RECOVERY ANALYSIS =================

  List<HealthInsight> _analyzeRecovery(
    List<WorkoutModel> workouts,
    List<HealthMetricModel> metrics,
  ) {
    final insights = <HealthInsight>[];

    // Check for overtraining signs
    final recentWorkouts = workouts.where((w) =>
      DateTime.now().difference(w.date).inDays <= 7
    ).toList();

    final recentMetrics = metrics.where((m) =>
      DateTime.now().difference(m.date).inDays <= 7
    ).toList();

    if (recentWorkouts.length >= 6) {
      final hasLowEnergy = recentMetrics.where((m) =>
        m.energyLevel != null && m.energyLevel! <= 3
      ).length >= 2;

      final hasHighStress = recentMetrics.where((m) =>
        m.stressLevel != null && m.stressLevel! >= 7
      ).length >= 2;

      if (hasLowEnergy || hasHighStress) {
        insights.add(
          HealthInsight(
            id: 'overtraining_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Possible Overtraining',
            severity: InsightSeverity.warning,
            category: InsightCategory.recovery,
            explanation: 'High workout frequency combined with low energy or high stress may indicate insufficient recovery.',
            contributingFactors: [
              'Workouts this week: ${recentWorkouts.length}',
              if (hasLowEnergy) 'Low energy days detected',
              if (hasHighStress) 'High stress days detected',
            ],
            recommendations: [
              'Take 1-2 rest days this week',
              'Focus on sleep quality',
              'Consider lighter workouts (yoga, walking)',
              'Ensure adequate protein intake',
            ],
            iconName: 'hotel',
          ),
        );
      }
    }

    return insights;
  }

  // ================= CORRELATION ANALYSIS =================

  List<HealthInsight> _analyzeMoodActivityCorrelation(
    List<MoodLogModel> moods,
    List<WorkoutModel> workouts,
  ) {
    final insights = <HealthInsight>[];

    if (moods.length < 7 || workouts.length < 3) return insights;

    // Group moods by date
    final moodByDate = <String, List<MoodLogModel>>{};
    for (final mood in moods) {
      final dateKey = '${mood.timestamp.year}-${mood.timestamp.month}-${mood.timestamp.day}';
      moodByDate[dateKey] = [...(moodByDate[dateKey] ?? []), mood];
    }

    // Check mood on workout vs non-workout days
    final workoutDates = workouts.map((w) =>
      '${w.date.year}-${w.date.month}-${w.date.day}'
    ).toSet();

    double workoutDayMood = 0;
    int workoutDayCount = 0;
    double nonWorkoutDayMood = 0;
    int nonWorkoutDayCount = 0;

    moodByDate.forEach((date, dayMoods) {
      final avgMood = dayMoods.map((m) => m.intensity).reduce((a, b) => a + b) / dayMoods.length;
      if (workoutDates.contains(date)) {
        workoutDayMood += avgMood;
        workoutDayCount++;
      } else {
        nonWorkoutDayMood += avgMood;
        nonWorkoutDayCount++;
      }
    });

    if (workoutDayCount >= 3 && nonWorkoutDayCount >= 3) {
      final avgWorkoutMood = workoutDayMood / workoutDayCount;
      final avgNonWorkoutMood = nonWorkoutDayMood / nonWorkoutDayCount;

      if (avgWorkoutMood > avgNonWorkoutMood + 1) {
        insights.add(
          HealthInsight(
            id: 'exercise_mood_boost_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Exercise Boosts Your Mood!',
            severity: InsightSeverity.info,
            category: InsightCategory.mood,
            explanation: 'Your mood tends to be better on days when you exercise.',
            contributingFactors: [
              'Workout day avg mood: ${avgWorkoutMood.toStringAsFixed(1)}/10',
              'Non-workout day avg: ${avgNonWorkoutMood.toStringAsFixed(1)}/10',
            ],
            recommendations: [
              'Use exercise as a tool to improve mood',
              'Even light activity can help on tough days',
            ],
            iconName: 'sentiment_very_satisfied',
          ),
        );
      }
    }

    return insights;
  }

  List<HealthInsight> _analyzeHydrationMoodCorrelation(
    List<HydrationModel> hydration,
    List<MoodLogModel> moods,
  ) {
    final insights = <HealthInsight>[];

    // Simple correlation check - days with good hydration vs mood
    // This is a simplified analysis

    return insights;
  }

  // ================= MENSTRUAL PATTERNS ANALYSIS =================

  List<HealthInsight> _analyzeMenstrualPatterns(
    List<PeriodCycleModel> cycles,
    List<HealthMetricModel> metrics,
  ) {
    final insights = <HealthInsight>[];

    if (cycles.length < 2) return insights;

    // Check cycle regularity
    final completedCycles = cycles.where((c) => c.endDate != null).toList();
    if (completedCycles.length >= 2) {
      final cycleLengths = <int>[];
      for (var i = 0; i < completedCycles.length - 1; i++) {
        final length = completedCycles[i + 1].startDate.difference(completedCycles[i].startDate).inDays;
        if (length > 0 && length < 60) {
          cycleLengths.add(length);
        }
      }

      if (cycleLengths.length >= 2) {
        final avgLength = cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
        final variance = cycleLengths.map((l) => (l - avgLength).abs()).reduce((a, b) => a + b) / cycleLengths.length;

        if (variance > 7) {
          insights.add(
            HealthInsight(
              id: 'irregular_cycle_${DateTime.now().millisecondsSinceEpoch}',
              title: 'Irregular Cycle Pattern',
              severity: InsightSeverity.attention,
              category: InsightCategory.menstrual,
              explanation: 'Your menstrual cycle length varies significantly between periods.',
              contributingFactors: [
                'Average cycle length: ${avgLength.toStringAsFixed(0)} days',
                'Variation: ±${variance.toStringAsFixed(0)} days',
              ],
              recommendations: [
                'Track your cycles consistently',
                'Note any symptoms or changes',
                'Consider discussing with a healthcare provider if concerning',
              ],
              iconName: 'calendar_today',
            ),
          );
        }
      }
    }

    return insights;
  }

  // ================= UTILITY METHODS =================

  HealthMetricTrend? _calculateMetricTrend({
    required List<HealthMetricModel> metrics,
    required double? Function(HealthMetricModel) getValue,
    required String metricName,
  }) {
    final now = DateTime.now();

    final recent = metrics
        .where((m) => now.difference(m.date).inDays <= _trendWindowDays)
        .map(getValue)
        .whereType<double>()
        .toList();

    final baseline = metrics
        .where((m) {
          final d = now.difference(m.date).inDays;
          return d > _trendWindowDays && d <= _baselineDays;
        })
        .map(getValue)
        .whereType<double>()
        .toList();

    if (recent.isEmpty) return null;

    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;

    // If no baseline, use recent as baseline
    final baseAvg = baseline.isNotEmpty
        ? baseline.reduce((a, b) => a + b) / baseline.length
        : recentAvg;

    final change = baseAvg != 0 ? ((recentAvg - baseAvg) / baseAvg) * 100 : 0.0;

    final direction = change.abs() < 2
        ? TrendDirection.stable
        : change > 0
            ? TrendDirection.increasing
            : TrendDirection.decreasing;

    return HealthMetricTrend(
      metricName: metricName,
      currentValue: recentAvg,
      baselineValue: baseAvg,
      percentChange: change,
      trendDirection: direction,
      dataPointsAnalyzed: recent.length + baseline.length,
    );
  }

  HealthMetricTrend? _calculateActivityTrend(List<WorkoutModel> workouts) {
    final now = DateTime.now();

    final recent = workouts.where((w) => now.difference(w.date).inDays <= 14).length;
    final baseline = workouts.where((w) =>
      now.difference(w.date).inDays > 14 && now.difference(w.date).inDays <= 28
    ).length;

    if (recent == 0 && baseline == 0) return null;

    final change = baseline != 0 ? ((recent - baseline) / baseline) * 100 : 0.0;

    final direction = change.abs() < 15
        ? TrendDirection.stable
        : change > 0
            ? TrendDirection.increasing
            : TrendDirection.decreasing;

    return HealthMetricTrend(
      metricName: 'Activity',
      currentValue: recent.toDouble(),
      baselineValue: baseline.toDouble(),
      percentChange: change,
      trendDirection: direction,
    );
  }

  HealthMetricTrend? _calculateHydrationTrend(List<HydrationModel> logs) {
    if (logs.isEmpty) return null;

    final now = DateTime.now();
    final recentLogs = logs.where((l) => now.difference(l.timestamp).inDays <= 7).toList();

    if (recentLogs.isEmpty) return null;

    // Group by day and calculate daily average
    final dailyTotals = <String, int>{};
    for (final log in recentLogs) {
      final dateKey = '${log.timestamp.year}-${log.timestamp.month}-${log.timestamp.day}';
      dailyTotals[dateKey] = (dailyTotals[dateKey] ?? 0) + log.amountMl;
    }

    final avgDaily = dailyTotals.values.reduce((a, b) => a + b) / dailyTotals.length;

    return HealthMetricTrend(
      metricName: 'Hydration',
      currentValue: avgDaily,
      baselineValue: avgDaily,
      percentChange: 0,
      trendDirection: TrendDirection.stable,
    );
  }

  int _calculateDaysOfData(
    List<HealthMetricModel> metrics,
    List<WorkoutModel> workouts,
    List<HydrationModel> hydration,
    List<MoodLogModel> moods,
    List<FoodLogModel> foods,
  ) {
    final dayKeys = <String>{};

    for (final m in metrics) {
      dayKeys.add('${m.date.year}-${m.date.month}-${m.date.day}');
    }
    for (final w in workouts) {
      dayKeys.add('${w.date.year}-${w.date.month}-${w.date.day}');
    }
    for (final h in hydration) {
      dayKeys.add('${h.timestamp.year}-${h.timestamp.month}-${h.timestamp.day}');
    }
    for (final mood in moods) {
      dayKeys.add('${mood.timestamp.year}-${mood.timestamp.month}-${mood.timestamp.day}');
    }
    for (final food in foods) {
      dayKeys.add('${food.timestamp.year}-${food.timestamp.month}-${food.timestamp.day}');
    }

    return dayKeys.length;
  }
}
