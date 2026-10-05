import 'package:flutter/material.dart';

import '../data/glucose_store.dart';
import '../utils/api_enums.dart';

class GlucoseEntryScreen extends StatefulWidget {
  const GlucoseEntryScreen({super.key});

  @override
  State<GlucoseEntryScreen> createState() =>
      _GlucoseEntryScreenState();
}

class _GlucoseEntryScreenState
    extends State<GlucoseEntryScreen> {
  final TextEditingController glucoseController =
      TextEditingController();

  String selectedTime = 'Fasting';

  final List<String> timeOptions =
      glucoseContextOptions.keys.toList();

  DateTime measuredAt = DateTime.now();

  Future<void> _pickMeasuredAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: measuredAt,
      firstDate: DateTime.now().subtract(
        const Duration(days: 30),
      ),
      lastDate: DateTime.now(),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(measuredAt),
    );

    if (time == null) {
      return;
    }

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      measuredAt = picked.isAfter(DateTime.now())
          ? DateTime.now()
          : picked;
    });
  }

  String _formatDateTime(DateTime value) {
    final day =
        value.day.toString().padLeft(2, '0');
    final month =
        value.month.toString().padLeft(2, '0');
    final hour =
        value.hour.toString().padLeft(2, '0');
    final minute =
        value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} '
        '$hour:$minute';
  }

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

    if (glucose == null ||
        glucose < glucoseMinMgDl ||
        glucose > glucoseMaxMgDl) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a value between 10 and 600 mg/dL.',
          ),
        ),
      );
      return;
    }

    glucoseStore.addRecord(
      glucoseValue: glucose,
      measurementTime: selectedTime,
      dateTime: measuredAt,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Blood glucose record saved successfully.',
        ),
      ),
    );

    Future.delayed(
      const Duration(milliseconds: 700),
      () {
        if (mounted) {
          Navigator.pop(context);
        }
      },
    );
  }

  @override
  void dispose() {
    glucoseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Add Blood Glucose',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE8EEF4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blood Glucose',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller:
                          glucoseController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          InputDecoration(
                        hintText: 'e.g. 105',
                        suffixText: 'mg/dL',
                        prefixIcon: const Icon(
                          Icons
                              .water_drop_rounded,
                        ),
                        filled: true,
                        fillColor:
                            const Color(0xFFF8FAFC),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Meal Context',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<
                        String>(
                      initialValue: selectedTime,
                      decoration:
                          InputDecoration(
                        filled: true,
                        fillColor:
                            const Color(0xFFF8FAFC),
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          borderSide:
                              BorderSide.none,
                        ),
                      ),
                      items: timeOptions
                          .map(
                            (option) =>
                                DropdownMenuItem(
                              value: option,
                              child: Text(option),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          selectedTime = value;
                        });
                      },
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Measurement Date & Time',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    InkWell(
                      onTap: _pickMeasuredAt,
                      borderRadius:
                          BorderRadius.circular(16),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration:
                            BoxDecoration(
                          color: const Color(
                            0xFFF8FAFC,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          border: Border.all(
                            color: const Color(
                              0xFFE3EAF1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons
                                  .calendar_month_outlined,
                              color: Color(
                                0xFF168AF7,
                              ),
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            Expanded(
                              child: Text(
                                _formatDateTime(
                                  measuredAt,
                                ),
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons
                                  .chevron_right_rounded,
                              color: Color(
                                0xFF9AA8B7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _saveMeasurement,
                  icon: const Icon(
                    Icons.check_rounded,
                  ),
                  label: const Text(
                    'Save Measurement',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding:
                    const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius:
                      BorderRadius.circular(18),
                ),
                child: const Text(
                  'Blood glucose values must be between '
                  '10 and 600 mg/dL.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xFF4E6A83),
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