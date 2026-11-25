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

/// A recognised food the patient confirmed, with the portion they chose
/// (SMALL, MEDIUM or LARGE).
class ConfirmedFood {
  final FoodPrediction prediction;
  final String portion;

  const ConfirmedFood(this.prediction, {this.portion = 'MEDIUM'});

  /// Rough carbs of the chosen portion, null if unknown.
  double? get carbsG => prediction.carbsFor(portion);

  /// Rough kcal, protein and fat of the chosen portion, null if unknown.
  double? get kcal => prediction.kcalFor(portion);
  double? get proteinG => prediction.proteinFor(portion);
  double? get fatG => prediction.fatFor(portion);
}

/// What the patient chose in the camera screen, put into the meal form.
class FoodPhotoResult {
  /// The confirmed foods first, then anything typed by hand.
  final List<String> foods;

  /// The recognised foods the patient confirmed (one for a single dish,
  /// several for a plate), empty if they only typed.
  final List<ConfirmedFood> confirmedFoods;

  const FoodPhotoResult({required this.foods, this.confirmedFoods = const []});

  /// The first confirmed food, null if they only typed.
  FoodPrediction? get confirmed =>
      confirmedFoods.isEmpty ? null : confirmedFoods.first.prediction;

  /// A food came from the recognition: the meal is saved as AI_PHOTO.
  bool get fromRecognition => confirmedFoods.isNotEmpty;

  /// For the meal log's aiConfidence (0..1, at most 3 decimals): the lowest
  /// confidence of the confirmed foods.
  double? get aiConfidence {
    if (confirmedFoods.isEmpty) {
      return null;
    }
    final lowest = confirmedFoods
        .map((f) => f.prediction.confidence)
        .reduce((a, b) => a < b ? a : b);
    return double.parse(lowest.toStringAsFixed(3));
  }

  /// Rough carbs of the confirmed foods and portions. Null when there is none
  /// or one of them has no estimate: a part of the meal is never counted as
  /// 0 g, the patient types the carbs instead.
  double? get carbsEstimate => _sum((f) => f.carbsG);

  /// Rough kcal, protein and fat of the confirmed foods and portions, saved
  /// with the meal next to the carbs. Null under the same rule as
  /// [carbsEstimate].
  double? get kcalEstimate => _sum((f) => f.kcal);
  double? get proteinEstimate => _sum((f) => f.proteinG);
  double? get fatEstimate => _sum((f) => f.fatG);

  /// Sum of [value] over the confirmed foods, 1 decimal (what the meal log
  /// accepts); null when there is none or one of them is unknown.
  double? _sum(double? Function(ConfirmedFood food) value) {
    if (confirmedFoods.isEmpty || confirmedFoods.any((f) => value(f) == null)) {
      return null;
    }
    final sum =
        confirmedFoods.fold<double>(0, (total, f) => total + value(f)!);
    return double.parse(sum.toStringAsFixed(1));
  }

  /// "Pizza, Salad"
  String get description => foods.join(', ');
}

/// One food region of a plate with several foods, as the patient set it.
class _PlateChoice {
  _PlateChoice(this.item) : included = !item.lowConfidence;

  final DetectedFood item;

  /// Which of the region's guesses is chosen.
  int index = 0;

  /// The patient ate it (ticked).
  bool included;

  String portion = 'MEDIUM';

  FoodPrediction get prediction => item.predictions[index];
}

