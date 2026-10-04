class FamilyMember {
  final String name;
  final DateTime dateOfBirth;
  final String gender;
  final String relationship;

  const FamilyMember({
    required this.name,
    required this.dateOfBirth,
    required this.gender,
    required this.relationship,
  });

  // Backend'e gönderilecek veri
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'relationship': relationship,
    };
  }
}