import '../services/api_client.dart';
import '../services/api_exception.dart';

/// One thing the food-vision model saw in the photo.
class FoodDetection {
  /// As the model names it, e.g. "pizza", "banana".
  final String name;

  /// 0..1, the highest of the boxes with this name.
  final double confidence;

  /// How many boxes had this name (e.g. 2 bananas).
  final int count;

  const FoodDetection({
    required this.name,
    required this.confidence,
    this.count = 1,
  });

  /// "Pizza", "Hot dog"
  String get label =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

  /// "82%"
  String get confidenceText => '${(confidence * 100).round()}%';

  /// Pre-selected when the model is fairly sure.
  bool get isLikely => confidence >= 0.5;
}

/// The food-vision service cannot be reached through the backend yet.
class FoodRecognitionUnavailable implements Exception {
  const FoodRecognitionUnavailable();
}

/// Sends a meal photo for recognition and reads the answer of Ayşenur's
/// food-vision service (food-vision-service/app.py, POST /upload-image):
///   { "success": true, "detections": [ {"name": "pizza", "confidence": 0.91} ] }
///
/// The app talks to Spring only. Spring has no endpoint that forwards to
/// food-vision yet; [path] is the proposed one (multipart field "image",
/// like POST /ai/voice), the only line to change if Spring picks another.
/// Until it exists the backend answers 404 and [recognize] throws
/// [FoodRecognitionUnavailable], so the meal can still be typed in.
class FoodRecognizer {
  FoodRecognizer({ApiClient? api}) : _api = api ?? apiClient;

  static const String path = '/ai/food';
  static const String field = 'image';

  /// food-vision refuses images over 5 MB.
  static const int maxBytes = 5 * 1024 * 1024;

  /// Things a general detection model often finds next to food: not food.
  static const Set<String> notFood = {
    'person',
    'dining table',
    'fork',
    'knife',
    'spoon',
    'bowl',
    'cup',
    'bottle',
    'wine glass',
    'chair',
    'cell phone',
  };

  final ApiClient _api;

  /// Food found in the photo, most certain first; [filename] tells the type
  /// (".jpg", ".png" or ".webp").
  Future<List<FoodDetection>> recognize(List<int> bytes, String filename) async {
    final dynamic json;

    try {
      json = await _api.postFile(path, field: field, bytes: bytes, filename: filename);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405 || e.statusCode == 501) {
        throw const FoodRecognitionUnavailable();
      }
      rethrow;
    }

    return parseDetections(json as Map<String, dynamic>);
  }

  /// Groups the boxes by name (keeping the highest confidence), drops
  /// non-food objects, most certain first.
  static List<FoodDetection> parseDetections(Map<String, dynamic> json) {
    final byName = <String, FoodDetection>{};

    for (final item in json['detections'] as List<dynamic>? ?? const []) {
      final map = item as Map<String, dynamic>;
      final name = (map['name'] as String? ?? '').trim().toLowerCase();
      final confidence = (map['confidence'] as num?)?.toDouble() ?? 0;

      if (name.isEmpty || notFood.contains(name)) {
        continue;
      }

      final previous = byName[name];
      byName[name] = FoodDetection(
        name: name,
        confidence: previous == null || confidence > previous.confidence
            ? confidence
            : previous.confidence,
        count: (previous?.count ?? 0) + 1,
      );
    }

    return byName.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }
}

final foodRecognizer = FoodRecognizer();
