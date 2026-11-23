import 'package:flutter/material.dart';

import '../data/care_store.dart';
import '../services/api_exception.dart';
import '../utils/form_helpers.dart';

/// For a doctor or caregiver: the patients who invited them. Accept to see
/// the patient's data (they then appear in the patient list), or decline.
class CareInvitationsScreen extends StatefulWidget {
  const CareInvitationsScreen({super.key, this.store});

  /// Defaults to [careStore]; tests pass one with a fake backend.
  final CareStore? store;

  @override
  State<CareInvitationsScreen> createState() => _CareInvitationsScreenState();
}

class _CareInvitationsScreenState extends State<CareInvitationsScreen> {
  static const _muted = Color(0xFF718096);

  List<CareRelationship> invitations = [];
  bool isLoading = true;
  String? loadError;

  /// Ids being accepted or declined right now.
  final Set<int> busy = {};

  /// Whether anything was accepted, so the caller reloads its patient list.
  bool _accepted = false;

  CareStore get _store => widget.store ?? careStore;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await _store.pendingInvitations();

      if (!mounted) {
        return;
      }

      setState(() {
        invitations = result;
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

  Future<void> _answer(CareRelationship invitation, bool accept) async {
    setState(() {
      busy.add(invitation.id);
    });

    try {
      if (accept) {
        await _store.accept(invitation.id);
        _accepted = true;
      } else {
        await _store.decline(invitation.id);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        busy.remove(invitation.id);
        invitations.removeWhere((i) => i.id == invitation.id);
      });

      final name = _patientName(invitation);
      _showMessage(
        accept
            ? 'You can now follow $name.'
            : 'Invitation from $name declined.',
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        busy.remove(invitation.id);
      });

      _showMessage(e.message);
      // Already answered elsewhere, or withdrawn by the patient.
      if (e.statusCode == 404 || e.statusCode == 409) {
        _load();
      }
    }
  }

  static String _patientName(CareRelationship r) =>
      r.patientName.isEmpty ? 'this patient' : r.patientName;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.pop(context, _accepted);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        appBar: AppBar(
          title: const Text('Invitations'),
          backgroundColor: Colors.white,
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
            children: [
              const Text(
                'Patients who want to share their health data with you.',
                style: TextStyle(fontSize: 13, color: _muted),
              ),
              const SizedBox(height: 16),
              ..._buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (isLoading && invitations.isEmpty) {
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

    if (invitations.isEmpty) {
      return const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Text(
              'No open invitations. A patient can invite you from '
              'More → Care Team in their app, using your account email.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4, color: _muted),
            ),
          ),
        ),
      ];
    }

    return [
      for (final invitation in invitations)
        _InvitationCard(
          invitation: invitation,
          isBusy: busy.contains(invitation.id),
          onAccept: () => _answer(invitation, true),
          onDecline: () => _answer(invitation, false),
        ),
    ];
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.isBusy,
    required this.onAccept,
    required this.onDecline,
  });

  final CareRelationship invitation;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final r = invitation;

    final shared = [
      if (r.canViewGlucose) 'glucose',
      if (r.canViewMeals) 'meals',
      if (r.canViewMedications) 'insulin',
      if (r.canViewActivity) 'activity',
      if (r.canReceiveAlerts) 'alerts',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFEAF5FF),
                  child: Icon(Icons.person_rounded, color: Color(0xFF168AF7)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.patientName.isEmpty ? 'A patient' : r.patientName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (r.invitedAt != null)
                        Text(
                          'Invited ${formatRelativeDay(r.invitedAt!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A97A5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (shared.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Shares: ${shared.join(', ')}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64788B)),
              ),
            ],
            if (r.expiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Until ${formatDateTime(r.expiresAt!)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64788B)),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: isBusy ? null : onDecline,
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isBusy ? null : onAccept,
                  child: Text(isBusy ? 'Please wait…' : 'Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
