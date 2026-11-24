import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/food_recognition.dart';
import '../services/api_exception.dart';

/// A photo taken or chosen for recognition.
class PickedPhoto {
  final Uint8List bytes;

  /// Ends in .jpg, .png or .webp (food-vision decides the type by it).
  final String filename;

  const PickedPhoto({required this.bytes, required this.filename});
}

typedef PhotoPicker = Future<PickedPhoto?> Function(ImageSource source);

/// Camera or gallery through image_picker, scaled down so a phone photo
/// stays well under food-vision's 5 MB limit.
Future<PickedPhoto?> pickMealPhoto(ImageSource source) async {
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 85,
  );

  if (file == null) {
    return null;
  }

  final name = file.name.toLowerCase();
  final extension = name.endsWith('.png')
      ? '.png'
      : name.endsWith('.webp')
          ? '.webp'
          : '.jpg';

  return PickedPhoto(
    bytes: await file.readAsBytes(),
    filename: 'meal$extension',
  );
}

/// What the patient chose in the camera screen, put into the meal form.
class FoodPhotoResult {
  /// The confirmed guess (if any) first, then anything typed by hand.
  final List<String> foods;

  /// The model's guess the patient confirmed, null if they only typed.
  final FoodPrediction? confirmed;

  const FoodPhotoResult({required this.foods, this.confirmed});

  /// A food came from the recognition: the meal is saved as AI_PHOTO.
  bool get fromRecognition => confirmed != null;

  /// For the meal log's aiConfidence (0..1, at most 3 decimals).
  double? get aiConfidence => confirmed == null
      ? null
      : double.parse(confirmed!.confidence.toStringAsFixed(3));

  /// Rough carbs of a typical serving of the confirmed food, null if unknown.
  double? get carbsEstimate => confirmed?.carbsGPerServing;

  /// "Pizza, Salad"
  String get description => foods.join(', ');
}

/// Photo of a meal -> the model's guesses (at most 3, for the whole plate)
/// -> the patient picks the right one or none and adds what was missed ->
/// back to the meal form, where meal type, time and carbs are checked and the
/// meal is saved. Nothing is saved here.
class FoodCameraScreen extends StatefulWidget {
  const FoodCameraScreen({super.key, this.picker, this.recognizer});

  /// Defaults to [pickMealPhoto]; tests pass a fake.
  final PhotoPicker? picker;

  /// Defaults to [foodRecognizer].
  final FoodRecognizer? recognizer;

  @override
  State<FoodCameraScreen> createState() => _FoodCameraScreenState();
}

enum _Stage { choose, analysing, results }

class _FoodCameraScreenState extends State<FoodCameraScreen> {
  static const _orange = Color(0xFFF0A126);
  static const _muted = Color(0xFF718096);

  _Stage stage = _Stage.choose;
  PickedPhoto? photo;

  List<FoodPrediction> predictions = [];

  /// The guess the patient picked ([FoodPrediction.food]), or null.
  String? selected;

  /// The backend's note on the numbers (shown under the guesses).
  String? recognitionNote;

  /// Foods typed by hand, kept in the order added.
  final List<String> manual = [];

  /// Why there are no detections: not connected yet, an error, or null.
  String? notice;
  bool noticeIsError = false;

  final _manualController = TextEditingController();

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    PickedPhoto? picked;

    try {
      picked = await (widget.picker ?? pickMealPhoto)(source);
    } catch (_) {
      _showMessage(
        source == ImageSource.camera
            ? 'The camera could not be opened. Please allow camera access '
                'or choose a photo from the gallery.'
            : 'The photo could not be opened.',
      );
      return;
    }

    if (picked == null || !mounted) {
      return;
    }

    if (picked.bytes.length > FoodRecognizer.maxBytes) {
      _showMessage('That photo is too large (over 5 MB). Please try another.');
      return;
    }

    setState(() {
      photo = picked;
    });

