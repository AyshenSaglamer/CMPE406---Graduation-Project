import 'package:flutter/material.dart';

class PdfReportScreen extends StatefulWidget {
  const PdfReportScreen({super.key});

  @override
  State<PdfReportScreen> createState() => _PdfReportScreenState();
}

class _PdfReportScreenState extends State<PdfReportScreen> {
  DateTime startDate = DateTime.now().subtract(
    const Duration(days: 7),
  );

  DateTime endDate = DateTime.now();

  bool isGenerating = false;

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() {
        startDate = selected;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: startDate,
      lastDate: DateTime.now(),
    );

    if (selected != null) {
      setState(() {
        endDate = selected;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Future<void> _generateReport() async {
    setState(() {
      isGenerating = true;
    });

    await Future.delayed(
      const Duration(seconds: 1),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isGenerating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'PDF report generation started.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('PDF Report'),
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
              'Report Period',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _DateCard(
                    title: 'Start Date',
                    date: _formatDate(startDate),
                    icon: Icons.calendar_today_outlined,
                    iconColor: const Color(0xFF168AF7),
                    background: const Color(0xFFEAF5FF),
                    onTap: _selectStartDate,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _DateCard(
                    title: 'End Date',
                    date: _formatDate(endDate),
                    icon: Icons.event_outlined,
                    iconColor: const Color(0xFF765BD4),
                    background: const Color(0xFFF0ECFF),
                    onTap: _selectEndDate,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            const Text(
              'Health Summary',
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
                  child: _SummaryCard(
                    icon: Icons.water_drop_rounded,
                    iconColor: const Color(0xFFE95D76),
                    background: const Color(0xFFFFEEF1),
                    title: 'Glucose',
                    value: '119',
                    unit: 'mg/dL',
                    detail: '7 measurements',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _SummaryCard(
                    icon: Icons.medication_rounded,
                    iconColor: const Color(0xFF765BD4),
                    background: const Color(0xFFF0ECFF),
                    title: 'Insulin',
                    value: '18',
                    unit: 'units',
                    detail: '3 records',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.restaurant_rounded,
                    iconColor: const Color(0xFFF0A126),
                    background: const Color(0xFFFFF2E2),
                    title: 'Meals',
                    value: '12',
                    unit: 'records',
                    detail: '3 meals / day',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _SummaryCard(
                    icon: Icons.directions_run_rounded,
                    iconColor: const Color(0xFF35B779),
                    background: const Color(0xFFEAF8EE),
                    title: 'Activity',
                    value: '150',
                    unit: 'min',
                    detail: '5 activities',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            _buildReportIncludesCard(),

            const SizedBox(height: 22),

            _buildPreviewCard(),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isGenerating
                    ? null
                    : _generateReport,
                icon: isGenerating
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.picture_as_pdf_rounded,
                      ),
                label: Text(
                  isGenerating
                      ? 'Generating...'
                      : 'Generate PDF Report',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF168AF7),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF8DBEF0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
              ),
            ),
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
            Color(0xFFF0ECFF),
            Color(0xFFF8F5FF),
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
              color: Colors.white.withValues(alpha: 0.82),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFF765BD4),
              size: 31,
            ),
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health Report',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF31294B),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Create a summary of your health records for the selected period.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF776D89),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportIncludesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.description_outlined,
            color: Color(0xFF168AF7),
            size: 21,
          ),

          SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report includes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF26384B),
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Blood glucose, insulin, meal and physical activity summaries.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: Color(0xFF5F7489),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 19,
                  color: Color(0xFF718096),
                ),
                SizedBox(width: 8),
                Text(
                  'Report Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _PreviewRow(
                    label: 'Date Range',
                    value:
                        '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                  ),
                  const Divider(height: 20),
                  const _PreviewRow(
                    label: 'Average Glucose',
                    value: '119 mg/dL',
                  ),
                  const Divider(height: 20),
                  const _PreviewRow(
                    label: 'Insulin Records',
                    value: '3',
                  ),
                  const Divider(height: 20),
                  const _PreviewRow(
                    label: 'Meal Records',
                    value: '12',
                  ),
                  const Divider(height: 20),
                  const _PreviewRow(
                    label: 'Activity',
                    value: '150 minutes',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String title;
  final String date;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final VoidCallback onTap;

  const _DateCard({
    required this.title,
    required this.date,
    required this.icon,
    required this.iconColor,
    required this.background,
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
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF718096),
                ),
              ),

              const SizedBox(height: 4),

              Text(
                date,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color background;
  final String title;
  final String value;
  final String unit;
  final String detail;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.title,
    required this.value,
    required this.unit,
    required this.detail,
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

            const SizedBox(height: 10),

            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF718096),
              ),
            ),

            const SizedBox(height: 3),

            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(width: 4),

                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      bottom: 2,
                    ),
                    child: Text(
                      unit,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF718096),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              detail,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF718096),
            ),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}