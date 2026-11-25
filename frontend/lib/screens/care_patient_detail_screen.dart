import 'package:flutter/material.dart';

import '../data/ai_insights_store.dart';
import '../data/care_patients_store.dart';
import '../data/glucose_store.dart';
import '../data/log_store.dart';
import '../data/reminder_store.dart';
import '../services/api_exception.dart';
import '../utils/form_helpers.dart';
import '../widgets/ai_insights_card.dart';
import 'activity_entry_screen.dart';
import 'ai_assistant_screen.dart';
import 'glucose_chart_screen.dart';
import 'glucose_entry_screen.dart';
import 'insulin_entry_screen.dart';
import 'meal_entry_screen.dart';
import 'reminder_screen.dart';

/// Colour of a glucose status, shared by the doctor and caregiver screens.
Color glucoseStatusColor(GlucoseStatus status) => switch (status) {
      GlucoseStatus.high => const Color(0xFFE85D75),
      GlucoseStatus.low => const Color(0xFFF0A126),
      GlucoseStatus.inRange => const Color(0xFF35B779),
      GlucoseStatus.noData => const Color(0xFF9AA8B7),
    };

/// A followed patient, seen by their doctor or caregiver: latest glucose,
/// the last 14 days of readings (GET /patients/{id}/glucose-logs) and the
/// AI insights. What is shown follows the patient's permissions.
/// For a family member without an account whom the caregiver manages, the
/// caregiver also keeps the diary here (Add Entry).
class CarePatientDetailScreen extends StatefulWidget {
  const CarePatientDetailScreen({
    super.key,
    required this.patient,
    this.glucose,
    this.insightsStore,
    this.reminderStoreFor,
  });

  /// The managed family member's reminders; defaults to the reminders API.
  final ReminderStore Function(int patientId)? reminderStoreFor;

  final CarePatient patient;

  /// Defaults to [glucoseStore]; tests pass one with a fake backend.
  final LogStore<GlucoseRecord>? glucose;

  /// Defaults to [aiInsightsStore].
  final AiInsightsStore? insightsStore;

  /// How far back the history and the AI insights look.
  static const int historyDays = 14;

  @override
  State<CarePatientDetailScreen> createState() =>
      _CarePatientDetailScreenState();
}

class _CarePatientDetailScreenState extends State<CarePatientDetailScreen> {
  static const _muted = Color(0xFF718096);

  List<GlucoseRecord> readings = [];
  bool isLoading = true;
  String? loadError;

  CarePatient get patient => widget.patient;

  @override
  void initState() {
    super.initState();
    if (patient.canViewGlucose) {
      _load();
    } else {
      isLoading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: CarePatientDetailScreen.historyDays - 1));

