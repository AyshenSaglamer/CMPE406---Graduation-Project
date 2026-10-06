import '../utils/api_enums.dart';
import 'log_store.dart';

class InsulinRecord implements LogRecord {
  @override
  final int id;
  final double doseUnits;

  /// Display label, e.g. "Rapid-acting".
  final String type;
  final DateTime administeredAt;

  const InsulinRecord({
    required this.id,
    required this.doseUnits,
    required this.type,
    required this.administeredAt,
  });

  @override
  DateTime get time => administeredAt;

  /// Mirrors the backend InsulinLogResponse.
  factory InsulinRecord.fromJson(Map<String, dynamic> json) {
    return InsulinRecord(
      id: (json['id'] as num).toInt(),
      doseUnits: parseApiDecimal(json['doseUnits']) ?? 0,
      type: labelForApiValue(
        insulinTypeOptions,
        json['insulinType'] as String?,
      ),
      administeredAt: parseApiTime(json['administeredAt']),
    );
  }
}

final insulinStore = LogStore<InsulinRecord>(
  resource: 'insulin-logs',
  fromJson: InsulinRecord.fromJson,
);
