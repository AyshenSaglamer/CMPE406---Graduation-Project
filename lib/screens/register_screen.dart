import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../navigation/session_navigation.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/api_enums.dart';
class RegisterScreen extends StatefulWidget {
  final UserRole role;
  const RegisterScreen({
    super.key,
    required this.role,
  });
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  // --------------------------------------------------------
  // CONTROLLERS
  // Backend needs first and last name separately (max 50 characters each).
  // --------------------------------------------------------
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  // --------------------------------------------------------
  // STATE
  // --------------------------------------------------------
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  DateTime? selectedDateOfBirth;
  // Holds the API value: FEMALE / MALE / OTHER (see genderOptions).
  String? selectedGender;
  // Disables the button while the request is running.
  bool isSubmitting = false;
  // Backend validation messages, keyed by field name.
  Map<String, String> fieldErrors = {};
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  // --------------------------------------------------------
  // DATE OF BIRTH
  // --------------------------------------------------------
  Future<void> selectDateOfBirth() async {
    final DateTime today = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(
        today.year - 18,
        today.month,
        today.day,
      ),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Select your date of birth',
      cancelText: 'Cancel',
      confirmText: 'Select',
    );
    if (pickedDate != null) {
      setState(() {
        selectedDateOfBirth = pickedDate;
      });
    }
  }
  // --------------------------------------------------------
  // AGE CALCULATION
  // --------------------------------------------------------
  int calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }
  // --------------------------------------------------------
  // CREATE ACCOUNT
  // --------------------------------------------------------
  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
  Future<void> createAccount() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;
    // ----- client-side checks (same rules as the backend) ----
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        selectedDateOfBirth == null ||
        selectedGender == null) {
      _showMessage('Please fill in all fields.');
      return;
    }
    if (!_emailPattern.hasMatch(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }
    if (calculateAge(selectedDateOfBirth!) < 16) {
      _showMessage('You must be at least 16 years old to create an account.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Password must be at least 8 characters.');
      return;
    }
    // BCrypt limit on the backend: 72 bytes (Turkish letters count as 2).
    if (utf8.encode(password).length > 72) {
      _showMessage('Password is too long.');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }
    // ----- API call ----
    setState(() {
      isSubmitting = true;
      fieldErrors = {};
    });
    try {
      await authService.register(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        dateOfBirth: selectedDateOfBirth!,
        gender: selectedGender!,
        role: widget.role,
      );
      // Register does not return a token, so log in with the same credentials.
      final user = await authService.login(
        email: email,
        password: password,
      );
      if (!mounted) return;
      _showMessage('Account created successfully.');
      goToHome(context, user.role);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => fieldErrors = e.fieldErrors);
      if (e.statusCode == 409) {
        _showMessage('An account with this email already exists.');
      } else if (e.fieldErrors.isNotEmpty) {
        _showMessage(e.fieldErrors.values.first);
      } else {
        _showMessage(e.message);
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }
  // --------------------------------------------------------
  // DISPOSE
  // --------------------------------------------------------
  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
  // --------------------------------------------------------
  // STYLE HELPERS
  // --------------------------------------------------------
  static const TextStyle _labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Color(0xFF273142),
  );
  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    String? errorText,
    Widget? suffixIcon,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    ),
  }) {
    OutlineInputBorder outline(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: contentPadding,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: outline(const Color(0xFFE3EAF1)),
      focusedBorder: outline(const Color(0xFF168AF7), width: 1.5),
      errorBorder: outline(const Color(0xFFE85D75)),
      focusedErrorBorder: outline(const Color(0xFFE85D75), width: 1.5),
    );
  }
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
  // --------------------------------------------------------
  // BUILD
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -----------------------------------------------
              // BACK BUTTON
              // -----------------------------------------------
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
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
              // -----------------------------------------------
              // ICON
              // -----------------------------------------------
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFDDF0FF),
                        Color(0xFFEFF8FF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFF168AF7),
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // -----------------------------------------------
              // TITLE
              // -----------------------------------------------
              const Text(
                'Create your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start managing your health with DiaMate.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 30),
              // -----------------------------------------------
              // FORM CARD
              // -----------------------------------------------
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: const Color(0xFFE8EEF4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // -----------------------------------------
                    // FIRST NAME
                    // -----------------------------------------
                    const Text('First Name', style: _labelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hintText: 'Enter your first name',
                        icon: Icons.person_outline_rounded,
                        errorText: fieldErrors['firstName'],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // -----------------------------------------
                    // LAST NAME
                    // -----------------------------------------
                    const Text('Last Name', style: _labelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hintText: 'Enter your last name',
                        icon: Icons.person_outline_rounded,
                        errorText: fieldErrors['lastName'],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // -----------------------------------------
                    // EMAIL
                    // -----------------------------------------
                    const Text('Email', style: _labelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(
                        hintText: 'you@example.com',
                        icon: Icons.email_outlined,
                        errorText: fieldErrors['email'],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // -----------------------------------------
                    // DATE OF BIRTH
                    // -----------------------------------------
                    const Text('Date of Birth', style: _labelStyle),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: selectDateOfBirth,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: fieldErrors['dateOfBirth'] == null
                                ? const Color(0xFFE3EAF1)
                                : const Color(0xFFE85D75),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_outlined,
                              color: Color(0xFF718096),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                selectedDateOfBirth == null
                                    ? 'Select your date of birth'
                                    : _formatDate(selectedDateOfBirth!),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: selectedDateOfBirth == null
                                      ? const Color(0xFF718096)
                                      : const Color(0xFF273142),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF718096),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (fieldErrors['dateOfBirth'] != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 6),
                        child: Text(
                          fieldErrors['dateOfBirth']!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE85D75),
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    // -----------------------------------------
                    // GENDER
                    // Backend accepts only FEMALE / MALE / OTHER.
                    // -----------------------------------------
                    const Text('Gender', style: _labelStyle),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGender,
                      decoration: _inputDecoration(
                        hintText: 'Select your gender',
                        icon: Icons.wc_outlined,
                        errorText: fieldErrors['gender'],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                      ),
                      items: genderOptions.entries
                          .map(
                            (option) => DropdownMenuItem(
                              value: option.value, // FEMALE / MALE / OTHER
                              child: Text(option.key), // Female / Male / Other
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value;
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    // -----------------------------------------
                    // PASSWORD
                    // -----------------------------------------
                    const Text('Password', style: _labelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: _inputDecoration(
                        hintText: 'At least 8 characters',
                        icon: Icons.lock_outline_rounded,
                        errorText: fieldErrors['password'],
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // -----------------------------------------
                    // CONFIRM PASSWORD
                    // -----------------------------------------
                    const Text('Confirm Password', style: _labelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      decoration: _inputDecoration(
                        hintText: 'Re-enter your password',
                        icon: Icons.lock_reset_rounded,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    // -----------------------------------------
                    // CREATE ACCOUNT BUTTON
                    // -----------------------------------------
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF168AF7),
                          disabledBackgroundColor:
                              const Color(0xFF168AF7).withValues(alpha: 0.6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
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
              // -----------------------------------------------
              // LOGIN
              // -----------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF718096),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // -----------------------------------------------
              // SECURITY INFO
              // -----------------------------------------------
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: Color(0xFF168AF7),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your account information is kept private and secure.',
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
