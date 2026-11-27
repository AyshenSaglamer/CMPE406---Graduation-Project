import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/food_recognition.dart';
import 'package:gradia/data/log_store.dart';
import 'package:gradia/data/meal_store.dart';
import 'package:gradia/data/offline_queue.dart';
import 'package:gradia/screens/food_camera_screen.dart';
import 'package:gradia/screens/meal_entry_screen.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/auth_service.dart';
import 'package:gradia/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

/// A 1x1 PNG, so Image.memory has something real to show.
final Uint8List tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

const String backendNote =
    'Photo recognition can be wrong and the nutrition values are rough '
    'estimates. Check the food and the amount before saving. Do not use these '
    'values to calculate an insulin dose.';

/// Test-only stand-in for POST /api/v1/ai/food (FoodRecognitionResponse of
/// the backend) and POST /api/v1/patients/7/meal-logs. [status] 404 = a backend without
/// the food endpoint.
class FakeBackend {
  int status = 200;
  final requests = <http.Request>[];
  final savedMeals = <Map<String, dynamic>>[];

  bool lowConfidence = false;
  List<Map<String, dynamic>> predictions = [
    {
      'food': 'pizza',
      'displayName': 'Pizza',
      'confidence': 0.9123,
      'foodCatalogId': 41,
      'kcalPer100g': 266,
      'carbsGPer100g': 33,
      'typicalServingG': 150,
      'carbsGPerServing': 49.5,
      'nutritionVerified': false,
    },
    {
      'food': 'lasagna',
      'displayName': 'Lasagna',
      'confidence': 0.05,
      'foodCatalogId': 57,
      'kcalPer100g': 135,
      'carbsGPer100g': 14,
      'typicalServingG': 250,
      'carbsGPerServing': 35,
      'nutritionVerified': false,
    },
    {
      'food': 'cig_kofte',
      'displayName': 'Cig kofte',
      'confidence': 0.02,
      'foodCatalogId': null,
      'kcalPer100g': null,
      'carbsGPer100g': null,
      'typicalServingG': null,
      'carbsGPerServing': null,
      'nutritionVerified': false,
    },
  ];

  /// Food regions of a plate with several foods (empty = one dish).
  List<Map<String, dynamic>> items = [];

