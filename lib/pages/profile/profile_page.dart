import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../utils/helpers.dart';
import '../../widgets/glass_widgets.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row with actions ──
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  _HeaderIconButton(
                    icon: Icons.edit_rounded,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.editProfile),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.settings_rounded,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconButton(
                    icon: Icons.logout_rounded,
                    onTap: () async {
                      if (!kIsWeb) HapticFeedback.lightImpact();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Logout',
                                  style: TextStyle(color: Color(0xFFEF4444))),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        await ref.read(authStateProvider.notifier).logout(ref);
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context, AppRoutes.landing, (route) => false);
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ══════════════════════════════════════════
              //  PROFILE CARD — Glassmorphism (BR24)
              // ══════════════════════════════════════════
              ClipRRect(
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
                    child: Row(
                      children: [
                        // Avatar with high-contrast ring
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF38BDF8),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: AppTheme.midnightLight,
                            backgroundImage: user?.profilePictureUrl != null &&
                                    user!.profilePictureUrl!.isNotEmpty
                                ? (user.profilePictureUrl!.startsWith('http')
                                    ? NetworkImage(user.profilePictureUrl!)
                                    : FileImage(File(user.profilePictureUrl!))
                                        as ImageProvider)
                                : null,
                            child: user?.profilePictureUrl == null ||
                                    user!.profilePictureUrl!.isEmpty
                                ? Text(
                                    (user?.username ?? 'U')
                                        .substring(0, 1)
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF38BDF8),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? user?.username ?? 'User',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                              if (user?.age != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${user!.age} years old  •  ${user.gender ?? "Not specified"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.45),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ══════════════════════════════════════════
              //  HEALTH STATS — Glassmorphism (BR24)
              // ══════════════════════════════════════════
              if (user?.weight != null || user?.height != null) ...[
                const Text(
                  'Health Stats',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 20, horizontal: 12),
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
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (user?.weight != null)
                            _GlassStatItem(
                              label: 'Weight',
                              value: Helpers.formatWeight(user!.weight!),
                              icon: Icons.monitor_weight_rounded,
                              color: AppTheme.emerald,
                            ),
                          if (user?.height != null)
                            _GlassStatItem(
                              label: 'Height',
                              value: Helpers.formatHeight(user!.height!),
                              icon: Icons.height_rounded,
                              color: const Color(0xFF38BDF8),
                            ),
                          if (user?.bmi != null)
                            _GlassStatItem(
                              label: 'BMI',
                              value: user!.bmi!.toStringAsFixed(1),
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFFF472B6),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ══════════════════════════════════════════
              //  FEATURE GRID — Glassmorphism tiles (BR24)
              // ══════════════════════════════════════════
              const Text(
                'Features',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: const [
                  _FeatureCard(
                      label: 'Meal Timer',
                      icon: Icons.timer_rounded,
                      color: Color(0xFFFBBF24)),
                  _FeatureCard(
                      label: 'Stay Mindful',
                      icon: Icons.self_improvement_rounded,
                      color: Color(0xFFA78BFA)),
                  _FeatureCard(
                      label: 'Your Workout',
                      icon: Icons.fitness_center_rounded,
                      color: Color(0xFF10B981)),
                  _FeatureCard(
                      label: 'Your Diet',
                      icon: Icons.restaurant_menu_rounded,
                      color: Color(0xFFFF7043)),
                  _FeatureCard(
                      label: 'Habit Tracker',
                      icon: Icons.check_circle_rounded,
                      color: Color(0xFF2DD4BF)),
                  _FeatureCard(
                      label: 'Period Tracker',
                      icon: Icons.calendar_today_rounded,
                      color: Color(0xFFF472B6)),
                  _FeatureCard(
                      label: 'Stress Help',
                      icon: Icons.spa_rounded,
                      color: Color(0xFF818CF8)),
                  _FeatureCard(
                      label: 'Hydration',
                      icon: Icons.water_drop_rounded,
                      color: Color(0xFF38BDF8)),
                  _FeatureCard(
                      label: 'AI Chatbot',
                      icon: Icons.chat_bubble_rounded,
                      color: Color(0xFF34D399)),
                  _FeatureCard(
                      label: 'Security (MFA)',
                      icon: Icons.security_rounded,
                      color: Color(0xFF64748B)),
                ],
              ),
              const SizedBox(height: 20),

              // ── SOS Button ──
              SpringButton(
                onTap: () {
                  if (!kIsWeb) HapticFeedback.heavyImpact();
                  Navigator.pushNamed(context, AppRoutes.sos);
                },
                child: Container(
                  width: double.infinity,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'SOS',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header icon pill button ──
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SpringButton(
      onTap: () {
        if (!kIsWeb) HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
      ),
    );
  }
}

// ── Glass stat item (for Health Stats) ──
class _GlassStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _GlassStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.25), color.withOpacity(0.10)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}

// ── Feature tile card — glass (BR24) ──
class _FeatureCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _FeatureCard({
    required this.label,
    required this.icon,
    required this.color,
  });

  String? _getRoute(String label) {
    switch (label) {
      case 'Meal Timer':
        return AppRoutes.mealReminder;
      case 'Stay Mindful':
        return AppRoutes.meditation;
      case 'Your Workout':
        return AppRoutes.workoutLog;
      case 'Your Diet':
        return AppRoutes.nutrition;
      case 'Habit Tracker':
        return AppRoutes.habitTracker;
      case 'Period Tracker':
        return AppRoutes.periodTracker;
      case 'Stress Help':
        return AppRoutes.stressHelp;
      case 'Hydration':
        return AppRoutes.hydration;
      case 'AI Chatbot':
        return AppRoutes.chatbot;
      case 'Security (MFA)':
        return AppRoutes.mfaSettings;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _getRoute(label);

    return SpringButton(
      onTap: () {
        if (!kIsWeb) HapticFeedback.lightImpact();
        if (route != null) {
          Navigator.pushNamed(context, route);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label coming soon!')),
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.14),
                  Colors.white.withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withOpacity(0.22),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.3),
                        color.withOpacity(0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
