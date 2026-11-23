import 'package:flutter/material.dart';

import 'caregiver_dashboard_screen.dart';

class CaregiverSetupScreen extends StatefulWidget {
  const CaregiverSetupScreen({
    super.key,
  });

  @override
  State<CaregiverSetupScreen> createState() => _CaregiverSetupScreenState();
}

class _CaregiverSetupScreenState extends State<CaregiverSetupScreen> {
  final nameController = TextEditingController();

  DateTime? selectedDateOfBirth;
  String? selectedGender;
  String? selectedRelationship;

  Future<void> selectDateOfBirth() async {
    final today = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(
        today.year - 50,
        today.month,
        today.day,
      ),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Select date of birth',
    );

    if (pickedDate != null) {
      setState(() {
        selectedDateOfBirth = pickedDate;
      });
    }
  }

  void addPerson() {
    final name = nameController.text.trim();

    if (name.isEmpty ||
        selectedDateOfBirth == null ||
        selectedGender == null ||
        selectedRelationship == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all fields.',
          ),
        ),
      );

      return;
    }

    final dateOfBirth =
        selectedDateOfBirth!.toIso8601String();

    final gender = selectedGender;
    final relationship = selectedRelationship;

    /*
      Backend'e daha sonra gönderilecek bilgiler:

      {
        "name": name,
        "date_of_birth": dateOfBirth,
        "gender": gender,
        "relationship": relationship
      }

      Şimdilik API çağrısı YOK.
      Backendci arkadaş endpoint'i hazırlayınca
      bu bilgiler API'ye gönderilecek.
    */

    debugPrint('Managed Person Name: $name');
    debugPrint('Managed Person DOB: $dateOfBirth');
    debugPrint('Managed Person Gender: $gender');
    debugPrint('Relationship: $relationship');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Person added successfully.',
        ),
      ),
    );

    Future.delayed(
      const Duration(milliseconds: 700),
      () {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const CaregiverDashboardScreen(),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            22,
            16,
            22,
            30,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              // BACK BUTTON

              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFE4EBF2),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 21,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ICON

              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFDDF0FF),
                        Color(0xFFEFF8FF),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.family_restroom_rounded,
                    color: Color(0xFF168AF7),
                    size: 38,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // TITLE

              const Text(
                'Who are you caring for?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Add the person you want to manage and support.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF718096),
                ),
              ),

              const SizedBox(height: 30),

              // FORM CARD

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFFE8EEF4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(
                        alpha: 0.03,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    // FULL NAME

                    const Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273142),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: nameController,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText:
                            'Enter their full name',
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFFF8FAFC),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color:
                                Color(0xFFE3EAF1),
                          ),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color:
                                Color(0xFF168AF7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // DATE OF BIRTH

                    const Text(
                      'Date of Birth',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273142),
                      ),
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: selectDateOfBirth,
                      borderRadius:
                          BorderRadius.circular(16),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF8FAFC),
                          borderRadius:
                              BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                const Color(0xFFE3EAF1),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons
                                  .calendar_month_outlined,
                              color:
                                  Color(0xFF718096),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                selectedDateOfBirth ==
                                        null
                                    ? 'Select date of birth'
                                    : '${selectedDateOfBirth!.day.toString().padLeft(2, '0')}/'
                                        '${selectedDateOfBirth!.month.toString().padLeft(2, '0')}/'
                                        '${selectedDateOfBirth!.year}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color:
                                      selectedDateOfBirth ==
                                              null
                                          ? const Color(
                                              0xFF718096,
                                            )
                                          : const Color(
                                              0xFF273142,
                                            ),
                                ),
                              ),
                            ),

                            const Icon(
                              Icons
                                  .keyboard_arrow_down_rounded,
                              color:
                                  Color(0xFF718096),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // GENDER

                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273142),
                      ),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      decoration: InputDecoration(
                        hintText: 'Select gender',
                        prefixIcon: const Icon(
                          Icons.wc_outlined,
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFFF8FAFC),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color:
                                Color(0xFFE3EAF1),
                          ),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color:
                                Color(0xFF168AF7),
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Male',
                          child: Text('Male'),
                        ),
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                        DropdownMenuItem(
                          value: 'Prefer not to say',
                          child: Text(
                            'Prefer not to say',
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    // RELATIONSHIP

                    const Text(
                      'Relationship',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273142),
                      ),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue:
                          selectedRelationship,
                      decoration: InputDecoration(
                        hintText:
                            'Select relationship',
                        prefixIcon: const Icon(
                          Icons.people_outline_rounded,
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFFF8FAFC),
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color:
                                Color(0xFFE3EAF1),
                          ),
                        ),
                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color:
                                Color(0xFF168AF7),
                            width: 1.5,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Mother',
                          child: Text('Mother'),
                        ),
                        DropdownMenuItem(
                          value: 'Father',
                          child: Text('Father'),
                        ),
                        DropdownMenuItem(
                          value: 'Child',
                          child: Text('Child'),
                        ),
                        DropdownMenuItem(
                          value: 'Spouse',
                          child: Text('Spouse'),
                        ),
                        DropdownMenuItem(
                          value: 'Sibling',
                          child: Text('Sibling'),
                        ),
                        DropdownMenuItem(
                          value: 'Other',
                          child: Text('Other'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedRelationship = value;
                        });
                      },
                    ),

                    const SizedBox(height: 26),

                    // BUTTON

                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: addPerson,
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF168AF7),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(17),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons
                                  .arrow_forward_rounded,
                              size: 19,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // INFO

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FF),
                  borderRadius:
                      BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFF168AF7),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This person does not need to create a separate account.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: Color(0xFF5F7489),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}