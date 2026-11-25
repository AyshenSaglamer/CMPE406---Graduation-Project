import '../services/api_client.dart';
import '../services/api_exception.dart';

/// A one-tap portion of a food: SMALL (half a typical serving), MEDIUM (a
/// typical serving) or LARGE (one and a half), with its rough nutrition.
class PortionOption {
  final String size;
  final double grams;
  final double? carbsG;
  final double? kcal;
  final double? proteinG;
  final double? fatG;

  const PortionOption({
    required this.size,
    required this.grams,
    this.carbsG,
    this.kcal,
    this.proteinG,
    this.fatG,
  });

  static PortionOption? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final size = json['size'] as String?;
    final grams = (json['grams'] as num?)?.toDouble();
    if (size == null || grams == null) {
      return null;
    }
    return PortionOption(
      size: size,
      grams: grams,
      carbsG: (json['carbsG'] as num?)?.toDouble(),
      kcal: (json['kcal'] as num?)?.toDouble(),
      proteinG: (json['proteinG'] as num?)?.toDouble(),
      fatG: (json['fatG'] as num?)?.toDouble(),
    );
  }

  /// "Small", "Medium", "Large".
  String get label => size.isEmpty
      ? size
      : size[0].toUpperCase() + size.substring(1).toLowerCase();
}

/// One guess of the photo model for the whole plate.
class FoodPrediction {
  /// The model's class name, e.g. "apple_pie".
  final String food;

  /// The name to show, e.g. "Apple pie".
  final String displayName;

  /// 0..1.
  final double confidence;

  /// food_catalog id, null when the food is not in the catalog.
  final int? foodCatalogId;

  /// Rough carbohydrate estimate for a typical serving, null if unknown.
  final double? carbsGPerServing;

  /// The typical serving the estimate is for, null if unknown.
  final double? typicalServingG;

  /// Rough calories, protein and fat of a typical serving, null if unknown.
  final double? kcalPerServing;
  final double? proteinGPerServing;
  final double? fatGPerServing;

  /// Small / medium / large, empty when the serving is not known.
  final List<PortionOption> portionOptions;

  /// false = rough estimate, never to be used for insulin dosing.
  final bool nutritionVerified;

  const FoodPrediction({
    required this.food,
    required this.displayName,
    required this.confidence,
    this.foodCatalogId,
    this.carbsGPerServing,
    this.typicalServingG,
    this.kcalPerServing,
    this.proteinGPerServing,
    this.fatGPerServing,
    this.portionOptions = const [],
    this.nutritionVerified = false,
  });

  /// The portion of [size], or null when there are no portion options.
  PortionOption? portion(String size) {
    for (final option in portionOptions) {
      if (option.size == size) {
        return option;
      }
    }
    return null;
  }

  /// Rough carbs of the portion of [size]; the typical serving's when the
  /// backend sent no portion options.
  double? carbsFor(String size) =>
      portion(size)?.carbsG ?? (size == 'MEDIUM' ? carbsGPerServing : null);

  /// Rough kcal of the portion of [size], like [carbsFor].
  double? kcalFor(String size) =>
      portion(size)?.kcal ?? (size == 'MEDIUM' ? kcalPerServing : null);

  /// Rough protein of the portion of [size], like [carbsFor].
  double? proteinFor(String size) =>
      portion(size)?.proteinG ??
      (size == 'MEDIUM' ? proteinGPerServing : null);

  /// Rough fat of the portion of [size], like [carbsFor].
  double? fatFor(String size) =>
      portion(size)?.fatG ?? (size == 'MEDIUM' ? fatGPerServing : null);

  factory FoodPrediction.fromJson(Map<String, dynamic> json) {
    final food = (json['food'] as String? ?? '').trim();
    final displayName = (json['displayName'] as String? ?? '').trim();

    return FoodPrediction(
      food: food,
      displayName: displayName.isNotEmpty ? displayName : _readable(food),
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      foodCatalogId: (json['foodCatalogId'] as num?)?.toInt(),
      carbsGPerServing: (json['carbsGPerServing'] as num?)?.toDouble(),
      typicalServingG: (json['typicalServingG'] as num?)?.toDouble(),
      kcalPerServing: (json['kcalPerServing'] as num?)?.toDouble(),
      proteinGPerServing: (json['proteinGPerServing'] as num?)?.toDouble(),
      fatGPerServing: (json['fatGPerServing'] as num?)?.toDouble(),
      portionOptions: [
        for (final option in json['portionOptions'] as List<dynamic>? ?? const [])
          ?PortionOption.fromJson(option),
      ],
      nutritionVerified: json['nutritionVerified'] as bool? ?? false,
    );
  }

  /// "chicken_curry" -> "Chicken curry"
  static String _readable(String food) {
    final words = food.replaceAll('_', ' ').trim();
    return words.isEmpty ? food : words[0].toUpperCase() + words.substring(1);
  }

  /// "82%"
  String get confidenceText => '${(confidence * 100).round()}%';

