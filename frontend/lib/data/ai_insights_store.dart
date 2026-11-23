import '../services/api_client.dart';
import '../services/auth_service.dart';

/// The glucose trend the AI model expects next (ai-service
/// future_target_builder: LOWER, STABLE or HIGHER).
class AiTrendPrediction {
  static const String lower = 'LOWER';
  static const String stable = 'STABLE';
  static const String higher = 'HIGHER';

  final String trend;

  /// 0..1, or null when the service sends none.
  final double? confidence;

  const AiTrendPrediction({required this.trend, this.confidence});

  String get label => switch (trend) {
        lower => 'Trending lower',
        higher => 'Trending higher',
        stable => 'Staying stable',
        _ => trend,
      };

  /// "72%" or null.
  String? get confidenceText {
    final c = confidence;
    if (c == null) {
      return null;
    }
    final percent = c <= 1 ? c * 100 : c;
    return '${percent.round()}%';
  }
}

/// Answer of GET /api/v1/ai/patients/{id}/summary (the ai-service
/// patient-summary object, passed through unchanged by Spring):
///   { "record_count": 12,
///     "configured_range": {"low_mg_dl": 70, "high_mg_dl": 180},
///     "analytics": {
///       "glucose_statistics": {"mean", "minimum", "maximum", "standard_deviation"},
///       "time_in_range": {"below_range_percentage", "time_in_range_percentage",
///                         "above_range_percentage"} },
///     "ml_prediction": {"status": "AVAILABLE", "result": {"prediction": "STABLE",
///                                                       "confidence": 0.71}},
///     "insight_summary": {"insights": ["...", "..."]},
///     "disclaimer": "..." }
/// Every field is read defensively: a missing one is null or empty.
class AiSummary {
  final int recordCount;
  final double? mean;
  final double? minimum;
  final double? maximum;
  final double? standardDeviation;
  final double? belowPercent;
  final double? inRangePercent;
  final double? abovePercent;
  final double rangeLow;
  final double rangeHigh;
  final List<String> insights;
  final AiTrendPrediction? prediction;
  final String? disclaimer;

  const AiSummary({
    required this.recordCount,
    this.mean,
    this.minimum,
    this.maximum,
    this.standardDeviation,
    this.belowPercent,
    this.inRangePercent,
    this.abovePercent,
    this.rangeLow = 70,
    this.rangeHigh = 180,
    this.insights = const [],
    this.prediction,
    this.disclaimer,
  });

  bool get hasTimeInRange =>
      belowPercent != null && inRangePercent != null && abovePercent != null;

  factory AiSummary.fromJson(Map<String, dynamic> json) {
    final analytics = _map(json['analytics']);
    final stats = _map(analytics['glucose_statistics']);
    final tir = _map(analytics['time_in_range']);
    final range = _map(json['configured_range']);
    final insightSummary = _map(json['insight_summary']);
    final ml = _map(json['ml_prediction']);
    final result = _map(ml['result']);

    AiTrendPrediction? prediction;
    final trend = result['prediction'];
    if (ml['status'] == 'AVAILABLE' && trend is String && trend.isNotEmpty) {
      prediction = AiTrendPrediction(
        trend: trend,
        confidence: _number(result['confidence']),
      );
    }

    return AiSummary(
      recordCount: _number(json['record_count'])?.toInt() ?? 0,
      mean: _number(stats['mean']),
      minimum: _number(stats['minimum']),
      maximum: _number(stats['maximum']),
      standardDeviation: _number(stats['standard_deviation']),
      belowPercent: _number(tir['below_range_percentage']),
      inRangePercent: _number(tir['time_in_range_percentage']),
      abovePercent: _number(tir['above_range_percentage']),
      rangeLow: _number(range['low_mg_dl']) ?? 70,
      rangeHigh: _number(range['high_mg_dl']) ?? 180,
      insights: [
        for (final item in insightSummary['insights'] as List<dynamic>? ?? const [])
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ],
      prediction: prediction,
      disclaimer: json['disclaimer'] as String?,
    );
  }

  static Map<String, dynamic> _map(Object? value) =>
      value is Map<String, dynamic> ? value : const {};

  static double? _number(Object? value) =>
      value is num ? value.toDouble() : null;
}

/// AI analyses of a patient's logs:
///   GET /api/v1/ai/patients/{patientId}/summary?from=&to=
/// The backend covers at most 31 days per request.
class AiInsightsStore {
  AiInsightsStore({ApiClient? api}) : _api = api ?? apiClient;

  final ApiClient _api;

  /// The backend rejects ranges longer than 31 days.
  static const int maxDays = 30;

  /// Summary of the last [days] days (capped at [maxDays]) of the
  /// logged-in patient, or of [patientId] for a care team member.
  Future<AiSummary> summary({
    required int days,
    int? patientId,
    DateTime? now,
  }) async {
    final id = patientId ?? authService.currentUser?.id;

    if (id == null) {
      throw StateError('No logged-in user.');
    }

    final to = (now ?? DateTime.now()).toUtc();
    final from = to.subtract(Duration(days: days.clamp(1, maxDays)));

    final query = 'from=${Uri.encodeQueryComponent(from.toIso8601String())}'
        '&to=${Uri.encodeQueryComponent(to.toIso8601String())}';

    final json = await _api.get('/ai/patients/$id/summary?$query');

    return AiSummary.fromJson(json as Map<String, dynamic>);
  }
}

final aiInsightsStore = AiInsightsStore();
