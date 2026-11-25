import 'package:flutter/material.dart';

import '../data/care_patients_store.dart';
import '../data/dependent_store.dart';
import '../services/api_exception.dart';

/// A caregiver adds a family member without an account (e.g. a child) and
/// keeps their diary: POST /care-team/dependents. With [existing] (a family
/// member this caregiver manages) the same form corrects the details:
/// PUT /care-team/dependents/{patientId}.
///
/// Pops with the saved [Dependent], or null when the caregiver goes back.
class AddFamilyMemberScreen extends StatefulWidget {
  const AddFamilyMemberScreen({
    super.key,
    this.existing,
    this.store,
    this.today,
  });

  /// The managed family member to edit; null adds a new one.
  final CarePatient? existing;

  /// Defaults to [dependentStore]; tests pass one with a fake backend.
  final DependentStore? store;

  /// Defaults to the phone's date; tests fix it.
  final DateTime Function()? today;

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  static const _purple = Color(0xFF765BD4);
  static const _border = Color(0xFFE2E8F0);
  static const _label = Color(0xFF344054);
  static const _muted = Color(0xFF667085);

  /// The backend's limit (AuthService.MAX_AGE_YEARS).
  static const _maxAgeYears = 120;

  static const _genders = {
    'FEMALE': 'Female',
    'MALE': 'Male',
    'OTHER': 'Other',
  };

  static const _diabetesTypes = {
    'TYPE_1': 'Type 1',
    'TYPE_2': 'Type 2',
    'GESTATIONAL': 'Gestational',
    'OTHER': 'Other / not sure',
  };

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  DateTime? selectedDateOfBirth;
  String? selectedGender;
  String? selectedDiabetesType;

  bool saving = false;

  /// Errors the backend sent per field (firstName, dateOfBirth, ...).
  Map<String, String> fieldErrors = const {};

  bool get isEditing => widget.existing != null;

  DependentStore get _store => widget.store ?? dependentStore;

  DateTime get _today {
    final now = (widget.today ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    if (existing != null) {
      firstNameController.text = existing.firstName;
      lastNameController.text = existing.lastName;
      selectedGender =
          _genders.containsKey(existing.gender) ? existing.gender : null;
      selectedDiabetesType = _diabetesTypes.containsKey(existing.diabetesType)
          ? existing.diabetesType
          : null;
      // The backend does not send the date of birth back (only the age), and
      // the update replaces every field: the caregiver picks it again.
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------

  Future<void> _selectDateOfBirth() async {
    final today = _today;
    // The date of birth must be in the past (not today).
    final lastDate = today.subtract(const Duration(days: 1));
    final firstDate =
        DateTime(today.year - _maxAgeYears, today.month, today.day);

    final age = widget.existing?.ageYears;
    final initialDate = selectedDateOfBirth ??
        DateTime(today.year - (age ?? 8), today.month, today.day);

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select date of birth',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );

    if (pickedDate != null) {
      setState(() {
        selectedDateOfBirth = pickedDate;
        fieldErrors = Map.of(fieldErrors)..remove('dateOfBirth');
      });
    }
  }

  // ------------------------------------------------------------
  // SAVE
  // ------------------------------------------------------------

  Future<void> _save() async {
    if (saving) {
      return;
    }

    if (firstNameController.text.trim().isEmpty) {
      _showMessage('Please enter the first name.');
      return;
    }

    if (lastNameController.text.trim().isEmpty) {
      _showMessage('Please enter the last name.');
      return;
    }

    if (selectedDateOfBirth == null) {
      _showMessage('Please select the date of birth.');
      return;
    }

    if (selectedGender == null) {
      _showMessage('Please select the gender.');
      return;
    }

    final details = DependentDetails(
      firstName: firstNameController.text,
      lastName: lastNameController.text,
      dateOfBirth: selectedDateOfBirth!,
      gender: selectedGender!,
      diabetesType: selectedDiabetesType,
    );

    setState(() {
      saving = true;
      fieldErrors = const {};
    });

    try {
      final existing = widget.existing;
      final saved = existing == null
          ? await _store.add(details)
          : await _store.update(existing.id, details);

      if (!mounted) {
        return;
      }

      _showMessage(
        existing == null
            ? '${saved.name} was added to your family.'
            : '${saved.name} was updated.',
      );
      Navigator.pop(context, saved);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        saving = false;
        fieldErrors = e.fieldErrors;
      });
      _showMessage(
        e.isNetworkError
            ? 'No connection. Family members can only be saved online.'
            : e.message,
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ------------------------------------------------------------
  // FIELD HELPERS
  // ------------------------------------------------------------

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    String? errorText,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      errorText: errorText,
      filled: true,
      fillColor: Colors.white,
      border: border(_border),
      enabledBorder: border(_border),
      focusedBorder: border(_purple, 1.5),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _label,
        ),
      ),
    );
  }

