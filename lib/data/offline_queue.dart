import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_client.dart';
import '../services/api_exception.dart';

/// Shown by the entry screens when a log was kept on the phone.
const String savedOfflineMessage =
    'No internet connection. Saved on this phone; it will be sent '
    'automatically when you are back online.';

/// A new health log saved on the phone while the backend could not be
/// reached, waiting to be sent:
///   POST /api/v1/patients/{patientId}/{resource}   with [body]
/// [body] carries the log's clientUuid, so sending it again is safe: the
/// backend answers 200 with the existing log instead of saving it twice.
class PendingLog {
  final String resource;
  final int patientId;
  final Map<String, dynamic> body;
  final DateTime queuedAt;

  /// Set when the backend refused the log (e.g. a value no longer allowed);
  /// such a log is not sent again until the patient discards it.
  final String? error;

  const PendingLog({
    required this.resource,
    required this.patientId,
    required this.body,
    required this.queuedAt,
    this.error,
  });

  String get clientUuid => body['clientUuid'] as String? ?? '';

  PendingLog withError(String? message) => PendingLog(
        resource: resource,
        patientId: patientId,
        body: body,
        queuedAt: queuedAt,
        error: message,
      );

  /// "Blood Glucose", "Insulin", "Meal", "Activity".
  String get kindLabel => switch (resource) {
        'glucose-logs' => 'Blood Glucose',
        'insulin-logs' => 'Insulin',
        'meal-logs' => 'Meal',
        'activity-logs' => 'Activity',
        _ => 'Entry',
      };

  /// "125 mg/dL", "6 units", "45 g carbs", "30 min".
  String get valueLabel {
    String number(Object? v) {
      if (v is num) {
        return v % 1 == 0 ? v.toInt().toString() : v.toString();
      }
      return '$v';
    }

    switch (resource) {
      case 'glucose-logs':
        return '${number(body['glucoseValue'])} mg/dL';
      case 'insulin-logs':
        return '${number(body['doseUnits'])} units';
      case 'meal-logs':
        final carbs = body['carbsG'];
        final description = body['description'] as String? ?? '';
        return carbs == null ? description : '${number(carbs)} g carbs';
      case 'activity-logs':
        return '${number(body['durationMinutes'])} min '
            '${body['activityType'] ?? ''}'
            .trim();
      default:
        return '';
    }
  }

  /// When it happened, as entered by the patient (local time).
  DateTime? get happenedAt {
    final raw = body['measurementTime'] ??
        body['administeredAt'] ??
        body['eatenAt'] ??
        body['startedAt'];
    return raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
  }

  Map<String, dynamic> toJson() => {
        'resource': resource,
        'patientId': patientId,
        'body': body,
        'queuedAt': queuedAt.toUtc().toIso8601String(),
        if (error != null) 'error': error,
      };

  factory PendingLog.fromJson(Map<String, dynamic> json) => PendingLog(
        resource: json['resource'] as String,
        patientId: (json['patientId'] as num).toInt(),
        body: Map<String, dynamic>.from(json['body'] as Map),
        queuedAt: DateTime.parse(json['queuedAt'] as String).toLocal(),
        error: json['error'] as String?,
      );
}

/// What one sync run did.
class SyncResult {
  final int sent;
  final int rejected;

  /// True when the run stopped early (still offline, session expired or a
  /// server error); the remaining logs are tried again later.
  final bool stopped;

  const SyncResult({this.sent = 0, this.rejected = 0, this.stopped = false});
}

/// New logs made without a connection, kept in the phone's encrypted
/// storage until they reach the backend. Oldest first. Only the logs of
/// the patient who made them are ever sent, under that patient's session.
class OfflineQueue extends ValueNotifier<List<PendingLog>> {
  OfflineQueue({ApiClient? api, FlutterSecureStorage? storage})
      : _api = api ?? apiClient,
        _storage = storage ?? const FlutterSecureStorage(),
        super(const []);

