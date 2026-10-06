import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/glucose_store.dart';
import '../services/api_exception.dart';
import '../utils/form_helpers.dart';
import 'glucose_entry_screen.dart';

class GlucoseChartScreen extends StatefulWidget {
  const GlucoseChartScreen({super.key});

  @override
  State<GlucoseChartScreen> createState() => _GlucoseChartScreenState();
}

class _GlucoseChartScreenState extends State<GlucoseChartScreen> {
  String selectedPeriod = '7 Days';

  final List<String> periods = ['7 Days', '30 Days', '3 Months'];

  static const Map<String, int> _periodDays = {
    '7 Days': 7,
    '30 Days': 30,
    '3 Months': 90,
  };

  /// Target range used for "time in range".
  static const double _targetLow = 70;
  static const double _targetHigh = 180;

  /// Readings of the selected period, oldest first.
  List<GlucoseRecord> records = [];

  bool isLoading = true;

  String? loadError;

  late DateTime periodStart;

  int _loadRequest = 0;

  int get periodDays => _periodDays[selectedPeriod]!;

  @override
  void initState() {
    super.initState();
    periodStart = _startFor(periodDays);
    // Reload when a reading is added, edited or deleted anywhere in the app.
    glucoseStore.addListener(_load);
    _fetch();
  }

  @override
  void dispose() {
    glucoseStore.removeListener(_load);
    super.dispose();
  }

