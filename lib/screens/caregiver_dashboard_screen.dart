import 'package:flutter/material.dart';

import '../models/child_profile.dart';
import 'add_child_screen.dart';
import 'child_profile_screen.dart';
import 'role_selection_screen.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState
    extends State<CaregiverDashboardScreen> {
  final List<ChildProfile> children = [];

  int selectedIndex = 0;

  Future<void> _addChild() async {
    final child = await Navigator.push<ChildProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddChildScreen(),
      ),
    );

    if (child != null) {
      setState(() {
        children.add(child);
      });
    }
  }

  void _openChild(ChildProfile child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChildProfileScreen(
          child: child,
        ),
      ),
    );
  }

  void _showFeatureMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Log out?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to log out of DiaMate?',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const RoleSelectionScreen(),
                  ),
                  (route) => false,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE85D75),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        height: 76,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F3FF),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Family',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_rounded),
            selectedIcon: Icon(Icons.notifications_rounded),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (selectedIndex) {
      case 0:
        return _buildHomePage();

      case 1:
        return _buildFamilyPage();

      case 2:
        return _buildReminderPage();

      case 3:
        return _buildMorePage();

      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 18),

          _buildOverviewCard(),

          const SizedBox(height: 22),

          const Text(
            'My Children',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          if (children.isEmpty)
            _EmptyChildrenCard(
              onAddChild: _addChild,
            )
          else
            ...children.map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChildCard(
                  child: child,
                  onTap: () => _openChild(child),
                ),
              ),
            ),

          const SizedBox(height: 12),

          _buildFamilyInsight(),

          const SizedBox(height: 18),

          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF0ECFF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.family_restroom_rounded,
            color: Color(0xFF765BD4),
            size: 26,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello 👋',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Keep your family health on track.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF718096),
                ),
              ),
            ],
          ),
        ),

        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFE3EAF1),
            ),
          ),
          child: IconButton(
            onPressed: () {
              _showFeatureMessage(
                'Profile settings will be available here.',
              );
            },
            icon: const Icon(
              Icons.person_outline_rounded,
              size: 21,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFECE6FF),
            Color(0xFFF7F3FF),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFF765BD4),
              size: 29,
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Family Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Stay informed about your family members.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF71657C),
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
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${children.length} ${children.length == 1 ? 'child' : 'children'}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF675A78),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyInsight() {
    return Card(
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
                Icons.check_circle_outline_rounded,
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
                    'Family Status',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF718096),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Everything looks up to date.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'No new alerts need your attention.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _CaregiverActionCard(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Add Child',
                background: const Color(0xFFEAF5FF),
                iconColor: const Color(0xFF168AF7),
                onTap: _addChild,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _CaregiverActionCard(
                icon: Icons.notifications_active_outlined,
                title: 'Reminders',
                background: const Color(0xFFFFF3DF),
                iconColor: const Color(0xFFF0A126),
                onTap: () {
                  setState(() {
                    selectedIndex = 2;
                  });
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _CaregiverActionCard(
                icon: Icons.analytics_outlined,
                title: 'Reports',
                background: const Color(0xFFF0ECFF),
                iconColor: const Color(0xFF765BD4),
                onTap: () {
                  _showFeatureMessage(
                    'Family reports will be available here.',
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFamilyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Family',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Manage your family members.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF718096),
            ),
          ),

          const SizedBox(height: 20),

          if (children.isEmpty)
            _EmptyChildrenCard(
              onAddChild: _addChild,
            )
          else
            ...children.map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ChildCard(
                  child: child,
                  onTap: () => _openChild(child),
                ),
              ),
            ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            height: 54,
          ),
        ],
      ),
    );
  }

  Widget _buildReminderPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
      children: [
        const Text(
          'Reminders',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Stay informed about important health reminders.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF718096),
          ),
        ),

        const SizedBox(height: 20),

        _FamilyReminderCard(
          time: '08:00',
          title: 'Morning glucose check',
          subtitle: 'Emma',
          enabled: true,
        ),

        _FamilyReminderCard(
          time: '12:30',
          title: 'Insulin',
          subtitle: 'Emma',
          enabled: true,
        ),

        _FamilyReminderCard(
          time: '20:00',
          title: 'Evening glucose check',
          subtitle: 'Emma',
          enabled: false,
        ),
      ],
    );
  }

  Widget _buildMorePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
      children: [
        const Text(
          'More',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Manage your caregiver tools.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF718096),
          ),
        ),

        const SizedBox(height: 20),

        _MoreOption(
          icon: Icons.people_outline_rounded,
          title: 'Family Members',
          subtitle: 'Manage children and profiles',
          onTap: () {
            setState(() {
              selectedIndex = 1;
            });
          },
        ),

        _MoreOption(
          icon: Icons.security_outlined,
          title: 'Privacy & Security',
          subtitle: 'Manage account security settings',
          onTap: () {
            _showFeatureMessage(
              'Privacy settings will be available here.',
            );
          },
        ),

        _MoreOption(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Customize your DiaMate experience',
          onTap: () {
            _showFeatureMessage(
              'Settings will be available here.',
            );
          },
        ),

        const SizedBox(height: 4),

        _MoreOption(
          icon: Icons.logout_rounded,
          title: 'Log Out',
          subtitle: 'Sign out of your DiaMate account',
          iconColor: const Color(0xFFE85D75),
          background: const Color(0xFFFFEFF1),
          onTap: _showLogoutDialog,
        ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  final ChildProfile child;
  final VoidCallback onTap;

  const _ChildCard({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  color: Color(0xFF168AF7),
                  size: 30,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      child.diabetesType,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Row(
                      children: [
                        Icon(
                          Icons.water_drop_rounded,
                          size: 14,
                          color: Color(0xFF168AF7),
                        ),
                        SizedBox(width: 4),
                        Text(
                          '112 mg/dL',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '• Today 08:30',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8A97A5),
                          ),
                        ),
                      ],
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

class _EmptyChildrenCard extends StatelessWidget {
  final VoidCallback onAddChild;

  const _EmptyChildrenCard({
    required this.onAddChild,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 22,
          vertical: 26,
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.child_care_rounded,
                size: 38,
                color: Color(0xFF168AF7),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'No children added yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Add a child to start managing their health information.',
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
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddChild,
                icon: const Icon(
                  Icons.add_rounded,
                  size: 20,
                ),
                label: const Text(
                  'Add Child',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaregiverActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  const _CaregiverActionCard({
    required this.icon,
    required this.title,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 7,
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
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

              const SizedBox(height: 8),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyReminderCard extends StatelessWidget {
  final String time;
  final String title;
  final String subtitle;
  final bool enabled;

  const _FamilyReminderCard({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
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
                color: enabled
                    ? const Color(0xFFFFF3DF)
                    : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                color: enabled
                    ? const Color(0xFFF0A126)
                    : const Color(0xFF98A1AC),
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
                      color: Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),

            Text(
              time,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color background;

  const _MoreOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = const Color(0xFF168AF7),
    this.background = const Color(0xFFEAF5FF),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
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