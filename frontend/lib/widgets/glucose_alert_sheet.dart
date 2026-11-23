import 'package:flutter/material.dart';

import '../data/alert_store.dart';
import '../services/api_exception.dart';
import '../utils/form_helpers.dart';

/// Default thresholds of patient_profiles (hypo 70, hyper 180, urgent low
/// 54, urgent high 250). Used only when the backend could not be asked
/// (a reading saved offline); online, the backend's alert decides, with the
/// patient's own thresholds.
String? defaultAlertTypeFor(num value) {
  if (value <= 54) {
    return 'URGENT_LOW';
  }
  if (value <= 70) {
    return 'LOW';
  }
  if (value >= 250) {
    return 'URGENT_HIGH';
  }
  if (value >= 180) {
    return 'HIGH';
  }
  return null;
}

bool _isLow(String type) => type == 'URGENT_LOW' || type == 'LOW';

bool _isUrgent(String type) => type == 'URGENT_LOW' || type == 'URGENT_HIGH';

/// Colour of a glucose alert type.
Color alertTypeColor(String type) =>
    _isUrgent(type) ? const Color(0xFFE85D75) : const Color(0xFFF0A126);

/// Title and first steps for a hypo / hyper alert. General self-care steps
/// only; the patient's own care plan comes first.
(String, List<String>) alertGuidance(String type) {
  switch (type) {
    case 'URGENT_LOW':
      return (
        'Urgent low glucose',
        [
          'Take 15–20 g of fast-acting sugar now (juice, glucose tablets or '
              'regular soda).',
          'Check again in 15 minutes and repeat if still low.',
          'If you feel confused, cannot swallow safely or it does not rise, '
              'get help right away: call 112.',
        ],
      );
    case 'LOW':
      return (
        'Low glucose',
        [
          'Take 15 g of fast-acting sugar (juice, glucose tablets).',
          'Check again in 15 minutes; repeat if still low.',
          'Once it is back in range, have a snack or your next meal.',
        ],
      );
    case 'URGENT_HIGH':
      return (
        'Very high glucose',
        [
          'Follow the high-glucose plan from your doctor.',
          'Drink water and check ketones if you have been told to.',
          'If you vomit, breathe fast or feel very unwell, get medical help '
              'now.',
        ],
      );
    default:
      return (
        'High glucose',
        [
          'Follow the plan from your doctor for high readings.',
          'Drink water and stay active if you feel well.',
          'Check again in about 2 hours.',
        ],
      );
  }
}

/// Shows what a low or high reading means and the first steps, right after
/// the reading was saved (or from the alert list). With [alert] (the
/// backend's alert) "Got it" marks it as seen (ACKNOWLEDGED).
Future<void> showGlucoseAlertSheet(
  BuildContext context, {
  required String type,
  required double value,
  PatientAlert? alert,
  AlertStore? store,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GlucoseAlertSheet(
      type: type,
      value: value,
      alert: alert,
      store: store,
    ),
  );
}

class GlucoseAlertSheet extends StatefulWidget {
  const GlucoseAlertSheet({
    super.key,
    required this.type,
    required this.value,
    this.alert,
    this.store,
  });

  final String type;
  final double value;
  final PatientAlert? alert;
  final AlertStore? store;

  @override
  State<GlucoseAlertSheet> createState() => _GlucoseAlertSheetState();
}

class _GlucoseAlertSheetState extends State<GlucoseAlertSheet> {
  bool isSaving = false;

  Future<void> _gotIt() async {
    final alert = widget.alert;

    if (alert != null && alert.status == PatientAlert.open) {
      setState(() {
        isSaving = true;
      });

      try {
        await (widget.store ?? alertStore).changeStatus(
          alert.patientId,
          alert.id,
          PatientAlert.acknowledged,
        );
      } on ApiException {
        // Seen or not, the patient has read the steps; the alert stays OPEN
        // and can be marked from My Alerts.
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = alertTypeColor(widget.type);
    final (title, steps) = alertGuidance(widget.type);
    final low = _isLow(widget.type);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        22 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  low ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatNumber(widget.value)} mg/dL',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'What to do now',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            widget.alert == null
                ? 'General guidance only. Follow the plan from your care team.'
                : 'General guidance only. Follow the plan from your care team. '
                    'Care team members who receive your alerts can see this one.',
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Color(0xFF8A97A5),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: isSaving ? null : _gotIt,
              style: FilledButton.styleFrom(backgroundColor: color),
              child: Text(isSaving ? 'Saving…' : 'Got it'),
            ),
          ),
        ],
      ),
    );
  }
}
