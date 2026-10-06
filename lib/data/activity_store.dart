import 'log_store.dart';

class ActivityRecord implements LogRecord {
  @override
  final int id;

  /// Free text, e.g. "Walking".
  final String activityType;
  final DateTime startedAt;
  final double? durationMinutes;

  const ActivityRecord({
    required this.id,
    required this.activityType,
    required this.startedAt,
    this.durationMinutes,
  });

  @override
  DateTime get time => startedAt;

  /// Mirrors the backend ActivityLogResponse.
  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    return ActivityRecord(
      id: (json['id'] as num).toInt(),
      activityType: json['activityType'] as String,
      startedAt: parseApiTime(json['startedAt']),
      durationMinutes: parseApiDecimal(json['durationMinutes']),
    );
  }
}

final activityStore = LogStore<ActivityRecord>(
  resource: 'activity-logs',
  fromJson: ActivityRecord.fromJson,
);
