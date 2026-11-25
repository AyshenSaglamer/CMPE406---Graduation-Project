import '../models/app_user.dart';

/// "Hello, Ayşe 👋" with the logged-in user's first name; a doctor is
/// greeted by surname ("Hello, Dr. Kaya 👋"). Without a name (e.g. an old
/// session) it stays "Hello 👋" / "Hello, Doctor 👋".
String greetingFor(AppUser? user, {bool doctor = false}) {
  const wave = '\u{1F44B}';

  if (doctor) {
    final lastName = user?.lastName.trim() ?? '';
    return lastName.isEmpty ? 'Hello, Doctor $wave' : 'Hello, Dr. $lastName $wave';
  }

  final firstName = user?.firstName.trim() ?? '';
  return firstName.isEmpty ? 'Hello $wave' : 'Hello, $firstName $wave';
}
