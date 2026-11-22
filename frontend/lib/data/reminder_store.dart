import '../services/api_client.dart';
import '../services/auth_service.dart';

/// One reminder of the patient. Mirrors ReminderResponse:
///   { "id": 60, "reminderType": "MEDICATION", "medicationName": "Metformin",
///     "dosage": "500 mg", "message": null, "scheduledTime": "08:00:00",
///     "daysOfWeek": ["MONDAY","FRIDAY"], "timezone": "Europe/Istanbul",
///     "active": true, "missedCount": 0, ... }
class Reminder {
  static const String medication = 'MEDICATION';
  static const String glucoseCheck = 'GLUCOSE_CHECK';
  static const String meal = 'MEAL';
  static const String appointment = 'APPOINTMENT';
  static const String other = 'OTHER';

  /// Backend type -> screen label, in the order the form offers them.
  static const Map<String, String> typeLabels = {
    medication: 'Medication',
    glucoseCheck: 'Blood Glucose',
    meal: 'Meal',
    appointment: 'Appointment',
    other: 'Other',
  };

  /// DateTime.weekday (1 = Monday) <-> the backend's day names.
  static const List<String> dayNames = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  final int? id;
  final String type;
  final String? medicationName;
  final String? dosage;
  final String? message;
  final int hour;
  final int minute;

  /// DateTime.weekday values, 1 = Monday ... 7 = Sunday.
  final Set<int> days;
  final String? timezone;
  final bool active;
  final int missedCount;

  const Reminder({
    this.id,
    required this.type,
    this.medicationName,
    this.dosage,
    this.message,
    required this.hour,
    required this.minute,
    required this.days,
    this.timezone,
    this.active = true,
    this.missedCount = 0,
  });

  bool get isMedication => type == medication;

  String get typeLabel => typeLabels[type] ?? 'Other';

  /// "Metformin", "Before lunch" or the type.
  String get title {
    if (medicationName != null && medicationName!.isNotEmpty) {
      return medicationName!;
    }
    if (message != null && message!.isNotEmpty) {
      return message!;
    }
    return typeLabel;
  }

