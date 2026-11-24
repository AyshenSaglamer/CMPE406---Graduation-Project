import 'package:flutter/material.dart';

import '../data/care_patients_store.dart';
import '../data/reminder_store.dart';
import '../services/api_exception.dart';

/// Reminders tab of the caregiver: today's reminders of every family member
/// who shares medications, with what they answered (Taken / Skipped /
/// Missed), and each member's reminder plan below.
///
/// Read only: the patient creates and answers reminders in their own app.
class CareRemindersView extends StatefulWidget {
  const CareRemindersView({
    super.key,
    required this.members,
    this.membersLoading = false,
    this.storeFor,
    this.now,
  });

  /// Accepted family members (from the dashboard).
  final List<CarePatient> members;
  final bool membersLoading;

  /// Defaults to a [ReminderStore] for that patient; tests pass fakes.
  final ReminderStore Function(int patientId)? storeFor;

  /// Defaults to [DateTime.now]; tests fix the time.
  final DateTime Function()? now;

  @override
  State<CareRemindersView> createState() => _CareRemindersViewState();
}

/// One member's reminders and today's answers, or why they are missing.
class _MemberReminders {
  final CarePatient member;
  final List<Reminder> reminders;
  final List<ReminderAnswer> answers;
  final String? error;

  const _MemberReminders(
    this.member, {
    this.reminders = const [],
    this.answers = const [],
    this.error,
  });
}

/// One reminder ringing today for one member.
class _TodayItem {
  final CarePatient member;
  final Reminder reminder;
  final DateTime at;
  final ReminderAnswer? answer;

  const _TodayItem(this.member, this.reminder, this.at, this.answer);
}

class _CareRemindersViewState extends State<CareRemindersView> {
  List<_MemberReminders>? loaded;
  bool loading = false;

  DateTime _now() => (widget.now ?? DateTime.now)();

  List<CarePatient> get _sharing =>
      widget.members.where((m) => m.canViewMedications).toList();

