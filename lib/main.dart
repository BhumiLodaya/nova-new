import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'services/database_service.dart';
import 'pages/auth/landing_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/signup_page.dart';
import 'pages/auth/consent_screen.dart';
import 'pages/auth/gender_page.dart';
import 'pages/auth/forgot_password_page.dart';
import 'pages/home/home_page.dart';
import 'pages/profile/edit_profile_page.dart';
import 'pages/profile/change_password_page.dart';
import 'pages/settings/settings_page.dart';
import 'pages/settings/mfa_settings_page.dart';
import 'pages/tracking/workout_log_page.dart';
import 'pages/tracking/hydration_page.dart';
import 'pages/tracking/symptoms_page.dart';
import 'pages/tracking/period_tracker_page.dart';
import 'pages/nutrition/nutrition_page.dart';
import 'pages/nutrition/meal_plan_page.dart';
import 'pages/nutrition/meal_reminder_page.dart';
import 'pages/wellness/mood_tracker_page.dart';
import 'pages/wellness/meditation_page.dart';
import 'pages/wellness/stress_help_page.dart';
import 'pages/profile/habit_tracker_page.dart';
import 'pages/settings/sos_page.dart';
import 'pages/health_risk_page.dart';
import 'pages/chatbot/chatbot_page.dart';
import 'pages/settings/sync_test_page.dart';
import 'pages/leaderboard/leaderboard_page.dart';
import 'pages/onboarding/onboarding_page.dart';
import 'providers/auth_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/supabase_service.dart';
import 'services/backend_keepalive_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  print("Firestore initialized");

  // 2) Supabase (optional - only if configured)
  if (SupabaseConfig.isConfigured) {
    try {
      await SupabaseService().init(
        supabaseUrl: SupabaseConfig.supabaseUrl,
        supabaseAnonKey: SupabaseConfig.supabaseAnonKey,
      );
      print("Supabase initialized");
    } catch (e) {
      print("Supabase initialization skipped: $e");
    }
  } else {
    print("Supabase not configured - running in local-only mode");
  }

  // 3) Hive local storage + SQLite + Sync Service
  await Hive.initFlutter();

  // Initialize DatabaseService (includes Hive, SQLite, and Sync)
  await DatabaseService().init();

  // 4) Start ML Backend Keep-Alive Service
  // Pings the backend every 10 minutes to prevent Render free tier from sleeping
  BackendKeepAliveService().start();
  print("ML Backend Keep-Alive Service started");

  // 5) Riverpod root
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return MaterialApp(
      title: 'NovaHealth',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: isLoggedIn ? AppRoutes.home : AppRoutes.landing,
      routes: {
        AppRoutes.landing: (context) => const LandingPage(),
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.signup: (context) => const SignupPage(),
        AppRoutes.consent: (context) => HealthDataConsentPage(fromSignup: true),
        AppRoutes.gender: (context) => const GenderPage(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordPage(),
        AppRoutes.onboarding: (context) => const OnboardingPage(),
        AppRoutes.home: (context) => const HomePage(),
        AppRoutes.editProfile: (context) => const EditProfilePage(),
        '/change-password': (context) => const ChangePasswordPage(),
        AppRoutes.settings: (context) => const SettingsPage(),
        AppRoutes.mfaSettings: (context) => const MfaSettingsPage(),
        AppRoutes.workoutLog: (context) => const WorkoutLogPage(),
        AppRoutes.hydration: (context) => const HydrationPage(),
        AppRoutes.symptoms: (context) => const SymptomsPage(),
        AppRoutes.periodTracker: (context) => const PeriodTrackerPage(),
        AppRoutes.nutrition: (context) => const NutritionPage(),
        AppRoutes.mealPlan: (context) => const MealPlanPage(),
        AppRoutes.mealReminder: (context) => const MealReminderPage(),
        AppRoutes.moodTracker: (context) => const MoodTrackerPage(),
        AppRoutes.meditation: (context) => const MeditationPage(),
        AppRoutes.stressHelp: (context) => const StressHelpPage(),
        AppRoutes.habitTracker: (context) => const HabitTrackerPage(),
        AppRoutes.sos: (context) => const SosPage(),
        AppRoutes.healthRisk: (context) => const HealthRiskPage(),
        AppRoutes.chatbot: (context) => const ChatbotPage(),
        AppRoutes.leaderboard: (context) => const LeaderboardPage(),
        AppRoutes.syncTest: (context) => const SyncTestPage(),
      },
    );
  }
}
