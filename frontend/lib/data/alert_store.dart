import '../services/api_client.dart';
import 'log_store.dart';

/// A patient who gave the logged-in clinician / caregiver access.
/// Mirrors the backend CareTeamPatientResponse (only the fields the app uses).
class CareTeamPatient {
  final int id;
  final String firstName;
  final String lastName;

  /// can_receive_alerts: without it the alerts API answers 404 for this patient.
  final bool canReceiveAlerts;

  const CareTeamPatient({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.canReceiveAlerts,
  });

  String get name => '$firstName $lastName';

  ///   { "patientId": 19, "firstName": "Ayşe", "lastName": "Kaya",
  ///     "canReceiveAlerts": true, ... }
  factory CareTeamPatient.fromJson(Map<String, dynamic> json) {
    return CareTeamPatient(
      id: (json['patientId'] as num).toInt(),
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      canReceiveAlerts: json['canReceiveAlerts'] as bool? ?? false,
    );
  }
}

/// Backend alert_type -> screen label. The backend creates only the four
/// glucose types for now; the others are listed so a future type still reads well.
const Map<String, String> alertTypeLabels = {
  'URGENT_LOW': 'Urgent low',
  'LOW': 'Low',
  'HIGH': 'High',
  'URGENT_HIGH': 'Urgent high',
  'RAPID_RISE': 'Rising fast',
  'RAPID_FALL': 'Falling fast',
  'MISSED_DOSE': 'Missed dose',
  'NO_DATA': 'No recent data',
  'PREDICTIVE_LOW': 'Low expected',
};

/// One alert of a patient. Mirrors the backend AlertResponse:
///   { "id": 41, "patientId": 19, "alertType": "URGENT_LOW",
///     "severity": "CRITICAL", "glucoseLogId": 103, "valueMgdl": 48.0,
///     "message": "Urgent low glucose: 48 mg/dL", "status": "OPEN",
///     "triggeredAt": "2026-10-13T08:12:00Z", "acknowledgedBy": null,
///     "acknowledgedAt": null, "resolvedAt": null, "resolvedBy": null }
/// acknowledgedBy / resolvedBy are user ids (the backend sends no names);
/// resolvedBy is null for alerts resolved before the backend recorded it.
class PatientAlert {
  static const String open = 'OPEN';
  static const String acknowledged = 'ACKNOWLEDGED';
  static const String resolved = 'RESOLVED';
  static const String dismissed = 'DISMISSED';

  final int id;
  final int patientId;
  final String type;
  final String severity;

  /// The reading that triggered the alert.
  final int? glucoseLogId;
  final double? valueMgdl;
  final String message;
  final String status;
  final DateTime triggeredAt;
  final int? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final int? resolvedBy;
  final DateTime? resolvedAt;

  const PatientAlert({
    required this.id,
    required this.patientId,
    required this.type,
    required this.severity,
    this.glucoseLogId,
    required this.valueMgdl,
    required this.message,
    required this.status,
    required this.triggeredAt,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolvedBy,
    this.resolvedAt,
  });

  bool get isCritical => severity == 'CRITICAL';

  /// RESOLVED and DISMISSED alerts cannot change any more (the backend answers 409).
  bool get isClosed => status == resolved || status == dismissed;

  String get typeLabel => alertTypeLabels[type] ?? 'Alert';

  factory PatientAlert.fromJson(Map<String, dynamic> json) {
    return PatientAlert(
      id: (json['id'] as num).toInt(),
      patientId: (json['patientId'] as num).toInt(),
      type: json['alertType'] as String,
      severity: json['severity'] as String,
      glucoseLogId: (json['glucoseLogId'] as num?)?.toInt(),
      valueMgdl: parseApiDecimal(json['valueMgdl']),
      message: json['message'] as String,
      status: json['status'] as String,
      triggeredAt: parseApiTime(json['triggeredAt']),
      acknowledgedBy: (json['acknowledgedBy'] as num?)?.toInt(),
      resolvedBy: (json['resolvedBy'] as num?)?.toInt(),
      acknowledgedAt: json['acknowledgedAt'] == null
          ? null
          : parseApiTime(json['acknowledgedAt']),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : parseApiTime(json['resolvedAt']),
    );
  }
}

/// An alert together with the patient it belongs to (for the care team's list).
class CareTeamAlert {
  final CareTeamPatient patient;
  final PatientAlert alert;

  const CareTeamAlert(this.patient, this.alert);