  late final client = MockClient((request) async {
    requests.add(request);

    if (request.url.path == '/api/v1/patients/7/meal-logs' &&
        request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      savedMeals.add(body);
      return _json(201, {
        'id': savedMeals.length,
        'mealType': body['mealType'],
        'eatenAt': body['eatenAt'],
        'description': body['description'],
        'carbsG': body['carbsG'],
        'source': body['source'] ?? 'MANUAL',
        'aiConfidence': body['aiConfidence'],
      });
    }
    if (request.url.path != '/api/v1/ai/food' || status == 404) {
      return _json(404, {'detail': 'Resource not found'});
    }
    if (status == 422) {
      return _json(422, {'detail': 'The image could not be read.'});
    }
    if (status != 200) {
      return _json(status, {
        'detail': 'The food recognition service is currently unavailable',
      });
    }
    return _json(200, {
      'model': 'ResNet50',
      'lowConfidence': lowConfidence,
      'requiresConfirmation': true,
      'predictions': predictions,
      'multipleFoods': items.length >= 2,
      'items': items,
      'note': backendNote,
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
  late LogStore<MealRecord> meals;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStorage.save(
      token: 'test-token',
      expiresInSeconds: 3600,
      userJson: jsonEncode({
        'id': 7,
        'firstName': 'Nil',
        'lastName': 'Su',
        'email': 'n@example.com',
        'role': 'PATIENT',
      }),
    );
    await authService.restoreSession();

    backend = FakeBackend();
    final api = ApiClient(httpClient: backend.client);
    recognizer = FoodRecognizer(api: api);
    meals = LogStore<MealRecord>(
      resource: 'meal-logs',
      fromJson: MealRecord.fromJson,
      api: api,
      queue: OfflineQueue(api: api),
    );
  });

  group('FoodRecognizer', () {
    test('reads the backend answer, best guess first', () async {
      final result = await recognizer.recognize(tinyPng, 'meal.png');

      expect(result.model, 'ResNet50');
      expect(result.note, backendNote);
      expect(result.predictions.map((p) => p.food),
          ['pizza', 'lasagna', 'cig_kofte']);

      final pizza = result.predictions.first;
      expect(pizza.displayName, 'Pizza');
      expect(pizza.confidenceText, '91%');
      expect(pizza.foodCatalogId, 41);
      expect(pizza.carbsGPerServing, 49.5);
      expect(pizza.carbsText, 'about 49.5 g carbs per serving (150 g)');
      expect(result.suggested?.food, 'pizza');

      // Not in the catalog: no numbers, but still a name to show.
      final kofte = result.predictions.last;
      expect(kofte.foodCatalogId, isNull);
      expect(kofte.carbsText, isNull);
    });

    test('nothing is suggested when the model is not sure', () {
      final result = FoodRecognition.fromJson({
        'lowConfidence': true,
        'predictions': [
          {'food': 'apple_pie', 'confidence': 0.3},
        ],
      });

      expect(result.suggested, isNull);
      expect(result.predictions.single.displayName, 'Apple pie');
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

    test('a backend without the endpoint means unavailable, not an error',
        () async {
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

      // A start page under the form, so saving can pop it.
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => MealEntryScreen(
                    recognizer: recognizer,
                    store: meals,
                    photoPicker: (ImageSource source) async {
                      picks++;
                      return nextPhoto;
                    },
                  ),
                ),
              ),
              child: const Text('Open meal form'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Open meal form'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take a photo of your meal'));
      await tester.pumpAndSettle();
    }

    Future<void> settle(WidgetTester tester) async {
      // Saving reads the token and the queue before the request: a few rounds.
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    TextEditingController field(WidgetTester tester, int index) =>
        tester.widget<TextField>(find.byType(TextField).at(index)).controller!;

    testWidgets('the best guess is picked, carbs are estimated, saved as '
        'AI_PHOTO', (tester) async {
      await openPhoto(tester);

      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      expect(find.text('Is this what you ate?'), findsOneWidget);
      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Lasagna'), findsOneWidget);
      expect(find.text('Cig kofte'), findsOneWidget);
      expect(find.textContaining('49.5 g carbs'), findsOneWidget);
      expect(find.text(backendNote), findsOneWidget);
      expect(find.text('Use 1 food'), findsOneWidget);

      await tester.tap(find.text('Use 1 food'));
      await tester.pumpAndSettle();

      expect(find.byType(FoodCameraScreen), findsNothing);
      expect(field(tester, 0).text, 'Pizza');
      expect(field(tester, 1).text, '49.5');
      expect(find.text('Rough estimate from the photo: check it'),
          findsOneWidget);

      await tester.tap(find.text('Save Meal Record'));
      await settle(tester);

      final saved = backend.savedMeals.single;
      expect(saved['source'], 'AI_PHOTO');
      expect(saved['aiConfidence'], 0.912);
      expect(saved['description'], 'Pizza');
      expect(saved['carbsG'], 49.5);
    });

    testWidgets('only one guess can be picked; a typed food is added',
        (tester) async {
      await openPhoto(tester);
      await tester.tap(find.text('Choose from gallery'));
      await settle(tester);

      await tester.tap(find.text('Lasagna'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Salad');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Use 2 foods'), findsOneWidget);
      await tester.tap(find.text('Use 2 foods'));
      await tester.pumpAndSettle();

      expect(field(tester, 0).text, 'Lasagna, Salad');
      expect(field(tester, 1).text, '35');
    });

    testWidgets('typed carbs are kept and a manual-only meal stays MANUAL',
        (tester) async {
      await openPhoto(tester);
      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      // Un-pick the suggestion, type the food instead.
      await tester.tap(find.text('Pizza'));
      await tester.pump();
      expect(find.text('Choose a food'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Lentil soup');
      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use 1 food'));
      await tester.pumpAndSettle();

      expect(field(tester, 0).text, 'Lentil soup');
      expect(field(tester, 1).text, isEmpty);

      await tester.enterText(find.byType(TextField).at(1), '30');
      await tester.tap(find.text('Save Meal Record'));
      await settle(tester);

      final saved = backend.savedMeals.single;
      expect(saved['source'], 'MANUAL');
      expect(saved.containsKey('aiConfidence'), isFalse);
      expect(saved['carbsG'], 30);
    });

    testWidgets('low confidence suggests nothing', (tester) async {
      backend.lowConfidence = true;
      await openPhoto(tester);
      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      expect(find.textContaining('not sure about this photo'), findsOneWidget);
      expect(find.text('Choose a food'), findsOneWidget);

      await tester.tap(find.text('Pizza'));
      await tester.pump();
      expect(find.text('Use 1 food'), findsOneWidget);
    });

    testWidgets('without the food endpoint the foods can be typed',
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

      expect(field(tester, 0).text, 'Lentil soup');
    });

    testWidgets('an unusable image shows the backend message', (tester) async {
      backend.status = 422;
      await openPhoto(tester);

      await tester.tap(find.text('Take a photo'));
      await settle(tester);
      expect(find.text('The image could not be read.'), findsOneWidget);
    });

    testWidgets('a service outage can be retried', (tester) async {
      backend.status = 503;
      await openPhoto(tester);

      await tester.tap(find.text('Take a photo'));
      await settle(tester);
      expect(
        find.text('The food recognition service is currently unavailable'),
        findsOneWidget,
      );

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

    testWidgets('a portion changes the carb estimate', (tester) async {
      backend.predictions.first['portionOptions'] = [
        {'size': 'SMALL', 'grams': 75, 'carbsG': 24.8, 'kcal': 200},
        {'size': 'MEDIUM', 'grams': 150, 'carbsG': 49.5, 'kcal': 399},
        {'size': 'LARGE', 'grams': 225, 'carbsG': 74.3, 'kcal': 599},
      ];
      await openPhoto(tester);
      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      await tester.tap(find.textContaining('Large · 225 g'));
      await tester.pump();
      await tester.tap(find.text('Use 1 food'));
      await tester.pumpAndSettle();

      expect(field(tester, 0).text, 'Pizza');
      expect(field(tester, 1).text, '74.3');
    });

    void pizzaPortionsWithMacros() {
      backend.predictions.first['portionOptions'] = [
        {
          'size': 'SMALL',
          'grams': 75,
          'carbsG': 24.8,
          'kcal': 199.5,
          'proteinG': 8.3,
          'fatG': 7.4,
        },
        {
          'size': 'MEDIUM',
          'grams': 150,
          'carbsG': 49.5,
          'kcal': 399,
          'proteinG': 16.5,
          'fatG': 14.9,
        },
        {
          'size': 'LARGE',
          'grams': 225,
          'carbsG': 74.3,
          'kcal': 598.5,
          'proteinG': 24.8,
          'fatG': 22.4,
        },
      ];
    }

    testWidgets('the kcal, protein and fat of the portion are saved with the '
        'carbs', (tester) async {
      pizzaPortionsWithMacros();
      await openPhoto(tester);
      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      await tester.tap(find.textContaining('Large · 225 g'));
      await tester.pump();
      await tester.tap(find.text('Use 1 food'));
      await tester.pumpAndSettle();

      expect(
        find.text('Also about 598.5 kcal · 24.8 g protein · 22.4 g fat'),
        findsOneWidget,
      );

      await tester.tap(find.text('Save Meal Record'));
      await settle(tester);

      final saved = backend.savedMeals.single;
      expect(saved['carbsG'], 74.3);
      expect(saved['caloriesKcal'], 598.5);
      expect(saved['proteinG'], 24.8);
      expect(saved['fatG'], 22.4);
    });

    testWidgets('corrected carbs drop the photo\'s kcal, protein and fat',
        (tester) async {
      pizzaPortionsWithMacros();
      await openPhoto(tester);
      await tester.tap(find.text('Take a photo'));
      await settle(tester);
      await tester.tap(find.text('Use 1 food'));
      await tester.pumpAndSettle();

      // Ate only part of it: the other estimates no longer fit.
      await tester.enterText(find.byType(TextField).at(1), '30');
      await tester.pump();
      expect(find.textContaining('Also about'), findsNothing);

      await tester.tap(find.text('Save Meal Record'));
      await settle(tester);

      final saved = backend.savedMeals.single;
      expect(saved['carbsG'], 30);
      expect(saved['source'], 'AI_PHOTO');
      expect(saved.containsKey('caloriesKcal'), isFalse);
      expect(saved.containsKey('proteinG'), isFalse);
      expect(saved.containsKey('fatG'), isFalse);
    });

    testWidgets('several foods on a plate: tick, fix a name, add up carbs',
        (tester) async {
      Map<String, dynamic> guess(String food, String name, double confidence,
              double? carbs) =>
          {
            'food': food,
            'displayName': name,
            'confidence': confidence,
            'carbsGPerServing': carbs,
            'portionOptions': carbs == null
                ? []
                : [
                    {'size': 'SMALL', 'grams': 50, 'carbsG': carbs / 2},
                    {'size': 'MEDIUM', 'grams': 100, 'carbsG': carbs},
                    {'size': 'LARGE', 'grams': 150, 'carbsG': carbs * 1.5},
                  ],
          };
      backend.items = [
        {
          'box': [0.0, 0.1, 0.3, 0.8],
          'lowConfidence': false,
          'predictions': [guess('hamburger', 'Hamburger', 0.99, 48)],
        },
        {
          'box': [0.35, 0.1, 0.65, 0.8],
          'lowConfidence': false,
          'predictions': [
            guess('lahmacun', 'Lahmacun', 0.6, 45),
            guess('pizza', 'Pizza', 0.35, 36),
          ],
        },
        {
          'box': [0.7, 0.2, 1.0, 0.8],
          'lowConfidence': true,
          'predictions': [guess('ramen', 'Ramen', 0.3, 65)],
        },
      ];
      await openPhoto(tester);
      await tester.tap(find.text('Take a photo'));
      await settle(tester);

      expect(find.text('Foods on your plate'), findsOneWidget);
      expect(find.text('Is this what you ate?'), findsNothing);
      // The unsure one is not ticked.
      expect(find.text('Use 2 foods'), findsOneWidget);

      // Lahmacun was really pizza.
      await tester.tap(find.byTooltip('Not Lahmacun?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pizza (35%)'));
      await tester.pumpAndSettle();

      // A small hamburger.
      await tester.tap(find.textContaining('Small · 50 g').first);
      await tester.pump();

      await tester.tap(find.text('Use 2 foods'));
      await tester.pumpAndSettle();

      expect(field(tester, 0).text, 'Hamburger, Pizza');
      expect(field(tester, 1).text, '60'); // 24 + 36

      await tester.tap(find.text('Save Meal Record'));
      await settle(tester);

      final saved = backend.savedMeals.single;
      expect(saved['source'], 'AI_PHOTO');
      expect(saved['aiConfidence'], 0.35); // the lowest of the confirmed foods
    });
  });

  group('FoodPhotoResult', () {
    FoodPrediction food(String name, double confidence, double? carbs) =>
        FoodPrediction(
          food: name,
          displayName: name,
          confidence: confidence,
          carbsGPerServing: carbs,
        );

    test('a food without an estimate makes the total unknown, not 0', () {
      final result = FoodPhotoResult(foods: const ['A', 'B'], confirmedFoods: [
        ConfirmedFood(food('A', 0.9, 30)),
        ConfirmedFood(food('B', 0.8, null)),
      ]);

      expect(result.carbsEstimate, isNull);
      expect(result.aiConfidence, 0.8);
      expect(result.fromRecognition, isTrue);
    });

    test('kcal, protein and fat add up over the foods and portions', () {
      FoodPrediction withMacros(String name, double kcal, double protein,
              double? fat) =>
          FoodPrediction(
            food: name,
            displayName: name,
            confidence: 0.9,
            carbsGPerServing: 10,
            kcalPerServing: kcal,
            proteinGPerServing: protein,
            fatGPerServing: fat,
            portionOptions: [
              PortionOption(
                size: 'LARGE',
                grams: 150,
                carbsG: 15,
                kcal: kcal * 1.5,
                proteinG: protein * 1.5,
                fatG: fat == null ? null : fat * 1.5,
              ),
            ],
          );

      final result = FoodPhotoResult(foods: const ['A', 'B'], confirmedFoods: [
        ConfirmedFood(withMacros('A', 200, 10.2, 5)),
        ConfirmedFood(withMacros('B', 100.4, 4, null), portion: 'LARGE'),
      ]);

      expect(result.kcalEstimate, 350.6); // 200 + 150.6
      expect(result.proteinEstimate, 16.2); // 10.2 + 6
      // One food has no fat value: unknown, not counted as 0 g.
      expect(result.fatEstimate, isNull);
    });

    test('typed foods only: MANUAL, no estimate', () {
      const result = FoodPhotoResult(foods: ['Soup']);

      expect(result.fromRecognition, isFalse);
      expect(result.aiConfidence, isNull);
      expect(result.carbsEstimate, isNull);
      expect(result.confirmed, isNull);
    });
  });

  group('parsing', () {
    test('portion options, macros and plate items', () {
      final result = FoodRecognition.fromJson({
        'lowConfidence': false,
        'multipleFoods': true,
        'predictions': [
          {
            'food': 'pizza',
            'displayName': 'Pizza',
            'confidence': 0.9,
            'kcalPerServing': 297,
            'proteinGPerServing': 12.1,
            'fatGPerServing': 11.4,
            'portionOptions': [
              {'size': 'SMALL', 'grams': 55, 'carbsG': 18.2},
              {'size': 'bad'},
              'not a map',
            ],
          },
        ],
        'items': [
          {
            'box': [0, 0, 0.5, 1],
            'predictions': [
              {'food': 'pizza', 'confidence': 0.9},
            ],
          },
          {
            'box': [0.5, 0, 1, 1],
            'predictions': [
              {'food': 'sushi', 'confidence': 0.4},
            ],
          },
          {'predictions': []},
        ],
      });

      final pizza = result.predictions.single;
      expect(pizza.portionOptions.single.label, 'Small');
      expect(pizza.carbsFor('SMALL'), 18.2);
      expect(pizza.macrosText, '12.1 g protein · 11.4 g fat · 297 kcal');
      expect(result.items, hasLength(2));
      expect(result.items.first.box, [0.0, 0.0, 0.5, 1.0]);
      expect(result.items.last.lowConfidence, isTrue);
      expect(result.showsPlate, isTrue);
    });
  });
}
