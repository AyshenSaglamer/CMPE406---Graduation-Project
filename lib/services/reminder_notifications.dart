import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/reminder_store.dart';

/// Puts the patient's reminders on the phone as notifications. The screen
/// talks to this interface so tests run without the notification plugin.
abstract class ReminderNotifier {
  /// Asks for permission to show notifications (Android 13+, iOS). False
  /// when refused or not supported.
  Future<bool> requestPermission();

  /// Replaces every scheduled reminder notification with [reminders].
  Future<void> schedule(List<Reminder> reminders);

  /// The phone's time zone ("Europe/Istanbul"), sent with each reminder.
  Future<String?> timezone();
}

/// flutter_local_notifications: one weekly notification per reminder and
/// day, at the reminder's time in the phone's time zone. Inexact (Android
/// may deliver it a few minutes late) so no exact-alarm permission is
/// needed. Web has no scheduled notifications; there it does nothing.
class LocalReminderNotifier implements ReminderNotifier {
  LocalReminderNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  String? _zone;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'diamate_reminders',
      'Reminders',
      channelDescription: 'Medication, glucose check and other reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _init() async {
    if (_ready) {
      return;
    }
    tz_data.initializeTimeZones();
    try {
      _zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(_zone!));
    } catch (_) {
      _zone = null; // keeps UTC; the reminder is still saved
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<String?> timezone() async {
    if (kIsWeb) {
      return null;
    }
    try {
      await _init();
    } catch (_) {
      return null;
    }
    return _zone;
  }

  @override
  Future<bool> requestPermission() async {
    if (kIsWeb) {
      return false;
    }
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  @override
  Future<void> schedule(List<Reminder> reminders) async {
    if (kIsWeb) {
      return;
    }
    await _init();
    await _plugin.cancelAll();

    for (final reminder in reminders) {
      if (!reminder.active || reminder.id == null) {
        continue;
      }
      for (final weekday in reminder.days) {
        await _plugin.zonedSchedule(
          id: notificationId(reminder.id!, weekday),
          title: notificationTitle(reminder),
          body: notificationBody(reminder),
          scheduledDate: nextOccurrence(tz.TZDateTime.now(tz.local), weekday,
              reminder.hour, reminder.minute),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'reminder:${reminder.id}',
        );
      }
    }
  }

  /// A stable id per reminder and weekday (ids must fit in 32 bits).
  static int notificationId(int reminderId, int weekday) =>
      (reminderId % 200000000) * 10 + weekday;

  /// The first time on or after [now] that is [weekday] at hour:minute.
  static tz.TZDateTime nextOccurrence(
      tz.TZDateTime now, int weekday, int hour, int minute) {
    var at = tz.TZDateTime(now.location, now.year, now.month, now.day, hour, minute);
    while (at.weekday != weekday || !at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
      at = tz.TZDateTime(at.location, at.year, at.month, at.day, hour, minute);
    }
    return at;
  }
}

/// "Time for Metformin", "Check your blood glucose", ...
String notificationTitle(Reminder r) => switch (r.type) {
      Reminder.medication => 'Time for ${r.title}',
      Reminder.glucoseCheck => 'Check your blood glucose',
      Reminder.meal => 'Meal time',
      Reminder.appointment => 'Appointment reminder',
      _ => 'DiaMate reminder',
    };

/// The dosage or the note, then a hint to answer in the app.
String notificationBody(Reminder r) {
  final detail = r.isMedication ? r.dosage : r.message;
  final first = detail == null || detail.isEmpty ? '' : '$detail. ';
  return r.isMedication
      ? '${first}Open DiaMate to mark it as taken.'
      : '${first}Open DiaMate to see today\'s reminders.';
}

final ReminderNotifier reminderNotifier = LocalReminderNotifier();