/// Photo of a meal -> the model's guesses (at most 3 for one dish, or one per
/// food when the plate has several) -> the patient picks the right ones and
/// their portions and adds what was missed -> back to the meal form, where
/// meal type, time and carbs are checked and the meal is saved. Nothing is
/// saved here.
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

  /// Portion of the picked guess (one dish).
  String portion = 'MEDIUM';

  /// Several foods on the plate: one entry per food, instead of [predictions].
  List<_PlateChoice> plate = [];

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
        portion = 'MEDIUM';
        plate = found.showsPlate
            ? [for (final item in found.items) _PlateChoice(item)]
            : [];
        recognitionNote = found.note;
        stage = _Stage.results;
        notice = found.predictions.isEmpty
            ? 'No food was recognised in this photo. Add what you ate below.'
            : plate.isNotEmpty
                ? (plate.any((c) => !c.included)
                    ? 'DiaMate is not sure about some foods. Tick only what '
                        'you ate.'
                    : null)
                : found.lowConfidence
                    ? 'DiaMate is not sure about this photo. Pick the right '
                        'food if it is listed, or add it below.'
                    : null;
      });
    } on FoodRecognitionUnavailable {
      if (!mounted) {
        return;
      }

      setState(() {
        predictions = [];
        selected = null;
        plate = [];
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
        plate = [];
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

  /// The recognised foods the patient confirmed, with their portions.
  List<ConfirmedFood> get _confirmedFoods => plate.isNotEmpty
      ? [
          for (final choice in plate)
            if (choice.included)
              ConfirmedFood(choice.prediction, portion: choice.portion),
        ]
      : [if (_confirmed != null) ConfirmedFood(_confirmed!, portion: portion)];

  List<String> get _chosenFoods {
    final foods = <String>[];
    for (final name in [
      for (final food in _confirmedFoods) food.prediction.displayName,
      ...manual,
    ]) {
      if (!foods.any((f) => f.toLowerCase() == name.toLowerCase())) {
        foods.add(name);
      }
    }
    return foods;
  }

  void _useFoods() {
    final foods = _chosenFoods;
    if (foods.isEmpty) {
      return;
    }

    Navigator.pop(
      context,
      FoodPhotoResult(foods: foods, confirmedFoods: _confirmedFoods),
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
      if (plate.isNotEmpty) ...[
        const Text(
          'Foods on your plate',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tick what you ate, choose the portion. Tap ⋮ if a name is wrong.',
          style: TextStyle(fontSize: 12, color: _muted),
        ),
        const SizedBox(height: 8),
        for (final choice in plate) _buildPlateChoice(choice),
        if (recognitionNote != null) ...[
          const SizedBox(height: 4),
          Text(
            recognitionNote!,
            style: const TextStyle(fontSize: 11, height: 1.4, color: _muted),
          ),
        ],
        const SizedBox(height: 12),
      ] else if (predictions.isNotEmpty) ...[
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
                portion = 'MEDIUM';
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
                  if (p.macrosText != null) p.macrosText!,
                ].join(' · '),
              ),
            ),
          ),
        if (_confirmed != null && _confirmed!.portionOptions.isNotEmpty) ...[
          const SizedBox(height: 4),
          _buildPortions(
            _confirmed!,
            portion,
            (size) => setState(() => portion = size),
          ),
        ],
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

  Widget _buildPlateChoice(_PlateChoice choice) {
    final p = choice.prediction;
    final carbs = p.carbsFor(choice.portion);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              onTap: () => setState(() => choice.included = !choice.included),
              leading: Icon(
                choice.included
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: choice.included ? _orange : _muted,
              ),
              title: Text(
                p.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  '${p.confidenceText} sure',
                  carbs == null
                      ? 'carbs unknown'
                      : 'about ${_amount(carbs)} g carbs',
                ].join(' · '),
              ),
              trailing: choice.item.predictions.length < 2
                  ? null
                  : PopupMenuButton<int>(
                      tooltip: 'Not ${p.displayName}?',
                      onSelected: (index) => setState(() {
                        choice.index = index;
                        choice.included = true;
                        choice.portion = 'MEDIUM';
                      }),
                      itemBuilder: (context) => [
                        for (var i = 0; i < choice.item.predictions.length; i++)
                          PopupMenuItem(
                            value: i,
                            child: Text(
                              '${choice.item.predictions[i].displayName} '
                              '(${choice.item.predictions[i].confidenceText})',
                            ),
                          ),
                      ],
                    ),
            ),
            if (choice.included && p.portionOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildPortions(
                  p,
                  choice.portion,
                  (size) => setState(() => choice.portion = size),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Small / medium / large chips with their grams and rough carbs.
  Widget _buildPortions(
    FoodPrediction p,
    String current,
    ValueChanged<String> onSelected,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final option in p.portionOptions)
          ChoiceChip(
            label: Text(
              '${option.label} · ${_amount(option.grams)} g'
              '${option.carbsG == null ? '' : ' · ${_amount(option.carbsG!)} g carbs'}',
              style: const TextStyle(fontSize: 12),
            ),
            selected: option.size == current,
            onSelected: (_) => onSelected(option.size),
          ),
      ],
    );
  }

  static String _amount(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

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
                portion = 'MEDIUM';
                plate = [];
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
