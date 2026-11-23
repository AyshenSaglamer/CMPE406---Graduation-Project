import 'package:flutter/material.dart';

import '../utils/form_helpers.dart';

/// Tappable date and time row. Only past times can be picked, because the
/// backend rejects times in the future.
class DateTimeTile extends StatelessWidget {
  const DateTimeTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.accentColor = const Color(0xFF168AF7),
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final Color accentColor;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: value.isAfter(now) ? now : value,
      firstDate: now.subtract(const Duration(days: 90)),
      lastDate: now,
    );

    if (date == null || !context.mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );

    if (time == null) {
      return;
    }

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final latest = DateTime.now();

    onChanged(picked.isAfter(latest) ? latest : picked);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3EAF1)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  formatDateTime(value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA8B7)),
            ],
          ),
        ),
      ),
    );
  }
}
