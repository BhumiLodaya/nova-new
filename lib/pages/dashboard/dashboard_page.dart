import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/health_provider.dart';
import '../../providers/nutrition_providers.dart';
import '../../providers/wellness_providers.dart';
import '../../providers/sugar_log_provider.dart';
import '../../providers/streak_provider.dart';
import '../../services/database_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/success_animation_overlay.dart';
import '../../widgets/streak_milestone_popup.dart';
import '../../widgets/signup_gate_card.dart';
import '../../widgets/streak_widgets.dart';
import '../../widgets/glass_widgets.dart';
import '../leaderboard/leaderboard_page.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final hydrationTotal = ref.watch(todayHydrationTotalProvider);
    final nutritionTotals = ref.watch(todayNutritionTotalsProvider);
    final sugarState = ref.watch(sugarLogProvider);
    final streak = ref.watch(streakProvider);

    // Show milestone popup when a new milestone is reached
    ref.listen<StreakState>(streakProvider, (prev, next) {
      if (next.milestoneJustReached != null &&
          prev?.milestoneJustReached != next.milestoneJustReached) {
        StreakMilestonePopup.show(context, next.milestoneJustReached!);
      }
    });

    final weeklyStats = _calculateWeeklyStats(ref, user?.id);
    final sugarProgress =
        (sugarState.totalSugarToday / 50).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ═══════════════════════════════════════
                  //  CUSTOM HEADER (replaces AppBar)
                  // ═══════════════════════════════════════
                  const SizedBox(height: 8),
                  _DynamicIslandHeader(
                    userName: user?.fullName ?? user?.username ?? 'User',
                    streakDays: streak.currentStreak,
                    onLeaderboard: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const LeaderboardPage()),
                    ),
                    onRefresh: () {
                      if (!kIsWeb) HapticFeedback.lightImpact();
                      ref.read(hydrationProvider.notifier).refresh();
                      ref.read(workoutsProvider.notifier).refresh();
                      ref.read(foodLogsProvider.notifier).refresh();
                      ref.read(moodLogsProvider.notifier).refresh();
                      ref.read(sugarLogProvider.notifier).refresh();
                      ref.read(streakProvider.notifier).recalculate();
                    },
                  ),
                  const SizedBox(height: 16),

                  // ═══════════════════════════════════════
                  //  HERO: Circular Progress + Streak Glow
                  // ═══════════════════════════════════════
                  _HeroProgressSection(
                    sugarProgress: sugarProgress,
                    totalGrams: sugarState.totalSugarToday,
                    streakDays: streak.currentStreak,
                    logCount: sugarState.todayLogs.length,
                  ),
                  const SizedBox(height: 16),

                  // ─── STREAK-AT-RISK BANNER ───
                  const StreakAtRiskBanner(),
                  const SizedBox(height: 10),

                  // ─── SIGNUP GATE ───
                  const SignupGateCard(),

                  // ═══════════════════════════════════════
                  //  BENTO GRID: 2x2 stat cards
                  // ═══════════════════════════════════════
                  _SectionLabel('Today\'s Overview'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BentoStatCard(
                          title: 'Water',
                          value: Helpers.formatWater(hydrationTotal),
                          goal: Helpers.formatWater(
                              user?.dailyWaterGoalMl ?? 2000),
                          iconType: HealthIconType.water,
                          accentColor: const Color(0xFF38BDF8),
                          progress: hydrationTotal /
                              (user?.dailyWaterGoalMl ?? 2000),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BentoStatCard(
                          title: 'Calories',
                          value: '${nutritionTotals.calories.toInt()}',
                          goal: '${user?.dailyCalorieGoal ?? 2000}',
                          iconType: HealthIconType.calories,
                          accentColor: const Color(0xFFFF7043),
                          progress: nutritionTotals.calories /
                              (user?.dailyCalorieGoal ?? 2000),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BentoStatCard(
                          title: 'Weight',
                          value: user?.weight != null
                              ? Helpers.formatWeight(user!.weight!)
                              : '--',
                          goal: user?.targetWeight != null
                              ? 'Goal: ${Helpers.formatWeight(user!.targetWeight!)}'
                              : '--',
                          iconType: HealthIconType.weight,
                          accentColor: AppTheme.emerald,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BentoStatCard(
                          title: 'BMI',
                          value: user?.bmi != null
                              ? user!.bmi!.toStringAsFixed(1)
                              : '--',
                          goal: user?.bmiCategory ?? '--',
                          iconType: HealthIconType.bmi,
                          accentColor: const Color(0xFFF472B6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════
                  //  WEEKLY SUMMARY
                  // ═══════════════════════════════════════
                  _SectionLabel('This Week'),
                  const SizedBox(height: 12),
                  _WeeklySummaryCard(weeklyStats: weeklyStats),
                  const SizedBox(height: 20),

                  // ═══════════════════════════════════════
                  //  QUICK ACTIONS BENTO
                  // ═══════════════════════════════════════
                  _SectionLabel('Quick Actions'),
                  const SizedBox(height: 12),
                  _BentoQuickActions(context: context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // ============ SUCCESS OVERLAY ============
          if (sugarState.lastLog != null)
            const Positioned.fill(child: SuccessAnimationOverlay()),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateWeeklyStats(WidgetRef ref, String? userId) {
    if (userId == null) {
      return {
        'workoutCount': 0,
        'avgHydration': 0.0,
        'avgCalories': 0.0,
        'totalWorkoutMinutes': 0.0,
      };
    }

    final db = DatabaseService();
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final workouts = db.getUserWorkoutsByDateRange(userId, weekStart, weekEnd);
    final totalWorkoutMinutes =
        workouts.fold<double>(0, (sum, w) => sum + w.durationMinutes);

    double totalHydration = 0;
    int daysWithHydration = 0;
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final dailyTotal = db.getTotalHydrationForDay(userId, date);
      if (dailyTotal > 0) {
        totalHydration += dailyTotal;
        daysWithHydration++;
      }
    }
    final avgHydration =
        daysWithHydration > 0 ? totalHydration / daysWithHydration : 0.0;

    double totalCalories = 0;
    int daysWithFood = 0;
    for (int i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final foodLogs = db.getUserFoodLogsByDate(userId, date);
      final dailyCalories =
          foodLogs.fold<double>(0, (sum, f) => sum + f.calories);
      if (dailyCalories > 0) {
        totalCalories += dailyCalories;
        daysWithFood++;
      }
    }
    final avgCalories =
        daysWithFood > 0 ? totalCalories / daysWithFood : 0.0;

    return {
      'workoutCount': workouts.length,
      'avgHydration': avgHydration,
      'avgCalories': avgCalories,
      'totalWorkoutMinutes': totalWorkoutMinutes,
    };
  }
}

// ═══════════════════════════════════════════════════════════════
//  SECTION LABEL
// ═══════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  CUSTOM HEADER — sits below Dynamic Island
// ═══════════════════════════════════════════════════════════════

class _DynamicIslandHeader extends StatelessWidget {
  final String userName;
  final int streakDays;
  final VoidCallback onLeaderboard;
  final VoidCallback onRefresh;

  const _DynamicIslandHeader({
    required this.userName,
    required this.streakDays,
    required this.onLeaderboard,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Greeting + name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Helpers.getGreeting(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.slateLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        // Leaderboard
        SpringButton(
          onTap: () {
            if (!kIsWeb) HapticFeedback.lightImpact();
            onLeaderboard();
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            child: const Center(
              child: Text('🏆', style: TextStyle(fontSize: 20)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Refresh
        SpringButton(
          onTap: onRefresh,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            child: Icon(
              Icons.refresh_rounded,
              color: AppTheme.slateLight,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  HERO: Circular Gradient Progress Ring + Animated Streak
// ═══════════════════════════════════════════════════════════════

class _HeroProgressSection extends StatefulWidget {
  final double sugarProgress;
  final double totalGrams;
  final int streakDays;
  final int logCount;

  const _HeroProgressSection({
    required this.sugarProgress,
    required this.totalGrams,
    required this.streakDays,
    required this.logCount,
  });

  @override
  State<_HeroProgressSection> createState() => _HeroProgressSectionState();
}

class _HeroProgressSectionState extends State<_HeroProgressSection>
    with TickerProviderStateMixin {
  late final AnimationController _ringController;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color ringColor;
    if (widget.totalGrams <= 25) {
      ringColor = AppTheme.emerald;
    } else if (widget.totalGrams <= 50) {
      ringColor = AppTheme.amber;
    } else {
      ringColor = const Color(0xFFEF4444);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // ── Circular Progress Ring ──
              AnimatedBuilder(
                animation: _ringController,
                builder: (context, child) {
                  return AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, _) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: ringColor.withOpacity(
                                  0.15 + _glowController.value * 0.15),
                              blurRadius: 24 + _glowController.value * 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 110,
                          height: 110,
                          child: CustomPaint(
                            painter: _GradientRingPainter(
                              progress: widget.sugarProgress *
                                  _ringController.value,
                              ringColor: ringColor,
                              glowValue: _glowController.value,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${widget.totalGrams.toStringAsFixed(0)}g',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  Text(
                                    'of 50g',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(width: 20),

              // ── Stack stats + Animated Flame ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Streak with glow
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: widget.streakDays > 0
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFFF6B35),
                                      Color(0xFFFFA62B)
                                    ],
                                  )
                                : null,
                            color: widget.streakDays == 0
                                ? AppTheme.slate.withOpacity(0.4)
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: widget.streakDays > 0
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B35)
                                          .withOpacity(0.2 +
                                              _glowController.value * 0.3),
                                      blurRadius:
                                          12 + _glowController.value * 8,
                                      spreadRadius:
                                          _glowController.value * 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🔥',
                                style: TextStyle(
                                  fontSize:
                                      20 + _glowController.value * 3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${widget.streakDays}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                widget.streakDays == 1 ? 'day' : 'days',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Sub-stats
                    Text(
                      'Daily Ritual',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.logCount} item${widget.logCount != 1 ? 's' : ''} logged today',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Custom painter for a gradient arc ring ──
class _GradientRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final double glowValue;

  _GradientRingPainter({
    required this.progress,
    required this.ringColor,
    required this.glowValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 14) / 2;
    const strokeWidth = 8.0;

    // Track
    final trackPaint = Paint()
      ..color = AppTheme.slate.withOpacity(0.4)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Gradient arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final sweepAngle = 2 * math.pi * progress;
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: [
          ringColor.withOpacity(0.6),
          ringColor,
          ringColor.withOpacity(0.9),
        ],
        stops: const [0.0, 0.6, 1.0],
      );

      final arcPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        arcPaint,
      );

      // Tip dot
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      final tipPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth / 2 + 1, tipPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientRingPainter old) =>
      old.progress != progress ||
      old.ringColor != ringColor ||
      old.glowValue != glowValue;
}

// ═══════════════════════════════════════════════════════════════
//  BENTO STAT CARD  — glassmorphism with accent glow (BR24)
// ═══════════════════════════════════════════════════════════════

class _BentoStatCard extends StatelessWidget {
  final String title;
  final String value;
  final String goal;
  final HealthIconType iconType;
  final Color accentColor;
  final double? progress;

  const _BentoStatCard({
    required this.title,
    required this.value,
    required this.goal,
    required this.iconType,
    required this.accentColor,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SpringButton(
      onTap: () {
        if (!kIsWeb) HapticFeedback.lightImpact();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.10),
                  accentColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HealthIcon(type: iconType, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  goal,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 5,
                      child: LinearProgressIndicator(
                        value: (progress! > 1 ? 1 : progress)!,
                        backgroundColor: AppTheme.slate.withOpacity(0.5),
                        valueColor: AlwaysStoppedAnimation(accentColor),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  WEEKLY SUMMARY  — glassmorphism (BR24)
// ═══════════════════════════════════════════════════════════════

class _WeeklySummaryCard extends StatelessWidget {
  final Map<String, dynamic> weeklyStats;

  const _WeeklySummaryCard({required this.weeklyStats});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _WeeklyStatItem(
                    icon: Icons.fitness_center,
                    color: AppTheme.emerald,
                    value: '${weeklyStats['workoutCount']}',
                    label: 'Workouts',
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: AppTheme.slate.withOpacity(0.5)),
                  _WeeklyStatItem(
                    icon: Icons.water_drop,
                    color: const Color(0xFF38BDF8),
                    value: Helpers.formatWater(
                        weeklyStats['avgHydration'].toInt()),
                    label: 'Avg Water',
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: AppTheme.slate.withOpacity(0.5)),
                  _WeeklyStatItem(
                    icon: Icons.local_fire_department,
                    color: const Color(0xFFFF7043),
                    value: '${weeklyStats['avgCalories'].toInt()}',
                    label: 'Avg Cals',
                  ),
                ],
              ),
              if (weeklyStats['totalWorkoutMinutes'] > 0) ...[
                const SizedBox(height: 16),
                Divider(color: AppTheme.slate.withOpacity(0.4)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_rounded,
                        size: 18, color: AppTheme.emerald),
                    const SizedBox(width: 8),
                    Text(
                      '${weeklyStats['totalWorkoutMinutes'].toInt()} min of exercise this week',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WeeklyStatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _WeeklyStatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.45),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  BENTO QUICK ACTIONS GRID (BR24)
// ═══════════════════════════════════════════════════════════════

class _BentoQuickActions extends StatelessWidget {
  final BuildContext context;

  const _BentoQuickActions({required this.context});

  @override
  Widget build(BuildContext _) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        _BentoActionTile(
          emoji: '💧',
          title: 'Log Water',
          accentColor: const Color(0xFF38BDF8),
          onTap: () => Navigator.pushNamed(context, AppRoutes.hydration),
        ),
        _BentoActionTile(
          emoji: '🍽️',
          title: 'Log Meal',
          accentColor: const Color(0xFFFF7043),
          onTap: () => Navigator.pushNamed(context, AppRoutes.nutrition),
        ),
        _BentoActionTile(
          emoji: '💪',
          title: 'Log Workout',
          accentColor: AppTheme.emerald,
          onTap: () => Navigator.pushNamed(context, AppRoutes.workoutLog),
        ),
        _BentoActionTile(
          emoji: '🧠',
          title: 'Log Mood',
          accentColor: const Color(0xFFA78BFA),
          onTap: () => Navigator.pushNamed(context, AppRoutes.moodTracker),
        ),
        _BentoActionTile(
          emoji: '📊',
          title: 'Health Analysis',
          accentColor: const Color(0xFF2DD4BF),
          onTap: () => Navigator.pushNamed(context, AppRoutes.healthRisk),
        ),
        _BentoActionTile(
          emoji: '🏆',
          title: 'Leaderboard',
          accentColor: const Color(0xFFFBBF24),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LeaderboardPage()),
          ),
        ),
      ],
    );
  }
}

class _BentoActionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final Color accentColor;
  final VoidCallback onTap;

  const _BentoActionTile({
    required this.emoji,
    required this.title,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SpringButton(
      onTap: () {
        if (!kIsWeb) HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity(0.12),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: accentColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withOpacity(0.25),
                        accentColor.withOpacity(0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

