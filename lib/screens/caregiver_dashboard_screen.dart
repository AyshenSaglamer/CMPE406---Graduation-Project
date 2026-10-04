import 'package:flutter/material.dart';

import '../models/family_member.dart';
import 'add_family_member_screen.dart';
import 'role_selection_screen.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState
    extends State<CaregiverDashboardScreen> {
  final List<FamilyMember> familyMembers = [];

  int selectedIndex = 0;

  // ------------------------------------------------------------
  // ADD FAMILY MEMBER
  // ------------------------------------------------------------

  Future<void> _addFamilyMember() async {
    final member = await Navigator.push<FamilyMember>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddFamilyMemberScreen(),
      ),
    );

    if (member != null) {
      setState(() {
        familyMembers.add(member);
      });
    }
  }

  // ------------------------------------------------------------
  // OPEN FAMILY MEMBER
  // ------------------------------------------------------------

  void _openFamilyMember(FamilyMember member) {
    _showFeatureMessage(
      '${member.name} profile will open here.',
    );
  }

  // ------------------------------------------------------------
  // MESSAGE
  // ------------------------------------------------------------

  void _showFeatureMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

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
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
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

  // ------------------------------------------------------------
  // CURRENT PAGE
  // ------------------------------------------------------------

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

  // ============================================================
  // HOME PAGE
  // ============================================================

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        18,
        14,
        18,
        26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 18),

          _buildOverviewCard(),

          const SizedBox(height: 22),

          const Text(
            'Family Members',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          // ------------------------------------------------------
          // HOME'DA SADECE ÜYELER GÖSTERİLİYOR.
          // ADD FAMILY MEMBER BUTONU YOK.
          // ------------------------------------------------------

          if (familyMembers.isEmpty)
            _EmptyFamilyCard()
          else
            ...familyMembers.map(
              (member) => Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: _FamilyMemberCard(
                  member: member,
                  onTap: () => _openFamilyMember(member),
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

  // ============================================================
  // HEADER
  // ============================================================

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

  // ============================================================
  // OVERVIEW CARD
  // ============================================================

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
              color: Colors.white.withValues(
                alpha: 0.78,
              ),
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
              color: Colors.white.withValues(
                alpha: 0.78,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${familyMembers.length} '
              '${familyMembers.length == 1 ? 'member' : 'members'}',
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

  // ============================================================
  // FAMILY INSIGHT
  // ============================================================

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

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

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
            // --------------------------------------------------
            // REMINDERS
            // --------------------------------------------------

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

            // --------------------------------------------------
            // REPORTS
            // --------------------------------------------------

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

  // ============================================================
  // FAMILY PAGE
  // ============================================================

  Widget _buildFamilyPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        30,
      ),
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

          if (familyMembers.isEmpty)
            _EmptyFamilyCard()
          else
            ...familyMembers.map(
              (member) => Padding(
                padding: const EdgeInsets.only(
                  bottom: 12,
                ),
                child: _FamilyMemberCard(
                  member: member,
                  onTap: () => _openFamilyMember(member),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ----------------------------------------------------
          // TEK ADD FAMILY MEMBER BUTONU SADECE BURADA
          // ----------------------------------------------------

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _addFamilyMember,
              icon: const Icon(
                Icons.add_rounded,
              ),
              label: const Text(
                'Add Family Member',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF765BD4),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REMINDERS
  // ============================================================

  Widget _buildReminderPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        30,
      ),
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

        const _FamilyReminderCard(
          time: '08:00',
          title: 'Morning glucose check',
          subtitle: 'Family Member',
          enabled: true,
        ),

        const _FamilyReminderCard(
          time: '12:30',
          title: 'Medication',
          subtitle: 'Family Member',
          enabled: true,
        ),

        const _FamilyReminderCard(
          time: '20:00',
          title: 'Evening glucose check',
          subtitle: 'Family Member',
          enabled: false,
        ),
      ],
    );
  }

  // ============================================================
  // MORE
  // ============================================================

  Widget _buildMorePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        30,
      ),
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
          subtitle: 'Manage family profiles',
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

// ============================================================================
// FAMILY MEMBER CARD
// ============================================================================

class _FamilyMemberCard extends StatelessWidget {
  final FamilyMember member;
  final VoidCallback onTap;

  const _FamilyMemberCard({
    required this.member,
    required this.onTap,
  });

  IconData _getIcon() {
    switch (member.relationship) {
      case 'Mother':
        return Icons.woman_rounded;

      case 'Father':
        return Icons.man_rounded;

      case 'Spouse':
        return Icons.favorite_rounded;

      case 'Sibling':
        return Icons.people_rounded;

      case 'Child':
        return Icons.child_care_rounded;

      default:
        return Icons.person_rounded;
    }
  }

  Color _getIconColor() {
    switch (member.relationship) {
      case 'Mother':
        return const Color(0xFFE85D9E);

      case 'Father':
        return const Color(0xFF168AF7);

      case 'Spouse':
        return const Color(0xFFE85D75);

      case 'Sibling':
        return const Color(0xFF765BD4);

      case 'Child':
        return const Color(0xFF168AF7);

      default:
        return const Color(0xFF667085);
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _getIconColor();

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
                  color: iconColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  _getIcon(),
                  color: iconColor,
                  size: 30,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      member.relationship,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      member.gender,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A97A5),
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

// ============================================================================
// EMPTY FAMILY CARD
// ============================================================================

class _EmptyFamilyCard extends StatelessWidget {
  const _EmptyFamilyCard();

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
                color: const Color(0xFFF0ECFF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                size: 38,
                color: Color(0xFF765BD4),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'No family members added yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Add a family member to start managing '
              'their health information.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF718096),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// QUICK ACTION CARD
// ============================================================================

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

// ============================================================================
// REMINDER CARD
// ============================================================================

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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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

// ============================================================================
// MORE OPTION
// ============================================================================

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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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