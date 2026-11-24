import '../utils/api_enums.dart';

/// Reads blood glucose readings from a CSV file (exported from a meter app
/// or written by hand) for the Import CSV screen.
///
/// The first line names the columns (any order, any case):
///   - `date` and `time` (or one `datetime` / `timestamp` column)
///   - `glucose` (also `value`, `mg/dl`, `bg`), in mg/dL
///   - optional `context` (Fasting, Before meal, After meal, Bedtime,
///     Exercise, Other) and `notes`
///
/// Separator: comma or semicolon. Dates: 2026-11-23, 23.11.2026 or
/// 23/11/2026. Times: 08:30 or 08:30:15.
class GlucoseCsv {
  GlucoseCsv._();

  /// The backend accepts 10–600 mg/dL (GlucoseLogRequest).
  static const int minValue = 10;
  static const int maxValue = 600;

  /// Rows read at most from one file.
  static const int maxRows = 5000;

  static const _dateNames = {'date', 'day', 'tarih'};
  static const _timeNames = {'time', 'hour', 'saat'};
  static const _dateTimeNames = {
    'datetime',
    'date_time',
    'timestamp',
    'measured_at',
    'measurement_time',
  };
  static const _valueNames = {
    'glucose',
    'value',
    'mg/dl',
    'mgdl',
    'glucose_mg_dl',
    'glucose (mg/dl)',
    'bg',
    'blood_glucose',
    'blood glucose',
    'kan sekeri',
    'kan şekeri',
  };
  static const _contextNames = {'context', 'meal_context', 'type', 'when'};
  static const _notesNames = {'notes', 'note', 'comment', 'not'};

  /// Every data row of [text], in file order, with what is wrong with it.
  /// Throws [FormatException] when the header has no date or glucose column.
  static List<CsvGlucoseRow> parse(String text, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final lines = text
        .replaceFirst('﻿', '')
        .split(RegExp(r'\r\n|\r|\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      throw const FormatException('The file is empty.');
    }

    final separator = _separatorOf(lines.first);
    final header = _split(lines.first, separator)
        .map((h) => h.trim().toLowerCase())
        .toList();

    int find(Set<String> names) => header.indexWhere(names.contains);

    final dateCol = find(_dateNames);
    final timeCol = find(_timeNames);
    final dateTimeCol = find(_dateTimeNames);
    final valueCol = find(_valueNames);
    final contextCol = find(_contextNames);
    final notesCol = find(_notesNames);

    if (valueCol < 0) {
      throw const FormatException(
        'No glucose column. Name one column "glucose".',
      );
    }
    if (dateCol < 0 && dateTimeCol < 0) {
      throw const FormatException(
        'No date column. Name one column "date" (and one "time").',
      );
    }

    final rows = <CsvGlucoseRow>[];
    final seen = <String>{};

    for (var i = 1; i < lines.length && rows.length < maxRows; i++) {
      final cells = _split(lines[i], separator);
      String cell(int col) =>
          col >= 0 && col < cells.length ? cells[col].trim() : '';

      final rawDate = dateTimeCol >= 0 ? cell(dateTimeCol) : cell(dateCol);
      final rawTime = dateTimeCol >= 0 ? '' : cell(timeCol);
      final rawValue = cell(valueCol);
      final rawContext = cell(contextCol);

      final at = _parseDateTime(rawDate, rawTime);
      final value = _parseValue(rawValue);
      final context = _parseContext(rawContext);

      String? problem;
      if (at == null) {
        problem = 'Unreadable date or time';
      } else if (at.isAfter(current)) {
        problem = 'Date is in the future';
      } else if (value == null) {
        problem = 'Glucose is not a number';
      } else if (value < minValue || value > maxValue) {
        problem = 'Glucose must be $minValue–$maxValue mg/dL';
      } else if (rawContext.isNotEmpty && context == null) {
        problem = 'Unknown context "$rawContext"';
      } else if (!seen.add('${at.millisecondsSinceEpoch}|$value')) {
        problem = 'Same reading twice in the file';
      }

      rows.add(CsvGlucoseRow(
        line: i + 1,
        measuredAt: at,
        value: value,
        mealContext: context,
        notes: cell(notesCol),
        rawDate: rawDate,
        rawTime: rawTime,
        rawValue: rawValue,
        problem: problem,
      ));
    }

    return rows;
  }

  static String _separatorOf(String headerLine) {
    final commas = ','.allMatches(headerLine).length;
    final semicolons = ';'.allMatches(headerLine).length;
    return semicolons > commas ? ';' : ',';
  }

  /// One CSV line into cells; double quotes may wrap a cell that contains
  /// the separator, and "" inside quotes is a quote.
  static List<String> _split(String line, String separator) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var quoted = false;

    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (quoted) {
        if (c == '"' && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else if (c == '"') {
          quoted = false;
        } else {
          buffer.write(c);
        }
      } else if (c == '"') {
        quoted = true;
      } else if (c == separator) {
        cells.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    cells.add(buffer.toString());
    return cells;
  }

  /// Whole mg/dL: "105", "105.0" or "105,0" (a decimal comma).
  static int? _parseValue(String raw) {
    final text = raw.replaceAll(',', '.');
    final number = double.tryParse(text);
    if (number == null || number.isNaN || number.isInfinite) {
      return null;
    }
    return number.round();
  }

  static String? _parseContext(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    final wanted = raw.toLowerCase().replaceAll(RegExp(r'[_\-]'), ' ');
    for (final entry in glucoseContextOptions.entries) {
      if (entry.key.toLowerCase() == wanted ||
          entry.value.toLowerCase().replaceAll('_', ' ') == wanted) {
        return entry.value;
      }
    }
    return null;
  }

  static final _isoDate = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$');
  static final _dayFirst = RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{4})$');
  static final _clock = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$');

  /// Phone's local time. [time] empty: [date] may carry the time itself
  /// ("2026-11-23 08:30", "2026-11-23T08:30:00", or ISO with a zone).
  static DateTime? _parseDateTime(String date, String time) {
    var datePart = date;
    var timePart = time;

    if (timePart.isEmpty) {
      // Full ISO with a zone ("...Z", "+03:00"): DateTime.parse handles it.
      if (RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(date) &&
          date.contains('T')) {
        return DateTime.tryParse(date)?.toLocal();
      }
      final parts = date.split(RegExp(r'[T ]'));
      datePart = parts.first;
      timePart = parts.length > 1 ? parts[1] : '';
    }

    int year;
    int month;
    int day;
    final iso = _isoDate.firstMatch(datePart);
    final dayFirst = _dayFirst.firstMatch(datePart);
    if (iso != null) {
      year = int.parse(iso.group(1)!);
      month = int.parse(iso.group(2)!);
      day = int.parse(iso.group(3)!);
    } else if (dayFirst != null) {
      day = int.parse(dayFirst.group(1)!);
      month = int.parse(dayFirst.group(2)!);
      year = int.parse(dayFirst.group(3)!);
    } else {
      return null;
    }

    var hour = 0;
    var minute = 0;
    var second = 0;
    if (timePart.isNotEmpty) {
      final clock = _clock.firstMatch(timePart);
      if (clock == null) {
        return null;
      }
      hour = int.parse(clock.group(1)!);
      minute = int.parse(clock.group(2)!);
      second = int.parse(clock.group(3) ?? '0');
    } else {
      // A date without a time is not enough for a reading.
      return null;
    }

    if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 ||
        minute > 59 || second > 59) {
      return null;
    }
    final result = DateTime(year, month, day, hour, minute, second);
    // 31.02.2026 rolls over into March: not a real date.
    if (result.month != month || result.day != day) {
      return null;
    }
    return result;
  }

