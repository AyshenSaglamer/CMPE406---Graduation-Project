import 'activity_store.dart';
import 'glucose_store.dart';
import 'insulin_store.dart';
import 'log_store.dart';
import 'meal_store.dart';

/// A patient's logs for one period, read from the backend, with the
/// numbers shown on the report screen and in the exported PDF / CSV.
class HealthReport {
  /// The target range the time-in-range figures use.
  static const double targetLow = 70;
  static const double targetHigh = 180;

  final DateTime from;

  /// Inclusive day; the logs are read until the end of this day.
  final DateTime to;
  final String patientName;
  final DateTime generatedAt;

  /// Newest first.
  final List<GlucoseRecord> glucose;
  final List<InsulinRecord> insulin;
  final List<MealRecord> meals;
  final List<ActivityRecord> activities;

  /// Kinds of logs the patient does not share with the viewer ("Meals",
  /// "Activity"...): they were not read, so their empty lists mean
  /// "not shared", not "nothing logged". Empty for the patient's own report.
  final List<String> notShared;

  HealthReport({
    required this.from,
    required this.to,
    required this.patientName,
    required this.glucose,
    required this.insulin,
    required this.meals,
    required this.activities,
    this.notShared = const [],
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  /// Reads the four kinds of logs between the start of [from] and the end
  /// of [to] (local days).
  ///
  /// [patientId] reads a family member's or patient's logs (a caregiver or
  /// doctor); the share flags say which kinds that patient shares with the
  /// viewer (glucose, medications = insulin, meals, activity). A kind that is
  /// not shared is not asked for at all and is listed in [notShared].
  static Future<HealthReport> load({
    required DateTime from,
    required DateTime to,
    required String patientName,
    int? patientId,
    bool glucoseShared = true,
    bool insulinShared = true,
    bool mealsShared = true,
    bool activityShared = true,
    LogStore<GlucoseRecord>? glucose,
    LogStore<InsulinRecord>? insulin,
    LogStore<MealRecord>? meals,
    LogStore<ActivityRecord>? activities,
  }) async {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    Future<List<T>> read<T extends LogRecord>(
      bool shared,
      LogStore<T> store,
    ) =>
        shared
            ? store.fetch(from: start, to: end, patientId: patientId)
            : Future.value(<T>[]);

    final results = await Future.wait([
      read(glucoseShared, glucose ?? glucoseStore),
      read(insulinShared, insulin ?? insulinStore),
      read(mealsShared, meals ?? mealStore),
      read(activityShared, activities ?? activityStore),
    ]);

    return HealthReport(
      from: start,
      to: DateTime(to.year, to.month, to.day),
      patientName: patientName,
      glucose: results[0] as List<GlucoseRecord>,
      insulin: results[1] as List<InsulinRecord>,
      meals: results[2] as List<MealRecord>,
      activities: results[3] as List<ActivityRecord>,
      notShared: [
        if (!glucoseShared) 'Blood glucose',
        if (!insulinShared) 'Insulin',
        if (!mealsShared) 'Meals',
        if (!activityShared) 'Activity',
      ],
    );
  }

  bool get isEmpty =>
      glucose.isEmpty && insulin.isEmpty && meals.isEmpty && activities.isEmpty;

  int get days => to.difference(from).inDays + 1;

  double? get averageGlucose => glucose.isEmpty
      ? null
      : glucose.fold<double>(0, (s, r) => s + r.value) / glucose.length;

  double? get lowestGlucose => glucose.isEmpty
      ? null
      : glucose.map((r) => r.value).reduce((a, b) => a < b ? a : b);

  double? get highestGlucose => glucose.isEmpty
      ? null
      : glucose.map((r) => r.value).reduce((a, b) => a > b ? a : b);

  double _share(bool Function(double v) test) => glucose.isEmpty
      ? 0
      : glucose.where((r) => test(r.value)).length * 100 / glucose.length;

  double get belowRangePercent => _share((v) => v < targetLow);
  double get inRangePercent =>
      _share((v) => v >= targetLow && v <= targetHigh);
  double get aboveRangePercent => _share((v) => v > targetHigh);

  double get insulinTotal => insulin.fold(0, (s, r) => s + r.doseUnits);

  double get carbsTotal => meals.fold(0, (s, r) => s + (r.carbsG ?? 0));

  double get activityMinutes =>
      activities.fold(0, (s, r) => s + (r.durationMinutes ?? 0));

  /// "diamate-report-2026-11-01_2026-11-23"
  String get fileBaseName => 'diamate-report-${_isoDay(from)}_${_isoDay(to)}';

  /// One row per log, oldest first:
  ///   type,date_time,value,unit,details
  /// Times are local ("2026-11-23 08:30"). Starts with a UTF-8 byte order
  /// mark so spreadsheet programs read letters such as ş and ğ correctly.
  String toCsv() {
    final rows = <(DateTime, List<Object?>)>[
      for (final r in glucose)
        (r.dateTime, ['Glucose', r.value, 'mg/dL', _join([r.measurementTime, r.notes])]),
      for (final r in insulin)
        (r.administeredAt, ['Insulin', r.doseUnits, 'units', r.type]),
      for (final r in meals)
        (r.eatenAt, ['Meal', r.carbsG, r.carbsG == null ? '' : 'g carbs', _join([r.mealType, r.description])]),
      for (final r in activities)
        (r.startedAt, ['Activity', r.durationMinutes, r.durationMinutes == null ? '' : 'min', r.activityType]),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    final buffer = StringBuffer('﻿')
      ..write('type,date_time,value,unit,details\r\n');

    for (final (time, cells) in rows) {
      final line = [cells[0], formatReportTime(time), cells[1], cells[2], cells[3]]
          .map(_csvCell)
          .join(',');
      buffer.write('$line\r\n');
    }

    return buffer.toString();
  }

  static String _join(List<String?> parts) =>
      parts.where((p) => p != null && p.trim().isNotEmpty).join(' - ');

  /// RFC 4180: quote a cell holding a comma, quote or line break.
  static String _csvCell(Object? value) {
    if (value == null) {
      return '';
    }

    var text = value is double ? formatReportNumber(value) : '$value';

    // A cell starting with = + - @ could run as a formula in a spreadsheet.
    if (text.isNotEmpty && '=+-@'.contains(text[0]) && value is! num) {
      text = "'$text";
    }

    if (text.contains(RegExp(r'[",\r\n]'))) {
      return '"${text.replaceAll('"', '""')}"';
    }

    return text;
  }

  static String _isoDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// "2026-11-23 08:30"
String formatReportTime(DateTime t) =>
    '${HealthReport._isoDay(t)} '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// "23.11.2026"
String formatReportDay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// 6.0 -> "6", 6.5 -> "6.5", 119.333 -> "119.3"
String formatReportNumber(double v) {
  if (v % 1 == 0) {
    return v.toInt().toString();
  }
  return v.toStringAsFixed(1);
}
