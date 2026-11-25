import '../services/api_client.dart';

/// A family member without an account (e.g. a child) whose diary the
/// logged-in caregiver keeps (DependentResponse). Nobody logs in as them.
class Dependent {
  /// The id for their logs: /patients/{patientId}/glucose-logs ...
  final int patientId;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;

  /// FEMALE, MALE or OTHER.
  final String gender;

  /// TYPE_1, TYPE_2, GESTATIONAL or OTHER.
  final String diabetesType;

  /// The care relationship through which the caregiver manages them.
  final int relationshipId;

  const Dependent({
    required this.patientId,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.diabetesType,
    required this.relationshipId,
  });

  String get name => '$firstName $lastName'.trim();

  factory Dependent.fromJson(Map<String, dynamic> json) {
    return Dependent(
      patientId: (json['patientId'] as num).toInt(),
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      dateOfBirth: DateTime.parse(json['dateOfBirth'] as String),
      gender: json['gender'] as String? ?? 'OTHER',
      diabetesType: json['diabetesType'] as String? ?? 'OTHER',
      relationshipId: (json['relationshipId'] as num).toInt(),
    );
  }
}

/// What the caregiver fills in on the Add / Edit Family Member screen
/// (DependentRequest). PUT replaces every field, so it is always sent whole.
class DependentDetails {
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;

  /// FEMALE, MALE or OTHER.
  final String gender;

  /// TYPE_1, TYPE_2, GESTATIONAL or OTHER; null leaves it to the backend
  /// (OTHER).
  final String? diabetesType;

  const DependentDetails({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    this.diabetesType,
  });

  Map<String, dynamic> toJson() => {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        // A calendar date (LocalDate), not a moment: no time, no zone.
        'dateOfBirth': '${dateOfBirth.year.toString().padLeft(4, '0')}-'
            '${dateOfBirth.month.toString().padLeft(2, '0')}-'
            '${dateOfBirth.day.toString().padLeft(2, '0')}',
        'gender': gender,
        if (diabetesType != null) 'diabetesType': diabetesType,
      };
}

/// Family members without an account (Melih's V12 + CareTeamController):
///   POST /care-team/dependents              caregiver adds one (201)
///   PUT  /care-team/dependents/{patientId}  the managing caregiver corrects
/// They then appear in GET /care-team/patients with managed = true.
class DependentStore {
  DependentStore({ApiClient? api}) : _api = api ?? apiClient;

  final ApiClient _api;

  Future<Dependent> add(DependentDetails details) async {
    final json =
        await _api.post('/care-team/dependents', body: details.toJson());
    return Dependent.fromJson(json as Map<String, dynamic>);
  }

  Future<Dependent> update(int patientId, DependentDetails details) async {
    final json = await _api.put(
      '/care-team/dependents/$patientId',
      body: details.toJson(),
    );
    return Dependent.fromJson(json as Map<String, dynamic>);
  }
}

final dependentStore = DependentStore();
