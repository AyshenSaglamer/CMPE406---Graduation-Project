import 'dart:math';

import '../services/api_client.dart';
import '../services/auth_service.dart';

/// One statement the AI assistant understood. Mirrors AiParseResponse.Entry:
///   { "intent": "LOG_GLUCOSE", "status": "SUCCESS", "value": 125.0,
///     "unit": "mg/dL", "activity": null, "message": null }
/// status is SUCCESS, MISSING_VALUE or INVALID_VALUE (then [message] says
/// what is wrong). Only SUCCESS entries can be saved.
class AiEntry {
  static const String glucose = 'LOG_GLUCOSE';
  static const String insulin = 'LOG_INSULIN';
  static const String meal = 'LOG_MEAL';
  static const String activity = 'LOG_ACTIVITY';

  final String intent;
  final String status;
  final double? value;
  final String? unit;
  final String? activityName;
  final String? message;

  /// Sent with the save request, so saving the same entry twice (e.g. a retry
  /// after a lost answer) stores it only once.
  final String clientUuid;

  AiEntry({
    required this.intent,
    required this.status,
    this.value,
    this.unit,
    this.activityName,
    this.message,
    String? clientUuid,
  }) : clientUuid = clientUuid ?? newUuid();

  bool get canSave => status == 'SUCCESS' && value != null && value! > 0;

  String get title => switch (intent) {
        glucose => 'Glucose',
        insulin => 'Insulin',
        meal => 'Meal carbs',
        activity => activityName == null || activityName!.isEmpty
            ? 'Activity'
            : 'Activity • ${activityName!}',
        _ => 'Entry',
      };

  factory AiEntry.fromJson(Map<String, dynamic> json) {
    return AiEntry(
      intent: json['intent'] as String? ?? '',
      status: json['status'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      activityName: json['activity'] as String?,
      message: json['message'] as String?,
    );
  }

  /// One item of POST /patients/{id}/ai-entries. intent, value, unit and
  /// activity are copied from the parse answer; "at" is left empty (= now).
  Map<String, dynamic> toSaveJson() => {
        'intent': intent,
        'value': value,
        if (unit != null && unit!.isNotEmpty) 'unit': unit,
        if (activityName != null && activityName!.isNotEmpty)
          'activity': activityName,
        'clientUuid': clientUuid,
      };
}

/// Answer of POST /ai/parse. status is SUCCESS (at least one entry
/// understood) or UNKNOWN (nothing understood; see [message]).
class AiParseResult {
  final String status;
  final List<AiEntry> entries;
  final String? message;

  const AiParseResult({
    required this.status,
    required this.entries,
    this.message,
  });

  List<AiEntry> get savable => entries.where((e) => e.canSave).toList();

  factory AiParseResult.fromJson(Map<String, dynamic> json) {
    return AiParseResult(
      status: json['status'] as String? ?? 'UNKNOWN',
      entries: [
        for (final item in json['results'] as List<dynamic>? ?? const [])
          AiEntry.fromJson(item as Map<String, dynamic>),
      ],
      message: json['message'] as String?,
    );
  }
}

/// The AI assistant of the logged-in patient:
///   POST /api/v1/ai/parse                       what was understood (nothing saved)
///   POST /api/v1/patients/{patientId}/ai-entries saves the entries the patient confirmed
class AiStore {
  AiStore({ApiClient? api}) : _api = api ?? apiClient;

  final ApiClient _api;

  /// The backend accepts at most 500 characters.
  static const int maxTextLength = 500;

  /// The backend saves at most 10 entries per request.
  static const int _maxPerSave = 10;

  Future<AiParseResult> parse(String text) async {
    final json = await _api.post('/ai/parse', body: {'text': text.trim()});

    return AiParseResult.fromJson(json as Map<String, dynamic>);
  }

  /// Saves [entries] for the logged-in patient (or [patientId]) and returns
  /// the backend's savedCount (one per entry). Entries already saved before
  /// (same clientUuid) are not stored a second time.
  Future<int> save(List<AiEntry> entries, {int? patientId}) async {
    final id = patientId ?? authService.currentUser?.id;

    if (id == null) {
      throw StateError('No logged-in user.');
    }

    var saved = 0;

    for (var start = 0; start < entries.length; start += _maxPerSave) {
      final chunk = entries.skip(start).take(_maxPerSave);
      final json = await _api.post(
        '/patients/$id/ai-entries',
        body: {'entries': [for (final e in chunk) e.toSaveJson()]},
      ) as Map<String, dynamic>;

      saved += (json['savedCount'] as num).toInt();
    }

    return saved;
  }
}

final aiStore = AiStore();

final Random _random = Random.secure();

/// A random (version 4) UUID, e.g. "3f2a9c1e-7b4d-4e8a-9c2f-1a2b3c4d5e6f".
String newUuid() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
