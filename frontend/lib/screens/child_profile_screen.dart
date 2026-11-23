import 'package:flutter/material.dart';

import '../models/child_profile.dart';

class ChildProfileScreen extends StatelessWidget {
  final ChildProfile child;

  const ChildProfileScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Child Profile'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),

            const SizedBox(height: 22),

            const Text(
              "Today's Overview",
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.water_drop_rounded,
                    iconColor: const Color(0xFFE95D76),
                    background: const Color(0xFFFFEEF1),
                    title: 'Glucose',
                    value: '112',
                    unit: 'mg/dL',
                    footer: 'Normal',
                    footerColor: const Color(0xFF35A96B),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.medication_rounded,
                    iconColor: const Color(0xFF765BD4),
                    background: const Color(0xFFF0ECFF),
                    title: 'Insulin',
                    value: '6',
                    unit: 'units',
                    footer: 'Today',
                    footerColor: const Color(0xFF765BD4),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.restaurant_rounded,
                    iconColor: const Color(0xFFF0A126),
                    background: const Color(0xFFFFF2E2),
                    title: 'Meals',
                    value: '3',
                    unit: 'today',
                    footer: 'On track',
                    footerColor: const Color(0xFFF0A126),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.directions_run_rounded,
                    iconColor: const Color(0xFF35B779),
                    background: const Color(0xFFEAF8EE),
                    title: 'Activity',
                    value: '30',
                    unit: 'min',
                    footer: 'Good',
                    footerColor: const Color(0xFF35B779),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            const Text(
              'Health Status',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF8EE),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF35B779),
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Looking good',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'No unusual readings detected today.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF718096),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 22),

            const Text(
              'Recent Records',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 12),

            _RecentRecord(
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFFE95D76),
              background: const Color(0xFFFFEEF1),
              title: 'Blood Glucose',
              subtitle: 'Today • 08:30',
              value: '112 mg/dL',
            ),

            const SizedBox(height: 10),

            _RecentRecord(
              icon: Icons.medication_rounded,
              iconColor: const Color(0xFF765BD4),
              background: const Color(0xFFF0ECFF),
              title: 'Insulin',
              subtitle: 'Today • 12:30',
              value: '6 units',
            ),

            const SizedBox(height: 10),

            _RecentRecord(
              icon: Icons.directions_run_rounded,
              iconColor: const Color(0xFF35B779),
              background: const Color(0xFFEAF8EE),
              title: 'Walking',
              subtitle: 'Yesterday • 18:00',
              value: '30 min',
            ),

            const SizedBox(height: 22),

            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 12),

            _ActionCard(
              icon: Icons.show_chart_rounded,
              title: 'Glucose History',
              subtitle: 'View blood glucose trends and measurements.',
              background: const Color(0xFFEAF5FF),
              iconColor: const Color(0xFF168AF7),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Glucose history will be available here.',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            _ActionCard(
              icon: Icons.notifications_none_rounded,
              title: 'Manage Reminders',
              subtitle: 'View and manage this child’s reminders.',
              background: const Color(0xFFFFF3DF),
              iconColor: const Color(0xFFF0A126),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Reminder management will be available here.',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            _ActionCard(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Health Report',
              subtitle: 'Generate a health summary report.',
              background: const Color(0xFFF0ECFF),
              iconColor: const Color(0xFF765BD4),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Health report will be available here.',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDFF1FF),
            Color(0xFFF0F9FF),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.child_care_rounded,
              color: Color(0xFF168AF7),
              size: 40,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172033),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  child.diabetesType,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64788B),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Date of birth: ${child.dateOfBirth}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String title;
  final String value;
  final String unit;
  final String footer;
  final Color footerColor;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.title,
    required this.value,
    required this.unit,
    required this.footer,
    required this.footerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 21,
              ),
            ),

            const SizedBox(height: 11),

            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF718096),
              ),
            ),

            const SizedBox(height: 4),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF718096),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              footer,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: footerColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentRecord extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String title;
  final String subtitle;
  final String value;

  const _RecentRecord({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 21,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),

            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9AA8B7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}