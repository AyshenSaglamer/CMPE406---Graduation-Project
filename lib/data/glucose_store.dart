import '../utils/api_enums.dart';
import 'log_store.dart';

class GlucoseRecord implements LogRecord {
  @override
  final int id;
  final double value;
  final DateTime dateTime;

  /// Display label, e.g. "Fasting" or "After meal".
  final String measurementTime;

  final String? notes;

  const GlucoseRecord({
    required this.id,
    required this.value,
    required this.dateTime,
    required this.measurementTime,
    this.notes,
  });

  @override
  DateTime get time => dateTime;

  /// Mirrors the backend GlucoseLogResponse:
  ///   { "id": 1, "glucoseValue": 105,
  ///     "measurementTime": "2026-10-05T08:30:00Z",
  ///     "mealContext": "FASTING", "notes": null, ... }
  factory GlucoseRecord.fromJson(Map<String, dynamic> json) {
    return GlucoseRecord(
      id: (json['id'] as num).toInt(),
      value: (json['glucoseValue'] as num).toDouble(),
      dateTime: parseApiTime(json['measurementTime']),
      measurementTime: labelForApiValue(
        glucoseContextOptions,
        json['mealContext'] as String?,
      ),
      notes: json['notes'] as String?,
    );
  }

  /// Body for POST and PUT .../glucose-logs
  static Map<String, dynamic> requestBody({
    required int glucoseValue,
    required DateTime measuredAt,
    required String mealContextLabel,
    required String clientUuid,
    String? notes,
  }) {
    return {
      'glucoseValue': glucoseValue,
      'measurementTime': measuredAt.toUtc().toIso8601String(),
      'mealContext': glucoseContextOptions[mealContextLabel],
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'source': 'MANUAL',
      'clientUuid': clientUuid,
    };
  }
}

final glucoseStore = LogStore<GlucoseRecord>(
  resource: 'glucose-logs',
  fromJson: GlucoseRecord.fromJson,
);
