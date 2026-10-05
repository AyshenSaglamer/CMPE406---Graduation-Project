String formatApiDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');

  return '$y-$m-$d';
}

const Map<String, String> genderOptions = {
  'Female': 'FEMALE',
  'Male': 'MALE',
  'Other': 'OTHER',
};

const Map<String, String> glucoseContextOptions = {
  'Fasting': 'FASTING',
  'Before meal': 'BEFORE_MEAL',
  'After meal': 'AFTER_MEAL',
  'Bedtime': 'BEDTIME',
  'Exercise': 'EXERCISE',
  'Other': 'OTHER',
};

const int glucoseMinMgDl = 10;
const int glucoseMaxMgDl = 600;

const Map<String, String> mealTypeOptions = {
  'Breakfast': 'BREAKFAST',
  'Lunch': 'LUNCH',
  'Dinner': 'DINNER',
  'Snack': 'SNACK',
  'Other': 'OTHER',
};

const Map<String, String> insulinTypeOptions = {
  'Rapid-acting': 'RAPID',
  'Short-acting': 'SHORT',
  'Intermediate-acting': 'INTERMEDIATE',
  'Long-acting': 'LONG',
  'Mixed': 'MIXED',
};

const Map<String, String> insulinDeliveryOptions = {
  'Pen': 'PEN',
  'Syringe': 'SYRINGE',
  'Pump (bolus)': 'PUMP_BOLUS',
  'Pump (basal)': 'PUMP_BASAL',
  'Other': 'OTHER',
};

const double insulinMaxUnits = 300;

const Map<String, String> activityIntensityOptions = {
  'Light': 'LOW',
  'Moderate': 'MODERATE',
  'Intense': 'HIGH',
};

const Map<String, String> reminderTypeOptions = {
  'Blood Glucose': 'GLUCOSE_CHECK',
  'Medication': 'MEDICATION',
  'Meal': 'MEAL',
  'Appointment': 'APPOINTMENT',
  'Other': 'OTHER',
};