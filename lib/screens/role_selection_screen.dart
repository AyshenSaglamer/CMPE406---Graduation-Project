
import 'package:flutter/material.dart';

import '../models/user_role.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _openLogin(
    BuildContext context,
    UserRole role,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(role: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // LOGO
              Center(
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFDDF0FF),
                        Color(0xFFF1F9FF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFF168AF7),
                    size: 40,
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Welcome to DiaMate',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your health, made simpler.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF718096),
                ),
              ),

              const SizedBox(height: 38),

              const Text(
                'Choose your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'Select the option that best describes you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF718096),
                ),
              ),

              const SizedBox(height: 22),

              // PATIENT
              _RoleCard(
                icon: Icons.person_rounded,
                iconColor: const Color(0xFF168AF7),
                iconBackground: const Color(0xFFEAF5FF),
                title: 'Patient',
                description:
                    'Track your glucose, insulin, meals, activity and reminders.',
                buttonText: 'Continue as Patient',
                onTap: () {
                  _openLogin(
                    context,
                    UserRole.patient,
                  );
                },
              ),

              const SizedBox(height: 16),

              // CAREGIVER
              _RoleCard(
                icon: Icons.family_restroom_rounded,
                iconColor: const Color(0xFF765BD4),
                iconBackground: const Color(0xFFF0ECFF),
                title: 'Caregiver',
                description:
                    'Manage family members and support their health journey.',
                buttonText: 'Continue as Caregiver',
                onTap: () {
                  _openLogin(
                    context,
                    UserRole.caregiver,
                  );
                },
              ),

              const SizedBox(height: 16),

              // DOCTOR
              _RoleCard(
                icon: Icons.medical_services_rounded,
                iconColor: const Color(0xFF168A9F),
                iconBackground: const Color(0xFFE6F8FA),
                title: 'Doctor',
                description:
                    'Monitor patients, review glucose readings and access health reports.',
                buttonText: 'Continue as Doctor',
                onTap: () {
                  _openLogin(
                    context,
                    UserRole.doctor,
                  );
                },
              ),

              const SizedBox(height: 24),

              // CAREGIVER INFORMATION
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFDCEEFF),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.child_care_rounded,
                        color: Color(0xFF168AF7),
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 12),

                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Managing a child?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF26364A),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Children can be added to a caregiver account and managed from the family dashboard.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.45,
                              color: Color(0xFF647A8F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Your privacy and security matter to us.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9AA8B7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ROLE CARD WIDGET
class _RoleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE7EDF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 30,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),

          const SizedBox(height: 13),

          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF718096),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: iconColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}