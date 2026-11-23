enum UserRole {
  patient,
  caregiver,
  doctor,
}

extension UserRoleApi on UserRole {
  String get apiValue {
    switch (this) {
      case UserRole.patient:
        return 'PATIENT';

      case UserRole.caregiver:
        return 'CAREGIVER';

      case UserRole.doctor:
        return 'CLINICIAN';
    }
  }

  static UserRole? fromApi(String value) {
    switch (value) {
      case 'PATIENT':
        return UserRole.patient;

      case 'CAREGIVER':
        return UserRole.caregiver;

      case 'CLINICIAN':
        return UserRole.doctor;

      default:
        return null;
    }
  }
}