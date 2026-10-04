import 'package:flutter/material.dart';

import '../models/user_role.dart';
import 'caregiver_dashboard_screen.dart';
import 'dashboard_screen.dart';
import 'doctor_dashboard_screen.dart';

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
  // ---------------------------------------------------------
  // CONTROLLERS
  // ---------------------------------------------------------

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  // ---------------------------------------------------------
  // PASSWORD VISIBILITY
  // ---------------------------------------------------------

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  // ---------------------------------------------------------
  // DATE OF BIRTH
  // ---------------------------------------------------------

  DateTime? selectedDateOfBirth;

  // ---------------------------------------------------------
  // GENDER
  // ---------------------------------------------------------

  String? selectedGender;

  // ---------------------------------------------------------
  // DATE OF BIRTH
  // ---------------------------------------------------------

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

  // ---------------------------------------------------------
  // AGE CALCULATION
  // ---------------------------------------------------------

  int calculateAge(DateTime birthDate) {
    final today = DateTime.now();

    int age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month &&
            today.day < birthDate.day)) {
      age--;
    }

    return age;
  }

  // ---------------------------------------------------------
  // CREATE ACCOUNT
  // ---------------------------------------------------------

  void createAccount() {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    // ---------------------------------------------------------
    // EMPTY FIELD CHECK
    // ---------------------------------------------------------

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        selectedDateOfBirth == null ||
        selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all fields.',
          ),
        ),
      );

      return;
    }

    // ---------------------------------------------------------
    // AGE CHECK
    // ---------------------------------------------------------

    final age = calculateAge(
      selectedDateOfBirth!,
    );

    if (age < 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must be at least 16 years old to create an account.',
          ),
        ),
      );

      return;
    }

    // ---------------------------------------------------------
    // PASSWORD CHECK
    // ---------------------------------------------------------

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Passwords do not match.',
          ),
        ),
      );

      return;
    }

    // ---------------------------------------------------------
    // DATA READY FOR BACKEND
    // ---------------------------------------------------------

    final dateOfBirth =
        selectedDateOfBirth!.toIso8601String();

    final gender = selectedGender;

    final role = widget.role.name;

    /*
      Backend'e gönderilecek bilgiler:

      {
        "name": name,
        "email": email,
        "password": password,
        "date_of_birth": dateOfBirth,
        "gender": gender,
        "role": role
      }

      Şimdilik API çağrısı YOK.

      Backendci endpoint'i hazırlayınca
      bu bölüm API çağrısına bağlanabilir.
    */

    debugPrint('Name: $name');
    debugPrint('Email: $email');
    debugPrint('Date of Birth: $dateOfBirth');
    debugPrint('Gender: $gender');
    debugPrint('Role: $role');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Account created successfully.',
        ),
      ),
    );

    // ---------------------------------------------------------
    // ROLE-BASED NAVIGATION
    // ---------------------------------------------------------

    Future.delayed(
      const Duration(milliseconds: 700),
      () {
        if (!mounted) return;

        // -------------------------------------------------------
        // CAREGIVER
        // Kayıttan sonra direkt Caregiver Dashboard
        // -------------------------------------------------------

        if (widget.role == UserRole.caregiver) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const CaregiverDashboardScreen(),
            ),
          );
        }

        // -------------------------------------------------------
        // DOCTOR
        // -------------------------------------------------------

        else if (widget.role == UserRole.doctor) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const DoctorDashboardScreen(),
            ),
          );
        }

        // -------------------------------------------------------
        // PATIENT
        // -------------------------------------------------------

        else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const DashboardScreen(),
            ),
          );
        }
      },
    );
  }

  // ---------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------

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
              // ------------------------------------------------
              // BACK BUTTON
              // ------------------------------------------------

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

              // ------------------------------------------------
              // ICON
              // ------------------------------------------------

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
                    Icons.person_add_alt_1_rounded,
                    color: Color(0xFF168AF7),
                    size: 38,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // ------------------------------------------------
              // TITLE
              // ------------------------------------------------

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

              // ------------------------------------------------
              // FORM CARD
              // ------------------------------------------------

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
                      color: Colors.black.withValues(
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
                    // ------------------------------------------
                    // FULL NAME
                    // ------------------------------------------

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
                            'Enter your full name',

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
                          borderSide:
                              BorderSide.none,
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFFE3EAF1),
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFF168AF7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ------------------------------------------
                    // EMAIL
                    // ------------------------------------------

                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273142),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: emailController,

                      keyboardType:
                          TextInputType.emailAddress,

                      decoration: InputDecoration(
                        hintText: 'you@example.com',

                        prefixIcon: const Icon(
                          Icons.email_outlined,
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
                          borderSide:
                              BorderSide.none,
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFFE3EAF1),
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFF168AF7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ------------------------------------------
                    // DATE OF BIRTH
                    // ------------------------------------------

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
                              Icons.calendar_month_outlined,
                              color:
                                  Color(0xFF718096),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                selectedDateOfBirth ==
                                        null
                                    ? 'Select your date of birth'
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

                    // ------------------------------------------
                    // GENDER
                    // ------------------------------------------

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
                        hintText:
                            'Select your gender',

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
                          borderSide:
                              BorderSide.none,
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFFE3EAF1),
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFF168AF7),
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

                    // ------------------------------------------
                    // PASSWORD
                    // ------------------------------------------

                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273142),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: passwordController,

                      obscureText: obscurePassword,

                      decoration: InputDecoration(
                        hintText:
                            'Create a password',

                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                        ),

                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscurePassword =
                                  !obscurePassword;
                            });
                          },

                          icon: Icon(
                            obscurePassword
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                          ),
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
                          borderSide:
                              BorderSide.none,
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFFE3EAF1),
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFF168AF7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ------------------------------------------
                    // CONFIRM PASSWORD
                    // ------------------------------------------

                    const Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273142),
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller:
                          confirmPasswordController,

                      obscureText:
                          obscureConfirmPassword,

                      decoration: InputDecoration(
                        hintText:
                            'Re-enter your password',

                        prefixIcon: const Icon(
                          Icons.lock_reset_rounded,
                        ),

                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword =
                                  !obscureConfirmPassword;
                            });
                          },

                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                          ),
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
                          borderSide:
                              BorderSide.none,
                        ),

                        enabledBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFFE3EAF1),
                          ),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(
                            color: Color(0xFF168AF7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ------------------------------------------
                    // CREATE ACCOUNT BUTTON
                    // ------------------------------------------

                    SizedBox(
                      height: 56,

                      child: ElevatedButton(
                        onPressed: createAccount,

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF168AF7),

                          foregroundColor:
                              Colors.white,

                          elevation: 0,

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(17),
                          ),
                        ),

                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,

                          children: const [
                            Text(
                              'Create Account',
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

              // ------------------------------------------------
              // LOGIN
              // ------------------------------------------------

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,

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

              // ------------------------------------------------
              // SECURITY INFO
              // ------------------------------------------------

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