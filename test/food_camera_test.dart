import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/food_recognition.dart';
import 'package:gradia/screens/food_camera_screen.dart';
import 'package:gradia/screens/meal_entry_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

/// A 1x1 PNG, so Image.memory has something real to show.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Test-only stand-in for the proposed Spring endpoint in front of
/// food-vision. [status] 404 = the endpoint does not exist yet.
class FakeBackend {
  int status = 200;
  final requests = <http.Request>[];
  List<Map<String, dynamic>> detections = [
    {'name': 'pizza', 'confidence': 0.91},
    {'name': 'banana', 'confidence': 0.62},
    {'name': 'banana', 'confidence': 0.71},
    {'name': 'cup', 'confidence': 0.95},
    {'name': 'broccoli', 'confidence': 0.31},
  ];

  late final client = MockClient((request) async {
    requests.add(request);

    if (request.url.path != '/api/v1/ai/food' || status == 404) {
      return _json(404, {'detail': 'Resource not found'});
    }
    if (status != 200) {
      return _json(status, {'detail': 'Food recognition failed.'});
    }
    return _json(200, {
      'success': true,
      'message': 'Image uploaded and analyzed successfully!',
      'filename': 'abc.jpg',
      'size_bytes': 68,
      'detections': detections,
    });
  });

  static http.Response _json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );
}

void main() {
  late FakeBackend backend;
  late FoodRecognizer recognizer;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'access_token_expires_at':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    backend = FakeBackend();
    recognizer = FoodRecognizer(
      api: ApiClient(httpClient: backend.client),
    );
  });

  group('FoodRecognizer', () {
    test('groups boxes by name, drops non-food, most certain first', () {
      final found = FoodRecognizer.parseDetections({
        'detections': FakeBackend().detections,
      });

      expect(found.map((d) => d.name), ['pizza', 'banana', 'broccoli']);
      final banana = found[1];
      expect(banana.count, 2);
      expect(banana.confidence, 0.71);
      expect(banana.label, 'Banana');
      expect(banana.confidenceText, '71%');
      expect(found.last.isLikely, isFalse);
    });

    test('sends the photo as multipart field "image"', () async {
      await recognizer.recognize(tinyPng, 'meal.png');

      final request = backend.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/ai/food');
      expect(
        latin1.decode(request.bodyBytes),
        contains('name="image"; filename="meal.png"'),
      );
    });

    test('no Spring endpoint yet means unavailable, not an error', () async {
      backend.status = 404;

      expect(
        () => recognizer.recognize(tinyPng, 'meal.jpg'),
        throwsA(isA<FoodRecognitionUnavailable>()),
      );
    });
  });

  group('meal photo in the meal form', () {
    late int picks;
    PickedPhoto? nextPhoto;

    Future<void> openPhoto(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      picks = 0;
      nextPhoto = PickedPhoto(bytes: tinyPng, filename: 'meal.png');

      await tester.pumpWidget(MaterialApp(
        home: MealEntryScreen(
          recognizer: recognizer,
          photoPicker: (ImageSource source) async {
            picks++;
            return nextPhoto;
          },
        ),
      ));

      await tester.tap(find.text('Take a photo of your meal'));
      await tester.pumpAndSettle();
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    testWidgets('recognised foods are confirmed and fill the description',
        (tester) async {
      await openPhoto(tester);

      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      expect(find.text('Is this what you ate?'), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Banana (2)'), findsOneWidget);
      expect(find.text('Broccoli'), findsOneWidget);
      expect(find.text('Cup'), findsNothing);
      // Likely ones are ticked, the 31% broccoli is not.
      expect(find.text('Use 2 foods'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Salad');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Use 3 foods'), findsOneWidget);

      await tester.tap(find.text('Use 3 foods'));
      await tester.pumpAndSettle();

      expect(find.byType(FoodCameraScreen), findsNothing);
      final description = tester.widget<TextField>(find.byType(TextField).first);
      expect(description.controller!.text, 'Pizza, Banana (2), Salad');
    });

    testWidgets('unticking a wrong food leaves it out', (tester) async {
      await openPhoto(tester);
      await tester.tap(find.text('Choose from gallery'));
      await settle(tester);

      await tester.tap(find.text('Pizza'));
      await tester.pump();
      await tester.tap(find.text('Use 1 food'));
      await tester.pumpAndSettle();

      final description = tester.widget<TextField>(find.byType(TextField).first);
      expect(description.controller!.text, 'Banana (2)');
    });

    testWidgets('without the Spring endpoint the foods can be typed',
        (tester) async {
      backend.status = 404;
      await openPhoto(tester);

      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      expect(find.textContaining('not connected yet'), findsOneWidget);
      expect(find.text('Choose a food'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Lentil soup');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use 1 food'));
      await tester.pumpAndSettle();

      final description = tester.widget<TextField>(find.byType(TextField).first);
      expect(description.controller!.text, 'Lentil soup');
    });

    testWidgets('a failed recognition can be retried', (tester) async {
      backend.status = 500;
      await openPhoto(tester);

      await tester.tap(find.text('Take a photo'));
      await settle(tester);
      expect(find.text('Food recognition failed.'), findsOneWidget);

      backend.status = 200;
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('Pizza'), findsOneWidget);
    });

    testWidgets('cancelling the camera keeps the choice screen',
        (tester) async {
      await openPhoto(tester);
      nextPhoto = null;

      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      expect(picks, 1);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(backend.requests, isEmpty);
    });

    testWidgets('Retake goes back to the choice', (tester) async {
      await openPhoto(tester);
      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();

      expect(find.text('Take a photo'), findsOneWidget);
    });
  });
}
