import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'sqlite_service.dart';
import 'supabase_service.dart';
import '../models/workout_model.dart';
import '../models/hydration_model.dart';
import '../models/health_metric_model.dart';
import '../models/mood_log_model.dart';
import '../models/food_log_model.dart';
import '../models/period_cycle_model.dart';
import '../models/symptom_model.dart';
import '../models/meditation_session_model.dart';
import '../models/sugar_log_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

/// Database sync service to coordinate between local (SQLite/Hive) and cloud (Supabase)
/// Handles automatic synchronization, conflict resolution, and offline support
class DatabaseSyncService {
  static final DatabaseSyncService _instance = DatabaseSyncService._internal();
  factory DatabaseSyncService() => _instance;
  DatabaseSyncService._internal();

  final _sqliteService = SQLiteService();
  final _supabaseService = SupabaseService();

  Timer? _syncTimer;
  bool _isSyncing = false;

  /// Initialize sync service
  Future<void> init() async {
    // Services should already be initialized by main app
    // Perform initial sync immediately
    Future.delayed(const Duration(seconds: 5), () {
      syncAllData();
    });
    
    // Start periodic sync every 1 minute for continuous syncing
    startPeriodicSync(const Duration(minutes: 1));
  }

  /// Start periodic background sync
  void startPeriodicSync(Duration interval) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      syncAllData();
    });
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Sync all user data to cloud
  Future<bool> syncAllData() async {
    if (_isSyncing || !_supabaseService.isAvailable) {
      return false;
    }

    _isSyncing = true;
    debugPrint('🔄 Starting automatic data sync to Supabase...');

    try {
      // Get unsynced data from SQLite (if available) or Hive (web fallback)
      List<Map<String, dynamic>> unsyncedUserProfiles = [];
      List<Map<String, dynamic>> unsyncedWorkouts = [];
      List<Map<String, dynamic>> unsyncedHydration = [];
      List<Map<String, dynamic>> unsyncedHealthMetrics = [];
      List<Map<String, dynamic>> unsyncedMoodLogs = [];
      List<Map<String, dynamic>> unsyncedFoodLogs = [];
      List<Map<String, dynamic>> unsyncedPeriodCycles = [];
      List<Map<String, dynamic>> unsyncedSymptoms = [];
      List<Map<String, dynamic>> unsyncedMeditationSessions = [];
      List<Map<String, dynamic>> unsyncedSugarLogs = [];
      List<Map<String, dynamic>> unsyncedHabitTracking = [];
      Map<String, dynamic> sosProfile = {};
      
      if (_sqliteService.isAvailable) {
        // Desktop/Mobile: Get from SQLite
        unsyncedUserProfiles = await _sqliteService.getUnsyncedRecords('user_profiles');
        unsyncedWorkouts = await _sqliteService.getUnsyncedRecords('workout_tracking');
        unsyncedHydration = await _sqliteService.getUnsyncedRecords('hydration_tracking');
        unsyncedHealthMetrics = await _sqliteService.getUnsyncedRecords('health_metrics_tracking');
        unsyncedMoodLogs = await _sqliteService.getUnsyncedRecords('mood_tracking');
        unsyncedFoodLogs = await _sqliteService.getUnsyncedRecords('food_log_tracking');
      } else {
        // Web: Get from Hive
        unsyncedUserProfiles = await _getUserProfilesFromHive();
        unsyncedWorkouts = await _getWorkoutsFromHive();
        unsyncedHydration = await _getHydrationFromHive();
        unsyncedHealthMetrics = await _getHealthMetricsFromHive();
        unsyncedMoodLogs = await _getMoodLogsFromHive();
        unsyncedFoodLogs = await _getFoodLogsFromHive();
      }

      // Additional data currently persisted in Hive/settings for all platforms.
      unsyncedPeriodCycles = await _getPeriodCyclesFromHive();
      unsyncedSymptoms = await _getSymptomsFromHive();
      unsyncedMeditationSessions = await _getMeditationSessionsFromHive();
      unsyncedSugarLogs = await _getSugarLogsFromHive();
      unsyncedHabitTracking = await _getHabitTrackingFromSettings();
      sosProfile = await _getSosProfileFromSettings();

      // Sync user profiles to Supabase
      if (unsyncedUserProfiles.isNotEmpty) {
        await _syncUserProfilesToSupabase(unsyncedUserProfiles);
      }

      // Sync to Supabase
      final results = await _supabaseService.syncAllData(
        workouts: unsyncedWorkouts,
        hydration: unsyncedHydration,
        healthMetrics: unsyncedHealthMetrics,
        moodLogs: unsyncedMoodLogs,
        foodLogs: unsyncedFoodLogs,
        periodCycles: unsyncedPeriodCycles,
        symptoms: unsyncedSymptoms,
        meditationSessions: unsyncedMeditationSessions,
        sugarLogs: unsyncedSugarLogs,
        habitTracking: unsyncedHabitTracking,
        sosProfile: sosProfile,
      );

      // Mark synced records in SQLite (if available)
      if (_sqliteService.isAvailable) {
        if (results['workouts'] == true) {
          for (final record in unsyncedWorkouts) {
            await _sqliteService.markAsSynced('workout_tracking', record['id']);
          }
        }
        if (results['hydration'] == true) {
          for (final record in unsyncedHydration) {
            await _sqliteService.markAsSynced('hydration_tracking', record['id']);
          }
        }
        if (results['health_metrics'] == true) {
          for (final record in unsyncedHealthMetrics) {
            await _sqliteService.markAsSynced('health_metrics_tracking', record['id']);
          }
        }
        if (results['mood_logs'] == true) {
          for (final record in unsyncedMoodLogs) {
            await _sqliteService.markAsSynced('mood_tracking', record['id']);
          }
        }
        if (results['food_logs'] == true) {
          for (final record in unsyncedFoodLogs) {
            await _sqliteService.markAsSynced('food_log_tracking', record['id']);
          }
        }
      }

      final totalSynced = unsyncedWorkouts.length + unsyncedHydration.length + 
                          unsyncedHealthMetrics.length + unsyncedMoodLogs.length + 
                          unsyncedFoodLogs.length + unsyncedPeriodCycles.length +
                          unsyncedSymptoms.length + unsyncedMeditationSessions.length +
                          unsyncedSugarLogs.length + unsyncedHabitTracking.length +
                          (sosProfile.isNotEmpty ? 1 : 0);

      final settings = Hive.box(AppConstants.settingsBox);
      await settings.put('sync_last_status', 'success');
      await settings.put('sync_last_timestamp', DateTime.now().toIso8601String());
      await settings.put('sync_last_count', totalSynced);
      await settings.put('sync_last_details', results.map((k, v) => MapEntry(k, v ? 'ok' : 'failed')));

      debugPrint('✅ Data sync completed! Synced $totalSynced records to Supabase');
      debugPrint('   - Workouts: ${unsyncedWorkouts.length}');
      debugPrint('   - Hydration: ${unsyncedHydration.length}');
      debugPrint('   - Health Metrics: ${unsyncedHealthMetrics.length}');
      debugPrint('   - Mood Logs: ${unsyncedMoodLogs.length}');
      debugPrint('   - Food Logs: ${unsyncedFoodLogs.length}');
      debugPrint('   - Period Cycles: ${unsyncedPeriodCycles.length}');
      debugPrint('   - Symptoms: ${unsyncedSymptoms.length}');
      debugPrint('   - Meditation Sessions: ${unsyncedMeditationSessions.length}');
      debugPrint('   - Sugar Logs: ${unsyncedSugarLogs.length}');
      return true;
    } catch (e) {
      debugPrint('Error during data sync: $e');
      final settings = Hive.box(AppConstants.settingsBox);
      await settings.put('sync_last_status', 'failed');
      await settings.put('sync_last_timestamp', DateTime.now().toIso8601String());
      await settings.put('sync_last_error', e.toString());
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Track user profile in SQLite
  Future<void> trackUserProfile(UserModel user) async {
    if (!_sqliteService.isAvailable) return;

    try {
      await _sqliteService.insertOrUpdate('user_profiles', {
        'id': user.id,
        'user_id': user.id,
        'username': user.username,
        'email': user.email,
        'name': user.fullName,
        'age': user.dateOfBirth != null ? DateTime.now().year - user.dateOfBirth!.year : null,
        'gender': user.gender,
        'height': user.height,
        'weight': user.weight,
        'profile_image': user.profilePictureUrl,
        'created_at': user.createdAt.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'last_login': DateTime.now().millisecondsSinceEpoch,
        'synced': 0,
      });

      debugPrint('✅ User profile tracked in SQLite');
    } catch (e) {
      debugPrint('Error tracking user profile: $e');
    }
  }

  /// Track workout in SQLite for analytics
  Future<void> trackWorkout(WorkoutModel workout) async {
    if (!_sqliteService.isAvailable) return;

    try {
      await _sqliteService.insertOrUpdate('workout_tracking', {
        'id': workout.id,
        'user_id': workout.userId,
        'workout_type': workout.activityType,
        'duration': workout.durationMinutes.toInt(),
        'calories_burned': workout.caloriesBurned.toInt(),
        'intensity': workout.intensity,
        'date': workout.date.millisecondsSinceEpoch,
        'synced': 0,
      });

      // Log analytics event
      if (_supabaseService.isAvailable) {
        await _supabaseService.logAnalyticsEvent(
          eventType: 'workout_logged',
          eventData: {
            'workout_type': workout.activityType,
            'duration': workout.durationMinutes,
            'calories': workout.caloriesBurned,
          },
        );
      }
    } catch (e) {
      debugPrint('Error tracking workout: $e');
    }
  }

  /// Track hydration in SQLite
  Future<void> trackHydration(HydrationModel hydration) async {
    if (!_sqliteService.isAvailable) return;

    try {
      await _sqliteService.insertOrUpdate('hydration_tracking', {
        'id': hydration.id,
        'user_id': hydration.userId,
        'amount_ml': hydration.amountMl,
        'timestamp': hydration.timestamp.millisecondsSinceEpoch,
        'synced': 0,
      });

      // Log analytics event
      if (_supabaseService.isAvailable) {
        await _supabaseService.logAnalyticsEvent(
          eventType: 'hydration_logged',
          eventData: {'amount_ml': hydration.amountMl},
        );
      }
    } catch (e) {
      debugPrint('Error tracking hydration: $e');
    }
  }

  /// Track health metrics in SQLite (merged with period and symptom tracking)
  Future<void> trackHealthMetrics(HealthMetricModel metrics) async {
    if (!_sqliteService.isAvailable) return;

    try {
      await _sqliteService.insertOrUpdate('health_metrics_tracking', {
        'id': metrics.id,
        'user_id': metrics.userId,
        'weight': metrics.weight,
        'height': null,
        'bmi': null,
        'heart_rate': null,
        'blood_pressure': null,
        'sleep_hours': metrics.sleepMinutes != null ? metrics.sleepMinutes! / 60.0 : null,
        'steps': metrics.steps,
        'mood': metrics.mood,
        'stress_level': metrics.stressLevel,
        'energy_level': metrics.energyLevel,
        'notes': metrics.notes,
        'date': metrics.date.millisecondsSinceEpoch,
        'is_period_day': metrics.isPeriodDay ? 1 : 0,
        'flow_intensity': metrics.flowIntensity,
        'period_symptoms': metrics.periodSymptoms != null ? metrics.periodSymptoms!.join(',') : null,
        'cycle_day': metrics.cycleDay,
        'symptoms': metrics.symptoms != null ? metrics.symptoms!.join(',') : null,
        'symptom_severity': metrics.symptomSeverity != null ? _encodeMap(metrics.symptomSeverity!) : null,
        'symptom_body_parts': metrics.symptomBodyParts != null ? _encodeMap(metrics.symptomBodyParts!) : null,
        'symptom_triggers': metrics.symptomTriggers != null ? metrics.symptomTriggers!.join(',') : null,
        'synced': 0,
      });

      // Log analytics event
      if (_supabaseService.isAvailable) {
        await _supabaseService.logAnalyticsEvent(
          eventType: 'health_metrics_logged',
          eventData: {
            'weight': metrics.weight,
            'steps': metrics.steps,
            'sleep_minutes': metrics.sleepMinutes,
            'is_period_day': metrics.isPeriodDay,
            'has_symptoms': metrics.symptoms != null && metrics.symptoms!.isNotEmpty,
          },
        );
      }
    } catch (e) {
      debugPrint('Error tracking health metrics: $e');
    }
  }

  /// Helper method to encode map to JSON string
  String _encodeMap(Map<String, dynamic> map) {
    try {
      return jsonEncode(map);
    } catch (e) {
      debugPrint('Error encoding map: $e');
      return '{}';
    }
  }

  /// Track mood in SQLite
  Future<void> trackMood(MoodLogModel mood) async {
    if (!_sqliteService.isAvailable) return;

    try {
      await _sqliteService.insertOrUpdate('mood_tracking', {
        'id': mood.id,
        'user_id': mood.userId,
        'mood_type': mood.mood,
        'mood_score': mood.intensity,
        'notes': mood.notes,
        'timestamp': mood.timestamp.millisecondsSinceEpoch,
        'synced': 0,
      });

      // Log analytics event
      if (_supabaseService.isAvailable) {
        await _supabaseService.logAnalyticsEvent(
          eventType: 'mood_logged',
          eventData: {
            'mood_type': mood.mood,
            'intensity': mood.intensity,
          },
        );
      }
    } catch (e) {
      debugPrint('Error tracking mood: $e');
    }
  }

  /// Track food log in SQLite
  Future<void> trackFoodLog(FoodLogModel foodLog) async {
    if (!_sqliteService.isAvailable) return;

    try {
      await _sqliteService.insertOrUpdate('food_log_tracking', {
        'id': foodLog.id,
        'user_id': foodLog.userId,
        'meal_type': foodLog.mealType,
        'food_name': foodLog.foodName,
        'calories': foodLog.calories,
        'protein': foodLog.protein,
        'carbs': foodLog.carbs,
        'fats': foodLog.fats,
        'timestamp': foodLog.timestamp.millisecondsSinceEpoch,
        'synced': 0,
      });

      // Log analytics event
      if (_supabaseService.isAvailable) {
        await _supabaseService.logAnalyticsEvent(
          eventType: 'food_logged',
          eventData: {
            'meal_type': foodLog.mealType,
            'calories': foodLog.calories,
          },
        );
      }
    } catch (e) {
      debugPrint('Error tracking food log: $e');
    }
  }

  /// Get analytics insights from SQLite
  Future<Map<String, dynamic>> getAnalyticsInsights(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (!_sqliteService.isAvailable) {
      return {
        'workout_stats': {},
        'hydration_stats': {},
        'mood_trends': [],
      };
    }

    try {
      final workoutStats = await _sqliteService.getWorkoutStats(userId, startDate, endDate);
      final hydrationStats = await _sqliteService.getHydrationStats(userId, DateTime.now());
      final moodTrends = await _sqliteService.getMoodTrends(userId, startDate, endDate);

      return {
        'workout_stats': workoutStats,
        'hydration_stats': hydrationStats,
        'mood_trends': moodTrends,
      };
    } catch (e) {
      debugPrint('Error getting analytics insights: $e');
      return {
        'workout_stats': {},
        'hydration_stats': {},
        'mood_trends': [],
      };
    }
  }

  /// Get AI predictions from Supabase
  Future<Map<String, dynamic>?> getHealthPredictions(String userId) async {
    if (!_supabaseService.isAvailable) return null;
    return await _supabaseService.getHealthPredictions(userId);
  }

  /// Get personalized recommendations
  Future<List<Map<String, dynamic>>> getRecommendations(String userId) async {
    if (!_supabaseService.isAvailable) return [];
    return await _supabaseService.getRecommendations(userId);
  }

  /// Generate AI meal plan
  Future<Map<String, dynamic>?> generateMealPlan({
    required String userId,
    required Map<String, dynamic> preferences,
  }) async {
    if (!_supabaseService.isAvailable) return null;
    return await _supabaseService.generateMealPlan(
      userId: userId,
      preferences: preferences,
    );
  }

  /// Force sync to cloud
  Future<bool> syncToCloud() async {
    return await syncAllData();
  }

  /// Restore user data from Supabase on login
  Future<void> restoreUserDataFromCloud(String userId) async {
    if (!_supabaseService.isAvailable) {
      debugPrint('⚠️ Supabase not available, skipping data restore');
      return;
    }

    try {
      debugPrint('🔄 Restoring user data from Supabase (non-blocking)...');

      // Restore workouts
      final workouts = await _supabaseService.client
          ?.from('workout_data')
          .select()
          .eq('user_id', userId);
      
      if (workouts != null && workouts.isNotEmpty) {
        final workoutBox = Hive.box<WorkoutModel>(AppConstants.workoutBox);
        for (final w in workouts) {
          final workout = WorkoutModel(
            id: w['id'],
            userId: w['user_id'],
            date: DateTime.parse(w['date']),
            activityType: w['workout_type'],
            durationMinutes: (w['duration'] as num).toDouble(),
            intensity: w['intensity'],
            caloriesBurned: (w['calories_burned'] as num?)?.toDouble() ?? 0,
            createdAt: DateTime.parse(w['synced_at'] ?? DateTime.now().toIso8601String()),
          );
          await workoutBox.put(workout.id, workout);
        }
        debugPrint('✅ Restored ${workouts.length} workouts');
      }

      // Restore hydration
      final hydration = await _supabaseService.client
          ?.from('hydration_data')
          .select()
          .eq('user_id', userId);
      
      if (hydration != null && hydration.isNotEmpty) {
        final hydrationBox = Hive.box<HydrationModel>('hydration_box');
        for (final h in hydration) {
          final log = HydrationModel(
            id: h['id'],
            userId: h['user_id'],
            amountMl: h['amount_ml'],
            timestamp: DateTime.parse(h['timestamp']),
          );
          await hydrationBox.put(log.id, log);
        }
        debugPrint('✅ Restored ${hydration.length} hydration logs');
      }

      // Restore mood logs
      final moods = await _supabaseService.client
          ?.from('mood_data')
          .select()
          .eq('user_id', userId);
      
      if (moods != null && moods.isNotEmpty) {
        final moodBox = Hive.box<MoodLogModel>('mood_box');
        for (final m in moods) {
          final mood = MoodLogModel(
            id: m['id'],
            userId: m['user_id'],
            mood: m['mood_type'],
            intensity: m['mood_score'],
            timestamp: DateTime.parse(m['timestamp']),
            notes: m['notes'],
            createdAt: DateTime.parse(m['timestamp']),
          );
          await moodBox.put(mood.id, mood);
        }
        debugPrint('✅ Restored ${moods.length} mood logs');
      }

      // Restore food logs
      final foods = await _supabaseService.client
          ?.from('food_log_data')
          .select()
          .eq('user_id', userId);
      
      if (foods != null && foods.isNotEmpty) {
        final foodBox = Hive.box<FoodLogModel>('food_log_box');
        for (final f in foods) {
          final food = FoodLogModel(
            id: f['id'],
            userId: f['user_id'],
            mealType: f['meal_type'],
            foodName: f['food_name'],
            servingSize: 1.0,
            servingUnit: 'serving',
            calories: f['calories'] ?? 0,
            protein: (f['protein'] as num?)?.toDouble() ?? 0,
            carbs: (f['carbs'] as num?)?.toDouble() ?? 0,
            fats: (f['fats'] as num?)?.toDouble() ?? 0,
            timestamp: DateTime.parse(f['timestamp']),
            createdAt: DateTime.parse(f['timestamp']),
          );
          await foodBox.put(food.id, food);
        }
        debugPrint('✅ Restored ${foods.length} food logs');
      }

      // Restore period cycles
      final periodCycles = await _supabaseService.client
          ?.from('period_cycles')
          .select()
          .eq('user_id', userId);

      if (periodCycles != null && periodCycles.isNotEmpty) {
        final periodBox = Hive.box<PeriodCycleModel>('period_box');
        for (final p in periodCycles) {
          final cycle = PeriodCycleModel(
            id: p['id'],
            userId: p['user_id'],
            startDate: DateTime.parse(p['start_date']),
            endDate: p['end_date'] != null ? DateTime.parse(p['end_date']) : null,
            flowIntensity: p['flow_intensity'] ?? 'medium',
            symptoms: p['symptoms'] != null ? List<String>.from(p['symptoms']) : const [],
            mood: p['mood'],
            notes: p['notes'],
            cycleLength: p['cycle_length'],
            createdAt: p['created_at'] != null
                ? DateTime.parse(p['created_at'])
                : DateTime.now(),
          );
          await periodBox.put(cycle.id, cycle);
        }
        debugPrint('✅ Restored ${periodCycles.length} period cycles');
      }

      // Restore symptoms
      final symptoms = await _supabaseService.client
          ?.from('symptom_data')
          .select()
          .eq('user_id', userId);

      if (symptoms != null && symptoms.isNotEmpty) {
        final symptomBox = Hive.box<SymptomModel>('symptom_box');
        for (final s in symptoms) {
          final symptom = SymptomModel(
            id: s['id'],
            userId: s['user_id'],
            timestamp: DateTime.parse(s['timestamp']),
            symptomType: s['symptom_type'],
            severity: (s['severity'] as num).toInt(),
            bodyPart: s['body_part'],
            notes: s['notes'],
            triggers: s['triggers'] != null ? List<String>.from(s['triggers']) : null,
            createdAt: s['created_at'] != null
                ? DateTime.parse(s['created_at'])
                : DateTime.parse(s['timestamp']),
          );
          await symptomBox.put(symptom.id, symptom);
        }
        debugPrint('✅ Restored ${symptoms.length} symptoms');
      }

      // Restore meditation sessions
      final meditation = await _supabaseService.client
          ?.from('meditation_sessions')
          .select()
          .eq('user_id', userId);

      if (meditation != null && meditation.isNotEmpty) {
        final meditationBox = Hive.box<MeditationSessionModel>('meditation_box');
        for (final m in meditation) {
          final session = MeditationSessionModel(
            id: m['id'],
            userId: m['user_id'],
            timestamp: DateTime.parse(m['timestamp']),
            type: m['type'],
            durationMinutes: (m['duration_minutes'] as num).toInt(),
            exerciseName: m['exercise_name'],
            notes: m['notes'],
            completed: m['completed'] ?? true,
            createdAt: m['created_at'] != null
                ? DateTime.parse(m['created_at'])
                : DateTime.parse(m['timestamp']),
          );
          await meditationBox.put(session.id, session);
        }
        debugPrint('✅ Restored ${meditation.length} meditation sessions');
      }

      // Restore sugar logs
      final sugarLogs = await _supabaseService.client
          ?.from('sugar_logs')
          .select()
          .eq('user_id', userId);

      if (sugarLogs != null && sugarLogs.isNotEmpty) {
        final sugarBox = Hive.box<SugarLogModel>('sugar_log_box');
        for (final s in sugarLogs) {
          final log = SugarLogModel(
            id: s['id'],
            userId: s['user_id'],
            loggedAt: DateTime.parse(s['logged_at']),
            sugarType: s['sugar_type'],
            label: s['label'],
            estimatedSugarGrams: (s['estimated_sugar_grams'] as num).toDouble(),
            estimatedCalories: (s['estimated_calories'] as num).toDouble(),
            note: s['note'],
            xpEarned: (s['xp_earned'] as num?)?.toInt() ?? 10,
          );
          await sugarBox.put(log.id, log);
        }
        debugPrint('✅ Restored ${sugarLogs.length} sugar logs');
      }

      // Restore habit tracker snapshots into settings.
      final habits = await _supabaseService.client
          ?.from('habit_tracking')
          .select()
          .eq('user_id', userId);

      if (habits != null && habits.isNotEmpty) {
        final settings = Hive.box(AppConstants.settingsBox);
        for (final h in habits) {
          final dayKey = (h['day_key'] ?? '').toString();
          if (dayKey.isEmpty) continue;
          final completed = h['completed_habits'];
          final completedList = completed is List
              ? completed.map((e) => e.toString()).toList()
              : <String>[];

          await settings.put('habit_tracker_$dayKey', completedList);
        }
        debugPrint('✅ Restored ${habits.length} habit tracking entries');
      }

      // Restore SOS profile into settings.
      final sosRows = await _supabaseService.client
          ?.from('sos_profiles')
          .select()
          .eq('user_id', userId)
          .limit(1);

      if (sosRows != null && sosRows.isNotEmpty) {
        final settings = Hive.box(AppConstants.settingsBox);
        final sos = sosRows.first;
        await settings.put(
          'sos_primary_contact',
          (sos['primary_contact'] ?? '').toString(),
        );
        await settings.put(
          'sos_medical_note',
          (sos['medical_note'] ?? '').toString(),
        );
        debugPrint('✅ Restored SOS profile');
      }

      debugPrint('✅ User data restore completed!');
    } catch (e) {
      debugPrint('⚠️ Could not restore user data from cloud (network issue or Supabase unavailable): $e');
      debugPrint('ℹ️ App will work offline - data will sync when connection is restored');
    }
  }

  /// Check sync status
  bool get isSyncing => _isSyncing;

  /// Dispose resources
  void dispose() {
    stopPeriodicSync();
  }

  // ==================== Delete Sync Methods ====================

  /// Delete workout from Supabase
  Future<void> deleteWorkoutFromCloud(String id) async {
    if (!_supabaseService.isAvailable) return;
    
    try {
      await _supabaseService.client?.from('workout_data').delete().eq('id', id);
      debugPrint('✅ Deleted workout $id from Supabase');
    } catch (e) {
      debugPrint('Error deleting workout from Supabase: $e');
    }
  }

  /// Delete hydration from Supabase
  Future<void> deleteHydrationFromCloud(String id) async {
    if (!_supabaseService.isAvailable) return;
    
    try {
      await _supabaseService.client?.from('hydration_data').delete().eq('id', id);
      debugPrint('✅ Deleted hydration $id from Supabase');
    } catch (e) {
      debugPrint('Error deleting hydration from Supabase: $e');
    }
  }

  /// Delete health metrics from Supabase
  Future<void> deleteHealthMetricsFromCloud(String id) async {
    if (!_supabaseService.isAvailable) return;
    
    try {
      await _supabaseService.client?.from('health_metrics').delete().eq('id', id);
      debugPrint('✅ Deleted health metrics $id from Supabase');
    } catch (e) {
      debugPrint('Error deleting health metrics from Supabase: $e');
    }
  }

  /// Delete mood log from Supabase
  Future<void> deleteMoodLogFromCloud(String id) async {
    if (!_supabaseService.isAvailable) return;
    
    try {
      await _supabaseService.client?.from('mood_data').delete().eq('id', id);
      debugPrint('✅ Deleted mood log $id from Supabase');
    } catch (e) {
      debugPrint('Error deleting mood log from Supabase: $e');
    }
  }

  /// Delete food log from Supabase
  Future<void> deleteFoodLogFromCloud(String id) async {
    if (!_supabaseService.isAvailable) return;
    
    try {
      await _supabaseService.client?.from('food_log_data').delete().eq('id', id);
      debugPrint('✅ Deleted food log $id from Supabase');
    } catch (e) {
      debugPrint('Error deleting food log from Supabase: $e');
    }
  }

  // ==================== Helper Methods ====================

  /// Sync user profiles to Supabase
  Future<void> _syncUserProfilesToSupabase(List<Map<String, dynamic>> profiles) async {
    if (!_supabaseService.isAvailable || profiles.isEmpty) return;

    try {
      final profileData = profiles.map((p) => {
        'user_id': p['user_id'],
        'name': p['name'],
        'email': p['email'],
        'age': p['age'],
        'gender': p['gender'],
        'height': p['height'],
        'weight': p['weight'],
        'created_at': p['created_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(p['created_at']).toIso8601String()
            : DateTime.now().toIso8601String(),
        'updated_at': p['updated_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(p['updated_at']).toIso8601String()
            : DateTime.now().toIso8601String(),
      }).toList();

      await _supabaseService.client?.from('user_profiles').upsert(
        profileData,
        onConflict: 'user_id', // Update existing profile if user_id already exists
      );
      
      // Mark as synced in SQLite
      if (_sqliteService.isAvailable) {
        for (final profile in profiles) {
          await _sqliteService.markAsSynced('user_profiles', profile['id']);
        }
      }
      
      debugPrint('✅ Synced ${profiles.length} user profiles to Supabase');
    } catch (e) {
      debugPrint('Error syncing user profiles: $e');
    }
  }

  // ==================== Hive Data Readers (for Web) ====================

  Future<List<Map<String, dynamic>>> _getUserProfilesFromHive() async {
    try {
      final box = Hive.box<UserModel>(AppConstants.userBox);
      return box.values.map((u) => {
        'id': u.id,
        'user_id': u.id,
        'username': u.username,
        'email': u.email,
        'name': u.fullName,
        'age': u.dateOfBirth != null ? DateTime.now().year - u.dateOfBirth!.year : null,
        'gender': u.gender,
        'height': u.height,
        'weight': u.weight,
        'created_at': u.createdAt.millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }).toList();
    } catch (e) {
      debugPrint('Error reading user profiles from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getWorkoutsFromHive() async {
    try {
      final box = Hive.box<WorkoutModel>(AppConstants.workoutBox);
      return box.values.map((w) => {
        'id': w.id,
        'user_id': w.userId,
        'workout_type': w.activityType,
        'duration': w.durationMinutes.toInt(),
        'calories_burned': w.caloriesBurned.toInt(),
        'intensity': w.intensity,
        'date': w.date.toIso8601String(),
      }).toList();
    } catch (e) {
      debugPrint('Error reading workouts from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getHydrationFromHive() async {
    try {
      final box = Hive.box<HydrationModel>('hydration_box');
      return box.values.map((h) => {
        'id': h.id,
        'user_id': h.userId,
        'amount_ml': h.amountMl,
        'timestamp': h.timestamp.toIso8601String(),
      }).toList();
    } catch (e) {
      debugPrint('Error reading hydration from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getHealthMetricsFromHive() async {
    try {
      final box = Hive.box<HealthMetricModel>(AppConstants.healthBox);
      return box.values.map((m) => {
        'id': m.id,
        'user_id': m.userId,
        'weight': m.weight,
        'height': null,
        'bmi': null,
        'heart_rate': null,
        'blood_pressure': null,
        'sleep_hours': m.sleepMinutes != null ? m.sleepMinutes! / 60.0 : null,
        'steps': m.steps,
        'mood': m.mood,
        'stress_level': m.stressLevel,
        'energy_level': m.energyLevel,
        'notes': m.notes,
        'date': m.date.toIso8601String(),
        'is_period_day': m.isPeriodDay ? 1 : 0,
        'flow_intensity': m.flowIntensity,
        'period_symptoms': m.periodSymptoms != null ? m.periodSymptoms!.join(',') : null,
        'cycle_day': m.cycleDay,
        'symptoms': m.symptoms != null ? m.symptoms!.join(',') : null,
        'symptom_severity': m.symptomSeverity != null ? _encodeMap(m.symptomSeverity!) : null,
        'symptom_body_parts': m.symptomBodyParts != null ? _encodeMap(m.symptomBodyParts!) : null,
        'symptom_triggers': m.symptomTriggers != null ? m.symptomTriggers!.join(',') : null,
      }).toList();
    } catch (e) {
      debugPrint('Error reading health metrics from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getMoodLogsFromHive() async {
    try {
      final box = Hive.box<MoodLogModel>('mood_box');
      return box.values.map((m) => {
        'id': m.id,
        'user_id': m.userId,
        'mood_type': m.mood,
        'mood_score': m.intensity,
        'notes': m.notes,
        'timestamp': m.timestamp.toIso8601String(),
      }).toList();
    } catch (e) {
      debugPrint('Error reading mood logs from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getFoodLogsFromHive() async {
    try {
      final box = Hive.box<FoodLogModel>('food_log_box');
      return box.values.map((f) => {
        'id': f.id,
        'user_id': f.userId,
        'meal_type': f.mealType,
        'food_name': f.foodName,
        'calories': f.calories,
        'protein': f.protein,
        'carbs': f.carbs,
        'fats': f.fats,
        'timestamp': f.timestamp.toIso8601String(),
      }).toList();
    } catch (e) {
      debugPrint('Error reading food logs from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getPeriodCyclesFromHive() async {
    try {
      final box = Hive.box<PeriodCycleModel>('period_box');
      return box.values
          .map((p) => {
                'id': p.id,
                'user_id': p.userId,
                'start_date': p.startDate.toIso8601String(),
                'end_date': p.endDate?.toIso8601String(),
                'flow_intensity': p.flowIntensity,
                'symptoms': p.symptoms,
                'mood': p.mood,
                'notes': p.notes,
                'cycle_length': p.cycleLength,
                'created_at': p.createdAt.toIso8601String(),
              })
          .toList();
    } catch (e) {
      debugPrint('Error reading period cycles from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getSymptomsFromHive() async {
    try {
      final box = Hive.box<SymptomModel>('symptom_box');
      return box.values
          .map((s) => {
                'id': s.id,
                'user_id': s.userId,
                'timestamp': s.timestamp.toIso8601String(),
                'symptom_type': s.symptomType,
                'severity': s.severity,
                'body_part': s.bodyPart,
                'notes': s.notes,
                'triggers': s.triggers,
                'created_at': s.createdAt.toIso8601String(),
              })
          .toList();
    } catch (e) {
      debugPrint('Error reading symptoms from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getMeditationSessionsFromHive() async {
    try {
      final box = Hive.box<MeditationSessionModel>('meditation_box');
      return box.values
          .map((m) => {
                'id': m.id,
                'user_id': m.userId,
                'timestamp': m.timestamp.toIso8601String(),
                'type': m.type,
                'duration_minutes': m.durationMinutes,
                'exercise_name': m.exerciseName,
                'notes': m.notes,
                'completed': m.completed,
                'created_at': m.createdAt.toIso8601String(),
              })
          .toList();
    } catch (e) {
      debugPrint('Error reading meditation sessions from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getSugarLogsFromHive() async {
    try {
      final box = Hive.box<SugarLogModel>('sugar_log_box');
      return box.values
          .map((s) => {
                'id': s.id,
                'user_id': s.userId,
                'logged_at': s.loggedAt.toIso8601String(),
                'sugar_type': s.sugarType,
                'label': s.label,
                'estimated_sugar_grams': s.estimatedSugarGrams,
                'estimated_calories': s.estimatedCalories,
                'note': s.note,
                'xp_earned': s.xpEarned,
              })
          .toList();
    } catch (e) {
      debugPrint('Error reading sugar logs from Hive: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getHabitTrackingFromSettings() async {
    try {
      final settings = Hive.box(AppConstants.settingsBox);
      final rows = <Map<String, dynamic>>[];

      for (final key in settings.keys) {
        final rawKey = key.toString();
        if (!rawKey.startsWith('habit_tracker_')) continue;

        final value = settings.get(key);
        if (value is! List) continue;

        final day = rawKey.replaceFirst('habit_tracker_', '');
        rows.add({
          'id': 'habit_${day.replaceAll('-', '')}',
          'user_id': _extractCurrentUserIdFromSettings(settings),
          'day_key': day,
          'completed_habits': value.map((e) => e.toString()).toList(),
        });
      }
      return rows.where((r) => (r['user_id'] ?? '').toString().isNotEmpty).toList();
    } catch (e) {
      debugPrint('Error reading habit tracking from settings: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _getSosProfileFromSettings() async {
    try {
      final settings = Hive.box(AppConstants.settingsBox);
      final userId = _extractCurrentUserIdFromSettings(settings);
      if (userId.isEmpty) return {};

      final contact = settings.get('sos_primary_contact');
      final note = settings.get('sos_medical_note');
      if ((contact == null || contact.toString().isEmpty) &&
          (note == null || note.toString().isEmpty)) {
        return {};
      }

      return {
        'user_id': userId,
        'primary_contact': contact?.toString(),
        'medical_note': note?.toString(),
      };
    } catch (e) {
      debugPrint('Error reading SOS profile from settings: $e');
      return {};
    }
  }

  String _extractCurrentUserIdFromSettings(Box settings) {
    try {
      final userBox = Hive.box<UserModel>(AppConstants.userBox);
      if (userBox.isNotEmpty) {
        final user = userBox.values.first;
        if (user.id.isNotEmpty) {
          return user.id;
        }
      }
    } catch (_) {
      // Fall back to settings-based lookup below.
    }

    final auth = settings.get('auth_user');
    if (auth is Map && auth['id'] != null) {
      return auth['id'].toString();
    }
    return '';
  }
}
