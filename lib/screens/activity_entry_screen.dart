import 'package:flutter/material.dart';

import '../data/activity_store.dart';
import '../services/api_exception.dart';
import '../utils/api_enums.dart';
import '../utils/client_uuid.dart';
import '../widgets/date_time_tile.dart';

class ActivityEntryScreen extends StatefulWidget {
  const ActivityEntryScreen({super.key});

  @override
  State<ActivityEntryScreen> createState() => _ActivityEntryScreenState();
}

class _ActivityEntryScreenState extends State<ActivityEntryScreen> {
  final durationController = TextEditingController();

  String selectedActivity = 'Walking';
  String selectedIntensity = 'Moderate';

  final List<String> activityTypes = [
    'Walking',
    'Running',
    'Cycling',
    'Exercise',
    'Other',
  ];

  // Labels stay the same on screen. The backend expects LOW / MODERATE / HIGH.
  final List<String> intensityOptions = activityIntensityOptions.keys.toList();

  DateTime startedAt = DateTime.now();

  bool isSaving = false;

  // Same id while retrying after a network error, so the record is not
  // stored twice. A new one after any change.
  String clientUuid = newClientUuid();

  void _changed(VoidCallback update) {
    setState(() {
      update();
      clientUuid = newClientUuid();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveActivity() async {
    if (isSaving) {
      return;
    }

    final value = durationController.text.trim();

    if (value.isEmpty) {
      _showMessage('Please enter the activity duration.');
      return;
    }

    final duration = int.tryParse(value);

    if (duration == null || duration <= 0 || duration > 1440) {
      _showMessage('Please enter a duration between 1 and 1440 minutes.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await activityStore.create({
        'activityType': selectedActivity,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'durationMinutes': duration,
        'intensity': activityIntensityOptions[selectedIntensity],
        'clientUuid': clientUuid,
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isSaving = false;
      });

      final fieldError =
          e.fieldErrors['durationMinutes'] ?? e.fieldErrors['startedAt'];

      _showMessage(fieldError ?? e.message);
      return;
    }

    if (!mounted) {
      return;
    }

    _showMessage('$selectedActivity activity for $duration minutes saved.');

    Navigator.pop(context);
  }

  @override
  void dispose() {
    durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Activity'),
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
              'Activity Type',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildActivitySelector(),

            const SizedBox(height: 24),

            const Text(
              'Duration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildDurationInput(),

            const SizedBox(height: 24),

            const Text(
              'Start Time',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            DateTimeTile(
              value: startedAt,
              accentColor: const Color(0xFF35B779),
              onChanged: (value) => _changed(() => startedAt = value),
            ),

            const SizedBox(height: 24),

            const Text(
              'Intensity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildIntensitySelector(),

            const SizedBox(height: 22),

            _buildInfoCard(),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _saveActivity,
                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  isSaving ? 'Saving...' : 'Save Activity Record',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF35B779),
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
          colors: [Color(0xFFEAF8EE), Color(0xFFF3FCF6)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_run_rounded,
              size: 31,
              color: Color(0xFF35B779),
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Activity Record',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF294637),
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Record your physical activity and duration.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF668071),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: activityTypes.map((activity) {
        final isSelected = selectedActivity == activity;

        return ChoiceChip(
          label: Text(activity),
          selected: isSelected,
          onSelected: (_) => _changed(() => selectedActivity = activity),
          selectedColor: const Color(0xFFE3F7EB),
          backgroundColor: Colors.white,
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF35B779)
                : const Color(0xFFE1E8EF),
          ),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? const Color(0xFF26915D)
                : const Color(0xFF5F6E7D),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDurationInput() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EDF3)),
      ),
      child: Column(
        children: [
          const Text(
            'How long were you active?',
            style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: durationController,
            keyboardType: TextInputType.number,
            onChanged: (_) => clientUuid = newClientUuid(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
            decoration: const InputDecoration(
              hintText: '30',
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
            'minutes',
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

  Widget _buildIntensitySelector() {
    return Row(
      children: intensityOptions.map((intensity) {
        final isSelected = selectedIntensity == intensity;

        final Color selectedColor;

        switch (intensity) {
          case 'Light':
            selectedColor = const Color(0xFF74C69D);
            break;

          case 'Moderate':
            selectedColor = const Color(0xFF35B779);
            break;

          default:
            selectedColor = const Color(0xFF258A5A);
        }

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: intensity == intensityOptions.last ? 0 : 10,
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                onTap: () => _changed(() => selectedIntensity = intensity),
                borderRadius: BorderRadius.circular(17),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFEAF8EE) : Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: isSelected
                          ? selectedColor
                          : const Color(0xFFE1E8EF),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        intensity == 'Light'
                            ? Icons.directions_walk_rounded
                            : intensity == 'Moderate'
                            ? Icons.directions_run_rounded
                            : Icons.bolt_rounded,
                        color: isSelected
                            ? selectedColor
                            : const Color(0xFF7D8996),
                        size: 22,
                      ),

                      const SizedBox(height: 7),

                      Text(
                        intensity,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? selectedColor
                              : const Color(0xFF5F6E7D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF9F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF35B779), size: 21),

          SizedBox(width: 10),

          Expanded(
            child: Text(
              'Tracking physical activity can help you review daily patterns together with your other health records.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Color(0xFF587061),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
