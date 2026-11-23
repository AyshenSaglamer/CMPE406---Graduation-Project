import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../navigation/session_navigation.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({
    super.key,
    required this.role,
  });
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  // Disables the button while the request is running.
  bool isLoading = false;
  bool get isCaregiver => widget.role == UserRole.caregiver;
  bool get isDoctor => widget.role == UserRole.doctor;
  String get title {
    return 'Welcome back';
  }
  String get subtitle {
    if (isCaregiver) {
      return 'Sign in to your caregiver account';
    }
    if (isDoctor) {
      return 'Sign in to your doctor account';
    }
    return 'Sign in to continue managing your health';
  }
  // --------------------------------------------------------
  // LOGIN
  // --------------------------------------------------------
  Future<void> login() async {
    final email = emailController.text.trim();
    // Do not trim the password: spaces can be part of it.
    final password = passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your email and password.',
          ),
        ),
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      final user = await authService.login(
        email: email,
        password: password,
      );
      if (!mounted) return;
      // Navigate by the role the backend returned, not by the card the user
      // tapped (widget.role). Otherwise a patient could open the doctor
      // dashboard just by choosing "Doctor" on the first screen.
      goToHome(context, user.role);
    } on ApiException catch (e) {
      if (!mounted) return;
      // 401: same text for an unknown email and a wrong password.
      // 403: account disabled. 0: no connection. Others: server text.
      final message = e.statusCode == 401
          ? 'Incorrect email or password.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
  // --------------------------------------------------------
  // DISPOSE
  // --------------------------------------------------------
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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
              // LOGO
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
                  child: Icon(
                    isCaregiver
                        ? Icons.family_restroom_rounded
                        : isDoctor
                        ? Icons.medical_services_rounded
                        : Icons.favorite_rounded,
                    color: const Color(0xFF168AF7),
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // -----------------------------------------------
              // TITLE
              // -----------------------------------------------
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 8),
              // -----------------------------------------------
              // SUBTITLE
              // -----------------------------------------------
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 30),
              // -----------------------------------------------
              // LOGIN FORM
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
                    // -----------------------------------------------
                    // EMAIL LABEL
                    // -----------------------------------------------
                    const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273142),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // -----------------------------------------------
                    // EMAIL FIELD
                    // -----------------------------------------------
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      obscureText: false,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'you@example.com',
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
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
                          borderSide: const BorderSide(
                            color: Color(0xFFE3EAF1),
                          ),
                        ),
                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF168AF7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // -----------------------------------------------
                    // PASSWORD LABEL
                    // -----------------------------------------------
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF273142),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // -----------------------------------------------
                    // PASSWORD FIELD
                    // -----------------------------------------------
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        hintText: 'Enter your password',
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
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
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
                          borderSide: const BorderSide(
                            color: Color(0xFFE3EAF1),
                          ),
                        ),
                        focusedBorder:
                        OutlineInputBorder(
                          borderRadius:
                          BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF168AF7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // -----------------------------------------------
                    // FORGOT PASSWORD
                    // -----------------------------------------------
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password recovery will be available soon.',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot password?',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // -----------------------------------------------
                    // LOGIN BUTTON
                    // -----------------------------------------------
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFF168AF7),
                          disabledBackgroundColor:
                          const Color(0xFF168AF7).withValues(alpha: 0.6),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(17),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Log In',
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
              // REGISTER
              // -----------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF718096),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegisterScreen(
                            role: widget.role,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Create account',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // -----------------------------------------------
              // PRIVACY NOTICE
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
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Color(0xFF168AF7),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your health information is protected and kept private.',
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