    await _analyse();
  }

  Future<void> _analyse() async {
    final current = photo;
    if (current == null) {
      return;
    }

    setState(() {
      stage = _Stage.analysing;
      notice = null;
      noticeIsError = false;
    });

    try {
      final found = await (widget.recognizer ?? foodRecognizer)
          .recognize(current.bytes, current.filename);

      if (!mounted) {
        return;
      }

      setState(() {
        predictions = found.predictions;
        selected = found.suggested?.food;
        recognitionNote = found.note;
        stage = _Stage.results;
        notice = found.predictions.isEmpty
            ? 'No food was recognised in this photo. Add what you ate below.'
            : found.lowConfidence
                ? 'DiaMate is not sure about this photo. Pick the right food '
                    'if it is listed, or add it below.'
                : null;
      });
    } on FoodRecognitionUnavailable {
      if (!mounted) {
        return;
      }

      setState(() {
        predictions = [];
        selected = null;
        stage = _Stage.results;
        notice = 'Food recognition is not connected yet. Add what you see in '
            'the photo below.';
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        predictions = [];
        selected = null;
        stage = _Stage.results;
        notice = e.message;
        noticeIsError = true;
      });
    }
  }

  void _addManual() {
    final text = _manualController.text.trim();
    if (text.isEmpty) {
      return;
    }

    setState(() {
      if (!manual.any((m) => m.toLowerCase() == text.toLowerCase())) {
        manual.add(text);
      }
      _manualController.clear();
    });
  }

  FoodPrediction? get _confirmed {
    for (final p in predictions) {
      if (p.food == selected) {
        return p;
      }
    }
    return null;
  }

  List<String> get _chosenFoods => [
        if (_confirmed != null) _confirmed!.displayName,
        ...manual.where(
          (m) => m.toLowerCase() != _confirmed?.displayName.toLowerCase(),
        ),
      ];

  void _useFoods() {
    final foods = _chosenFoods;
    if (foods.isEmpty) {
      return;
    }

    Navigator.pop(
      context,
      FoodPhotoResult(foods: foods, confirmed: _confirmed),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        title: const Text('Meal Photo'),
        backgroundColor: const Color(0xFFF7FAFD),
      ),
      body: SafeArea(
        child: switch (stage) {
          _Stage.choose => _buildChoose(),
          _ => _buildPhotoAndResults(),
        },
      ),
      bottomNavigationBar: stage == _Stage.results ? _buildBottomBar() : null,
    );
  }

  Widget _buildChoose() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF2E2), Color(0xFFFFF8ED)],
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Row(
            children: [
              Icon(Icons.photo_camera_rounded, size: 34, color: _orange),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Take a photo of your plate. DiaMate suggests the foods it '
                  'sees; you choose what you really ate.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _SourceButton(
          icon: Icons.photo_camera_outlined,
          title: 'Take a photo',
          subtitle: 'Use the camera',
          onTap: () => _pick(ImageSource.camera),
        ),
        const SizedBox(height: 12),
        _SourceButton(
          icon: Icons.photo_library_outlined,
          title: 'Choose from gallery',
          subtitle: 'Use a photo you already took',
          onTap: () => _pick(ImageSource.gallery),
        ),
        const SizedBox(height: 18),
        const Text(
          'The photo is only used to recognise the food and is not stored. '
          'Carbohydrate values are rough estimates: check them, and do not '
          'use them to calculate an insulin dose.',
          style: TextStyle(fontSize: 11, height: 1.4, color: _muted),
        ),
      ],
    );
  }

  Widget _buildPhotoAndResults() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.memory(
              photo!.bytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFF1F5F9),
                child: const Icon(Icons.image_outlined,
                    size: 40, color: Color(0xFF9AA8B7)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (stage == _Stage.analysing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Recognising food…'),
              ],
            ),
          )
        else ..._buildResults(),
      ],
    );
  }

  List<Widget> _buildResults() {
    return [
      if (notice != null) ...[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: noticeIsError
                ? const Color(0xFFFFEFF1)
                : const Color(0xFFFFF7EA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(
                noticeIsError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                color: noticeIsError ? const Color(0xFFE85D75) : _orange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  notice!,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ),
              if (noticeIsError)
                TextButton(onPressed: _analyse, child: const Text('Retry')),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (predictions.isNotEmpty) ...[
        const Text(
          'Is this what you ate?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Pick the right one, or none if all are wrong.',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 8),
        for (final p in predictions)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => setState(() {
                // Tapping the picked one again un-picks it.
                selected = selected == p.food ? null : p.food;
              }),
              leading: Icon(
                selected == p.food
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected == p.food ? _orange : _muted,
              ),
              title: Text(
                p.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  '${p.confidenceText} sure',
                  if (p.carbsText != null) p.carbsText!,
                ].join(' · '),
              ),
            ),
          ),
        if (recognitionNote != null) ...[
          const SizedBox(height: 4),
          Text(
            recognitionNote!,
            style: const TextStyle(fontSize: 11, height: 1.4, color: _muted),
          ),
        ],
        const SizedBox(height: 12),
      ],
      const Text(
        'Add something else',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _manualController,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addManual(),
              decoration: const InputDecoration(
                hintText: 'e.g. Rice, Salad',
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add',
            onPressed: _addManual,
            icon: const Icon(Icons.add_circle_rounded, color: _orange),
          ),
        ],
      ),
      if (manual.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final m in manual)
              InputChip(
                label: Text(m),
                onDeleted: () => setState(() => manual.remove(m)),
              ),
          ],
        ),
      ],
    ];
  }

  Widget _buildBottomBar() {
    final foods = _chosenFoods;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() {
                stage = _Stage.choose;
                photo = null;
                predictions = [];
                selected = null;
                recognitionNote = null;
                notice = null;
              }),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Retake'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: foods.isEmpty ? null : _useFoods,
                style: FilledButton.styleFrom(backgroundColor: _orange),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  foods.isEmpty
                      ? 'Choose a food'
                      : foods.length == 1
                          ? 'Use 1 food'
                          : 'Use ${foods.length} foods',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFFFF2E2),
          child: Icon(icon, color: const Color(0xFFF0A126)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