  DateTime _startFor(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: days - 1));
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    await _fetch();
  }

  Future<void> _fetch() async {
    final request = ++_loadRequest;
    final start = _startFor(periodDays);

    try {
      final fetched = await glucoseStore.fetch(from: start);

      if (!mounted || request != _loadRequest) {
        return;
      }

      setState(() {
        periodStart = start;
        records = fetched.reversed.toList();
        isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _loadRequest) {
        return;
      }

      setState(() {
        isLoading = false;
        loadError = e.message;
      });
    }
  }

  void _selectPeriod(String period) {
    if (period == selectedPeriod) {
      return;
    }

    setState(() {
      selectedPeriod = period;
    });

    _load();
  }

  List<double> get _values => records.map((r) => r.value).toList();

  double get averageGlucose {
    if (records.isEmpty) {
      return 0;
    }

    return _values.reduce((a, b) => a + b) / records.length;
  }

  String get averageText {
    return records.isEmpty ? '—' : averageGlucose.toStringAsFixed(0);
  }

  Future<void> _edit(GlucoseRecord record) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GlucoseEntryScreen(existing: record)),
    );
  }

  Future<void> _delete(GlucoseRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reading?'),
        content: Text(
          '${formatNumber(record.value)} mg/dL on '
          '${formatDateTime(record.dateTime)} will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFE95D76)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await glucoseStore.delete(record.id);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }

    if (!mounted) {
      return;
    }

    // The store only holds the last 14 days; reload so older readings
    // in this period disappear too.
    _load();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reading deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Glucose Chart'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),

              const SizedBox(height: 22),

              const Text(
                'Overview',
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
                    child: _OverviewCard(
                      icon: Icons.water_drop_rounded,
                      iconColor: const Color(0xFFE95D76),
                      background: const Color(0xFFFFEEF1),
                      title: 'Average',
                      value: averageText,
                      unit: 'mg/dL',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OverviewCard(
                      icon: Icons.analytics_outlined,
                      iconColor: const Color(0xFF168AF7),
                      background: const Color(0xFFEAF5FF),
                      title: 'Measurements',
                      value: '${records.length}',
                      unit: 'total',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              const Text(
                'Time Period',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 10),

              _buildPeriodSelector(),

              const SizedBox(height: 16),

              if (loadError != null)
                _buildMessageCard(
                  icon: Icons.cloud_off_rounded,
                  text: loadError!,
                  action: TextButton(
                    onPressed: _load,
                    child: const Text('Try again'),
                  ),
                )
              else if (isLoading && records.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (records.isEmpty)
                _buildMessageCard(
                  icon: Icons.water_drop_outlined,
                  text: 'No readings in this period yet.',
                )
              else ...[
                _buildChartCard(),

                const SizedBox(height: 18),

                _buildStatisticsCard(),

                const SizedBox(height: 18),

                _buildReadingsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String text,
    Widget? action,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 34, color: const Color(0xFF9AA8B7)),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64788B)),
            ),
            if (action != null) ...[const SizedBox(height: 6), action],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF5FF), Color(0xFFF4FAFF)],
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
              Icons.show_chart_rounded,
              size: 31,
              color: Color(0xFF168AF7),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blood Glucose Trends',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF233247),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Review your glucose measurements over time.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF64788B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE3EAF1)),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = selectedPeriod == period;

          return Expanded(
            child: GestureDetector(
              onTap: () => _selectPeriod(period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  vertical: 11,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFE8F3FF)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  period,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? const Color(0xFF168AF7)
                        : const Color(0xFF718096),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// X axis = days since the start of the period (0 .. periodDays).
  double _x(DateTime time) {
    return time.difference(periodStart).inMinutes / (24 * 60);
  }

  Widget _buildChartCard() {
    final lowest = _values.reduce(math.min);
    final highest = _values.reduce(math.max);

    // Always show the 70-180 target range; widen it for readings outside.
    final minY = (math.min(60, lowest - 10) / 20).floor() * 20.0;
    final maxY = (math.max(200, highest + 10) / 20).ceil() * 20.0;
    final yInterval = maxY - minY > 240 ? 40.0 : 20.0;

    final labelEvery = periodDays <= 7 ? 1 : (periodDays <= 30 ? 5 : 15);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Glucose History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8EE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${records.length} readings',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E8B5A),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  minX: 0,
                  maxX: periodDays.toDouble(),
                  clipData: const FlClipData.all(),
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                        y1: _targetLow,
                        y2: _targetHigh,
                        color: const Color(0x1435B779),
                      ),
                    ],
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: Color(0xFFE8EDF2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final record = records[spot.spotIndex];
                          return LineTooltipItem(
                            '${formatNumber(record.value)} mg/dL\n'
                            '${formatDateTime(record.dateTime)}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: yInterval,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF8A97A5),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: labelEvery.toDouble(),
                        getTitlesWidget: (value, meta) {
                          if (value % 1 != 0 || value >= periodDays) {
                            return const SizedBox.shrink();
                          }

                          final day = periodStart.add(
                            Duration(days: value.toInt()),
                          );

                          const weekdays = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];

                          final label = periodDays <= 7
                              ? weekdays[day.weekday - 1]
                              : '${day.day.toString().padLeft(2, '0')}/'
                                    '${day.month.toString().padLeft(2, '0')}';

                          return Padding(
                            padding: const EdgeInsets.only(top: 7),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8A97A5),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: records
                          .map((r) => FlSpot(_x(r.dateTime), r.value))
                          .toList(),
                      isCurved: true,
                      preventCurveOverShooting: true,
                      barWidth: 3,
                      color: const Color(0xFF168AF7),
                      dotData: FlDotData(
                        show: records.length <= 60,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2.5,
                            strokeColor: const Color(0xFF168AF7),
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0x22168AF7),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Green band: target range 70-180 mg/dL',
              style: TextStyle(fontSize: 11, color: Color(0xFF8A97A5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final lowest = _values.reduce(math.min);
    final highest = _values.reduce(math.max);

    final inRange = records
        .where((r) => r.value >= _targetLow && r.value <= _targetHigh)
        .length;
    final inRangePercent = (inRange * 100 / records.length).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    label: 'Lowest',
                    value: '${formatNumber(lowest)} mg/dL',
                    icon: Icons.arrow_downward_rounded,
                    iconColor: const Color(0xFF35B779),
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: 'Average',
                    value: '$averageText mg/dL',
                    icon: Icons.remove_rounded,
                    iconColor: const Color(0xFF168AF7),
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: 'Highest',
                    value: '${formatNumber(highest)} mg/dL',
                    icon: Icons.arrow_upward_rounded,
                    iconColor: const Color(0xFFE95D76),
                  ),
                ),
                Expanded(
                  child: _StatisticItem(
                    label: 'In range',
                    value: '$inRangePercent%',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: const Color(0xFF2E8B5A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingsCard() {
    final newestFirst = records.reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Readings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a reading to edit it.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8A97A5)),
            ),
            const SizedBox(height: 6),
            for (final record in newestFirst)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _edit(record),
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEEF1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFFE95D76),
                    size: 20,
                  ),
                ),
                title: Text(
                  '${formatNumber(record.value)} mg/dL',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${record.measurementTime} • '
                  '${formatDateTime(record.dateTime)}'
                  '${record.notes == null ? '' : '\n${record.notes}'}',
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: record.notes != null,
                trailing: IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFF9AA8B7),
                  ),
                  onPressed: () => _delete(record),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String title;
  final String value;
  final String unit;

  const _OverviewCard({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.title,
    required this.value,
    required this.unit,
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(height: 11),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF718096)),
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
          ],
        ),
      ),
    );
  }
}

class _StatisticItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatisticItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 21),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF718096)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
