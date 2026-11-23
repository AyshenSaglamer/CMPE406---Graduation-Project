import 'package:flutter/material.dart';

import '../data/ai_insights_store.dart';
import '../data/care_patients_store.dart';
import '../data/glucose_store.dart';
import '../data/log_store.dart';
import '../services/api_exception.dart';
import '../utils/form_helpers.dart';
import '../widgets/ai_insights_card.dart';

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
class CarePatientDetailScreen extends StatefulWidget {
  const CarePatientDetailScreen({
    super.key,
    required this.patient,
    this.glucose,
    this.insightsStore,
  });

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

  Widget _buildLatestCard() {
    final color = glucoseStatusColor(patient.status);

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
          if (patient.lastGlucose == null)
            const Text(
              'No readings yet.',
              style: TextStyle(fontSize: 14, color: _muted),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${patient.lastGlucose}',
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
                    patient.statusLabel,
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
              if (patient.lastGlucoseAt != null)
                'Last measurement: ${formatRelativeDay(patient.lastGlucoseAt!)}',
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
