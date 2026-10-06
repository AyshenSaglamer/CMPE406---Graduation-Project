
import 'package:flutter/material.dart';
import 'role_selection_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() =>
      _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState
    extends State<DoctorDashboardScreen> {
  int selectedIndex = 0;

  final TextEditingController searchController =
      TextEditingController();

  final List<DoctorPatient> patients = [
    DoctorPatient(
      name: 'Emma Wilson',
      age: 12,
      diabetesType: 'Type 1 Diabetes',
      glucose: 112,
      lastMeasurement: 'Today, 08:30',
      status: 'In Range',
    ),
    DoctorPatient(
      name: 'Noah Smith',
      age: 16,
      diabetesType: 'Type 1 Diabetes',
      glucose: 245,
      lastMeasurement: 'Today, 09:15',
      status: 'High',
    ),
    DoctorPatient(
      name: 'Olivia Brown',
      age: 10,
      diabetesType: 'Type 1 Diabetes',
      glucose: 68,
      lastMeasurement: 'Today, 09:40',
      status: 'Low',
    ),
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Color get primaryColor => const Color(0xFF168AF7);

  Color _statusColor(String status) {
    switch (status) {
      case 'High':
        return const Color(0xFFE85D75);
      case 'Low':
        return const Color(0xFFF0A126);
      default:
        return const Color(0xFF35B779);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Log out?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Are you sure you want to log out of DiaMate?',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) =>
                      const RoleSelectionScreen(),
                ),
                (route) => false,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor:
                  const Color(0xFFE85D75),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
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
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Reports',
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
        return _buildPatientsPage();
      case 2:
        return _buildReportsPage();
      case 3:
        return _buildMorePage();
      default:
        return _buildHomePage();
    }
  }

  // HOME DASHBOARD

  Widget _buildHomePage() {
    final highCount =
        patients.where((p) => p.status == 'High').length;
    final lowCount =
        patients.where((p) => p.status == 'Low').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),

          const SizedBox(height: 22),

          _buildOverviewCard(),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Patients',
                  value: '${patients.length}',
                  icon: Icons.people_rounded,
                  color: const Color(0xFF168AF7),
                  background: const Color(0xFFEAF5FF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'High Glucose',
                  value: '$highCount',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFFE85D75),
                  background: const Color(0xFFFFEFF1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Low Glucose',
                  value: '$lowCount',
                  icon: Icons.trending_down_rounded,
                  color: const Color(0xFFF0A126),
                  background: const Color(0xFFFFF3DF),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(
            'Recent Patient Activity',
            'View All',
            () {
              setState(() {
                selectedIndex = 1;
              });
            },
          ),

          const SizedBox(height: 12),

          ...patients.map(
            (patient) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PatientCard(
                patient: patient,
                statusColor:
                    _statusColor(patient.status),
                onTap: () => _openPatient(patient),
              ),
            ),
          ),

          const SizedBox(height: 10),

          _buildAlertsCard(highCount, lowCount),
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
            color: const Color(0xFFEAF5FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.medical_services_rounded,
            color: primaryColor,
            size: 26,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, Doctor 👋',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Monitor your patients’ health.',
                style: TextStyle(
                  fontSize: 12,
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
              _showMessage(
                'Doctor profile settings will be available here.',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE1F0FF),
            Color(0xFFF1F7FF),
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
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.monitor_heart_rounded,
              color: Color(0xFF168AF7),
              size: 30,
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient Overview',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Review glucose readings and patient activity.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String action,
    VoidCallback onTap,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(
            action,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsCard(int highCount, int lowCount) {
    final alertCount = highCount + lowCount;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE9EEF5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3DF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Color(0xFFF0A126),
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Glucose Alerts',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alertCount == 0
                      ? 'No alerts in the current sample data.'
                      : '$alertCount readings outside the configured range.',
                  style: const TextStyle(
                    fontSize: 12,
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
    );
  }

  // PATIENTS PAGE

  Widget _buildPatientsPage() {
    final query = searchController.text.toLowerCase();

    final filteredPatients = patients.where((patient) {
      return patient.name.toLowerCase().contains(query) ||
          patient.diabetesType.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Patients',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'View and monitor your assigned patients.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search patients...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: filteredPatients.isEmpty
              ? const Center(
                  child: Text('No patients found.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    18, 10, 18, 25,
                  ),
                  itemCount: filteredPatients.length,
                  itemBuilder: (context, index) {
                    final patient = filteredPatients[index];

                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: _PatientCard(
                        patient: patient,
                        statusColor:
                            _statusColor(patient.status),
                        onTap: () => _openPatient(patient),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // REPORTS PAGE

  Widget _buildReportsPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
      children: [
        const Text(
          'Patient Reports',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Review glucose history and patient records.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 20),

        ...patients.map(
          (patient) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(14),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0ECFF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.insert_chart_outlined_rounded,
                  color: Color(0xFF765BD4),
                ),
              ),
              title: Text(
                patient.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                '${patient.diabetesType}\n'
                'Latest: ${patient.glucose} mg/dL',
              ),
              isThreeLine: true,
              trailing: const Icon(
                Icons.chevron_right_rounded,
              ),
              onTap: () => _openPatient(patient),
            ),
          ),
        ),
      ],
    );
  }

  // MORE PAGE

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
          'Manage your doctor account.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 20),

        _MoreOption(
          icon: Icons.people_outline_rounded,
          title: 'My Patients',
          subtitle: 'View assigned patient profiles',
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
          onTap: () => _showMessage(
            'Privacy settings will be available here.',
          ),
        ),

        _MoreOption(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Customize your DiaMate experience',
          onTap: () => _showMessage(
            'Settings will be available here.',
          ),
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

  void _openPatient(DoctorPatient patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPatientDetailScreen(
          patient: patient,
          statusColor: _statusColor(patient.status),
        ),
      ),
    );
  }
}

// PATIENT MODEL

class DoctorPatient {
  final String name;
  final int age;
  final String diabetesType;
  final int glucose;
  final String lastMeasurement;
  final String status;

  const DoctorPatient({
    required this.name,
    required this.age,
    required this.diabetesType,
    required this.glucose,
    required this.lastMeasurement,
    required this.status,
  });
}

// STAT CARD

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color background;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 15,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9EEF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF718096),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// PATIENT CARD

class _PatientCard extends StatelessWidget {
  final DoctorPatient patient;
  final Color statusColor;
  final VoidCallback onTap;

  const _PatientCard({
    required this.patient,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.person_rounded,
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
                      patient.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${patient.age} years • ${patient.diabetesType}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF718096),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.water_drop_rounded,
                          size: 15,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${patient.glucose} mg/dL',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      patient.lastMeasurement,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF8A97A5),
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      patient.status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9AA8B7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// MORE OPTION

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
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: Container(
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
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF718096),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFF9AA8B7),
        ),
        onTap: onTap,
      ),
    );
  }
}