  /// Same reading → same id, so importing the same file twice does not save
  /// it twice (the backend keeps one log per patient and clientUuid).
  static String clientUuidFor(DateTime measuredAt, int value) {
    final key = 'diamate-csv|${measuredAt.toUtc().toIso8601String()}|$value';
    final a = _fnv1a64(key, 0xcbf29ce484222325);
    final b = _fnv1a64(key, 0x84222325cbf29ce4);
    final bytes = [
      for (var i = 7; i >= 0; i--) (a >> (i * 8)) & 0xff,
      for (var i = 7; i >= 0; i--) (b >> (i * 8)) & 0xff,
    ];
    bytes[6] = (bytes[6] & 0x0f) | 0x50; // version 5 style: name based
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  static int _fnv1a64(String text, int seed) {
    var hash = seed;
    for (final unit in text.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001b3; // wraps at 64 bits
    }
    return hash;
  }
}

/// One data line of the CSV file.
class CsvGlucoseRow {
  /// Line number in the file (the header is line 1).
  final int line;
  final DateTime? measuredAt;
  final int? value;

  /// API value (FASTING, ...) or null.
  final String? mealContext;
  final String notes;

  final String rawDate;
  final String rawTime;
  final String rawValue;

  /// Why it cannot be imported; null when it can.
  final String? problem;

  const CsvGlucoseRow({
    required this.line,
    required this.measuredAt,
    required this.value,
    required this.mealContext,
    required this.notes,
    required this.rawDate,
    required this.rawTime,
    required this.rawValue,
    required this.problem,
  });

  bool get isValid => problem == null;

  /// Body for POST .../glucose-logs (GlucoseLogRequest).
  Map<String, dynamic> requestBody() => {
        'glucoseValue': value,
        'measurementTime': measuredAt!.toUtc().toIso8601String(),
        if (mealContext != null) 'mealContext': mealContext,
        if (notes.isNotEmpty)
          'notes': notes.length > 1000 ? notes.substring(0, 1000) : notes,
        'source': 'MANUAL',
        'clientUuid': GlucoseCsv.clientUuidFor(measuredAt!, value!),
      };
}
