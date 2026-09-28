import 'package:flutter/material.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  String? selectedFileName;
  bool isImporting = false;

  final List<Map<String, String>> previewData = [
    {
      'date': '08 Sep',
      'time': '08:30',
      'glucose': '105',
      'status': 'Valid',
    },
    {
      'date': '08 Sep',
      'time': '12:15',
      'glucose': '118',
      'status': 'Valid',
    },
    {
      'date': '08 Sep',
      'time': '18:40',
      'glucose': '145',
      'status': 'Valid',
    },
    {
      'date': '09 Sep',
      'time': '08:10',
      'glucose': 'abc',
      'status': 'Invalid',
    },
  ];

  int get invalidCount {
    return previewData
        .where((item) => item['status'] == 'Invalid')
        .length;
  }

  int get validCount {
    return previewData
        .where((item) => item['status'] == 'Valid')
        .length;
  }

  void _selectFile() {
    setState(() {
      selectedFileName = 'blood_glucose_data.csv';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'CSV file selected.',
        ),
      ),
    );
  }

  Future<void> _importData() async {
    if (selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a CSV file first.',
          ),
        ),
      );
      return;
    }

    if (invalidCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$invalidCount invalid record(s) found. Please review the data.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isImporting = true;
    });

    await Future.delayed(
      const Duration(milliseconds: 800),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      isImporting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'CSV data imported successfully.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Import CSV'),
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
              'Select File',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
              ),
            ),

            const SizedBox(height: 10),

            _buildFilePickerCard(),

            const SizedBox(height: 22),

            if (selectedFileName != null) ...[
              const Text(
                'Selected File',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 10),

              _buildSelectedFileCard(),

              const SizedBox(height: 22),

              const Text(
                'Data Preview',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF172033),
                ),
              ),

              const SizedBox(height: 10),

              _buildPreviewCard(),

              const SizedBox(height: 16),

              _buildValidationCard(),
            ],

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isImporting
                    ? null
                    : _importData,
                icon: isImporting
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.cloud_upload_rounded,
                      ),
                label: Text(
                  isImporting
                      ? 'Importing...'
                      : 'Import Data',
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
              Icons.upload_file_rounded,
              size: 31,
              color: Color(0xFF168AF7),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Import Health Data',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF233247),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Import blood glucose data from a CSV file.',
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

  Widget _buildFilePickerCard() {
    return Card(
      child: InkWell(
        onTap: _selectFile,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  color: Color(0xFF168AF7),
                  size: 32,
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'Choose a CSV file',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Select a file containing your blood glucose data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF718096),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _selectFile,
                  icon: const Icon(
                    Icons.folder_open_rounded,
                    size: 19,
                  ),
                  label: const Text(
                    'Choose File',
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(145, 44),
                    backgroundColor:
                        const Color(0xFFEAF5FF),
                    foregroundColor:
                        const Color(0xFF168AF7),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF8EE),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF35B779),
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selected file',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF718096),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    selectedFileName ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            IconButton(
              onPressed: _selectFile,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              tooltip: 'Change file',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Blood Glucose Records',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$validCount valid',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF35B779),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF596777),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 55,
                    child: Text(
                      'Time',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF596777),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      'Glucose',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF596777),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Status',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF596777),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            ...previewData.map(
              (item) => _PreviewRow(
                date: item['date']!,
                time: item['time']!,
                glucose: item['glucose']!,
                status: item['status']!,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationCard() {
    final hasErrors = invalidCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasErrors
            ? const Color(0xFFFFEEF1)
            : const Color(0xFFEAF8EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            hasErrors
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            color: hasErrors
                ? const Color(0xFFE95D76)
                : const Color(0xFF35B779),
            size: 22,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  hasErrors
                      ? 'Review required'
                      : 'Data ready to import',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: hasErrors
                        ? const Color(0xFFBA4A61)
                        : const Color(0xFF2D8758),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  hasErrors
                      ? '$invalidCount record is invalid. Please review the data before importing.'
                      : 'All records passed validation.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: hasErrors
                        ? const Color(0xFF805E66)
                        : const Color(0xFF587061),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String date;
  final String time;
  final String glucose;
  final String status;

  const _PreviewRow({
    required this.date,
    required this.time,
    required this.glucose,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = status == 'Valid';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFE9EEF3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 11,
              ),
            ),
          ),

          SizedBox(
            width: 55,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 11,
              ),
            ),
          ),

          SizedBox(
            width: 70,
            child: Text(
              glucose == 'abc'
                  ? 'Invalid'
                  : '$glucose mg/dL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: glucose == 'abc'
                    ? const Color(0xFFE95D76)
                    : const Color(0xFF334155),
              ),
            ),
          ),

          SizedBox(
            width: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: isValid
                    ? const Color(0xFFEAF8EE)
                    : const Color(0xFFFFEEF1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: isValid
                      ? const Color(0xFF2D8758)
                      : const Color(0xFFBA4A61),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}