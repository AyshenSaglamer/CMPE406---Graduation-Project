import 'package:flutter/material.dart';

class OfflineModeScreen extends StatefulWidget {
  const OfflineModeScreen({super.key});

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  bool isOffline = true;
  bool isSyncing = false;

  final List<LocalRecord> records = [
    LocalRecord(
      type: 'Blood Glucose',
      value: '105 mg/dL',
      time: 'Today • 08:30',
      icon: Icons.water_drop_rounded,
      iconColor: const Color(0xFFE95D76),
      background: const Color(0xFFFFEEF1),
    ),
    LocalRecord(
      type: 'Insulin',
      value: '6 units',
      time: 'Today • 12:30',
      icon: Icons.medication_rounded,
      iconColor: const Color(0xFF765BD4),
      background: const Color(0xFFF0ECFF),
    ),
    LocalRecord(
      type: 'Activity',
      value: '30 min',
      time: 'Yesterday • 18:00',
      icon: Icons.directions_run_rounded,
      iconColor: const Color(0xFF35B779),
      background: const Color(0xFFEAF8EE),
    ),
  ];

  Future<void> _syncData() async {
    if (isSyncing) {
      return;
    }

    setState(() {
      isSyncing = true;
    });

    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isSyncing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Data synchronized successfully.',
        ),
      ),
    );
  }

  void _toggleConnection(bool value) {
    setState(() {
      isOffline = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool offline = isOffline;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Offline Mode'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(offline),

            const SizedBox(height: 22),

            const Text(
              'Connection Status',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildConnectionCard(offline),

            const SizedBox(height: 22),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Local Data',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),
                ),
                Text(
                  '${records.length} records',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF718096),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            ...records.map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LocalRecordCard(
                  record: record,
                ),
              ),
            ),

            const SizedBox(height: 12),

            _buildSyncCard(),

            const SizedBox(height: 22),

            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(bool offline) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: offline
              ? const [
                  Color(0xFFFFF3DF),
                  Color(0xFFFFFAF0),
                ]
              : const [
                  Color(0xFFEAF8EE),
                  Color(0xFFF3FCF6),
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
            child: Icon(
              offline
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_done_rounded,
              size: 31,
              color: offline
                  ? const Color(0xFFF0A126)
                  : const Color(0xFF35B779),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  offline
                      ? 'Working Offline'
                      : 'You are Connected',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF293540),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  offline
                      ? 'Your health records can still be saved on this device.'
                      : 'Your device is connected and ready to sync.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF6F7780),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(bool offline) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: offline
                    ? const Color(0xFFFFF3DF)
                    : const Color(0xFFEAF8EE),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                offline
                    ? Icons.wifi_off_rounded
                    : Icons.wifi_rounded,
                color: offline
                    ? const Color(0xFFF0A126)
                    : const Color(0xFF35B779),
              ),
            ),

            const SizedBox(width: 13),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connection',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF718096),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Simulated connection status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            Switch.adaptive(
              value: offline,
              activeColor: const Color(0xFFF0A126),
              onChanged: _toggleConnection,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.82),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.sync_rounded,
              color: Color(0xFF168AF7),
            ),
          ),

          const SizedBox(width: 13),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to sync',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Upload locally stored records when connection is available.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xFF5F7489),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          SizedBox(
            height: 42,
            child: ElevatedButton(
              onPressed: isSyncing
                  ? null
                  : _syncData,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(92, 42),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                backgroundColor:
                    const Color(0xFF168AF7),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: isSyncing
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sync',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF718096),
            size: 21,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Data entered while offline remains on the device until synchronization is available.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Color(0xFF667586),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LocalRecord {
  final String type;
  final String value;
  final String time;
  final IconData icon;
  final Color iconColor;
  final Color background;

  LocalRecord({
    required this.type,
    required this.value,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.background,
  });
}

class _LocalRecordCard extends StatelessWidget {
  final LocalRecord record;

  const _LocalRecordCard({
    required this.record,
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
                color: record.background,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                record.icon,
                color: record.iconColor,
                size: 21,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    record.type,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    record.time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),

            Text(
              record.value,
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