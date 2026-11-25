import 'package:flutter/material.dart';

import '../data/alert_store.dart';
import '../data/care_patients_store.dart';
import '../data/dependent_store.dart';
import '../data/reminder_store.dart';
import '../navigation/session_navigation.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/form_helpers.dart';
import '../utils/greeting.dart';
import 'add_family_member_screen.dart';
import 'alerts_screen.dart';
import 'care_invitations_screen.dart';
import 'care_patient_detail_screen.dart';
import '../widgets/care_reminders_view.dart';

class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({
    super.key,
    this.patientsStore,
    this.reminderStoreFor,
    this.dependentStore,
  });

  /// Defaults to [carePatientsStore]; tests pass one with a fake backend.
  final CarePatientsStore? patientsStore;

  /// Adds and corrects family members without an account; defaults to the
  /// /care-team/dependents API.
  final DependentStore? dependentStore;

  /// Reminders of one family member; defaults to the reminders API.
  final ReminderStore Function(int patientId)? reminderStoreFor;

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState
    extends State<CaregiverDashboardScreen> {
  /// The people who invited this caregiver and were accepted
  /// (GET /care-team/patients + each one's overview).
  List<CarePatient> familyMembers = [];
  bool familyLoading = true;
  String? familyError;

  int selectedIndex = 0;

  /// OPEN alerts of the patients who allow alerts (from the backend).
  /// null while loading or after an error.
  int? openAlertCount;
  String? alertCountError;

  CarePatientsStore get _patientsStore =>
      widget.patientsStore ?? carePatientsStore;

  @override
  void initState() {
    super.initState();
    _loadFamily();
    _loadAlertCount();
  }

  Future<void> _loadFamily() async {
    setState(() {
      familyLoading = true;
      familyError = null;
    });

    try {
      final result = await _patientsStore.load();

      if (!mounted) {
        return;
      }

      setState(() {
        familyMembers = result;
        familyLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        familyLoading = false;
        familyError = e.message;
      });
    }
  }

  Future<void> _refresh() => Future.wait([_loadFamily(), _loadAlertCount()]);

  Future<void> _loadAlertCount() async {
    setState(() {
      openAlertCount = null;
      alertCountError = null;
    });

    try {
      final count = await alertStore.openCareTeamAlertCount();

      if (!mounted) {
        return;
      }

      setState(() {
        openAlertCount = count;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        alertCountError = e.message;
      });
    }
  }

  Future<void> _openAlerts() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AlertsScreen()),
    );

    // Alerts may have been seen or resolved there.
    if (mounted) {
      _loadAlertCount();
    }
  }

  // ------------------------------------------------------------
  // INVITATIONS
  // A family member invites the caregiver from their own app
  // (More -> Care Team); the caregiver accepts here.
  // ------------------------------------------------------------

  Future<void> _openInvitations() async {
    final accepted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CareInvitationsScreen(),
      ),
    );

    if (accepted == true && mounted) {
      _loadFamily();
    }
  }

  // ------------------------------------------------------------
  // ADD / EDIT A FAMILY MEMBER WITHOUT AN ACCOUNT
  // (e.g. a child): the caregiver keeps their diary.
  // ------------------------------------------------------------

  Future<void> _openAddFamilyMember({CarePatient? existing}) async {
    final saved = await Navigator.push<Dependent>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(
          existing: existing,
          store: widget.dependentStore,
        ),
      ),
    );

    if (saved != null && mounted) {
      _loadFamily();
    }
  }

  // ------------------------------------------------------------
  // OPEN FAMILY MEMBER
  // ------------------------------------------------------------

  void _openFamilyMember(CarePatient member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarePatientDetailScreen(patient: member),
      ),
    );
  }

  /// The family cards, or what to show while loading, after an error or
  /// when nobody shares their data yet.
  List<Widget> _buildFamilyCards() {
    if (familyLoading && familyMembers.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (familyError != null) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(familyError!, textAlign: TextAlign.center),
                TextButton(
                  onPressed: _loadFamily,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (familyMembers.isEmpty) {
      return const [_EmptyFamilyCard()];
    }

    return [
      for (final member in familyMembers)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _FamilyMemberCard(
            member: member,
            onTap: () => _openFamilyMember(member),
            onEdit: member.managed
                ? () => _openAddFamilyMember(existing: member)
                : null,
          ),
        ),
    ];
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
                logoutAndReturnToStart(context);
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
    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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

          ..._buildFamilyCards(),

          const SizedBox(height: 12),

          _buildFamilyInsight(),

          const SizedBox(height: 18),

          _buildQuickActions(),
        ],
      ),
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

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greetingFor(authService.currentUser),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
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
    final count = openAlertCount;
    final hasOpen = (count ?? 0) > 0;
    final color = hasOpen
        ? const Color(0xFFE85D75)
        : const Color(0xFF35B779);

    final String title;
    final String subtitle;

    if (alertCountError != null) {
      title = 'Alerts could not be loaded.';
      subtitle = 'Tap to try again.';
    } else if (count == null) {
      title = 'Checking for alerts...';
      subtitle = 'Glucose alerts of the people you care for.';
    } else if (count == 0) {
      title = 'Everything looks up to date.';
      subtitle = 'No new alerts need your attention.';
    } else {
      title = count == 1
          ? '1 alert needs your attention.'
          : '$count alerts need your attention.';
      subtitle = 'Tap to see and handle them.';
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: alertCountError != null ? _loadAlertCount : _openAlerts,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  hasOpen
                      ? Icons.notifications_active_outlined
                      : Icons.check_circle_outline_rounded,
                  color: color,
                  size: 27,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Family Status',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF718096),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: hasOpen ? color : null,
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
            'People you care for: those who share their health data '
            'with you and those you added yourself.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF718096),
            ),
          ),

          const SizedBox(height: 20),

          ..._buildFamilyCards(),

          const SizedBox(height: 12),

          // ----------------------------------------------------
          // Someone without an account (e.g. a child) is added
          // here; someone with an account invites the caregiver
          // and is accepted under Invitations.
          // ----------------------------------------------------

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => _openAddFamilyMember(),
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
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

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton.icon(
              onPressed: _openInvitations,
              icon: const Icon(
                Icons.mark_email_unread_outlined,
              ),
              label: const Text(
                'Invitations',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF765BD4),
                side: const BorderSide(color: Color(0xFFD9CFFA)),
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
    return CareRemindersView(
      members: familyMembers,
      membersLoading: familyLoading,
      storeFor: widget.reminderStoreFor,
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
          icon: Icons.mark_email_unread_outlined,
          title: 'Invitations',
          subtitle: 'Accept patients who invited you',
          onTap: _openInvitations,
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
  final CarePatient member;
  final VoidCallback onTap;

  /// Only for a family member this caregiver added and manages.
  final VoidCallback? onEdit;

  const _FamilyMemberCard({
    required this.member,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    const iconColor = Color(0xFF765BD4);
    final statusColor = glucoseStatusColor(member.status);

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
                child: const Icon(
                  Icons.person_rounded,
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

                    if (member.managed) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0ECFF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Managed by you',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),

                    Text(
                      member.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF718096),
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Icon(
                          Icons.water_drop_rounded,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            member.lastGlucose == null
                                ? 'No readings yet'
                                : '${member.lastGlucose} mg/dL • '
                                    '${member.statusLabel}'
                                    '${member.lastGlucoseAt == null ? '' : ' • ${formatRelativeDay(member.lastGlucoseAt!)}'}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: member.lastGlucose == null
                                  ? const Color(0xFF8A97A5)
                                  : statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit details',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: iconColor,
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
              'No family members yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Add someone without an account (e.g. a child) with '
              'Add Family Member on the Family tab. Someone with their own '
              'DiaMate app invites you from More → Care Team; accept it '
              'under Invitations.',
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