  Widget _nameField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required String errorKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        TextField(
          controller: controller,
          enabled: !saving,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          maxLength: 50,
          decoration: _decoration(
            hint: hint,
            icon: Icons.person_outline_rounded,
            errorText: fieldErrors[errorKey],
          ).copyWith(counterText: ''),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dob = selectedDateOfBirth;
    final dateText = dob == null
        ? 'Select date of birth'
        : '${dob.day.toString().padLeft(2, '0')}/'
            '${dob.month.toString().padLeft(2, '0')}/'
            '${dob.year}';
    final dobError = fieldErrors['dateOfBirth'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isEditing ? 'Edit Family Member' : 'Add Family Member',
          style: const TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: _label,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
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
                        color: _purple,
                        size: 29,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing
                                ? 'Correct their details'
                                : 'Who are you caring for?',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1D2939),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            isEditing
                                ? 'Their diary and readings stay as they are.'
                                : 'Add the person whose health you want to manage.',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: _muted,
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
              // NAME
              // ------------------------------------------------

              _nameField(
                label: 'First Name',
                hint: 'Enter first name',
                controller: firstNameController,
                errorKey: 'firstName',
              ),

              const SizedBox(height: 20),

              _nameField(
                label: 'Last Name',
                hint: 'Enter last name',
                controller: lastNameController,
                errorKey: 'lastName',
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // DATE OF BIRTH
              // ------------------------------------------------

              _fieldLabel('Date of Birth'),

              InkWell(
                key: const Key('dateOfBirthField'),
                onTap: saving ? null : _selectDateOfBirth,
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
                      color: dobError != null
                          ? Theme.of(context).colorScheme.error
                          : _border,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: _muted,
                        size: 21,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 15,
                          color: dob == null
                              ? const Color(0xFF98A2B3)
                              : _label,
                          fontWeight:
                              dob == null ? FontWeight.w400 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (dobError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text(
                    dobError,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                )
              else if (isEditing && dob == null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Text(
                    'Please select it again to save the changes.',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // GENDER
              // ------------------------------------------------

              _fieldLabel('Gender'),

              DropdownButtonFormField<String>(
                key: const Key('genderField'),
                initialValue: selectedGender,
                decoration: _decoration(
                  hint: 'Select gender',
                  icon: Icons.wc_rounded,
                  errorText: fieldErrors['gender'],
                ),
                items: [
                  for (final entry in _genders.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => selectedGender = value),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // DIABETES TYPE
              // ------------------------------------------------

              _fieldLabel('Diabetes Type (optional)'),

              DropdownButtonFormField<String>(
                key: const Key('diabetesTypeField'),
                initialValue: selectedDiabetesType,
                decoration: _decoration(
                  hint: 'Select diabetes type',
                  icon: Icons.water_drop_outlined,
                  errorText: fieldErrors['diabetesType'],
                ),
                items: [
                  for (final entry in _diabetesTypes.entries)
                    DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: saving
                    ? null
                    : (value) => setState(() => selectedDiabetesType = value),
              ),

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
                      color: _muted,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This person does not need an account and cannot log in. '
                        'You will manage their health information from your caregiver account.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // ------------------------------------------------
              // SAVE BUTTON
              // ------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _purple.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Save Changes' : 'Add Family Member',
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