  /// "about 45 g carbs per serving (250 g)", null when not known.
  String? get carbsText {
    final carbs = carbsGPerServing;
    if (carbs == null) {
      return null;
    }
    final serving = typicalServingG;
    return 'about ${_number(carbs)} g carbs per serving'
        '${serving == null ? '' : ' (${_number(serving)} g)'}';
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  /// "20 g protein · 18 g fat · 480 kcal", null when none is known.
  String? get macrosText {
    final parts = [
      if (proteinGPerServing != null) '${_number(proteinGPerServing!)} g protein',
      if (fatGPerServing != null) '${_number(fatGPerServing!)} g fat',
      if (kcalPerServing != null) '${_number(kcalPerServing!)} kcal',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// One food region of the photo (several foods on one plate), with its own
/// guesses, best first.
class DetectedFood {
  /// [x1, y1, x2, y2], each 0..1 of the photo, or null.
  final List<double>? box;

  /// Even the best guess for this region is below 50 %.
  final bool lowConfidence;

  final List<FoodPrediction> predictions;

  const DetectedFood({
    this.box,
    required this.lowConfidence,
    required this.predictions,
  });

  static DetectedFood? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }
    final predictions = [
      for (final item in json['predictions'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) FoodPrediction.fromJson(item),
    ].where((p) => p.food.isNotEmpty).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    if (predictions.isEmpty) {
      return null;
    }
    final box = [
      for (final v in json['box'] as List<dynamic>? ?? const [])
        if (v is num) v.toDouble(),
    ];
    return DetectedFood(
      box: box.length == 4 ? box : null,
      lowConfidence: json['lowConfidence'] as bool? ??
          predictions.first.confidence < 0.5,
      predictions: predictions,
    );
  }
}

/// The answer of POST /api/v1/ai/food. Nothing is saved by it.
class FoodRecognition {
  /// e.g. "ResNet50".
  final String? model;

  /// Even the best guess is below 50 %: nothing is suggested, the patient
  /// chooses or types the food.
  final bool lowConfidence;

  /// At most 3 guesses for the same plate, best first.
  final List<FoodPrediction> predictions;

  /// What the numbers are, shown to the patient.
  final String? note;

  /// The service found two or more separate foods on the plate: [items] is
  /// then the better answer than [predictions].
  final bool multipleFoods;

  /// Each food region with its own guesses; empty for one dish.
  final List<DetectedFood> items;

  const FoodRecognition({
    this.model,
    required this.lowConfidence,
    required this.predictions,
    this.note,
    this.multipleFoods = false,
    this.items = const [],
  });

  factory FoodRecognition.fromJson(Map<String, dynamic> json) {
    final predictions = [
      for (final item in json['predictions'] as List<dynamic>? ?? const [])
        if (item is Map<String, dynamic>) FoodPrediction.fromJson(item),
    ].where((p) => p.food.isNotEmpty).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return FoodRecognition(
      model: json['model'] as String?,
      lowConfidence: json['lowConfidence'] as bool? ??
          (predictions.isEmpty || predictions.first.confidence < 0.5),
      predictions: predictions,
      note: json['note'] as String?,
      multipleFoods: json['multipleFoods'] as bool? ?? false,
      items: [
        for (final item in json['items'] as List<dynamic>? ?? const [])
          ?DetectedFood.fromJson(item),
      ],
    );
  }

  /// Show the foods on the plate one by one instead of one guess list.
  bool get showsPlate => multipleFoods && items.length >= 2;

  /// The guess to pre-select, or null when the model is not sure enough.
  FoodPrediction? get suggested =>
      lowConfidence || predictions.isEmpty ? null : predictions.first;
}

/// The backend has no food recognition endpoint.
class FoodRecognitionUnavailable implements Exception {
  const FoodRecognitionUnavailable();
}

/// Sends a meal photo to POST /api/v1/ai/food (multipart field "image").
/// Spring checks the image, asks Ayşenur's food-vision service (ResNet50) and
/// adds rough nutrition from food_catalog; the photo is not stored.
///
/// 404 / 405 / 501 (a backend without the endpoint) throw
/// [FoodRecognitionUnavailable], so the meal can still be typed in. Other
/// errors (422 unusable image, 503 service down, 502) stay [ApiException]s
/// with the backend's message.
class FoodRecognizer {
  FoodRecognizer({ApiClient? api}) : _api = api ?? apiClient;

  static const String path = '/ai/food';
  static const String field = 'image';

  /// food-vision refuses images over 5 MB.
  static const int maxBytes = 5 * 1024 * 1024;

  final ApiClient _api;

  /// [filename] tells the type (".jpg", ".png" or ".webp").
  Future<FoodRecognition> recognize(List<int> bytes, String filename) async {
    final dynamic json;

    try {
      json = await _api.postFile(path, field: field, bytes: bytes, filename: filename);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405 || e.statusCode == 501) {
        throw const FoodRecognitionUnavailable();
      }
      rethrow;
    }

    return FoodRecognition.fromJson(json as Map<String, dynamic>);
  }
}

final foodRecognizer = FoodRecognizer();
