import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/hydration_model.dart';
import '../models/mood_log_model.dart';
import '../models/symptom_model.dart';

/// Service to communicate with FastAPI ML backend
class MLPredictionService {
  static const String _productionUrl = 'https://novahealth-backend.onrender.com';

  // In debug mode, use local backend for both web and mobile dev.
  static String get baseUrl {
    if (kDebugMode) {
      return kIsWeb ? 'http://127.0.0.1:8000' : 'http://localhost:8000';
    }
    return _productionUrl;
  }
  
  /// Predict comprehensive health risk
  Future<HealthRiskPrediction> predictHealthRisk({
    required UserModel user,
    required List<HydrationModel> hydrationLogs,
    required List<MoodLogModel> moodLogs,
    required List<SymptomModel> symptoms,
    int? exerciseDuration,
    int? exerciseIntensity,
    int? heartRate,
    double? sleepHours,
    int? caloriesConsumed,
  }) async {
    try {
      // Calculate total water intake
      final totalWaterMl = hydrationLogs.fold<int>(
        0,
        (sum, log) => sum + log.amountMl,
      );
      
      // Prepare request body
      final requestBody = {
        'userProfile': {
          'age': user.age ?? 25,
          'gender': user.gender ?? 'female',
          'weight': user.weight ?? 60.0,
          'height': user.height ?? 165.0,
          'activityLevel': user.activityLevel,
          'targetWeight': user.targetWeight,
        },
        'lifestyleData': {
          'totalWaterMl': totalWaterMl,
          'hydrationLogs': hydrationLogs.map((h) => h.toJson()).toList(),
          'moodLogs': moodLogs.map((m) => m.toJson()).toList(),
          'symptoms': symptoms.map((s) => s.toJson()).toList(),
          'exerciseDuration': exerciseDuration ?? 0,
          'exerciseIntensity': exerciseIntensity ?? 5,
          'heartRate': heartRate,
          'sleepHours': sleepHours,
          'caloriesConsumed': caloriesConsumed,
        },
        'dateRange': 7,
      };
      
      // Make API call
      final response = await http.post(
        Uri.parse('$baseUrl/predict/health-risk'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return HealthRiskPrediction.fromJson(data);
      } else {
        throw Exception('Failed to get prediction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('ML Prediction Error: $e');
    }
  }
  
  /// Check if ML API server is running
  Future<bool> checkServerHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

/// Symptom Risk Analysis
class SymptomRiskAnalysis {
  final List<String> probableConditions;
  final String riskLevel;
  final String urgency;
  final List<Map<String, dynamic>> detectedSymptoms;
  
  SymptomRiskAnalysis({
    required this.probableConditions,
    required this.riskLevel,
    required this.urgency,
    required this.detectedSymptoms,
  });
  
  factory SymptomRiskAnalysis.fromJson(Map<String, dynamic> json) {
    return SymptomRiskAnalysis(
      probableConditions: List<String>.from(json['probableConditions']),
      riskLevel: json['riskLevel'],
      urgency: json['urgency'],
      detectedSymptoms: List<Map<String, dynamic>>.from(json['detectedSymptoms']),
    );
  }
}

/// Health Risk Prediction Response Model
class HealthRiskPrediction {
  final ObesityRiskResult obesityRisk;
  final ExerciseRecommendation? exerciseRecommendation;
  final SymptomRiskAnalysis? symptomRiskAnalysis;
  final double overallRiskScore;
  final List<String> keyInsights;
  
  HealthRiskPrediction({
    required this.obesityRisk,
    this.exerciseRecommendation,
    this.symptomRiskAnalysis,
    required this.overallRiskScore,
    required this.keyInsights,
  });
  
  factory HealthRiskPrediction.fromJson(Map<String, dynamic> json) {
    return HealthRiskPrediction(
      obesityRisk: ObesityRiskResult.fromJson(json['obesityRisk']),
      exerciseRecommendation: json['exerciseRecommendation'] != null
          ? ExerciseRecommendation.fromJson(json['exerciseRecommendation'])
          : null,
      symptomRiskAnalysis: json['symptomRiskAnalysis'] != null
          ? SymptomRiskAnalysis.fromJson(json['symptomRiskAnalysis'])
          : null,
      overallRiskScore: json['overallRiskScore'].toDouble(),
      keyInsights: List<String>.from(json['keyInsights']),
    );
  }
}

/// Obesity Risk Result
class ObesityRiskResult {
  final String riskLevel;
  final double confidence;
  final double bmi;
  final double bmr;
  final List<String> recommendations;
  final Map<String, double> allProbabilities;
  
  ObesityRiskResult({
    required this.riskLevel,
    required this.confidence,
    required this.bmi,
    required this.bmr,
    required this.recommendations,
    required this.allProbabilities,
  });
  
  factory ObesityRiskResult.fromJson(Map<String, dynamic> json) {
    return ObesityRiskResult(
      riskLevel: json['riskLevel'],
      confidence: json['confidence'].toDouble(),
      bmi: json['bmi'].toDouble(),
      bmr: json['bmr'].toDouble(),
      recommendations: List<String>.from(json['recommendations']),
      allProbabilities: Map<String, double>.from(
        json['allProbabilities'].map((k, v) => MapEntry(k, v.toDouble())),
      ),
    );
  }
  
  String get riskLevelDisplay {
    return riskLevel.replaceAll('_', ' ');
  }
  
  String get riskColor {
    if (riskLevel.contains('Obesity')) return 'red';
    if (riskLevel.contains('Overweight')) return 'orange';
    if (riskLevel == 'Normal_Weight') return 'green';
    return 'yellow';
  }
}

/// Exercise Recommendation
class ExerciseRecommendation {
  final double predictedCalories;
  final double caloriesPerMinute;
  final double metScore;
  final String intensityLevel;
  final List<String> recommendations;
  
  ExerciseRecommendation({
    required this.predictedCalories,
    required this.caloriesPerMinute,
    required this.metScore,
    required this.intensityLevel,
    required this.recommendations,
  });
  
  factory ExerciseRecommendation.fromJson(Map<String, dynamic> json) {
    return ExerciseRecommendation(
      predictedCalories: json['predictedCalories'].toDouble(),
      caloriesPerMinute: json['caloriesPerMinute'].toDouble(),
      metScore: json['metScore'].toDouble(),
      intensityLevel: json['intensityLevel'],
      recommendations: List<String>.from(json['recommendations']),
    );
  }
}
