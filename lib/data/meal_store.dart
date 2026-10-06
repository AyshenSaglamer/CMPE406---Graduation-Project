import '../utils/api_enums.dart';
import 'log_store.dart';

class MealRecord implements LogRecord {
  @override
  final int id;

  /// Display label, e.g. "Breakfast".
  final String mealType;
  final DateTime eatenAt;
  final String? description;
  final double? carbsG;

  const MealRecord({
    required this.id,
    required this.mealType,
    required this.eatenAt,
    this.description,
    this.carbsG,
  });

  @override
  DateTime get time => eatenAt;

  /// Mirrors the backend MealLogResponse.
  factory MealRecord.fromJson(Map<String, dynamic> json) {
    return MealRecord(
      id: (json['id'] as num).toInt(),
      mealType: labelForApiValue(mealTypeOptions, json['mealType'] as String?),
      eatenAt: parseApiTime(json['eatenAt']),
      description: json['description'] as String?,
      carbsG: parseApiDecimal(json['carbsG']),
    );
  }
}

final mealStore = LogStore<MealRecord>(
  resource: 'meal-logs',
  fromJson: MealRecord.fromJson,
);
