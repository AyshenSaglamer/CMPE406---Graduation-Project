import 'package:flutter/material.dart';

import '../data/offline_queue.dart';
import '../services/auth_service.dart';
import '../utils/form_helpers.dart';

/// The logs saved on this phone while there was no connection
/// ([offlineQueue]), with "Sync now". They are also sent automatically
/// every minute and when the app opens. A log the backend refused is kept
/// with the reason until the patient discards it.
class OfflineModeScreen extends StatefulWidget {
  const OfflineModeScreen({super.key, this.queue, this.patientId});

  /// Defaults to [offlineQueue]; tests pass their own.
  final OfflineQueue? queue;

  /// Defaults to the logged-in patient.
  final int? patientId;

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  OfflineQueue get _queue => widget.queue ?? offlineQueue;

  int? get _patientId => widget.patientId ?? authService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _queue.addListener(_changed);
    _queue.restore();
  }

  @override
  void dispose() {
    _queue.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
    }
  }

  List<PendingLog> get _logs {
    final id = _patientId;
    return id == null ? const [] : _queue.forPatient(id);
  }

  Future<void> _syncNow() async {
    final id = _patientId;
    if (id == null || _queue.isSyncing) {
      return;
    }

    final result = await _queue.sync(id);

    if (!mounted) {
      return;
    }

    final String message;
    if (result.sent > 0 && result.stopped) {
      message = '${_entries(result.sent)} sent. The rest will be sent when '
          'the connection is back.';
    } else if (result.sent > 0) {
      message = '${_entries(result.sent)} sent to your account.';
    } else if (result.stopped) {
      message = 'Still no connection to DiaMate. We will try again '
          'automatically.';
    } else if (result.rejected > 0) {
      message = 'Some entries could not be saved. See the reason below.';
    } else {
      message = 'Nothing to send.';
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _entries(int n) => n == 1 ? '1 entry' : '$n entries';

  Future<void> _discard(PendingLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this entry?'),
        content: Text(
          '${log.kindLabel} ${log.valueLabel} will be removed from this '
          'phone and not saved to your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE85D75),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _queue.discard(log);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = _logs;
    final waiting = logs.where((l) => l.error == null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Offline Mode'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(waiting),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Saved on this phone',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),
                ),
                Text(
                  _entries(logs.length),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (logs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Everything you logged has reached your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
                  ),
                ),
              )
            else
              for (final log in logs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PendingLogCard(
                    log: log,
                    onDiscard: () => _discard(log),
                  ),
                ),
            const SizedBox(height: 12),
            _buildSyncCard(waiting),
            const SizedBox(height: 22),
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(int waiting) {
    final pending = waiting > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pending
              ? const [Color(0xFFFFF3DF), Color(0xFFFFFAF0)]
              : const [Color(0xFFEAF8EE), Color(0xFFF3FCF6)],
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
            child: Icon(
              pending ? Icons.cloud_upload_outlined : Icons.cloud_done_rounded,
              size: 31,
              color:
                  pending ? const Color(0xFFF0A126) : const Color(0xFF35B779),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending
                      ? '${_entries(waiting)} waiting to sync'
                      : 'Everything is synced',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF293540),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  pending
                      ? 'They will be sent automatically when the '
                          'connection is back.'
                      : 'You can keep logging without internet; entries '
                          'are kept here until they can be sent.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF6F7780),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncCard(int waiting) {
    final syncing = _queue.isSyncing;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.sync_rounded, color: Color(0xFF168AF7)),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync now',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Send the waiting entries to your account.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xFF5F7489),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: syncing || waiting == 0 ? null : _syncNow,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(92, 42),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: const Color(0xFF168AF7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: syncing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sync',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF718096),
            size: 21,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'New glucose, insulin, meal and activity entries made without '
              'internet are stored encrypted on this phone. Sending one twice '
              'never creates a duplicate. Editing or deleting older entries '
              'still needs a connection.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Color(0xFF667586),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingLogCard extends StatelessWidget {
  const _PendingLogCard({required this.log, required this.onDiscard});

  final PendingLog log;
  final VoidCallback onDiscard;

  (IconData, Color, Color) get _style => switch (log.resource) {
        'glucose-logs' => (
            Icons.water_drop_rounded,
            const Color(0xFFE95D76),
            const Color(0xFFFFEEF1),
          ),
        'insulin-logs' => (
            Icons.medication_rounded,
            const Color(0xFF765BD4),
            const Color(0xFFF0ECFF),
          ),
        'meal-logs' => (
            Icons.restaurant_rounded,
            const Color(0xFFF0A126),
            const Color(0xFFFFF3DF),
          ),
        _ => (
            Icons.directions_run_rounded,
            const Color(0xFF35B779),
            const Color(0xFFEAF8EE),
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = _style;
    final at = log.happenedAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 13, 4, 13),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log.kindLabel} • ${log.valueLabel}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    log.error != null
                        ? 'Not saved: ${log.error}'
                        : at == null
                            ? 'Waiting to sync'
                            : '${formatRelativeDay(at)} • waiting to sync',
                    style: TextStyle(
                      fontSize: 11,
                      color: log.error != null
                          ? const Color(0xFFE85D75)
                          : const Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Discard',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFF9AA8B7),
              ),
              onPressed: onDiscard,
            ),
          ],
        ),
      ),
    );
  }
}
