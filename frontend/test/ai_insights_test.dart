import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gradia/data/ai_insights_store.dart';
import 'package:gradia/services/api_client.dart';
import 'package:gradia/services/api_exception.dart';
import 'package:gradia/widgets/ai_insights_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Shaped like the ai-service patient-summary answer that Spring passes on.
Map<String, dynamic> sampleSummary({bool withPrediction = true}) => {
      'status': 'SUCCESS',
      'patient_id': null,
      'record_count': 11,
      'configured_range': {'low_mg_dl': 70.0, 'high_mg_dl': 180.0},
      'analytics': {
        'glucose_statistics': {
          'count': 12,
          'mean': 142.5,
          'minimum': 64.0,
          'maximum': 231.0,
          'standard_deviation': 38.2,
        },
        'time_in_range': {
          'total_readings': 12,
          'below_range_percentage': 8.33,
          'time_in_range_percentage': 66.67,
          'above_range_percentage': 25.0,
          'lower_bound': 70.0,
          'upper_bound': 180.0,
        },
      },
      'personalized_patterns': {'insights': []},
      'ml_prediction': withPrediction
          ? {
              'status': 'AVAILABLE',
              'result': {'prediction': 'HIGHER', 'confidence': 0.714},
            }
          : {'status': 'MODEL_NOT_AVAILABLE', 'result': null},
      'insight_summary': {
        'status': 'SUCCESS',
        'insight_count': 2,
        'insights': [
          'The average glucose value in the selected logged period was 142.5 mg/dL.',
          '  ',
          'Glucose was higher after evening meals.',
        ],
      },
      'disclaimer': 'Not medical advice.',
    };

class FakeBackend {
  final requests = <http.Request>[];
  int status = 200;
  Map<String, dynamic> body = sampleSummary();

  /// The AI service's reason for a 422 (passed through by Spring).
  String detail422 = 'At least 3 historical glucose readings are required.';

  late final client = MockClient((request) async {
    requests.add(request);

    if (request.headers['Authorization'] != 'Bearer test-token') {
      return _json(401, {'detail': 'Authentication required'});
    }

    if (request.url.path == '/api/v1/ai/patients/7/summary' &&
        request.method == 'GET') {
      if (status == 400) {
        // What the backend answers for a range with too few readings.
        return _json(400, {
          'detail': 'One or more fields are invalid',
          'errors': {
            'from': 'At least 2 glucose readings are needed in this time range',
          },
        });
      }
      if (status == 422) {
        return _json(422, {'detail': detail422});
      }
      if (status != 200) {
        return _json(status, {'detail': 'AI said no ($status)'});
      }
      return _json(200, body);
    }

    return _json(404, {'detail': 'Resource not found'});
  });

  static http.Response _json(int status, Object body) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
}

void main() {
  late FakeBackend backend;
  late AiInsightsStore store;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'test-token',
      'access_token_expires_at':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
    });
    backend = FakeBackend();
    store = AiInsightsStore(api: ApiClient(httpClient: backend.client));
  });

  group('AiSummary.fromJson', () {
    test('reads statistics, time in range, prediction and insights', () {
      final s = AiSummary.fromJson(sampleSummary());

      expect(s.recordCount, 11);
      expect(s.mean, 142.5);
      expect(s.minimum, 64.0);
      expect(s.maximum, 231.0);
      expect(s.inRangePercent, 66.67);
      expect(s.belowPercent, 8.33);
      expect(s.abovePercent, 25.0);
      expect(s.hasTimeInRange, isTrue);
      expect(s.prediction!.trend, AiTrendPrediction.higher);
      expect(s.prediction!.label, 'Trending higher');
      expect(s.prediction!.confidenceText, '71%');
      // Blank insights are dropped.
      expect(s.insights, hasLength(2));
      expect(s.disclaimer, 'Not medical advice.');
    });

    test('no prediction when the model is not available', () {
      final s = AiSummary.fromJson(sampleSummary(withPrediction: false));

      expect(s.prediction, isNull);
    });

    test('an almost empty answer does not throw', () {
      final s = AiSummary.fromJson({'status': 'SUCCESS'});

      expect(s.recordCount, 0);
      expect(s.hasTimeInRange, isFalse);
      expect(s.insights, isEmpty);
      expect(s.rangeLow, 70);
      expect(s.rangeHigh, 180);
    });
  });

  group('AiInsightsStore.summary', () {
    test('asks for the last N days as ISO times', () async {
      final now = DateTime.utc(2026, 11, 22, 12);

      await store.summary(days: 7, patientId: 7, now: now);

      final query = backend.requests.single.url.queryParameters;
      expect(query['to'], '2026-11-22T12:00:00.000Z');
      expect(query['from'], '2026-11-15T12:00:00.000Z');
    });

    test('caps the range at 30 days (backend limit is 31)', () async {
      final now = DateTime.utc(2026, 11, 22, 12);

      await store.summary(days: 90, patientId: 7, now: now);

      final query = backend.requests.single.url.queryParameters;
      expect(query['from'], '2026-10-23T12:00:00.000Z');
    });

    test('passes the backend error on', () async {
      backend.status = 422;

      expect(
        () => store.summary(days: 7, patientId: 7),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 422)),
      );
    });
  });

  group('AiInsightsCard', () {
    Future<void> pump(WidgetTester tester, {int days = 7}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiInsightsCard(days: days, patientId: 7, store: store),
          ),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pump();
    }

    testWidgets('shows time in range, prediction and insights',
        (tester) async {
      await pump(tester);

      expect(find.text('AI Insights'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('In range 67%'), findsOneWidget);
      expect(find.text('Low 8%'), findsOneWidget);
      expect(find.text('High 25%'), findsOneWidget);
      expect(find.text('Next glucose: Trending higher'), findsOneWidget);
      expect(find.textContaining('71% confidence'), findsOneWidget);
      expect(find.text('Glucose was higher after evening meals.'),
          findsOneWidget);
      expect(find.text('Not medical advice.'), findsOneWidget);
    });

    testWidgets('90-day period is labelled as the last 30 days',
        (tester) async {
      await pump(tester, days: 90);

      expect(find.text('Last 30 days'), findsOneWidget);
    });

    testWidgets('too little data gives a friendly message and a retry',
        (tester) async {
      backend.status = 422;
      await pump(tester);

      expect(find.textContaining('Not enough data for AI insights'),
          findsOneWidget);

      backend.status = 200;
      await tester.tap(find.text('Try again'));
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 50),
          ));
      await tester.pump();

      expect(find.text('Next glucose: Trending higher'), findsOneWidget);
      expect(backend.requests, hasLength(2));
    });

    testWidgets('data the AI cannot use is not called "not enough data"',
        (tester) async {
      backend.status = 422;
      backend.detail422 = 'All timestamps must be valid.';
      await pump(tester);

      expect(find.textContaining('Not enough data'), findsNothing);
      expect(
        find.text('AI insights could not be made for this period: '
            'All timestamps must be valid.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a rejected range shows the backend reason, not a generic one',
        (tester) async {
      backend.status = 400;
      await pump(tester);

      expect(find.text('At least 2 glucose readings are needed in this time range'),
          findsOneWidget);
      expect(find.text('One or more fields are invalid'), findsNothing);
    });

    testWidgets('AI service down is explained', (tester) async {
      backend.status = 503;
      await pump(tester);

      expect(find.textContaining('not available right now'), findsOneWidget);
    });
  });
}
