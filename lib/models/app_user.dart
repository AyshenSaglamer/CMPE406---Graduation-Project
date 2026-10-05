import 'user_role.dart';
/// Mirrors the backend UserResponse:
///   { "id": 1, "firstName": "...", "lastName": "...", "email": "...", "role": "PATIENT" }
class AppUser {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final UserRole role;
  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
  });
  String get fullName => '$firstName $lastName';
  factory AppUser.fromJson(Map<String, dynamic> json) {
    final role = UserRoleApi.fromApi(json['role'] as String);
    if (role == null) {
      throw FormatException('Unsupported role: ${json['role']}');
    }
    return AppUser(
      id: (json['id'] as num).toInt(),
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      role: role,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': role.apiValue,
    };
  }
}
