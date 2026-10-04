import 'package:flutter/material.dart';
import '../models/family_member.dart';

class AddFamilyMemberScreen extends StatefulWidget {
  const AddFamilyMemberScreen({super.key});

  @override
  State<AddFamilyMemberScreen> createState() =>
      _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  final nameController = TextEditingController();

  DateTime? selectedDateOfBirth;
  String? selectedGender;
  String? selectedRelationship;

  final List<String> relationships = [
    'Child',
    'Mother',
    'Father',
    'Spouse',
    'Sibling',
    'Other',
  ];

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // RELATIONSHIP DEĞİŞTİĞİNDE CİNSİYETİ OTOMATİK BELİRLE
  // ------------------------------------------------------------

  void _onRelationshipChanged(String? relationship) {
    if (relationship == null) return;

    setState(() {
      selectedRelationship = relationship;

      if (relationship == 'Mother') {
        selectedGender = 'Female';
      } else if (relationship == 'Father') {
        selectedGender = 'Male';
      } else {
        // Child, Spouse, Sibling ve Other için
        // kullanıcı cinsiyeti seçebilir.
        selectedGender = null;
      }
    });
  }

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(
        now.year - 18,
        now.month,
        now.day,
      ),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select date of birth',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );

    if (pickedDate != null) {
      setState(() {
        selectedDateOfBirth = pickedDate;
      });
    }
  }

  // ------------------------------------------------------------
  // RELATIONSHIP YAZISI
  // ------------------------------------------------------------

  String _getRelationshipText(String relationship) {
    switch (relationship) {
      case 'Child':
        return 'Child';

      case 'Mother':
        return 'Mother';

      case 'Father':
        return 'Father';

      case 'Spouse':
        return 'Spouse';

      case 'Sibling':
        return 'Sibling';

      case 'Other':
        return 'Other';

      default:
        return relationship;
    }
  }

  // ------------------------------------------------------------
  // BUTTON YAZISI
  // ------------------------------------------------------------

  String _getButtonText() {
    if (selectedRelationship == null) {
      return 'Add Family Member';
    }

    switch (selectedRelationship) {
      case 'Child':
        return 'Add Child';

      case 'Mother':
        return 'Add Mother';

      case 'Father':
        return 'Add Father';

      case 'Spouse':
        return 'Add Spouse';

      case 'Sibling':
        return 'Add Sibling';

      case 'Other':
        return 'Add Family Member';

      default:
        return 'Add Family Member';
    }
  }

  // ------------------------------------------------------------
  // CİNSİYET GÖSTERİMİ
  // ------------------------------------------------------------

  Widget _buildGenderField() {
    final isAutomaticallySelected =
        selectedRelationship == 'Mother' ||
        selectedRelationship == 'Father';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF344054),
          ),
        ),
        const SizedBox(height: 8),

        if (isAutomaticallySelected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selectedGender == 'Female'
                      ? Icons.female_rounded
                      : Icons.male_rounded,
                  color: const Color(0xFF765BD4),
                ),
                const SizedBox(width: 10),
                Text(
                  selectedGender ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF344054),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 17,
                  color: Color(0xFF98A2B3),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: selectedGender,
            decoration: InputDecoration(
              hintText: 'Select gender',
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF765BD4),
                  width: 1.5,
                ),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Female',
                child: Text('Female'),
              ),
              DropdownMenuItem(
                value: 'Male',
                child: Text('Male'),
              ),
              DropdownMenuItem(
                value: 'Other',
                child: Text('Other'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                selectedGender = value;
              });
            },
          ),
      ],
    );
  }

  // ------------------------------------------------------------
  // ADD FAMILY MEMBER
  // ------------------------------------------------------------

  void _addFamilyMember() {
    if (nameController.text.trim().isEmpty) {
      _showError('Please enter the full name.');
      return;
    }

    if (selectedDateOfBirth == null) {
      _showError('Please select the date of birth.');
      return;
    }

    if (selectedRelationship == null) {
      _showError('Please select the relationship.');
      return;
    }

    if (selectedGender == null) {
      _showError('Please select the gender.');
      return;
    }

    // ----------------------------------------------------------
    // BACKEND'E GÖNDERİLECEK DEĞİŞKENLER
    // ----------------------------------------------------------

    final managedPersonName = nameController.text.trim();
    final managedPersonDateOfBirth =
        selectedDateOfBirth!.toIso8601String();
    final managedPersonGender =
        selectedGender!.toLowerCase();
    final relationship =
        selectedRelationship!.toLowerCase();

    // Backendci arkadaşının kullanacağı veri.
    final requestBody = {
      'name': managedPersonName,
      'date_of_birth': managedPersonDateOfBirth,
      'gender': managedPersonGender,
      'relationship': relationship,
    };

    debugPrint('Managed Person: $requestBody');

    // ----------------------------------------------------------
    // ŞİMDİLİK FRONTEND
    // Backend geldiğinde API BURADA çağrılacak.
    // ----------------------------------------------------------

    final familyMember = FamilyMember(
      name: managedPersonName,
      dateOfBirth: selectedDateOfBirth!,
      gender: selectedGender!,
      relationship: selectedRelationship!,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$managedPersonName added successfully.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(
      context,
      familyMember,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dateText = selectedDateOfBirth == null
        ? 'Select date of birth'
        : '${selectedDateOfBirth!.day.toString().padLeft(2, '0')}/'
            '${selectedDateOfBirth!.month.toString().padLeft(2, '0')}/'
            '${selectedDateOfBirth!.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Add Family Member',
          style: TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF344054),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // HEADER
              // ------------------------------------------------

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFECE6FF),
                      Color(0xFFF7F3FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.family_restroom_rounded,
                        color: Color(0xFF765BD4),
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Who are you caring for?',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D2939),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Add the person whose health you want to manage.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // ------------------------------------------------
              // FULL NAME
              // ------------------------------------------------

              const Text(
                'Full Name',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF344054),
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Enter full name',
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF765BD4),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // DATE OF BIRTH
              // ------------------------------------------------

              const Text(
                'Date of Birth',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF344054),
                ),
              ),

              const SizedBox(height: 8),

              InkWell(
                onTap: _selectDateOfBirth,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFF667085),
                        size: 21,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 15,
                          color: selectedDateOfBirth == null
                              ? const Color(0xFF98A2B3)
                              : const Color(0xFF344054),
                          fontWeight:
                              selectedDateOfBirth == null
                                  ? FontWeight.w400
                                  : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // RELATIONSHIP
              // ------------------------------------------------

              const Text(
                'Relationship',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF344054),
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                initialValue: selectedRelationship,
                decoration: InputDecoration(
                  hintText: 'Who are you caring for?',
                  prefixIcon: const Icon(
                    Icons.family_restroom_outlined,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF765BD4),
                      width: 1.5,
                    ),
                  ),
                ),
                items: relationships.map((relationship) {
                  return DropdownMenuItem<String>(
                    value: relationship,
                    child: Text(
                      _getRelationshipText(relationship),
                    ),
                  );
                }).toList(),
                onChanged: _onRelationshipChanged,
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // GENDER
              // ------------------------------------------------

              _buildGenderField(),

              const SizedBox(height: 18),

              // ------------------------------------------------
              // INFO
              // ------------------------------------------------

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Color(0xFF667085),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This person does not need to create a separate account. '
                        'You will manage their health information from your caregiver account.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ------------------------------------------------
              // ADD BUTTON
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _addFamilyMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF765BD4),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: Text(
                    _getButtonText(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}