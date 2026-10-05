import 'package:flutter/foundation.dart';

class GlucoseRecord {
  final double value;
  final DateTime dateTime;
  final String measurementTime;

  const GlucoseRecord({
    required this.value,
    required this.dateTime,
    required this.measurementTime,
  });
}

class GlucoseStore
    extends ValueNotifier<List<GlucoseRecord>> {
  GlucoseStore()
      : super([
          GlucoseRecord(
            value: 105,
            dateTime: DateTime.now().subtract(
              const Duration(hours: 2),
            ),
            measurementTime: 'Fasting',
          ),
        ]);

  void addRecord({
    required double glucoseValue,
    required String measurementTime,
    DateTime? dateTime,
  }) {
    final newRecord = GlucoseRecord(
      value: glucoseValue,
      dateTime: dateTime ?? DateTime.now(),
      measurementTime: measurementTime,
    );

    value = [
      ...value,
      newRecord,
    ];
  }

  GlucoseRecord? get latestRecord {
    if (value.isEmpty) {
      return null;
    }

    final records = [...value]
      ..sort(
        (a, b) => b.dateTime.compareTo(a.dateTime),
      );

    return records.first;
  }

  List<GlucoseRecord> get recentRecords {
    final records = [...value]
      ..sort(
        (a, b) => b.dateTime.compareTo(a.dateTime),
      );

    return records;
  }
}

final glucoseStore = GlucoseStore();