  /// Mirrors the backend CareTeamAlertResponse:
  ///   { "patientId": 19, "patientFirstName": "Ayşe",
  ///     "patientLastName": "Kaya", "alert": { ...AlertResponse... } }
  /// The backend lists only patients who share alerts, so canReceiveAlerts is true.
  factory CareTeamAlert.fromJson(Map<String, dynamic> json) {
    return CareTeamAlert(
      CareTeamPatient(
        id: (json['patientId'] as num).toInt(),
        firstName: json['patientFirstName'] as String,
        lastName: json['patientLastName'] as String,
        canReceiveAlerts: true,
      ),
      PatientAlert.fromJson(json['alert'] as Map<String, dynamic>),
    );
  }
}

/// Alerts of the patients who gave the logged-in clinician / caregiver access:
///   GET   /api/v1/care-team/patients
///   GET   /api/v1/care-team/alerts?status=
///   GET   /api/v1/patients/{patientId}/alerts?status=
///   PATCH /api/v1/patients/{patientId}/alerts/{alertId}
class AlertStore {
  AlertStore({ApiClient? api}) : _api = api ?? apiClient;

  final ApiClient _api;

  /// The backend allows at most 200 items per page.
  static const int _pageSize = 200;

  Future<List<CareTeamPatient>> careTeamPatients() async {
    final json = await _api.get('/care-team/patients') as List<dynamic>;

    return json
        .map((item) => CareTeamPatient.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Every alert of one patient, newest first. [status] is optional
  /// (OPEN, ACKNOWLEDGED, RESOLVED, DISMISSED). Unlike the logs there is no
  /// 14-day default: an OPEN alert stays listed until someone handles it.
  Future<List<PatientAlert>> alertsOf(int patientId, {String? status}) async {
    final alerts = <PatientAlert>[];
    var page = 0;
    var totalPages = 1;

    while (page < totalPages) {
      final json = await _api.get(
        '/patients/$patientId/alerts?page=$page&size=$_pageSize'
        '${status == null ? '' : '&status=$status'}',
      ) as Map<String, dynamic>;

      for (final item in json['items'] as List<dynamic>) {
        alerts.add(PatientAlert.fromJson(item as Map<String, dynamic>));
      }

      totalPages = (json['totalPages'] as num).toInt();
      page++;
    }

    return alerts;
  }

  /// Alerts of every patient on the care list who allows alerts, newest first,
  /// from GET /care-team/alerts: one request per page instead of one per
  /// patient. The backend only includes ACTIVE relationships with
  /// can_receive_alerts, so there is nothing to filter or skip here.
  Future<List<CareTeamAlert>> careTeamAlerts({String? status}) async {
    final items = <CareTeamAlert>[];
    var page = 0;
    var totalPages = 1;

    while (page < totalPages) {
      final json = await _api.get(
        '/care-team/alerts?page=$page&size=$_pageSize'
        '${status == null ? '' : '&status=$status'}',
      ) as Map<String, dynamic>;

      for (final item in json['items'] as List<dynamic>) {
        items.add(CareTeamAlert.fromJson(item as Map<String, dynamic>));
      }

      totalPages = (json['totalPages'] as num).toInt();
      page++;
    }

    return items;
  }

  /// Number of OPEN alerts across the care list: a single request for one
  /// item, the count is totalElements.
  Future<int> openCareTeamAlertCount() async {
    final json = await _api.get(
      '/care-team/alerts?status=${PatientAlert.open}&size=1',
    ) as Map<String, dynamic>;

    return (json['totalElements'] as num).toInt();
  }

  /// Number of OPEN alerts of one patient (e.g. the logged-in patient's own).
  Future<int> openAlertCount(int patientId) async {
    final json = await _api.get(
      '/patients/$patientId/alerts?status=${PatientAlert.open}&size=1',
    ) as Map<String, dynamic>;

    return (json['totalElements'] as num).toInt();
  }

  /// The OPEN alert the backend created for a reading just saved, or null
  /// when the reading was in range. The backend checks a new reading in the
  /// same request that saves it, so the alert already exists.
  Future<PatientAlert?> alertForReading(int patientId, int glucoseLogId) async {
    final json = await _api.get(
      '/patients/$patientId/alerts?status=${PatientAlert.open}&size=20',
    ) as Map<String, dynamic>;

    for (final item in json['items'] as List<dynamic>) {
      final alert = PatientAlert.fromJson(item as Map<String, dynamic>);
      if (alert.glucoseLogId == glucoseLogId) {
        return alert;
      }
    }

    return null;
  }

  /// [status] is ACKNOWLEDGED ("seen") or RESOLVED. Asking for the status the
  /// alert already has returns it unchanged; a RESOLVED / DISMISSED alert is 409.
  Future<PatientAlert> changeStatus(
    int patientId,
    int alertId,
    String status,
  ) async {
    final json = await _api.patch(
      '/patients/$patientId/alerts/$alertId',
      body: {'status': status},
    );

    return PatientAlert.fromJson(json as Map<String, dynamic>);
  }
}

final alertStore = AlertStore();
