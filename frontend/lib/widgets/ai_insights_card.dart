import 'package:flutter/material.dart';

import '../data/ai_insights_store.dart';
import '../data/glucose_store.dart';
import '../services/api_exception.dart';

/// "AI Insights" card: what the AI service says about the last [days] days
/// of glucose, meal and activity logs (GET /ai/patients/{id}/summary).
/// Reloads when [days] changes or a glucose reading is added, edited or
/// deleted anywhere in the app.
class AiInsightsCard extends StatefulWidget {
  const AiInsightsCard({
    super.key,
    required this.days,
    this.patientId,
    this.store,
  });

  final int days;

  /// Null = the logged-in patient.
  final int? patientId;

  /// For tests; defaults to [aiInsightsStore].
  final AiInsightsStore? store;

  @override
  State<AiInsightsCard> createState() => _AiInsightsCardState();
}

class _AiInsightsCardState extends State<AiInsightsCard> {
  static const _blue = Color(0xFF168AF7);
  static const _muted = Color(0xFF64788B);

  AiSummary? summary;
  String? error;
  bool isLoading = true;
  int _request = 0;

  AiInsightsStore get _store => widget.store ?? aiInsightsStore;

  int get _coveredDays => widget.days.clamp(1, AiInsightsStore.maxDays);

  @override
  void initState() {
    super.initState();
    glucoseStore.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(AiInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days ||
        oldWidget.patientId != widget.patientId) {
      _load();
    }
  }

  @override
  void dispose() {
    glucoseStore.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final result = await _store.summary(
        days: widget.days,
        patientId: widget.patientId,
      );

      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        summary = result;
        isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || request != _request) {
        return;
      }

      setState(() {
        summary = null;
        isLoading = false;
        error = _messageFor(e);
      });
    }
  }

  static String _messageFor(ApiException e) {
    switch (e.statusCode) {
      case 422:
        return 'Not enough data for AI insights yet. '
            'Log at least three glucose readings in this period.';
      case 502:
      case 503:
        return 'The AI assistant is not available right now. '
            'Please try again later.';
      default:
        // e.g. 400 with errors.from = "At least 2 glucose readings are
        // needed in this time range": the field says what is wrong.
        return e.fieldErrors.values.isNotEmpty
            ? e.fieldErrors.values.first
            : e.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: _blue, size: 21),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'AI Insights',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  'Last $_coveredDays days',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ..._content(),
          ],
        ),
      ),
    );
  }

  List<Widget> _content() {
    if (isLoading && summary == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (error != null) {
      return [
        Text(error!, style: const TextStyle(fontSize: 13, color: _muted)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _load, child: const Text('Try again')),
        ),
      ];
    }

    final s = summary!;

    return [
      if (s.hasTimeInRange) ...[
        _TimeInRangeBar(summary: s),
        const SizedBox(height: 16),
      ],
      if (s.prediction != null) ...[
        _PredictionRow(prediction: s.prediction!),
        const SizedBox(height: 14),
      ],
      if (s.insights.isEmpty)
        const Text(
          'No notable patterns in this period.',
          style: TextStyle(fontSize: 13, color: _muted),
        )
      else
        for (final insight in s.insights)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(Icons.circle, size: 6, color: _blue),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      if (s.disclaimer != null) ...[
        const SizedBox(height: 6),
        Text(
          s.disclaimer!,
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.4,
            color: Color(0xFF8A97A5),
          ),
        ),
      ],
    ];
  }
}

class _TimeInRangeBar extends StatelessWidget {
  const _TimeInRangeBar({required this.summary});

  final AiSummary summary;

  static const _low = Color(0xFFF2A33A);
  static const _inRange = Color(0xFF35B779);
  static const _high = Color(0xFFE95D76);

  @override
  Widget build(BuildContext context) {
    final below = summary.belowPercent!;
    final inRange = summary.inRangePercent!;
    final above = summary.abovePercent!;

    // flex needs whole numbers; keep at least 1 so a tiny share stays visible.
    int flex(double p) => p <= 0 ? 0 : (p * 10).round().clamp(1, 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time in range (${summary.rangeLow.round()}–'
          '${summary.rangeHigh.round()} mg/dL)',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                if (flex(below) > 0)
                  Expanded(flex: flex(below), child: Container(color: _low)),
                if (flex(inRange) > 0)
                  Expanded(
                    flex: flex(inRange),
                    child: Container(color: _inRange),
                  ),
                if (flex(above) > 0)
                  Expanded(flex: flex(above), child: Container(color: _high)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _legend(_low, 'Low', below),
            _legend(_inRange, 'In range', inRange),
            _legend(_high, 'High', above),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label, double percent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label ${percent.round()}%',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64788B)),
        ),
      ],
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.prediction});

  final AiTrendPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final icon = switch (prediction.trend) {
      AiTrendPrediction.lower => Icons.trending_down_rounded,
      AiTrendPrediction.higher => Icons.trending_up_rounded,
      _ => Icons.trending_flat_rounded,
    };

    final confidence = prediction.confidenceText;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF168AF7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next glucose: ${prediction.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  confidence == null
                      ? 'Experimental model estimate'
                      : 'Experimental model estimate • $confidence confidence',
                  style: const TextStyle(
                    fontSize: 11,
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
}
