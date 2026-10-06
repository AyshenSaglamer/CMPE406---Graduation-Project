import 'package:flutter/material.dart';
import '../data/activity_store.dart';
import '../data/glucose_store.dart';
import '../data/insulin_store.dart';
import '../data/meal_store.dart';
import '../navigation/session_navigation.dart';
import '../services/api_exception.dart';
import '../utils/form_helpers.dart';
import 'activity_entry_screen.dart';
import 'ai_assistant_screen.dart';
import 'csv_import_screen.dart';
import 'glucose_chart_screen.dart';
import 'glucose_entry_screen.dart';
import 'insulin_entry_screen.dart';
import 'meal_entry_screen.dart';
import 'offline_mode_screen.dart';
import 'pdf_report_screen.dart';
import 'reminder_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedIndex = 0;
  final List<Widget> pages = const [
    _HomeTab(),
    GlucoseChartScreen(),
    _EmptyAddTab(),
    ReminderScreen(),
    _MoreTab(),
  ];
  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  /// Loads the last 14 days of glucose, insulin, meal and activity logs.
  Future<void> _loadRecords() async {
    try {
      await Future.wait([
        glucoseStore.load(),
        insulinStore.load(),
        mealStore.load(),
        activityStore.load(),
      ]);
    } on ApiException catch (e) {
      if (!mounted || e.statusCode == 401) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load your records: ${e.message}')),
      );
    }
  }

  void _onNavigationSelected(int index) {
    if (index == 2) {
      _showAddRecordSheet();
      return;
    }
    setState(() {
      selectedIndex = index;
    });
  }

  void _showAddRecordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const _AddRecordSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: _onNavigationSelected,
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
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart_rounded),
            label: 'Chart',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_rounded),
            selectedIcon: Icon(Icons.add_rounded),
            label: 'Add',
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
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();
  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),
          _buildTodayCard(context),
          const SizedBox(height: 14),
          // ----------------------------
          // HEALTH METRICS
          // ----------------------------
          ListenableBuilder(
            listenable: Listenable.merge([
              glucoseStore,
              insulinStore,
              mealStore,
              activityStore,
            ]),
            builder: (context, child) {
              final latestGlucose = glucoseStore.latest;

              final insulinToday = insulinStore.today.fold<double>(
                0,
                (sum, r) => sum + r.doseUnits,
              );

              final mealsToday = mealStore.today;
              final carbsToday = mealsToday.fold<double>(
                0,
                (sum, r) => sum + (r.carbsG ?? 0),
              );

              final activityToday = activityStore.today.fold<double>(
                0,
                (sum, r) => sum + (r.durationMinutes ?? 0),
              );

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _DashboardMetricCard(
                          icon: Icons.water_drop_rounded,
                          iconBackground: const Color(0xFFFFEEF1),
                          iconColor: const Color(0xFFE95D76),
                          title: 'Glucose',
                          value: latestGlucose == null
                              ? '\u2014'
                              : formatNumber(latestGlucose.value),
                          unit: 'mg/dL',
                          footer: latestGlucose == null
                              ? 'No reading'
                              : 'Latest reading',
                          footerColor: const Color(0xFFE95D76),
                          onTap: () {
                            _open(context, const GlucoseEntryScreen());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DashboardMetricCard(
                          icon: Icons.medication_rounded,
                          iconBackground: const Color(0xFFF0ECFF),
                          iconColor: const Color(0xFF765BD4),
                          title: 'Insulin',
                          value: formatNumber(insulinToday),
                          unit: 'units',
                          footer: 'Today',
                          footerColor: const Color(0xFF765BD4),
                          onTap: () {
                            _open(context, const InsulinEntryScreen());
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DashboardMetricCard(
                          icon: Icons.restaurant_rounded,
                          iconBackground: const Color(0xFFFFF2E2),
                          iconColor: const Color(0xFFF0A126),
                          title: 'Meals',
                          value: '${mealsToday.length}',
                          unit: 'today',
                          footer: mealsToday.isEmpty
                              ? 'No meals yet'
                              : '${formatNumber(carbsToday)} g carbs',
                          footerColor: const Color(0xFFF0A126),
                          onTap: () {
                            _open(context, const MealEntryScreen());
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DashboardMetricCard(
                          icon: Icons.directions_run_rounded,
                          iconBackground: const Color(0xFFEAF8EE),
                          iconColor: const Color(0xFF35B779),
                          title: 'Activity',
                          value: formatNumber(activityToday),
                          unit: 'min',
                          footer: 'Today',
                          footerColor: const Color(0xFF35B779),
                          onTap: () {
                            _open(context, const ActivityEntryScreen());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          // ----------------------------
          // QUICK ACTIONS
          // ----------------------------
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () {
                  _open(context, const GlucoseChartScreen());
                },
                child: const Text('View Chart'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.water_drop_rounded,
                  iconColor: const Color(0xFFE95D76),
                  background: const Color(0xFFFFEEF1),
                  title: 'Glucose',
                  onTap: () {
                    _open(context, const GlucoseEntryScreen());
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.restaurant_rounded,
                  iconColor: const Color(0xFFF0A126),
                  background: const Color(0xFFFFF2E2),
                  title: 'Meal',
                  onTap: () {
                    _open(context, const MealEntryScreen());
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.medication_rounded,
                  iconColor: const Color(0xFF765BD4),
                  background: const Color(0xFFF0ECFF),
                  title: 'Insulin',
                  onTap: () {
                    _open(context, const InsulinEntryScreen());
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildAssistantCard(context),
          const SizedBox(height: 22),
          // ----------------------------
          // RECENT ACTIVITY
          // ----------------------------
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () {
                  _open(context, const GlucoseChartScreen());
                },
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: Listenable.merge([
              glucoseStore,
              insulinStore,
              mealStore,
              activityStore,
            ]),
            builder: (context, child) {
              final cards = <Widget>[];

              final glucose = glucoseStore.latest;
              if (glucose != null) {
                cards.add(
                  _RecentActivityCard(
                    icon: Icons.water_drop_rounded,
                    iconBackground: const Color(0xFFFFEEF1),
                    iconColor: const Color(0xFFE95D76),
                    title: 'Blood Glucose',
                    subtitle:
                        '${glucose.measurementTime} \u2022 ${formatRelativeDay(glucose.dateTime)}',
                    value: '${formatNumber(glucose.value)} mg/dL',
                  ),
                );
              }

              final insulin = insulinStore.latest;
              if (insulin != null) {
                cards.add(
                  _RecentActivityCard(
                    icon: Icons.medication_rounded,
                    iconBackground: const Color(0xFFF0ECFF),
                    iconColor: const Color(0xFF765BD4),
                    title: 'Insulin',
                    subtitle: formatRelativeDay(insulin.administeredAt),
                    value: '${formatNumber(insulin.doseUnits)} units',
                  ),
                );
              }

              final meal = mealStore.latest;
              if (meal != null) {
                cards.add(
                  _RecentActivityCard(
                    icon: Icons.restaurant_rounded,
                    iconBackground: const Color(0xFFFFF2E2),
                    iconColor: const Color(0xFFF0A126),
                    title: meal.mealType,
                    subtitle: formatRelativeDay(meal.eatenAt),
                    value: meal.carbsG == null
                        ? '\u2014'
                        : '${formatNumber(meal.carbsG!)} g',
                  ),
                );
              }

              final activity = activityStore.latest;
              if (activity != null) {
                cards.add(
                  _RecentActivityCard(
                    icon: Icons.directions_run_rounded,
                    iconBackground: const Color(0xFFEAF8EE),
                    iconColor: const Color(0xFF35B779),
                    title: activity.activityType,
                    subtitle: formatRelativeDay(activity.startedAt),
                    value: activity.durationMinutes == null
                        ? '\u2014'
                        : '${formatNumber(activity.durationMinutes!)} min',
                  ),
                );
              }

              if (cards.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No records in the last 14 days yet.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
                  ),
                );
              }

              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    cards[i],
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          _buildReminderCard(context),
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
            color: const Color(0xFFE9F4FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF168AF7),
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello \u{1F44B}',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 3),
              Text(
                'Let’s take care of your health today.',
                style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
              ),
            ],
          ),
        ),
        _HeaderIconButton(icon: Icons.search_rounded, onTap: () {}),
        const SizedBox(width: 8),
        _HeaderIconButton(icon: Icons.notifications_none_rounded, onTap: () {}),
      ],
    );
  }

  Widget _buildTodayCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFDDFBB9), Color(0xFFF1FCDD)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF32552A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tuesday, September 8',
                      style: TextStyle(fontSize: 13, color: Color(0xFF587151)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '3 reminders',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4F6848),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ReminderMiniRow(
            time: '08:00',
            title: 'Blood glucose measurement',
            activeColor: const Color(0xFFE95D76),
          ),
          const SizedBox(height: 8),
          _ReminderMiniRow(
            time: '12:30',
            title: 'Insulin',
            activeColor: const Color(0xFF765BD4),
          ),
          const SizedBox(height: 8),
          _ReminderMiniRow(
            time: '20:00',
            title: 'Evening blood glucose',
            activeColor: const Color(0xFF168AF7),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE9FA), Color(0xFFF6EFFF)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              size: 30,
              color: Color(0xFF8B62D6),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need a little help?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Talk to your DiaMate Assistant.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF786B84)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(88, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: const Color(0xFF20202B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Open',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3DF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFFF0A126),
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Reminder',
                    style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Evening blood glucose',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Text(
              '20:00',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String value;
  final String unit;
  final String footer;
  final Color footerColor;
  final VoidCallback onTap;
  const _DashboardMetricCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.unit,
    required this.footer,
    required this.footerColor,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(height: 11),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
              ),
              const SizedBox(height: 3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
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
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String title;
  final VoidCallback onTap;
  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.title,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 21),
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

class _RecentActivityCard extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;
  const _RecentActivityCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
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
                color: iconBackground,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: iconColor, size: 21),
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderMiniRow extends StatelessWidget {
  final String time;
  final String title;
  final Color activeColor;
  const _ReminderMiniRow({
    required this.time,
    required this.title,
    required this.activeColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 32,
            decoration: BoxDecoration(
              color: activeColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF42603B),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF496144),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 21, color: const Color(0xFF273142)),
        ),
      ),
    );
  }
}

class _AddRecordSheet extends StatelessWidget {
  const _AddRecordSheet();
  void _open(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E0E8),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Add Health Record',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            _BottomSheetRecordTile(
              icon: Icons.water_drop_rounded,
              background: const Color(0xFFFFEEF1),
              iconColor: const Color(0xFFE95D76),
              title: 'Blood Glucose',
              subtitle: 'Add a glucose measurement',
              onTap: () {
                _open(context, const GlucoseEntryScreen());
              },
            ),
            const SizedBox(height: 10),
            _BottomSheetRecordTile(
              icon: Icons.medication_rounded,
              background: const Color(0xFFF0ECFF),
              iconColor: const Color(0xFF765BD4),
              title: 'Insulin',
              subtitle: 'Add an insulin record',
              onTap: () {
                _open(context, const InsulinEntryScreen());
              },
            ),
            const SizedBox(height: 10),
            _BottomSheetRecordTile(
              icon: Icons.restaurant_rounded,
              background: const Color(0xFFFFF2E2),
              iconColor: const Color(0xFFF0A126),
              title: 'Meal',
              subtitle: 'Add a meal record',
              onTap: () {
                _open(context, const MealEntryScreen());
              },
            ),
            const SizedBox(height: 10),
            _BottomSheetRecordTile(
              icon: Icons.directions_run_rounded,
              background: const Color(0xFFEAF8EE),
              iconColor: const Color(0xFF35B779),
              title: 'Activity',
              subtitle: 'Add physical activity',
              onTap: () {
                _open(context, const ActivityEntryScreen());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomSheetRecordTile extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BottomSheetRecordTile({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
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
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA8B7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab();
  void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
      children: [
        const Text(
          'More',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Manage your DiaMate tools.',
          style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
        ),
        const SizedBox(height: 20),
        _MoreTile(
          icon: Icons.upload_file_rounded,
          title: 'Import CSV',
          subtitle: 'Import blood glucose data',
          onTap: () {
            _open(context, const CsvImportScreen());
          },
        ),
        _MoreTile(
          icon: Icons.cloud_off_rounded,
          title: 'Offline Mode',
          subtitle: 'Manage locally stored data',
          onTap: () {
            _open(context, const OfflineModeScreen());
          },
        ),
        _MoreTile(
          icon: Icons.picture_as_pdf_rounded,
          title: 'PDF Report',
          subtitle: 'Generate your health report',
          onTap: () {
            _open(context, const PdfReportScreen());
          },
        ),
        _MoreTile(
          icon: Icons.smart_toy_outlined,
          title: 'DiaMate Assistant',
          subtitle: 'Get help with your health data',
          onTap: () {
            _open(context, const AiAssistantScreen());
          },
        ),
        _MoreTile(
          icon: Icons.logout_rounded,
          title: 'Log Out',
          subtitle: 'Sign out of your DiaMate account',
          onTap: () {
            _showLogoutDialog(context);
          },
        ),
      ],
    );
  }

  // -----------------------------------------------------------
  // LOGOUT
  // Same dialog as the doctor and caregiver dashboards.
  // -----------------------------------------------------------
  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Log out?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text('Are you sure you want to log out of DiaMate?'),
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
                // Deletes the stored token, then returns to the start screen.
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
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
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
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: const Color(0xFF168AF7)),
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
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA8B7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAddTab extends StatelessWidget {
  const _EmptyAddTab();
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
