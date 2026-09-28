import 'package:flutter/material.dart';

import '../data/glucose_store.dart';

class GlucoseEntryScreen extends StatefulWidget {
  const GlucoseEntryScreen({super.key});

  @override
  State<GlucoseEntryScreen> createState() => _GlucoseEntryScreenState();
}

class _GlucoseEntryScreenState extends State<GlucoseEntryScreen> {
  final TextEditingController glucoseController = TextEditingController();

  String selectedTime = 'Morning';

  final List<String> timeOptions = [
    'Morning',
    'Noon',
    'Evening',
    'Night',
  ];

  void _saveMeasurement() {
    final value = glucoseController.text.trim();

    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your blood glucose value.',
          ),
        ),
      );
      return;
    }

    final glucose = double.tryParse(value);

    if (glucose == null || glucose <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid glucose value.',
          ),
        ),
      );
      return;
    }

    glucoseStore.addRecord(
      glucoseValue: glucose,
      measurementTime: selectedTime,
    );

    final displayedValue =
        glucose % 1 == 0 ? glucose.toInt().toString() : glucose.toString();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Blood glucose measurement of $displayedValue mg/dL saved.',
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    glucoseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Blood Glucose'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 24),
            const Text(
              'Glucose Value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _buildGlucoseInput(),
            const SizedBox(height: 24),
            const Text(
              'Measurement Time',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _buildTimeSelector(),
            const SizedBox(height: 24),
            _buildStatusPreview(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saveMeasurement,
                icon: const Icon(
                  Icons.check_rounded,
                ),
                label: const Text(
                  'Save Measurement',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF168AF7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFEEF1),
            Color(0xFFFFF5F7),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              size: 31,
              color: Color(0xFFE95D76),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Blood Glucose',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B2930),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Record your latest glucose measurement.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF806B72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlucoseInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE7EDF3),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Enter your reading',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF718096),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: glucoseController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
            decoration: const InputDecoration(
              hintText: '105',
              hintStyle: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: Color(0xFFD1D9E2),
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'mg/dL',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF718096),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: timeOptions.map((time) {
        final isSelected = selectedTime == time;

        return ChoiceChip(
          label: Text(time),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              selectedTime = time;
            });
          },
          selectedColor: const Color(0xFFE8F3FF),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF168AF7)
                : const Color(0xFFE0E7EE),
          ),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? const Color(0xFF168AF7)
                : const Color(0xFF5F6E7D),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF35B779),
            size: 24,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current status',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF678071),
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Within the example target range',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E6E4B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}