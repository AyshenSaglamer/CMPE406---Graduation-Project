import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class GlucoseChartScreen extends StatefulWidget {
  const GlucoseChartScreen({super.key});

  @override
  State<GlucoseChartScreen> createState() => _GlucoseChartScreenState();
}

class _GlucoseChartScreenState extends State<GlucoseChartScreen> {
  String selectedPeriod = '7 Days';

  final List<String> periods = [
    '7 Days',
    '30 Days',
    '3 Months',
  ];

  final List<double> glucoseValues = [
    105,
    125,
    98,
    145,
    118,
    132,
    110,
  ];

  double get averageGlucose {
    if (glucoseValues.isEmpty) {
      return 0;
    }

    final total = glucoseValues.reduce(
      (value, element) => value + element,
    );

    return total / glucoseValues.length;
  }

  String get averageText {
    return averageGlucose.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Glucose Chart'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SingleChildScrollView(
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
                    value: '$averageText',
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
                    value: '${glucoseValues.length}',
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

            _buildChartCard(),

            const SizedBox(height: 18),

            _buildStatisticsCard(),
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
          colors: [
            Color(0xFFEAF5FF),
            Color(0xFFF4FAFF),
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
        border: Border.all(
          color: const Color(0xFFE3EAF1),
        ),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = selectedPeriod == period;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedPeriod = period;
                });
              },
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

  Widget _buildChartCard() {
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
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
                  child: const Text(
                    '7 readings',
                    style: TextStyle(
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
                  minY: 60,
                  maxY: 180,
                  minX: 0,
                  maxX: 6,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: const Color(0xFFE8EDF2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: false,
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: false,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 20,
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
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          const days = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ];

                          final index = value.toInt();

                          if (index < 0 || index >= days.length) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(
                              top: 7,
                            ),
                            child: Text(
                              days[index],
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
                      spots: List.generate(
                        glucoseValues.length,
                        (index) => FlSpot(
                          index.toDouble(),
                          glucoseValues[index],
                        ),
                      ),
                      isCurved: true,
                      barWidth: 3,
                      color: const Color(0xFF168AF7),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter:
                            (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.white,
                            strokeWidth: 2.5,
                            strokeColor:
                                const Color(0xFF168AF7),
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
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final lowest = glucoseValues.reduce(
      (current, next) => current < next ? current : next,
    );

    final highest = glucoseValues.reduce(
      (current, next) => current > next ? current : next,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: _StatisticItem(
                    label: 'Lowest',
                    value: '$lowest mg/dL',
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
                    value: '$highest mg/dL',
                    icon: Icons.arrow_upward_rounded,
                    iconColor: const Color(0xFFE95D76),
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
                  padding: const EdgeInsets.only(
                    bottom: 2,
                  ),
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
        Icon(
          icon,
          color: iconColor,
          size: 21,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}