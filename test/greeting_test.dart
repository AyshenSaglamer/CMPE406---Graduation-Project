import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/models/app_user.dart';
import 'package:gradia/models/user_role.dart';
import 'package:gradia/utils/greeting.dart';

AppUser user(String first, String last, UserRole role) => AppUser(
      id: 1,
      firstName: first,
      lastName: last,
      email: 'u@example.com',
      role: role,
    );

void main() {
  test('patients and caregivers are greeted by first name', () {
    expect(greetingFor(user('Ayşe', 'Kaya', UserRole.patient)),
        'Hello, Ayşe \u{1F44B}');
    expect(greetingFor(user('Can', 'Ak', UserRole.caregiver)),
        'Hello, Can \u{1F44B}');
  });

  test('a doctor is greeted by surname', () {
    expect(greetingFor(user('Elif', 'Demir', UserRole.doctor), doctor: true),
        'Hello, Dr. Demir \u{1F44B}');
  });

  test('without a name the old greeting stays', () {
    expect(greetingFor(null), 'Hello \u{1F44B}');
    expect(greetingFor(user(' ', '', UserRole.patient)), 'Hello \u{1F44B}');
    expect(greetingFor(null, doctor: true), 'Hello, Doctor \u{1F44B}');
  });
}
