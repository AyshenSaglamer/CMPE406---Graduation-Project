import 'package:flutter/material.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final List<ReminderItem> reminders = [
    ReminderItem(
      title: 'Blood glucose measurement',
      time: '08:00',
      category: 'Blood Glucose',
      enabled: true,
      icon: Icons.water_drop_rounded,
      iconColor: const Color(0xFFE95D76),
      background: const Color(0xFFFFEEF1),
    ),
    ReminderItem(
      title: 'Insulin',
      time: '12:30',
      category: 'Medication',
      enabled: true,
      icon: Icons.medication_rounded,
      iconColor: const Color(0xFF765BD4),
      background: const Color(0xFFF0ECFF),
    ),
    ReminderItem(
      title: 'Evening blood glucose',
      time: '20:00',
      category: 'Blood Glucose',
      enabled: false,
      icon: Icons.water_drop_rounded,
      iconColor: const Color(0xFF168AF7),
      background: const Color(0xFFEAF5FF),
    ),
  ];

  Future<void> _addReminder() async {
    final result = await showDialog<ReminderItem>(
      context: context,
      builder: (_) => const _AddReminderDialog(),
    );

    if (result != null) {
      setState(() {
        reminders.add(result);
      });
    }
  }

  void _deleteReminder(int index) {
    setState(() {
      reminders.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Reminder deleted.',
        ),
      ),
    );
  }

  void _toggleReminder(int index, bool value) {
    setState(() {
      reminders[index].enabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCount =
        reminders.where((reminder) => reminder.enabled).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Reminders'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(activeCount),

            const SizedBox(height: 22),

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
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 19,
                  ),
                  label: const Text(
                    'Add',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            if (reminders.isEmpty)
              _buildEmptyState()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reminders.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(height: 10);
                },
                itemBuilder: (context, index) {
                  final reminder = reminders[index];

                  return Dismissible(
                    key: ValueKey(
                      '${reminder.title}_$index',
                    ),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(
                        right: 20,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8EC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFE95D76),
                      ),
                    ),
                    onDismissed: (_) {
                      _deleteReminder(index);
                    },
                    child: _ReminderCard(
                      reminder: reminder,
                      onChanged: (value) {
                        _toggleReminder(index, value);
                      },
                    ),
                  );
                },
              ),

            const SizedBox(height: 22),

            _buildInfoCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addReminder,
        backgroundColor: const Color(0xFF168AF7),
        foregroundColor: Colors.white,
        elevation: 3,
        child: const Icon(
          Icons.add_rounded,
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
          colors: [
            Color(0xFFFFF3DF),
            Color(0xFFFFF9EF),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
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
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF806F5D),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 30,
        ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Create a reminder for glucose checks, insulin, or other important activities.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF718096),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _addReminder,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 20,
                ),
                label: const Text(
                  'Create Reminder',
                ),
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
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF168AF7),
            size: 21,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reminders can help you keep track of regular health routines and medication schedules.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Color(0xFF5F7489),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final ReminderItem reminder;
  final ValueChanged<bool> onChanged;

  const _ReminderCard({
    required this.reminder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: reminder.enabled
                    ? reminder.background
                    : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                reminder.icon,
                color: reminder.enabled
                    ? reminder.iconColor
                    : const Color(0xFF99A3AE),
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
                      color: reminder.enabled
                          ? const Color(0xFF172033)
                          : const Color(0xFF8A97A5),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Text(
                        reminder.time,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: reminder.enabled
                              ? reminder.iconColor
                              : const Color(0xFF8A97A5),
                        ),
                      ),

                      const SizedBox(width: 7),

                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: reminder.enabled
                              ? reminder.iconColor
                              : const Color(0xFFB0B8C0),
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(width: 7),

                      Text(
                        reminder.category,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Switch.adaptive(
              value: reminder.enabled,
              activeColor: reminder.iconColor,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class ReminderItem {
  String title;
  String time;
  String category;
  bool enabled;
  IconData icon;
  Color iconColor;
  Color background;

  ReminderItem({
    required this.title,
    required this.time,
    required this.category,
    required this.enabled,
    required this.icon,
    required this.iconColor,
    required this.background,
  });
}

class _AddReminderDialog extends StatefulWidget {
  const _AddReminderDialog();

  @override
  State<_AddReminderDialog> createState() =>
      _AddReminderDialogState();
}

class _AddReminderDialogState
    extends State<_AddReminderDialog> {
  final nameController = TextEditingController();

  TimeOfDay? selectedTime;

  String selectedCategory = 'Blood Glucose';

  final List<String> categories = [
    'Blood Glucose',
    'Medication',
    'Meal',
    'Activity',
  ];

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  Color get categoryColor {
    switch (selectedCategory) {
      case 'Medication':
        return const Color(0xFF765BD4);
      case 'Meal':
        return const Color(0xFFF0A126);
      case 'Activity':
        return const Color(0xFF35B779);
      default:
        return const Color(0xFFE95D76);
    }
  }

  Color get categoryBackground {
    switch (selectedCategory) {
      case 'Medication':
        return const Color(0xFFF0ECFF);
      case 'Meal':
        return const Color(0xFFFFF2E2);
      case 'Activity':
        return const Color(0xFFEAF8EE);
      default:
        return const Color(0xFFFFEEF1);
    }
  }

  IconData get categoryIcon {
    switch (selectedCategory) {
      case 'Medication':
        return Icons.medication_rounded;
      case 'Meal':
        return Icons.restaurant_rounded;
      case 'Activity':
        return Icons.directions_run_rounded;
      default:
        return Icons.water_drop_rounded;
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void _save() {
    final name = nameController.text.trim();

    if (name.isEmpty || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a reminder name and select a time.',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      ReminderItem(
        title: name,
        time: _formatTime(selectedTime!),
        category: selectedCategory,
        enabled: true,
        icon: categoryIcon,
        iconColor: categoryColor,
        background: categoryBackground,
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFF7FAFD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(25),
      ),
      title: const Text(
        'New Reminder',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reminder Name',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Blood glucose measurement',
                prefixIcon: const Icon(
                  Icons.edit_outlined,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Color(0xFFE3EAF1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Color(0xFFE3EAF1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Color(0xFF168AF7),
                    width: 1.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Category',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  categoryIcon,
                  color: categoryColor,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Color(0xFFE3EAF1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Color(0xFFE3EAF1),
                  ),
                ),
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  selectedCategory = value;
                });
              },
            ),

            const SizedBox(height: 16),

            const Text(
              'Time',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            InkWell(
              onTap: _selectTime,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFE3EAF1),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Color(0xFF718096),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        selectedTime == null
                            ? 'Select time'
                            : _formatTime(selectedTime!),
                        style: TextStyle(
                          fontSize: 14,
                          color: selectedTime == null
                              ? const Color(0xFFA0ACB8)
                              : const Color(0xFF172033),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF9AA8B7),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        18,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text(
            'Cancel',
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(100, 44),
          ),
          child: const Text(
            'Add Reminder',
          ),
        ),
      ],
    );
  }
}