import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

/// A saved health log (glucose, insulin, meal or activity).
abstract class LogRecord {
  int get id;

  /// When it happened (measured / given / eaten / started), local time.
  DateTime get time;
}

/// The logged-in patient's logs of one kind, kept in sync with the backend:
///   /api/v1/patients/{patientId}/{resource}
/// patientId is the logged-in patient's user id.
/// [value] holds the last 14 days, newest first.
class LogStore<T extends LogRecord> extends ValueNotifier<List<T>> {
  LogStore({required this.resource, required this.fromJson, ApiClient? api})
    : _api = api ?? apiClient,
      super(const []);

  /// e.g. 'glucose-logs'
  final String resource;

  final T Function(Map<String, dynamic> json) fromJson;

  final ApiClient _api;

  /// The backend allows at most 200 items per page.
  static const int _pageSize = 200;

  String get _path {
    final user = authService.currentUser;

    if (user == null) {
      throw StateError('No logged-in user.');
    }

    return '/patients/${user.id}/$resource';
  }

  /// Loads the last 14 days (the backend default).
  Future<void> load() async {
    value = await fetch();
  }

  /// Reads every page between [from] and [to] without changing [value].
  /// Without [from] the backend returns the last 14 days. Newest first.
  Future<List<T>> fetch({DateTime? from, DateTime? to}) async {
    final records = <T>[];
    var page = 0;
    var totalPages = 1;

    while (page < totalPages) {
      final query = <String, String>{
        'page': '$page',
        'size': '$_pageSize',
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      };

      final queryString = query.entries
          .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
          .join('&');

      final json =
          await _api.get('$_path?$queryString') as Map<String, dynamic>;

      for (final item in json['items'] as List<dynamic>) {
        records.add(fromJson(item as Map<String, dynamic>));
      }

      totalPages = (json['totalPages'] as num).toInt();
      page++;
    }

    return records;
  }

  /// POST. Added to [value] only after the backend accepted it.
  Future<T> create(Map<String, dynamic> body) async {
    final json = await _api.post(_path, body: body);
    final saved = fromJson(json as Map<String, dynamic>);
    _put(saved);
    return saved;
  }

  /// PUT replaces all editable fields, so send the whole log.
  Future<T> update(int id, Map<String, dynamic> body) async {
    final json = await _api.put('$_path/$id', body: body);
    final saved = fromJson(json as Map<String, dynamic>);
    _put(saved);
    return saved;
  }

  Future<void> delete(int id) async {
    await _api.delete('$_path/$id');
    value = value.where((r) => r.id != id).toList();
  }

  /// Called on logout so the next user does not see these logs.
  void clear() {
    value = const [];
  }

  void _put(T record) {
    value = [...value.where((r) => r.id != record.id), record]
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  /// Newest first.
  List<T> get recent => value;

  T? get latest => value.isEmpty ? null : value.first;

  List<T> get today {
    final now = DateTime.now();

    return value
        .where(
          (r) =>
              r.time.year == now.year &&
              r.time.month == now.month &&
              r.time.day == now.day,
        )
        .toList();
  }
}

/// Backend decimals (BigDecimal) may arrive as a number or a string.
double? parseApiDecimal(Object? value) {
  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

DateTime parseApiTime(Object? value) {
  return DateTime.parse(value as String).toLocal();
}
