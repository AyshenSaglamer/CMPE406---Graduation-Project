import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/health_report.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/report_pdf.dart';

/// What happened to an exported file.
enum ExportOutcome { shared, downloaded, cancelled }

/// Hands a file to the system: the share sheet on a phone (save to Files,
/// send by mail, WhatsApp...), a download in the browser.
typedef ReportExporter = Future<ExportOutcome> Function(
  Uint8List bytes,
  String fileName,
  String mimeType,
);

Future<ExportOutcome> shareReportFile(
  Uint8List bytes,
  String fileName,
  String mimeType,
) async {
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
      fileNameOverrides: [fileName],
      subject: 'DiaMate health report',
    ),
  );

  return switch (result.status) {
    ShareResultStatus.success => ExportOutcome.shared,
    ShareResultStatus.dismissed => ExportOutcome.cancelled,
    // Web and some desktops cannot share files; the file is downloaded.
    ShareResultStatus.unavailable => ExportOutcome.downloaded,
  };
}

/// The patient's health report for a chosen period: the real numbers from
/// the backend, exported as a PDF (for the doctor) or a CSV (for a
/// spreadsheet).
class PdfReportScreen extends StatefulWidget {
  const PdfReportScreen({super.key, this.loadReport, this.exporter});

  /// Defaults to [HealthReport.load] for the logged-in patient.
  final Future<HealthReport> Function(DateTime from, DateTime to)? loadReport;

  /// Defaults to [shareReportFile].
  final ReportExporter? exporter;

  @override
  State<PdfReportScreen> createState() => _PdfReportScreenState();
}

class _PdfReportScreenState extends State<PdfReportScreen> {
  late DateTime startDate;
  late DateTime endDate;

  HealthReport? report;
  bool isLoading = true;
  String? loadError;

  /// 'pdf' or 'csv' while that file is being made.
  String? exporting;

