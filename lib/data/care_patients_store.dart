import '../services/api_client.dart';
import '../services/api_exception.dart';

/// The latest glucose of a followed patient against their own target range.
enum GlucoseStatus { low, inRange, high, noData }

/// A patient the logged-in doctor or caregiver follows:
///   GET /care-team/patients            who, and what they share
///   GET /patients/{id}/overview        age, diabetes type, last glucose...
/// The overview needs the "glucose" permission and a patient profile; when
/// it cannot be read the patient is still listed, with the name only.
class CarePatient {
  final int id;
  final String firstName;
  final String lastName;

  final bool canViewGlucose;
  final bool canViewMeals;
  final bool canViewActivity;
  final bool canViewMedications;
  final bool canViewReports;
  final bool canReceiveAlerts;

  final int? ageYears;

  /// TYPE_1, TYPE_2, GESTATIONAL or OTHER.
  final String? diabetesType;
  final int targetMin;
  final int targetMax;
  final int? lastGlucose;
  final DateTime? lastGlucoseAt;

  /// null without the alerts permission.
  final int? openAlerts;

  const CarePatient({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.canViewGlucose = false,
    this.canViewMeals = false,
    this.canViewActivity = false,
    this.canViewMedications = false,
    this.canViewReports = false,
    this.canReceiveAlerts = false,
    this.ageYears,
    this.diabetesType,
    this.targetMin = 70,
    this.targetMax = 180,
    this.lastGlucose,
    this.lastGlucoseAt,
    this.openAlerts,
  });

  String get name {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? 'Patient #$id' : full;
  }

  String get diabetesLabel => switch (diabetesType) {
        'TYPE_1' => 'Type 1 Diabetes',
        'TYPE_2' => 'Type 2 Diabetes',
        'GESTATIONAL' => 'Gestational Diabetes',
        'OTHER' => 'Diabetes',
        _ => 'Diabetes type not set',
      };

  /// "12 years • Type 1 Diabetes" or just the type.
  String get subtitle =>
      ageYears == null ? diabetesLabel : '$ageYears years • $diabetesLabel';

  GlucoseStatus get status {
    final g = lastGlucose;
    if (g == null) {
      return GlucoseStatus.noData;
    }
    if (g < targetMin) {
      return GlucoseStatus.low;
    }
    if (g > targetMax) {
      return GlucoseStatus.high;
    }
    return GlucoseStatus.inRange;
  }

  String get statusLabel => switch (status) {
        GlucoseStatus.low => 'Low',
        GlucoseStatus.high => 'High',
        GlucoseStatus.inRange => 'In Range',
        GlucoseStatus.noData => 'No data',
      };

  factory CarePatient.fromJson(
    Map<String, dynamic> member, [
    Map<String, dynamic>? overview,
  ]) {
    final o = overview ?? const <String, dynamic>{};
    final lastAt = o['lastGlucoseAt'];

    return CarePatient(
      id: (member['patientId'] as num).toInt(),
      firstName: member['firstName'] as String? ?? '',
      lastName: member['lastName'] as String? ?? '',
      canViewGlucose: member['canViewGlucose'] as bool? ?? false,
      canViewMeals: member['canViewMeals'] as bool? ?? false,
      canViewActivity: member['canViewActivity'] as bool? ?? false,
      canViewMedications: member['canViewMedications'] as bool? ?? false,
      canViewReports: member['canViewReports'] as bool? ?? false,
      canReceiveAlerts: member['canReceiveAlerts'] as bool? ?? false,
      ageYears: (o['ageYears'] as num?)?.toInt(),
      diabetesType: o['diabetesType'] as String?,
      targetMin: (o['targetMinMgdl'] as num?)?.toInt() ?? 70,
      targetMax: (o['targetMaxMgdl'] as num?)?.toInt() ?? 180,
      lastGlucose: (o['lastGlucoseMgdl'] as num?)?.toInt(),
      lastGlucoseAt:
          lastAt is String ? DateTime.tryParse(lastAt)?.toLocal() : null,
      openAlerts: (o['openAlerts'] as num?)?.toInt(),
    );
  }
}

class CarePatientsStore {
  CarePatientsStore({ApiClient? api}) : _api = api ?? apiClient;

  final ApiClient _api;

  /// The followed patients with their overview, in the backend's order.
  Future<List<CarePatient>> load() async {
    final members = await _api.get('/care-team/patients') as List<dynamic>;

    return Future.wait([
      for (final item in members) _withOverview(item as Map<String, dynamic>),
    ]);
  }

  Future<CarePatient> _withOverview(Map<String, dynamic> member) async {
    final id = (member['patientId'] as num).toInt();

    if (member['canViewGlucose'] != true) {
      return CarePatient.fromJson(member);
    }

    try {
      final overview = await _api.get('/patients/$id/overview');
      return CarePatient.fromJson(member, overview as Map<String, dynamic>);
    } on ApiException catch (e) {
      // No patient profile yet (404) or access just ended (403): list the
      // patient anyway; a lost session (401) is still an error.
      if (e.statusCode == 401 || e.statusCode == 0) {
        rethrow;
      }
      return CarePatient.fromJson(member);
    }
  }
}

final carePatientsStore = CarePatientsStore();