  static const String storageKey = 'offline_logs_v1';

  /// Keeps the stored queue small; the oldest log is dropped beyond this.
  static const int maxItems = 500;

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  bool _restored = false;
  bool isSyncing = false;
  Timer? _timer;

  /// Called after a sync sent at least one log (e.g. reload the lists).
  Future<void> Function()? onSynced;

  List<PendingLog> forPatient(int patientId) =>
      value.where((p) => p.patientId == patientId).toList();

  /// Reads the stored queue (once; later calls do nothing).
  Future<void> restore() async {
    if (_restored) {
      return;
    }
    _restored = true;

    final raw = await _storage.read(key: storageKey);

    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      value = [
        for (final item in jsonDecode(raw) as List<dynamic>)
          PendingLog.fromJson(item as Map<String, dynamic>),
      ];
    } on Object {
      // A damaged entry must not block the app; start empty.
      value = const [];
    }
  }

  Future<void> add({
    required String resource,
    required int patientId,
    required Map<String, dynamic> body,
  }) async {
    await restore();

    final uuid = body['clientUuid'];
    final item = PendingLog(
      resource: resource,
      patientId: patientId,
      body: Map<String, dynamic>.from(body),
      queuedAt: DateTime.now(),
    );

    var list = [
      // The same log saved twice offline is kept once.
      ...value.where((p) => uuid == null || p.clientUuid != uuid),
      item,
    ];
    if (list.length > maxItems) {
      list = list.sublist(list.length - maxItems);
    }

    await _save(list);
  }

  /// Removes a log without sending it.
  Future<void> discard(PendingLog log) async {
    await _save(value.where((p) => !identical(p, log)).toList());
  }

  /// Sends the waiting logs of [patientId], oldest first.
  Future<SyncResult> sync(int patientId) async {
    await restore();

    if (isSyncing) {
      return const SyncResult(stopped: true);
    }

    isSyncing = true;
    notifyListeners();

    var sent = 0;
    var rejected = 0;
    var stopped = false;

    try {
      for (final log in forPatient(patientId)) {
        if (log.error != null) {
          continue;
        }

        try {
          await _api.post(
            '/patients/${log.patientId}/${log.resource}',
            body: log.body,
          );
          sent++;
          await _save(value.where((p) => !identical(p, log)).toList());
        } on ApiException catch (e) {
          if (e.statusCode == 0 || e.statusCode == 401 || e.statusCode >= 500) {
            // Offline again, session over or a server problem: try later.
            stopped = true;
            break;
          }

          if (e.statusCode == 409) {
            // Already stored.
            sent++;
            await _save(value.where((p) => !identical(p, log)).toList());
            continue;
          }

          rejected++;
          final reason = e.fieldErrors.values.isNotEmpty
              ? e.fieldErrors.values.first
              : e.message;
          await _save([
            for (final p in value) identical(p, log) ? p.withError(reason) : p,
          ]);
        }
      }
    } finally {
      isSyncing = false;
      notifyListeners();
    }

    if (sent > 0) {
      await onSynced?.call();
    }

    return SyncResult(sent: sent, rejected: rejected, stopped: stopped);
  }

  /// Tries [sync] every [every] while the app runs and [patientId] returns
  /// a logged-in patient (null = nobody, skip).
  void startAutoSync(
    int? Function() patientId, {
    Duration every = const Duration(minutes: 1),
  }) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) {
      final id = patientId();
      if (id != null && forPatient(id).any((p) => p.error == null)) {
        sync(id);
      }
    });
  }

  void stopAutoSync() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _save(List<PendingLog> list) async {
    value = List.unmodifiable(list);

    if (list.isEmpty) {
      await _storage.delete(key: storageKey);
    } else {
      await _storage.write(
        key: storageKey,
        value: jsonEncode([for (final p in list) p.toJson()]),
      );
    }
  }
}

final offlineQueue = OfflineQueue();