// PATIENT DETAIL SCREEN

class DoctorPatientDetailScreen extends StatelessWidget {
  final DoctorPatient patient;
  final Color statusColor;

  const DoctorPatientDetailScreen({
    super.key,
    required this.patient,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Patient Details',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5FF),
                    borderRadius: BorderRadius.circular(23),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 42,
                    color: Color(0xFF168AF7),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  patient.name,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${patient.age} years • ${patient.diabetesType}',
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFEAF5FF),
                  Color(0xFFF4F8FF),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Latest Blood Glucose',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${patient.glucose}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(
                        left: 8,
                        bottom: 9,
                      ),
                      child: Text(
                        'mg/dL',
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF718096),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        patient.status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Last measurement: ${patient.lastMeasurement}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Glucose History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          const _HistoryRow(
            time: '08:30 AM',
            glucose: '112 mg/dL',
            color: Color(0xFF35B779),
          ),
          const _HistoryRow(
            time: '12:30 PM',
            glucose: '125 mg/dL',
            color: Color(0xFF35B779),
          ),
          const _HistoryRow(
            time: '06:00 PM',
            glucose: '118 mg/dL',
            color: Color(0xFF35B779),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Patient report feature will be connected to the backend.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_rounded),
              label: const Text('View Full Report'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String time;
  final String glucose;
  final Color color;

  const _HistoryRow({
    required this.time,
    required this.glucose,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          Icons.water_drop_rounded,
          color: color,
        ),
        title: Text(
          glucose,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        trailing: Text(
          time,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF718096),
          ),
        ),
      ),
    );
  }
}