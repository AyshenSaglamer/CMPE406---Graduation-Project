import 'package:flutter/material.dart';

import '../data/alert_store.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/form_helpers.dart';
import '../widgets/glucose_alert_sheet.dart';
import '../widgets/ai_chat_button.dart';

/// The logged-in patient's own hypo / hyper alerts
/// (GET /patients/{id}/alerts), newest first. Tap one for the first steps;
/// "Seen" and "Resolved" work like on the care team's screen.
class PatientAlertsScreen extends StatefulWidget {
  const PatientAlertsScreen({super.key, this.store, this.patientId});

  /// Defaults to [alertStore]; tests pass one with a fake backend.
  final AlertStore? store;

  /// Defaults to the logged-in patient.
  final int? patientId;

  @override
  State<PatientAlertsScreen> createState() => _PatientAlertsScreenState();
}

class _PatientAlertsScreenState extends State<PatientAlertsScreen> {
  static const _muted = Color(0xFF718096);

  List<PatientAlert> alerts = [];
  bool isLoading = true;
  String? loadError;
  bool onlyOpen = true;
  final Set<int> busy = {};

  AlertStore get _store => widget.store ?? alertStore;

  int? get _patientId => widget.patientId ?? authService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = _patientId;
    if (id == null) {
      return;
    }

    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await _store.alertsOf(
        id,
        status: onlyOpen ? PatientAlert.open : null,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        alerts = result;
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

  Future<void> _change(PatientAlert alert, String status) async {
    setState(() {
      busy.add(alert.id);
    });

    try {
      final updated =
          await _store.changeStatus(alert.patientId, alert.id, status);

      if (!mounted) {
        return;
      }

      setState(() {
        busy.remove(alert.id);
        alerts = [
          for (final a in alerts)
            if (a.id != alert.id)
              a
            else if (!(onlyOpen && updated.status != PatientAlert.open))
              updated,
        ];
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        busy.remove(alert.id);
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
      _load();
    }
  }

  Future<void> _openGuidance(PatientAlert alert) async {
    await showGlucoseAlertSheet(
      context,
      type: alert.type,
      value: alert.valueMgdl ?? 0,
      alert: alert,
      store: _store,
    );

    if (mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const AiChatButton(),
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('My Alerts'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            const Text(
              'Low and high readings from your logs, checked against your '
              'own targets.',
              style: TextStyle(fontSize: 13, color: _muted),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Open')),
                ButtonSegment(value: false, label: Text('All')),
              ],
              selected: {onlyOpen},
              onSelectionChanged: (selection) {
                setState(() {
                  onlyOpen = selection.first;
                });
                _load();
              },
            ),
            const SizedBox(height: 16),
            ..._buildList(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildList() {
    if (isLoading && alerts.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (loadError != null) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(loadError!, textAlign: TextAlign.center),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ];
    }

    if (alerts.isEmpty) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Text(
              onlyOpen
                  ? 'No open alerts. Your recent readings are in range.'
                  : 'No alerts yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _muted),
            ),
          ),
        ),
      ];
    }

    return [
      for (final alert in alerts)
        _AlertTile(
          alert: alert,
          isBusy: busy.contains(alert.id),
          onTap: () => _openGuidance(alert),
          onSeen: () => _change(alert, PatientAlert.acknowledged),
          onResolve: () => _change(alert, PatientAlert.resolved),
        ),
    ];
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.alert,
    required this.isBusy,
    required this.onTap,
    required this.onSeen,
    required this.onResolve,
  });

  final PatientAlert alert;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onSeen;
  final VoidCallback onResolve;

  String get _statusLabel => switch (alert.status) {
        PatientAlert.open => 'Open',
        PatientAlert.acknowledged => 'Seen',
        PatientAlert.resolved => 'Resolved',
        _ => 'Dismissed',
      };

  @override
  Widget build(BuildContext context) {
    final color = alertTypeColor(alert.type);
    final low = alert.type.contains('LOW') || alert.type == 'RAPID_FALL';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      low
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.valueMgdl == null
                              ? alert.typeLabel
                              : '${alert.typeLabel} • '
                                  '${formatNumber(alert.valueMgdl!)} mg/dL',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatRelativeDay(alert.triggeredAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A97A5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _statusLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
              if (!alert.isClosed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (alert.status == PatientAlert.open)
                      TextButton(
                        onPressed: isBusy ? null : onSeen,
                        child: const Text('Seen'),
                      ),
                    TextButton(
                      onPressed: isBusy ? null : onResolve,
                      child: const Text('Resolved'),
                    ),
                  ],
                )
              else
                const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