    try {
      final result = await (widget.glucose ?? glucoseStore)
          .fetch(from: from, patientId: patient.id);

      if (!mounted) {
        return;
      }

      setState(() {
        readings = result;
        isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        loadError = e.message;
      });
    }
  }

  /// Opens an entry screen for this family member, then reloads the
  /// history (a new glucose reading may be the latest).
  Future<void> _addEntry(Widget Function(int id, String name) screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen(patient.id, patient.name)),
    );

    if (mounted && patient.canViewGlucose) {
      _load();
    }
  }

  GlucoseStatus _statusOf(double value) {
    if (value < patient.targetMin) {
      return GlucoseStatus.low;
    }
    if (value > patient.targetMax) {
      return GlucoseStatus.high;
    }
    return GlucoseStatus.inRange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Patient Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: patient.canViewGlucose ? _load : () async {},
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            if (patient.managed) ...[
              _buildAddEntry(),
              const SizedBox(height: 12),
              _buildManageTiles(),
              const SizedBox(height: 18),
            ],
            if (!patient.canViewGlucose)
              const _Note(
                text: 'This patient does not share glucose readings with you.',
              )
            else ...[
              _buildLatestCard(),
              const SizedBox(height: 18),
              if (patient.canViewReports) ...[
                AiInsightsCard(
                  days: CarePatientDetailScreen.historyDays,
                  patientId: patient.id,
                  store: widget.insightsStore,
                ),
                const SizedBox(height: 18),
              ],
              const Text(
                'Glucose History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Last ${CarePatientDetailScreen.historyDays} days',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 12),
              ..._buildHistory(),
              const SizedBox(height: 8),
              // The full chart (7 / 30 / 90 days) like the patient's own
              // Chart tab, read only.
              _ActionTile(
                icon: Icons.show_chart_rounded,
                color: const Color(0xFF168AF7),
                background: const Color(0xFFEAF5FF),
                title: 'Glucose Chart',
                subtitle: 'Trends over 7 days, 30 days or 3 months',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GlucoseChartScreen(
                      patient: patient,
                      store: widget.glucose,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5FF),
              borderRadius: BorderRadius.circular(23),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 42,
              color: Color(0xFF168AF7),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            patient.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            patient.subtitle,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          if (patient.openAlerts != null && patient.openAlerts! > 0) ...[
            const SizedBox(height: 10),
            Text(
              patient.openAlerts == 1
                  ? '1 open alert'
                  : '${patient.openAlerts} open alerts',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFFE85D75),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Entry',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'You keep ${patient.firstName.isEmpty ? 'their' : "${patient.firstName}'s"} diary.',
          style: const TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _EntryButton(
              icon: Icons.water_drop_rounded,
              label: 'Glucose',
              color: const Color(0xFF168AF7),
              onTap: () => _addEntry(
                (id, name) => GlucoseEntryScreen(
                  patientId: id,
                  patientName: name,
                  store: widget.glucose,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _EntryButton(
              icon: Icons.vaccines_rounded,
              label: 'Insulin',
              color: const Color(0xFF765BD4),
              onTap: () => _addEntry(
                (id, name) =>
                    InsulinEntryScreen(patientId: id, patientName: name),
              ),
            ),
            const SizedBox(width: 10),
            _EntryButton(
              icon: Icons.restaurant_rounded,
              label: 'Meal',
              color: const Color(0xFFF0A126),
              onTap: () => _addEntry(
                (id, name) => MealEntryScreen(patientId: id, patientName: name),
              ),
            ),
            const SizedBox(width: 10),
            _EntryButton(
              icon: Icons.directions_walk_rounded,
              label: 'Activity',
              color: const Color(0xFF35B779),
              onTap: () => _addEntry(
                (id, name) =>
                    ActivityEntryScreen(patientId: id, patientName: name),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The family member's reminder plan and the assistant, for the caregiver
  /// who keeps their diary.
  Widget _buildManageTiles() {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.notifications_active_outlined,
          color: const Color(0xFFF0A126),
          background: const Color(0xFFFFF3DF),
          title: 'Reminders',
          subtitle: 'Medicines, glucose checks and what was taken',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReminderScreen(
                patientId: patient.id,
                patientName: patient.name,
                store: widget.reminderStoreFor?.call(patient.id),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.smart_toy_rounded,
          color: const Color(0xFF8B62D6),
          background: const Color(0xFFF0E9FF),
          title: 'DiaMate Assistant',
          subtitle: 'Log in one sentence, typed or spoken',
          onTap: () => _addEntry(
            (id, name) => AiAssistantScreen(patientId: id, patientName: name),
          ),
        ),
      ],
    );
  }

  Widget _buildLatestCard() {
    // After the caregiver logged a reading here, the history is newer than
    // the overview the list was loaded with.
    final overviewAt = patient.lastGlucoseAt;
    var newest = readings.isEmpty ? null : readings.first;
    if (newest != null &&
        overviewAt != null &&
        newest.dateTime.isBefore(overviewAt)) {
      newest = null;
    }
    final lastGlucose = newest?.value.round() ?? patient.lastGlucose;
    final lastGlucoseAt = newest?.dateTime ?? overviewAt;
    final status = lastGlucose == null
        ? GlucoseStatus.noData
        : _statusOf(lastGlucose.toDouble());
    final color = glucoseStatusColor(status);
    final statusLabel = switch (status) {
      GlucoseStatus.low => 'Low',
      GlucoseStatus.high => 'High',
      GlucoseStatus.inRange => 'In Range',
      GlucoseStatus.noData => 'No data',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF5FF), Color(0xFFF4F8FF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Blood Glucose',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (lastGlucose == null)
            const Text(
              'No readings yet.',
              style: TextStyle(fontSize: 14, color: _muted),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$lastGlucose',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 9),
                  child: Text(
                    'mg/dL',
                    style: TextStyle(fontSize: 15, color: _muted),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            [
              if (lastGlucoseAt != null)
                'Last measurement: ${formatRelativeDay(lastGlucoseAt)}',
              'Target ${patient.targetMin}–${patient.targetMax} mg/dL',
            ].join('\n'),
            style: const TextStyle(fontSize: 12, height: 1.5, color: _muted),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildHistory() {
    if (isLoading && readings.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (loadError != null) {
      return [
        _Note(text: loadError!, actionLabel: 'Try again', onAction: _load),
      ];
    }

    if (readings.isEmpty) {
      return const [_Note(text: 'No readings in the last 14 days.')];
    }

    return [
      for (final r in readings)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Icon(
              Icons.water_drop_rounded,
              color: glucoseStatusColor(_statusOf(r.value)),
            ),
            title: Text(
              '${formatNumber(r.value)} mg/dL',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(r.measurementTime),
            trailing: Text(
              formatRelativeDay(r.dateTime),
              style: const TextStyle(fontSize: 12, color: _muted),
            ),
          ),
        ),
    ];
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _EntryButton extends StatelessWidget {
  const _EntryButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64788B)),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
