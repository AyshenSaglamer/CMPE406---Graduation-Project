import '../services/api_client.dart';

/// One care relationship as both sides see it (CareRelationshipResponse).
/// status: PENDING (invited), ACTIVE (data is shared), DECLINED or REVOKED.
/// An ACTIVE relationship past [expiresAt] keeps its status, so the app
/// shows [hasAccess], not the status alone.
class CareRelationship {
  static const String pending = 'PENDING';
  static const String active = 'ACTIVE';
  static const String declined = 'DECLINED';
  static const String revoked = 'REVOKED';

  final int id;
  final int patientId;
  final String patientName;
  final int memberId;
  final String memberName;
  final String memberEmail;

  /// CLINICIAN or CAREGIVER.
  final String memberRole;
  final String status;
  final bool hasAccess;
  final DateTime? invitedAt;
  final DateTime? expiresAt;

  final bool canViewGlucose;
  final bool canViewMeals;
  final bool canViewMedications;
  final bool canViewActivity;
  final bool canViewReports;
  final bool canReceiveAlerts;

  const CareRelationship({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.memberId,
    required this.memberName,
    required this.memberEmail,
    required this.memberRole,
    required this.status,
    required this.hasAccess,
    this.invitedAt,
    this.expiresAt,
    this.canViewGlucose = true,
    this.canViewMeals = true,
    this.canViewMedications = true,
    this.canViewActivity = true,
    this.canViewReports = true,
    this.canReceiveAlerts = true,
  });

  bool get isPending => status == pending;

  /// Still open: waiting for an answer or sharing (maybe expired).
  bool get isOpen => status == pending || status == active;

  bool get isClinician => memberRole == 'CLINICIAN';

  String get roleLabel => isClinician ? 'Doctor' : 'Caregiver';

  /// "Active", "Expired", "Waiting for answer", "Declined", "Ended".
  String get statusLabel {
    switch (status) {
      case pending:
        return 'Waiting for answer';
      case active:
        return hasAccess ? 'Active' : 'Expired';
      case declined:
        return 'Declined';
      default:
        return 'Ended';
    }
  }

  factory CareRelationship.fromJson(Map<String, dynamic> json) {
    String name(String first, String last) =>
        '${json[first] ?? ''} ${json[last] ?? ''}'.trim();

    return CareRelationship(
      id: (json['id'] as num).toInt(),
      patientId: (json['patientId'] as num).toInt(),
      patientName: name('patientFirstName', 'patientLastName'),
      memberId: (json['memberId'] as num).toInt(),
      memberName: name('memberFirstName', 'memberLastName'),
      memberEmail: json['memberEmail'] as String? ?? '',
      memberRole: json['memberRole'] as String? ?? '',
      status: json['status'] as String? ?? '',
      hasAccess: json['hasAccess'] as bool? ?? false,
      invitedAt: _time(json['invitedAt']),
      expiresAt: _time(json['expiresAt']),
      canViewGlucose: json['canViewGlucose'] as bool? ?? false,
      canViewMeals: json['canViewMeals'] as bool? ?? false,
      canViewMedications: json['canViewMedications'] as bool? ?? false,
      canViewActivity: json['canViewActivity'] as bool? ?? false,
      canViewReports: json['canViewReports'] as bool? ?? false,
      canReceiveAlerts: json['canReceiveAlerts'] as bool? ?? false,
    );
  }

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

/// Care relationships (Melih's /api/v1/care-relationships):
///   POST   /care-relationships              patient invites by email
///   GET    /care-relationships[?status=]    the caller's relationships
///   POST   /care-relationships/{id}/accept  clinician / caregiver
///   POST   /care-relationships/{id}/decline clinician / caregiver
///   DELETE /care-relationships/{id}         either side ends it
class CareStore {
  CareStore({ApiClient? api}) : _api = api ?? apiClient;

  final ApiClient _api;

  /// Newest first.
  Future<List<CareRelationship>> list({String? status}) async {
    final json = await _api.get(
      status == null ? '/care-relationships' : '/care-relationships?status=$status',
    ) as List<dynamic>;

    return [
      for (final item in json)
        CareRelationship.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Invitations waiting for the logged-in clinician or caregiver.
  Future<List<CareRelationship>> pendingInvitations() =>
      list(status: CareRelationship.pending);

  /// The patient invites the clinician or caregiver who owns [email].
  /// Everything is shared by default (backend defaults); [expiresAt] limits
  /// the sharing in time.
  Future<CareRelationship> invite(String email, {DateTime? expiresAt}) async {
    final json = await _api.post('/care-relationships', body: {
      'memberEmail': email.trim(),
      if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
    });

    return CareRelationship.fromJson(json as Map<String, dynamic>);
  }

  Future<CareRelationship> accept(int id) async {
    final json = await _api.post('/care-relationships/$id/accept');
    return CareRelationship.fromJson(json as Map<String, dynamic>);
  }

  Future<CareRelationship> decline(int id) async {
    final json = await _api.post('/care-relationships/$id/decline');
    return CareRelationship.fromJson(json as Map<String, dynamic>);
  }

  /// Ends the relationship (REVOKED); either side may do this.
  Future<void> revoke(int id) => _api.delete('/care-relationships/$id');
}

final careStore = CareStore();
