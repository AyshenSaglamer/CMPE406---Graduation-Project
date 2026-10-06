import 'package:flutter/material.dart';

import '../models/child_profile.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final nameController = TextEditingController();
  final pinController = TextEditingController();

  DateTime? dateOfBirth;

  String diabetesType = 'Type 1 Diabetes';

  bool obscurePin = true;

  Future<void> _selectDateOfBirth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 3650),
      ),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() {
        dateOfBirth = selected;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  void _saveChild() {
    final name = nameController.text.trim();
    final pin = pinController.text.trim();

    if (name.isEmpty ||
        dateOfBirth == null ||
        pin.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all fields correctly.',
          ),
        ),
      );
      return;
    }

    final child = ChildProfile(
      name: name,
      dateOfBirth: _formatDate(dateOfBirth!),
      diabetesType: diabetesType,
      pin: pin,
    );

    Navigator.pop(context, child);
  }

  @override
  void dispose() {
    nameController.dispose();
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Add Child'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFEAF5FF),
                    Color(0xFFF4FAFF),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.child_care_rounded,
                      color: Color(0xFF168AF7),
                      size: 31,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Child Profile',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF233247),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Add your child to your family account.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF64788B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Child Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 12),

            _buildFieldLabel('Child Name'),

            const SizedBox(height: 7),

            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Enter child name',
                prefixIcon: const Icon(
                  Icons.person_outline_rounded,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFE3EAF1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF168AF7),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            _buildFieldLabel('Date of Birth'),

            const SizedBox(height: 7),

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
                    color: const Color(0xFFE3EAF1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xFF718096),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dateOfBirth == null
                            ? 'Select date of birth'
                            : _formatDate(dateOfBirth!),
                        style: TextStyle(
                          fontSize: 14,
                          color: dateOfBirth == null
                              ? const Color(0xFFA0AEC0)
                              : const Color(0xFF172033),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF9AA8B7),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            _buildFieldLabel('Diabetes Type'),

            const SizedBox(height: 7),

            DropdownButtonFormField<String>(
              initialValue: diabetesType,
              decoration: InputDecoration(
                prefixIcon: const Icon(
                  Icons.medical_information_outlined,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFE3EAF1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF168AF7),
                    width: 1.5,
                  ),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Type 1 Diabetes',
                  child: Text('Type 1 Diabetes'),
                ),
                DropdownMenuItem(
                  value: 'Type 2 Diabetes',
                  child: Text('Type 2 Diabetes'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  diabetesType = value;
                });
              },
            ),

            const SizedBox(height: 18),

            _buildFieldLabel('Child PIN'),

            const SizedBox(height: 7),

            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: obscurePin,
              maxLength: 4,
              decoration: InputDecoration(
                hintText: 'Create a 4-digit PIN',
                prefixIcon: const Icon(
                  Icons.pin_outlined,
                ),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      obscurePin = !obscurePin;
                    });
                  },
                  icon: Icon(
                    obscurePin
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFE3EAF1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF168AF7),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 19,
                    color: Color(0xFFE4A329),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'The PIN can be used for a simple child-friendly login experience.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: Color(0xFF786A51),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveChild,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF168AF7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Create Child Profile',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF273142),
      ),
    );
  }
}