  int _request = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    endDate = DateTime(now.year, now.month, now.day);
    startDate = endDate.subtract(const Duration(days: 13));
    _load();
  }

  Future<HealthReport> _fetch(DateTime from, DateTime to) {
    final custom = widget.loadReport;
    if (custom != null) {
      return custom(from, to);
    }

    return HealthReport.load(
      from: from,
      to: to,
      patientName: authService.currentUser?.fullName ?? 'DiaMate patient',
    );
  }

  Future<void> _load() async {
    final request = ++_request;

    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final result = await _fetch(startDate, endDate);

      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        report = result;
        isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        report = null;
        isLoading = false;
        loadError = e.message;
      });
    }
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2020),
      lastDate: endDate,
    );

    if (selected != null && selected != startDate) {
      setState(() {
        startDate = selected;
      });
      _load();
    }
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: endDate,
      firstDate: startDate,
      lastDate: DateTime.now(),
    );

    if (selected != null && selected != endDate) {
      setState(() {
        endDate = selected;
      });
      _load();
    }
  }

  String _formatDate(DateTime date) => formatReportDay(date);

  Future<void> _export(String kind) async {
    final current = report;
    if (current == null || exporting != null) {
      return;
    }

    setState(() {
      exporting = kind;
    });

    String message;

    try {
      final Uint8List bytes;
      final String fileName;
      final String mimeType;

      if (kind == 'pdf') {
        bytes = await buildReportPdf(current);
        fileName = '${current.fileBaseName}.pdf';
        mimeType = 'application/pdf';
      } else {
        bytes = Uint8List.fromList(utf8.encode(current.toCsv()));
        fileName = '${current.fileBaseName}.csv';
        mimeType = 'text/csv';
      }

      final outcome =
          await (widget.exporter ?? shareReportFile)(bytes, fileName, mimeType);

      message = switch (outcome) {
        ExportOutcome.shared => '$fileName is ready.',
        ExportOutcome.downloaded => '$fileName was downloaded.',
        ExportOutcome.cancelled => 'Export cancelled.',
      };
    } on Exception {
      message = 'The file could not be created. Please try again.';
    }

    if (!mounted) {
      return;
    }

    setState(() {
      exporting = null;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Health Report'),
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
            ..._buildSummary(),
            const SizedBox(height: 28),
            _buildExportButtons(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSummary() {
    if (isLoading && report == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (loadError != null) {
      return [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Text(loadError!, textAlign: TextAlign.center),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      ];
    }

    final r = report!;
    String n(double? v) => v == null ? '—' : formatReportNumber(v);

    return [
      Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFFE95D76),
              background: const Color(0xFFFFEEF1),
              title: 'Avg. Glucose',
              value: r.averageGlucose == null
                  ? '—'
                  : r.averageGlucose!.round().toString(),
              unit: 'mg/dL',
              detail: r.glucose.length == 1
                  ? '1 measurement'
                  : '${r.glucose.length} measurements',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              icon: Icons.medication_rounded,
              iconColor: const Color(0xFF765BD4),
              background: const Color(0xFFF0ECFF),
              title: 'Insulin',
              value: n(r.insulinTotal),
              unit: 'units',
              detail: r.insulin.length == 1
                  ? '1 dose'
                  : '${r.insulin.length} doses',
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
              value: '${r.meals.length}',
              unit: 'records',
              detail: '${n(r.carbsTotal)} g carbs',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              icon: Icons.directions_run_rounded,
              iconColor: const Color(0xFF35B779),
              background: const Color(0xFFEAF8EE),
              title: 'Activity',
              value: n(r.activityMinutes),
              unit: 'min',
              detail: r.activities.length == 1
                  ? '1 activity'
                  : '${r.activities.length} activities',
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      _buildPreviewCard(r),
    ];
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0ECFF), Color(0xFFF8F5FF)],
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
                  'Export your glucose, insulin, meal and activity records as '
                  'a PDF for your doctor or a CSV for a spreadsheet.',
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

  Widget _buildPreviewCard(HealthReport r) {
    String n(double? v, String unit) =>
        v == null ? '—' : '${formatReportNumber(v)} $unit';

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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                        '${_formatDate(r.from)} - ${_formatDate(r.to)}',
                  ),
                  const Divider(height: 20),
                  _PreviewRow(
                    label: 'Lowest / Highest',
                    value: r.glucose.isEmpty
                        ? '—'
                        : '${n(r.lowestGlucose, '')}/ '
                            '${n(r.highestGlucose, 'mg/dL')}',
                  ),
                  const Divider(height: 20),
                  _PreviewRow(
                    label: 'Time in Range (70-180)',
                    value: r.glucose.isEmpty
                        ? '—'
                        : '${r.inRangePercent.round()}%',
                  ),
                  const Divider(height: 20),
                  _PreviewRow(
                    label: 'Rows in CSV',
                    value: '${r.glucose.length + r.insulin.length + r.meals.length + r.activities.length}',
                  ),
                ],
              ),
            ),
            if (r.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'No records in this period. Choose other dates to export.',
                style: TextStyle(fontSize: 12, color: Color(0xFFE85D75)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExportButtons() {
    final canExport =
        report != null && !report!.isEmpty && exporting == null && !isLoading;

    Widget spinner() => const SizedBox(
          width: 19,
          height: 19,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        );

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: canExport ? () => _export('pdf') : null,
            icon: exporting == 'pdf'
                ? spinner()
                : const Icon(Icons.picture_as_pdf_rounded),
            label: Text(
              exporting == 'pdf' ? 'Creating PDF...' : 'Export PDF Report',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF168AF7),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF8DBEF0),
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
          height: 52,
          child: OutlinedButton.icon(
            onPressed: canExport ? () => _export('csv') : null,
            icon: exporting == 'csv'
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_chart_outlined),
            label: Text(
              exporting == 'csv' ? 'Creating CSV...' : 'Export CSV',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
            ),
          ),
        ),
      ],
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
