import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/sugar_log_provider.dart';
import 'ml_prediction_service.dart';

/// Calls the FastAPI backend for cause-effect sugar insights,
/// with a local offline fallback.
class SugarInsightService {
  String get _baseUrl => MLPredictionService.baseUrl;

  /// POST /predict/sugar-insight
  /// Body: { sugarType, bmi, steps }
  /// Returns: { shortTermImpact, correctiveAction }
  Future<SugarInsightResult> getSugarInsight({
    required String sugarType,
    double? bmi,
    int? steps,
  }) async {
    final body = {
      'sugarType': sugarType,
      'bmi': bmi ?? 22.0,
      'steps': steps ?? 0,
    };

    final response = await http
        .post(
          Uri.parse('$_baseUrl/predict/sugar-insight'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return SugarInsightResult(
        shortTermImpact: data['shortTermImpact'] as String,
        correctiveAction: data['correctiveAction'] as String,
      );
    } else {
      throw Exception('Sugar insight API error: ${response.statusCode}');
    }
  }

  /// Offline rule-based fallback so the user always gets feedback.
  SugarInsightResult localFallbackInsight(String sugarType) {
    switch (sugarType) {
      case 'chai':
        return const SugarInsightResult(
          shortTermImpact:
              'The ~10 g of sugar in chai can cause a mild glucose bump in 20 min.',
          correctiveAction:
              'Take a 5-minute walk after your chai to blunt the spike.',
        );
      case 'cold_drink':
        return const SugarInsightResult(
          shortTermImpact:
              '~35 g of liquid sugar absorbs fast — expect a sharp spike in 15 min and an energy crash later.',
          correctiveAction:
              'Go for a brisk 10-minute walk right now, or drink a glass of water first next time.',
        );
      case 'sweets':
        return const SugarInsightResult(
          shortTermImpact:
              '~25 g of sugar from sweets can disrupt your sleep quality tonight.',
          correctiveAction:
              'Pair sweets with a handful of nuts to slow sugar absorption.',
        );
      case 'snack':
        return const SugarInsightResult(
          shortTermImpact:
              'Packaged snacks add hidden sugar (~15 g) plus sodium. Energy dip expected in ~45 min.',
          correctiveAction:
              'Next time swap for a fruit — or take 10 minutes of stairs now.',
        );
      default:
        return const SugarInsightResult(
          shortTermImpact: 'Sugar logged — glucose will rise within 30 min.',
          correctiveAction:
              'A short walk or 20 squats can help your body use the sugar faster.',
        );
    }
  }
}
