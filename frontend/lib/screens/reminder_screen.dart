import 'package:flutter/material.dart';

import '../data/reminder_store.dart';
import '../services/api_exception.dart';
import '../services/reminder_notifications.dart';

/// The patient's reminders (medication, glucose check, meal, appointment),
/// saved in the backend and shown as phone notifications. "Today" lists
/// today's reminders; the patient marks each one Taken, Skipped or Missed,
/// which the care team sees as medication adherence.
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key, this.store, this.notifier, this.now});

  /// Default to [reminderStore] and [reminderNotifier]; tests pass fakes.
  final ReminderStore? store;
  final ReminderNotifier? notifier;

  /// For tests; defaults to the clock.
  final DateTime Function()? now;

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  List<Reminder> reminders = [];
  List<ReminderAnswer> todayAnswers = [];
  bool isLoading = true;
  String? loadError;

  /// Reminder ids (and "id@time" for answers) being saved right now.
  final Set<String> busy = {};

  ReminderStore get _store => widget.store ?? reminderStore;
  ReminderNotifier get _notifier => widget.notifier ?? reminderNotifier;
  DateTime _now() => (widget.now ?? DateTime.now)();

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
      final now = _now();
      final start = DateTime(now.year, now.month, now.day);
      final results = await Future.wait([
        _store.list(),
        _store.answers(from: start, to: start.add(const Duration(days: 1))),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        reminders = results[0] as List<Reminder>;
        todayAnswers = results[1] as List<ReminderAnswer>;
        isLoading = false;
      });

      await _reschedule();
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

  /// Keeps the phone's notifications equal to the saved reminders.
  Future<void> _reschedule() async {
    try {
      await _notifier.schedule(reminders);
    } catch (_) {
      // The reminders are saved; only the phone notification is missing.
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addReminder() async {
    final draft = await showDialog<Reminder>(
      context: context,
      builder: (_) => const _ReminderDialog(),
    );

    if (draft == null || !mounted) {
      return;
    }

    final zone = await _notifier.timezone();

    try {
      final created = await _store.create(Reminder(
        type: draft.type,
        medicationName: draft.medicationName,
        dosage: draft.dosage,
        message: draft.message,
        hour: draft.hour,
        minute: draft.minute,
        days: draft.days,
        timezone: zone,
      ));

      if (!mounted) {
        return;
      }

      setState(() {
        reminders = [...reminders, created]..sort(_byTime);
      });

      final allowed = await _notifier.requestPermission();
      await _reschedule();

      if (!mounted) {
        return;
      }

      _showMessage(
        allowed
            ? 'Reminder saved. You will get a notification at ${created.timeText}.'
            : 'Reminder saved. Allow notifications in your phone settings to be reminded.',
      );
    } on ApiException catch (e) {
      if (mounted) {
        _showMessage(e.fieldErrors.values.isNotEmpty ? e.fieldErrors.values.first : e.message);
      }
    }
  }

  static int _byTime(Reminder a, Reminder b) =>
      (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);

  Future<void> _deleteReminder(Reminder reminder) async {
    setState(() {
      reminders = reminders.where((r) => r.id != reminder.id).toList();
    });

    try {
      await _store.delete(reminder.id!);
      await _reschedule();
      if (mounted) {
        _showMessage('Reminder deleted.');
      }
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message);
      _load();
    }
  }

  Future<void> _toggleReminder(Reminder reminder, bool value) async {
    final key = '${reminder.id}';
    setState(() {
      busy.add(key);
    });

    try {
      final updated = await _store.update(reminder.copyWith(active: value));
      if (!mounted) {
        return;
      }
      setState(() {
        busy.remove(key);
        reminders = [for (final r in reminders) r.id == updated.id ? updated : r];
      });
      await _reschedule();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        busy.remove(key);
      });
      _showMessage(e.message);
    }
  }

  Future<void> _answer(Reminder reminder, DateTime at, String status) async {
    final key = '${reminder.id}@$at';
    setState(() {
      busy.add(key);
    });

    try {
      final answer = await _store.answer(reminder.id!, at, status);
      if (!mounted) {
        return;
      }
      setState(() {
        busy.remove(key);
        todayAnswers = [
          ...todayAnswers.where((a) => !a.isFor(reminder.id!, at)),
          answer,
        ];
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        busy.remove(key);
      });
      _showMessage(e.message);
    }
  }

  /// Today's occurrences, earliest first.
  List<(Reminder, DateTime)> get _today {
    final now = _now();
    return [
      for (final r in reminders)
        if (r.occurrenceOn(now) case final at?) (r, at),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = reminders.where((reminder) => reminder.active).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(activeCount),
              const SizedBox(height: 22),
              ..._buildBody(),
              const SizedBox(height: 22),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add reminder',
        onPressed: isLoading || loadError != null ? null : _addReminder,
        backgroundColor: const Color(0xFF168AF7),
        foregroundColor: Colors.white,
        elevation: 3,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  List<Widget> _buildBody() {
    if (isLoading && reminders.isEmpty) {
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

    final today = _today;

    return [
      if (today.isNotEmpty) ...[
        const Text(
          'Today',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF172033),
          ),
        ),
        const SizedBox(height: 8),
        for (final (reminder, at) in today) _buildTodayRow(reminder, at),
        const SizedBox(height: 18),
      ],
      Row(
        children: [
          const Expanded(
            child: Text(
              'Your Reminders',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _addReminder,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Add'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (reminders.isEmpty)
        _buildEmptyState()
      else
        for (final reminder in reminders)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey('reminder_${reminder.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8EC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE95D76),
                ),
              ),
              onDismissed: (_) => _deleteReminder(reminder),
              child: _ReminderCard(
                reminder: reminder,
                isBusy: busy.contains('${reminder.id}'),
                onChanged: (value) => _toggleReminder(reminder, value),
              ),
            ),
          ),
    ];
  }

  Widget _buildTodayRow(Reminder reminder, DateTime at) {
    final answer = todayAnswers.where((a) => a.isFor(reminder.id!, at)).firstOrNull;
    final style = _ReminderStyle.of(reminder.type);
    final due = !at.isAfter(_now().add(const Duration(minutes: 30)));
    final isBusy = busy.contains('${reminder.id}@$at');

    final Widget trailing;
    if (answer != null) {
      final (label, color) = switch (answer.status) {
        ReminderAnswer.taken => ('Taken', const Color(0xFF35B779)),
        ReminderAnswer.skipped => ('Skipped', const Color(0xFF718096)),
        _ => ('Missed', const Color(0xFFE85D75)),
      };
      trailing = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
        ),
      );
    } else if (!due) {
      trailing = const Text(
        'Upcoming',
        style: TextStyle(fontSize: 12, color: Color(0xFF8A97A5)),
      );
    } else {
      trailing = const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(style.icon, color: style.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      Text(
                        [
                          reminder.timeText,
                          if (reminder.dosage != null && reminder.dosage!.isNotEmpty) reminder.dosage!,
                        ].join(' • '),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
            if (answer == null && due)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () => _answer(reminder, at, ReminderAnswer.missed),
                    child: const Text('Missed'),
                  ),
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () => _answer(reminder, at, ReminderAnswer.skipped),
                    child: const Text('Skip'),
                  ),
                  FilledButton(
                    onPressed: isBusy
                        ? null
                        : () => _answer(reminder, at, ReminderAnswer.taken),
                    child: Text(reminder.isMedication ? 'Taken' : 'Done'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(int activeCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3DF), Color(0xFFFFF9EF)],
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
              Icons.notifications_active_rounded,
              color: Color(0xFFF0A126),
              size: 31,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay on track',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF493827),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Keep important health reminders in one place.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF806F5D)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$activeCount active',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8B672E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3DF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 37,
                color: Color(0xFFF0A126),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No reminders yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            const Text(
              'Create a reminder for your medicines, glucose checks, meals or appointments.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF718096)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _addReminder,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create Reminder'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF168AF7), size: 21),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reminders are saved to your account and shown as notifications on '
              'this phone. Your doctor and caregivers who see your medications '
              'can see the plan and whether doses were taken. Swipe left to delete.',
              style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF5F7489)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon and colours per reminder type (the original card colours).
class _ReminderStyle {
  final IconData icon;
  final Color color;
  final Color background;

  const _ReminderStyle(this.icon, this.color, this.background);

  static _ReminderStyle of(String type) => switch (type) {
        Reminder.medication => const _ReminderStyle(
            Icons.medication_rounded, Color(0xFF765BD4), Color(0xFFF0ECFF)),
        Reminder.meal => const _ReminderStyle(
            Icons.restaurant_rounded, Color(0xFFF0A126), Color(0xFFFFF2E2)),
        Reminder.appointment => const _ReminderStyle(
            Icons.event_rounded, Color(0xFF168AF7), Color(0xFFE9F4FF)),
        Reminder.other => const _ReminderStyle(
            Icons.notifications_rounded, Color(0xFF5F6E7D), Color(0xFFF1F4F7)),
        _ => const _ReminderStyle(
            Icons.water_drop_rounded, Color(0xFFE95D76), Color(0xFFFFEEF1)),
      };
}

class _ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final bool isBusy;
  final ValueChanged<bool> onChanged;

  const _ReminderCard({
    required this.reminder,
    required this.isBusy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final style = _ReminderStyle.of(reminder.type);
    final enabled = reminder.active;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: enabled ? style.background : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                style.icon,
                color: enabled ? style.color : const Color(0xFF99A3AE),
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: enabled ? const Color(0xFF172033) : const Color(0xFF8A97A5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        reminder.timeText,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: enabled ? style.color : const Color(0xFF8A97A5),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          [
                            reminder.daysText,
                            if (reminder.dosage != null && reminder.dosage!.isNotEmpty)
                              reminder.dosage!,
                          ].join(' • '),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
                        ),
                      ),
                    ],
                  ),
                  if (reminder.missedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        reminder.missedCount == 1
                            ? 'Missed once'
                            : 'Missed ${reminder.missedCount} times',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFE85D75)),
                      ),
                    ),
                ],
              ),
            ),
            Switch.adaptive(
              value: enabled,
              activeThumbColor: style.color,
              onChanged: isBusy ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// New reminder: type, what (medicine name and dose, or a note), time and
/// days. Returns a [Reminder] without an id; the screen saves it.
class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog();

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  final nameController = TextEditingController();
  final dosageController = TextEditingController();

  String selectedType = Reminder.medication;
  TimeOfDay? selectedTime;
  final Set<int> selectedDays = {1, 2, 3, 4, 5, 6, 7};
  String? error;

  bool get isMedication => selectedType == Reminder.medication;

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  void _save() {
    final name = nameController.text.trim();

    if (isMedication && name.isEmpty) {
      setState(() => error = 'Please enter the medicine name.');
      return;
    }
    if (selectedTime == null) {
      setState(() => error = 'Please select a time.');
      return;
    }
    if (selectedDays.isEmpty) {
      setState(() => error = 'Please choose at least one day.');
      return;
    }

    Navigator.pop(
      context,
      Reminder(
        type: selectedType,
        medicationName: isMedication ? name : null,
        dosage: isMedication ? dosageController.text.trim() : null,
        message: isMedication ? null : name,
        hour: selectedTime!.hour,
        minute: selectedTime!.minute,
        days: Set.of(selectedDays),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE3EAF1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFE3EAF1)),
        ),
      );

  static const _label = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    final style = _ReminderStyle.of(selectedType);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return AlertDialog(
      backgroundColor: const Color(0xFFF7FAFD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      title: const Text(
        'New Reminder',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category', style: _label),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: _decoration('', style.icon).copyWith(
                prefixIcon: Icon(style.icon, color: style.color),
              ),
              items: [
                for (final entry in Reminder.typeLabels.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => selectedType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            Text(isMedication ? 'Medicine' : 'Note', style: _label),
            const SizedBox(height: 7),
            TextField(
              key: const ValueKey('reminder_name'),
              controller: nameController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: isMedication ? 100 : 255,
              decoration: _decoration(
                isMedication ? 'e.g. Metformin' : 'e.g. Before lunch',
                Icons.edit_outlined,
              ),
            ),
            if (isMedication) ...[
              const SizedBox(height: 8),
              const Text('Dose (optional)', style: _label),
              const SizedBox(height: 7),
              TextField(
                key: const ValueKey('reminder_dosage'),
                controller: dosageController,
                maxLength: 50,
                decoration: _decoration('e.g. 500 mg', Icons.medication_outlined),
              ),
            ],
            const SizedBox(height: 8),
            const Text('Time', style: _label),
            const SizedBox(height: 7),
            InkWell(
              onTap: _selectTime,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFE3EAF1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: Color(0xFF718096)),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        selectedTime == null
                            ? 'Select time'
                            : '${selectedTime!.hour.toString().padLeft(2, '0')}:'
                                '${selectedTime!.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedTime == null
                              ? const Color(0xFFA0ACB8)
                              : const Color(0xFF172033),
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9AA8B7)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Days', style: _label),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(dayLetters[day - 1]),
                    tooltip: Reminder.dayNames[day - 1],
                    selected: selectedDays.contains(day),
                    showCheckmark: false,
                    onSelected: (on) => setState(() {
                      on ? selectedDays.add(day) : selectedDays.remove(day);
                    }),
                  ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error!, style: const TextStyle(color: Color(0xFFE85D75), fontSize: 12)),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 44)),
          child: const Text('Add Reminder'),
        ),
      ],
    );
  }
}
