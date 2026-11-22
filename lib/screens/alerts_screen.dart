import 'package:flutter/material.dart';

import '../data/alert_store.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/form_helpers.dart';

/// Glucose alerts of every patient who gave the logged-in clinician /
/// caregiver alert access (can_receive_alerts). Opened from the doctor and
/// caregiver dashboards.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.store, this.currentUserId});

  /// Defaults to [alertStore]; tests pass one with a fake backend.
  final AlertStore? store;

  /// Id of the logged-in user, to tell "by you" from "by another care team
  /// member" on the cards. Defaults to [AuthService.currentUser].
  final int? currentUserId;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  /// Filter label -> backend status (null = every status).
  static const Map<String, String?> _filters = {
    'Open': PatientAlert.open,
    'Seen': PatientAlert.acknowledged,
    'All': null,
  };

  static const Color _red = Color(0xFFE85D75);
  static const Color _orange = Color(0xFFF0A126);
  static const Color _green = Color(0xFF35B779);
  static const Color _blue = Color(0xFF168AF7);
  static const Color _muted = Color(0xFF718096);

  String selectedFilter = 'Open';
  List<CareTeamAlert> items = [];
  bool isLoading = true;
  String? loadError;

  /// Alerts whose status change is on its way, so their buttons are disabled.
  final Set<int> busy = {};

  int _loadRequest = 0;

  AlertStore get _store => widget.store ?? alertStore;

  int? get _currentUserId => widget.currentUserId ?? authService.currentUser?.id;

  /// " by you" / " by another care team member", or nothing when the backend
  /// did not record who it was (alerts resolved before it did).
  String _byWhom(int? userId) {
    if (userId == null || _currentUserId == null) {
      return '';
    }

    return userId == _currentUserId ? ' by you' : ' by another care team member';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_loadRequest;

    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final fetched = await _store.careTeamAlerts(
        status: _filters[selectedFilter],
      );

      if (!mounted || request != _loadRequest) {
        return;
      }

      setState(() {
        items = fetched;
        isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _loadRequest) {
        return;
      }

      setState(() {
        isLoading = false;
        loadError = e.message;
      });
    }
  }

  void _selectFilter(String filter) {
    if (filter == selectedFilter) {
      return;
    }

    setState(() {
      selectedFilter = filter;
    });

    _load();
  }

  Future<void> _changeStatus(CareTeamAlert item, String status) async {
    final alert = item.alert;

    setState(() {
      busy.add(alert.id);
    });

    try {
      final updated = await _store.changeStatus(
        alert.patientId,
        alert.id,
        status,
      );

      if (!mounted) {
        return;
      }

      final wanted = _filters[selectedFilter];

      setState(() {
        busy.remove(alert.id);
        items = [
          for (final i in items)
            if (i.alert.id != alert.id)
              i
            else if (wanted == null || updated.status == wanted)
              CareTeamAlert(i.patient, updated),
        ];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == PatientAlert.resolved
                ? 'Alert resolved.'
                : 'Alert marked as seen.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        busy.remove(alert.id);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));

      // 409: someone else closed it, or the reading was deleted (DISMISSED).
      // 404: the patient removed access. Either way the list is out of date.
      if (e.statusCode == 409 || e.statusCode == 404) {
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Alerts',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(
              children: [
                for (final filter in _filters.keys) ...[
                  ChoiceChip(
                    label: Text(filter),
                    selected: selectedFilter == filter,
                    onSelected: (_) => _selectFilter(filter),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (loadError != null) {
      return _buildMessage(
        icon: Icons.cloud_off_rounded,
        color: _red,
        title: 'Alerts could not be loaded',
        text: loadError!,
        action: TextButton(
          onPressed: _load,
          child: const Text('Try again'),
        ),
      );
    }

    if (items.isEmpty) {
      return _buildMessage(
        icon: Icons.check_circle_outline_rounded,
        color: _green,
        title: selectedFilter == 'Open'
            ? 'No open alerts'
            : 'No alerts here',
        text: selectedFilter == 'Open'
            ? 'None of your patients has a glucose alert waiting.'
            : 'Alerts appear when a patient’s glucose is outside their range.',
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      itemCount: items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildAlertCard(items[index]),
      ),
    );
  }

  /// Scrollable, so pull-to-refresh also works on an empty list.
  Widget _buildMessage({
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    Widget? action,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 80, 32, 32),
      children: [
        Icon(icon, size: 48, color: color),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
        if (action != null) ...[
          const SizedBox(height: 10),
          Center(child: action),
        ],
      ],
    );
  }

  Widget _buildAlertCard(CareTeamAlert item) {
    final alert = item.alert;
    final color = alert.isCritical ? _red : _orange;
    final isBusy = busy.contains(alert.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  alert.type.contains('LOW') || alert.type == 'RAPID_FALL'
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
                      item.patient.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alert.valueMgdl == null
                          ? alert.typeLabel
                          : '${alert.typeLabel} • ${formatNumber(alert.valueMgdl!)} mg/dL',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatDateTime(alert.triggeredAt),
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: alert.status),
            ],
          ),
          if (alert.acknowledgedAt != null || alert.resolvedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (alert.acknowledgedAt != null)
                  'Seen${_byWhom(alert.acknowledgedBy)} '
                      '${formatDateTime(alert.acknowledgedAt!)}',
                if (alert.resolvedAt != null)
                  'Resolved${_byWhom(alert.resolvedBy)} '
                      '${formatDateTime(alert.resolvedAt!)}',
              ].join('  •  '),
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
          if (!alert.isClosed) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (alert.status == PatientAlert.open)
                  OutlinedButton(
                    onPressed: isBusy
                        ? null
                        : () => _changeStatus(item, PatientAlert.acknowledged),
                    child: const Text('Seen'),
                  ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isBusy
                      ? null
                      : () => _changeStatus(item, PatientAlert.resolved),
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                  child: const Text('Resolve'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      PatientAlert.open => ('Open', const Color(0xFFE85D75)),
      PatientAlert.acknowledged => ('Seen', const Color(0xFFF0A126)),
      PatientAlert.resolved => ('Resolved', const Color(0xFF35B779)),
      _ => ('Dismissed', const Color(0xFF98A1AC)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
