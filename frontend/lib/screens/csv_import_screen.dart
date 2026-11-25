import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/glucose_csv.dart';
import '../data/glucose_store.dart';
import '../data/log_store.dart';
import '../services/api_exception.dart';
import '../widgets/ai_chat_button.dart';

/// A file the patient picked: its name and bytes.
typedef PickedCsvFile = ({String name, Uint8List bytes});

/// Opens the phone's file picker for a .csv file; null when cancelled.
Future<PickedCsvFile?> pickCsvFromDevice() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['csv', 'txt'],
  );
  if (file == null) {
    return null;
  }
  return (name: file.name, bytes: await file.readAsBytes());
}

/// Import blood glucose readings from a CSV file: pick a file, check every
/// row (GlucoseCsv), then save the valid rows one by one through the
/// glucose-logs API. Rows with a problem are listed and skipped.
class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key, this.pickFile, this.store});

  /// Defaults to [pickCsvFromDevice]; tests pass a fake.
  final Future<PickedCsvFile?> Function()? pickFile;

  /// Defaults to [glucoseStore]; tests pass one with a fake backend.
  final LogStore<GlucoseRecord>? store;

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  /// Rows shown in the preview; the rest are counted only.
  static const int previewLimit = 50;

  String? selectedFileName;
  List<CsvGlucoseRow> rows = const [];
  String? fileError;
  bool isImporting = false;
  int importedSoFar = 0;

  LogStore<GlucoseRecord> get _store => widget.store ?? glucoseStore;

  List<CsvGlucoseRow> get validRows => rows.where((r) => r.isValid).toList();

  int get invalidCount => rows.length - validRows.length;

  int get validCount => validRows.length;

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectFile() async {
    if (isImporting) {
      return;
    }

    PickedCsvFile? picked;
    try {
      picked = await (widget.pickFile ?? pickCsvFromDevice)();
    } on Exception {
      if (mounted) {
        _show('Could not open the file.');
      }
      return;
    }
    if (picked == null || !mounted) {
      return;
    }

    final text = utf8.decode(picked.bytes, allowMalformed: true);
    List<CsvGlucoseRow> parsed = const [];
    String? error;
    try {
      parsed = GlucoseCsv.parse(text);
      if (parsed.isEmpty) {
        error = 'The file has no readings under the header line.';
      }
    } on FormatException catch (e) {
      error = e.message;
    }

    setState(() {
      selectedFileName = picked!.name;
      rows = parsed;
      fileError = error;
      importedSoFar = 0;
    });
  }

  Future<void> _importData() async {
    if (selectedFileName == null) {
      _show('Please select a CSV file first.');
      return;
    }
    final toSave = validRows;
    if (toSave.isEmpty) {
      _show('There is no valid reading to import.');
      return;
    }

    setState(() {
      isImporting = true;
      importedSoFar = 0;
    });

    var saved = 0;
    var queued = 0;
    final failed = <String>[];

    for (final row in toSave) {
      try {
        final result = await _store.create(row.requestBody());
        if (result == null) {
          queued++;
        } else {
          saved++;
        }
      } on ApiException catch (e) {
        failed.add('Line ${row.line}: ${e.message}');
      }
      if (!mounted) {
        return;
      }
      setState(() => importedSoFar++);
    }

    setState(() => isImporting = false);

    final parts = [
      if (saved > 0) '$saved reading${saved == 1 ? '' : 's'} imported',
      if (queued > 0) '$queued saved on this phone, sent when online',
      if (failed.isNotEmpty) '${failed.length} rejected',
      if (invalidCount > 0) '$invalidCount skipped',
    ];
    _show('${parts.join(', ')}.');

    if (failed.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Some readings were not saved'),
          content: SingleChildScrollView(
            child: Text(failed.take(20).join('\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: const AiChatButton(),
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Import CSV'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, AiChatButton.scrollClearance),
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

            const SizedBox(height: 12),

            _buildFormatHint(),

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

              if (fileError != null)
                _buildFileErrorCard()
              else ...[
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
            ],

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isImporting ||
                        (selectedFileName != null && validCount == 0)
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
                      ? 'Importing $importedSoFar of $validCount...'
                      : validCount > 0
                          ? 'Import $validCount reading${validCount == 1 ? '' : 's'}'
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
              color: Colors.white.withValues(alpha: 0.82),
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
    return SizedBox(
      width: double.infinity,
      child: Card(
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

            for (final row in rows.take(previewLimit))
              _PreviewRow(row: row),

            if (rows.length > previewLimit)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '+ ${rows.length - previewLimit} more rows',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF718096),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Color(0xFF168AF7),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'First line: column names. Needed: date, time and glucose '
              '(mg/dL). Optional: context (Fasting, Before meal, After '
              'meal, Bedtime, Exercise, Other) and notes.\n'
              'Example: 2026-11-23,08:30,105',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: Color(0xFF4A5D70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEF1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFE95D76),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This file cannot be read',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFBA4A61),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileError!,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFF805E66),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                      ? 'Some rows will be skipped'
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
                      ? '$invalidCount of ${rows.length} rows have a problem '
                          'and will be skipped. '
                          '$validCount can be imported.'
                      : 'All ${rows.length} readings passed validation.',
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
  final CsvGlucoseRow row;

  const _PreviewRow({required this.row});

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final at = row.measuredAt;
    final isValid = row.isValid;
    final date = at == null
        ? (row.rawDate.isEmpty ? '—' : row.rawDate)
        : '${_two(at.day)}.${_two(at.month)}.${at.year}';
    final time = at == null
        ? (row.rawTime.isEmpty ? '—' : row.rawTime)
        : '${_two(at.hour)}:${_two(at.minute)}';
    final glucose = row.value == null
        ? (row.rawValue.isEmpty ? '—' : row.rawValue)
        : '${row.value} mg/dL';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 11,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE9EEF3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  date,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              SizedBox(
                width: 55,
                child: Text(
                  time,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  glucose,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isValid
                        ? const Color(0xFF334155)
                        : const Color(0xFFE95D76),
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
                    isValid ? 'Valid' : 'Invalid',
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
          if (!isValid)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Line ${row.line}: ${row.problem}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFBA4A61),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