  List<CarePatient> get _notSharing =>
      widget.members.where((m) => !m.canViewMedications).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CareRemindersView old) {
    super.didUpdateWidget(old);
    final before = old.members.map((m) => m.id).join(',');
    final after = widget.members.map((m) => m.id).join(',');
    if (before != after) {
      _load();
    }
  }

  Future<void> _load() async {
    final members = _sharing;
    if (members.isEmpty) {
      setState(() => loaded = const []);
      return;
    }

    setState(() => loading = true);

    final now = _now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final results = await Future.wait([
      for (final member in members)
        _loadMember(member, dayStart, dayEnd),
    ]);

    if (!mounted) {
      return;
    }
    setState(() {
      loaded = results;
      loading = false;
    });
  }

  Future<_MemberReminders> _loadMember(
    CarePatient member,
    DateTime from,
    DateTime to,
  ) async {
    final store =
        widget.storeFor?.call(member.id) ?? ReminderStore(patientId: member.id);
    try {
      final reminders = await store.list();
      final answers = await store.answers(from: from, to: to);
      return _MemberReminders(member, reminders: reminders, answers: answers);
    } on ApiException catch (e) {
      return _MemberReminders(member, error: e.message);
    }
  }

  List<_TodayItem> _today(List<_MemberReminders> data) {
    final now = _now();
    final items = <_TodayItem>[];
    for (final m in data) {
      for (final r in m.reminders) {
        final at = r.occurrenceOn(now);
        if (at == null) {
          continue;
        }
        ReminderAnswer? answer;
        for (final a in m.answers) {
          if (a.isFor(r.id!, at)) {
            answer = a;
          }
        }
        items.add(_TodayItem(m.member, r, at, answer));
      }
    }
    items.sort((a, b) => a.at.compareTo(b.at));
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final data = loaded;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
        children: [
          const Text(
            'Reminders',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            "Your family members' reminders and whether they were taken.",
            style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
          ),
          const SizedBox(height: 20),
          ..._body(data),
        ],
      ),
    );
  }

  List<Widget> _body(List<_MemberReminders>? data) {
    if (widget.membersLoading || loading || data == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (widget.members.isEmpty) {
      return const [
        _InfoCard(
          icon: Icons.group_add_outlined,
          text: 'No family members yet. When a patient invites you and you '
              'accept under Invitations, their reminders show here.',
        ),
      ];
    }

    final today = _today(data);
    final widgets = <Widget>[
      const _SectionTitle('Today'),
      if (_sharing.isEmpty)
        const _InfoCard(
          icon: Icons.lock_outline_rounded,
          text: 'Your family members do not share their medications and '
              'reminders with you.',
        )
      else if (today.isEmpty)
        const _InfoCard(
          icon: Icons.event_available_outlined,
          text: 'No reminders today.',
        )
      else
        for (final item in today)
          _FamilyReminderCard(
            time: item.reminder.timeText,
            title: item.reminder.title,
            subtitle: [
              if (widget.members.length > 1) item.member.name,
              if (item.reminder.typeLabel != item.reminder.title)
                item.reminder.typeLabel,
              if (item.reminder.dosage?.isNotEmpty ?? false)
                item.reminder.dosage!,
            ].join(' • '),
            status: _statusOf(item),
          ),
    ];

    for (final m in data) {
      widgets.add(const SizedBox(height: 18));
      widgets.add(_SectionTitle("${m.member.name}'s plan"));
      if (m.error != null) {
        widgets.add(_InfoCard(
          icon: Icons.error_outline_rounded,
          text: 'Could not load the reminders: ${m.error}',
        ));
      } else if (m.reminders.isEmpty) {
        widgets.add(const _InfoCard(
          icon: Icons.notifications_off_outlined,
          text: 'No reminders set up yet.',
        ));
      } else {
        for (final r in [...m.reminders]
          ..sort((a, b) => (a.hour * 60 + a.minute)
              .compareTo(b.hour * 60 + b.minute))) {
          widgets.add(_FamilyReminderCard(
            time: r.timeText,
            title: r.title,
            subtitle: [
              r.daysText,
              if (r.dosage != null && r.dosage!.isNotEmpty) r.dosage!,
            ].join(' • '),
            status: r.active ? null : _Status.paused,
          ));
        }
      }
    }

    if (_notSharing.isNotEmpty) {
      widgets.add(const SizedBox(height: 18));
      widgets.add(_InfoCard(
        icon: Icons.lock_outline_rounded,
        text: '${_notSharing.map((m) => m.name).join(', ')} '
            '${_notSharing.length == 1 ? 'does' : 'do'} not share '
            'medications and reminders with you.',
      ));
    }

    return widgets;
  }

  _Status _statusOf(_TodayItem item) {
    switch (item.answer?.status) {
      case ReminderAnswer.taken:
        return _Status.taken;
      case ReminderAnswer.skipped:
        return _Status.skipped;
      case ReminderAnswer.missed:
        return _Status.missed;
    }
    return item.at.isAfter(_now()) ? _Status.upcoming : _Status.noAnswer;
  }
}

enum _Status {
  taken('Taken', Color(0xFFEAF8EE), Color(0xFF2D8758)),
  skipped('Skipped', Color(0xFFF1F3F5), Color(0xFF5F6E7D)),
  missed('Missed', Color(0xFFFFEEF1), Color(0xFFBA4A61)),
  upcoming('Upcoming', Color(0xFFEAF5FF), Color(0xFF168AF7)),
  noAnswer('No answer yet', Color(0xFFFFF3DF), Color(0xFFB7791F)),
  paused('Paused', Color(0xFFF1F3F5), Color(0xFF98A1AC));

  const _Status(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: const Color(0xFF168AF7)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF4A5D70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyReminderCard extends StatelessWidget {
  const _FamilyReminderCard({
    required this.time,
    required this.title,
    required this.subtitle,
    this.status,
  });

  final String time;
  final String title;
  final String subtitle;
  final _Status? status;

  @override
  Widget build(BuildContext context) {
    final muted = status == _Status.paused;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: muted
                    ? const Color(0xFFF1F3F5)
                    : const Color(0xFFFFF3DF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                color: muted
                    ? const Color(0xFF98A1AC)
                    : const Color(0xFFF0A126),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status!.background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      status!.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: status!.foreground,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