  /// "08:00"
  String get timeText =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// "Every day", "Weekdays", "Mon, Wed, Fri"
  String get daysText {
    if (days.length == 7) {
      return 'Every day';
    }
    if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) {
      return 'Weekdays';
    }
    if (days.length == 2 && days.containsAll({6, 7})) {
      return 'Weekends';
    }
    const short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (days.toList()..sort()).map((d) => short[d - 1]).join(', ');
  }

  Reminder copyWith({bool? active}) => Reminder(
        id: id,
        type: type,
        medicationName: medicationName,
        dosage: dosage,
        message: message,
        hour: hour,
        minute: minute,
        days: days,
        timezone: timezone,
        active: active ?? this.active,
        missedCount: missedCount,
      );

  /// Body of POST / PUT /patients/{id}/reminders.
  Map<String, dynamic> toRequestJson() => {
        'reminderType': type,
        if (medicationName != null && medicationName!.trim().isNotEmpty)
          'medicationName': medicationName!.trim(),
        if (dosage != null && dosage!.trim().isNotEmpty) 'dosage': dosage!.trim(),
        if (message != null && message!.trim().isNotEmpty) 'message': message!.trim(),
        'scheduledTime': timeText,
        'daysOfWeek': [for (final d in days.toList()..sort()) dayNames[d - 1]],
        if (timezone != null) 'timezone': timezone,
        'active': active,
      };

  factory Reminder.fromJson(Map<String, dynamic> json) {
    final time = (json['scheduledTime'] as String? ?? '00:00').split(':');
    return Reminder(
      id: (json['id'] as num).toInt(),
      type: json['reminderType'] as String? ?? other,
      medicationName: json['medicationName'] as String?,
      dosage: json['dosage'] as String?,
      message: json['message'] as String?,
      hour: int.parse(time[0]),
      minute: int.parse(time.length > 1 ? time[1] : '0'),
      days: {
        for (final name in json['daysOfWeek'] as List<dynamic>? ?? const [])
          if (dayNames.contains(name)) dayNames.indexOf(name as String) + 1,
      },
      timezone: json['timezone'] as String?,
      active: json['active'] as bool? ?? true,
      missedCount: (json['missedCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// When this reminder rings on the given day, or null when it does not
  /// ring that day (or is paused). Phone's local time.
  DateTime? occurrenceOn(DateTime day) {
    if (!active || !days.contains(day.weekday)) {
      return null;
    }
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}

/// What the patient did with one occurrence (ReminderEventResponse).
class ReminderAnswer {
  static const String taken = 'TAKEN';
  static const String skipped = 'SKIPPED';
  static const String missed = 'MISSED';

  final int reminderId;
  final DateTime scheduledFor;
  final String status;

  const ReminderAnswer({
    required this.reminderId,
    required this.scheduledFor,
    required this.status,
  });

  factory ReminderAnswer.fromJson(Map<String, dynamic> json) => ReminderAnswer(
        reminderId: (json['reminderId'] as num).toInt(),
        scheduledFor: DateTime.parse(json['scheduledFor'] as String).toLocal(),
        status: json['status'] as String,
      );

  /// Same occurrence (to the minute) of the same reminder.
  bool isFor(int id, DateTime at) =>
      reminderId == id &&
      scheduledFor.year == at.year &&
      scheduledFor.month == at.month &&
      scheduledFor.day == at.day &&
      scheduledFor.hour == at.hour &&
      scheduledFor.minute == at.minute;
}

/// The patient's reminders (Nilsu's reminders API):
///   GET    /patients/{id}/reminders
///   POST   /patients/{id}/reminders
///   PUT    /patients/{id}/reminders/{reminderId}
///   DELETE /patients/{id}/reminders/{reminderId}
///   POST   /patients/{id}/reminders/{reminderId}/events   Taken / Skipped / Missed
///   GET    /patients/{id}/reminder-events?from=&to=
class ReminderStore {
  ReminderStore({ApiClient? api, int? patientId})
      : _api = api ?? apiClient,
        _patientId = patientId;

  final ApiClient _api;
  final int? _patientId;

  String get _base {
    final id = _patientId ?? authService.currentUser?.id;
    if (id == null) {
      throw StateError('No logged-in user.');
    }
    return '/patients/$id';
  }

  Future<List<Reminder>> list() async {
    final json = await _api.get('$_base/reminders') as List<dynamic>;
    return [
      for (final item in json) Reminder.fromJson(item as Map<String, dynamic>),
    ];
  }

  Future<Reminder> create(Reminder reminder) async {
    final json = await _api.post('$_base/reminders', body: reminder.toRequestJson());
    return Reminder.fromJson(json as Map<String, dynamic>);
  }

  Future<Reminder> update(Reminder reminder) async {
    final json = await _api.put(
      '$_base/reminders/${reminder.id}',
      body: reminder.toRequestJson(),
    );
    return Reminder.fromJson(json as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('$_base/reminders/$id');

  /// The patient's answer for one occurrence; sending it again changes it.
  Future<ReminderAnswer> answer(int reminderId, DateTime scheduledFor, String status) async {
    final json = await _api.post(
      '$_base/reminders/$reminderId/events',
      body: {
        'scheduledFor': scheduledFor.toUtc().toIso8601String(),
        'status': status,
      },
    );
    return ReminderAnswer.fromJson(json as Map<String, dynamic>);
  }

  /// Answers given between [from] and [to] (first page of up to 200).
  Future<List<ReminderAnswer>> answers({required DateTime from, required DateTime to}) async {
    final query = 'from=${Uri.encodeQueryComponent(from.toUtc().toIso8601String())}'
        '&to=${Uri.encodeQueryComponent(to.toUtc().toIso8601String())}&size=200';
    final json = await _api.get('$_base/reminder-events?$query') as Map<String, dynamic>;
    return [
      for (final item in json['items'] as List<dynamic>)
        ReminderAnswer.fromJson(item as Map<String, dynamic>),
    ];
  }
}

final reminderStore = ReminderStore();
