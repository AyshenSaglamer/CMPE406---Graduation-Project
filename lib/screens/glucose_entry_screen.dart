import 'package:flutter/material.dart';

import '../data/glucose_store.dart';
import '../services/api_exception.dart';
import '../utils/api_enums.dart';
import '../utils/client_uuid.dart';
import '../widgets/date_time_tile.dart';

class GlucoseEntryScreen extends StatefulWidget {
  /// Pass a reading to edit it; leave empty to add a new one.
  const GlucoseEntryScreen({super.key, this.existing});

  final GlucoseRecord? existing;

  @override
  State<GlucoseEntryScreen> createState() => _GlucoseEntryScreenState();
}

class _GlucoseEntryScreenState extends State<GlucoseEntryScreen> {
  final TextEditingController glucoseController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  String selectedTime = 'Fasting';

  final List<String> timeOptions = glucoseContextOptions.keys.toList();

  DateTime measuredAt = DateTime.now();

  bool isSaving = false;

  String? glucoseError;

  // One id per reading. It stays the same if the user taps Save again
  // after a network error, so the backend does not store the reading twice.
  // It changes when the user edits the reading.
  String clientUuid = newClientUuid();

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    if (existing != null) {
      glucoseController.text = existing.value.round().toString();
      notesController.text = existing.notes ?? '';
      selectedTime = existing.measurementTime;
      measuredAt = existing.dateTime;
    }
  }

  void _readingChanged() {
    clientUuid = newClientUuid();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveMeasurement() async {
    if (isSaving) {
      return;
    }

    final value = glucoseController.text.trim();

    if (value.isEmpty) {
      _showMessage('Please enter your blood glucose value.');
      return;
    }

    final glucose = int.tryParse(value);

    if (glucose == null ||
        glucose < glucoseMinMgDl ||
        glucose > glucoseMaxMgDl) {
      _showMessage('Please enter a whole number between 10 and 600 mg/dL.');
      return;
    }

    setState(() {
      isSaving = true;
      glucoseError = null;
    });

    final body = GlucoseRecord.requestBody(
      glucoseValue: glucose,
      measuredAt: measuredAt,
      mealContextLabel: selectedTime,
      clientUuid: clientUuid,
      notes: notesController.text.trim(),
    );

    try {
      final existing = widget.existing;

      if (existing == null) {
        await glucoseStore.create(body);
      } else {
        await glucoseStore.update(existing.id, body);
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
        glucoseError = e.fieldErrors['glucoseValue'];
      });

      final otherError =
          e.fieldErrors['measurementTime'] ?? e.fieldErrors['notes'];

      _showMessage(otherError ?? e.message);
      return;
    }

    if (!mounted) {
      return;
    }

    _showMessage(
      isEditing
          ? 'Blood glucose record updated.'
          : 'Blood glucose record saved successfully.',
    );

    Navigator.pop(context);
  }

  @override
  void dispose() {
    glucoseController.dispose();
    notesController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    String? hintText,
    String? suffixText,
    Widget? prefixIcon,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      errorText: errorText,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          isEditing ? 'Edit Blood Glucose' : 'Add Blood Glucose',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE8EEF4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Blood Glucose',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: glucoseController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        _readingChanged();

                        if (glucoseError != null) {
                          setState(() {
                            glucoseError = null;
                          });
                        }
                      },
                      decoration: _fieldDecoration(
                        hintText: 'e.g. 105',
                        suffixText: 'mg/dL',
                        prefixIcon: const Icon(Icons.water_drop_rounded),
                        errorText: glucoseError,
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Meal Context',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: selectedTime,
                      decoration: _fieldDecoration(),
                      items: timeOptions
                          .map(
                            (option) => DropdownMenuItem(
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
                          _readingChanged();
                        });
                      },
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Measurement Date & Time',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    DateTimeTile(
                      value: measuredAt,
                      onChanged: (value) {
                        setState(() {
                          measuredAt = value;
                          _readingChanged();
                        });
                      },
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'Notes (optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _readingChanged(),
                      decoration: _fieldDecoration(
                        hintText: 'e.g. Felt dizzy before the measurement',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : _saveMeasurement,
                  icon: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    isSaving
                        ? 'Saving...'
                        : isEditing
                        ? 'Save Changes'
                        : 'Save Measurement',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(18),
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
