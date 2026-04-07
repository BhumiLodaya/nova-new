class AppRoutes {
  // Auth routes
  static const String landing = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String consent = '/consent';
  static const String gender = '/gender';
  static const String forgotPassword = '/forgot-password';

  // Guest / Onboarding routes (Beat the Sugar Spike)
  static const String onboarding = '/onboarding';

  // Main app routes
  static const String home = '/home';
  static const String dashboard = '/dashboard';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String settings = '/settings';
  static const String mfaSettings = '/mfa-settings';
  static const String language = '/language';

  // Health tracking routes
  static const String input = '/input';
  static const String workoutLog = '/workout-log';
  static const String hydration = '/hydration';
  static const String symptoms = '/symptoms';
  static const String periodTracker = '/period-tracker';

  // Nutrition routes
  static const String nutrition = '/nutrition';
  static const String mealPlan = '/meal-plan';
  static const String mealReminder = '/meal-reminder';

  // Wellness routes
  static const String moodTracker = '/mood-tracker';
  static const String meditation = '/meditation';
  static const String stressHelp = '/stress-help';

  // Profile tools routes
  static const String habitTracker = '/habit-tracker';
  static const String sos = '/sos';
  
  // ML Prediction & Health Insights routes
  static const String healthRisk = '/health-risk';

  // AI Chatbot routes
  static const String chatbot = '/chatbot';

  // Leaderboard routes
  static const String leaderboard = '/leaderboard';

  // Testing routes
  static const String syncTest = '/sync-test';
}
