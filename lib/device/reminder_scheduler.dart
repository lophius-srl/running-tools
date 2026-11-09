import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notifications locales programmées (aucun serveur, aucun compte payant).
abstract interface class ReminderScheduler {
  /// [onOpen] reçoit la charge utile d'une notification touchée.
  Future<void> init(void Function(String payload) onOpen);

  /// Charge utile de la notification qui a lancé l'app, s'il y en a une.
  Future<String?> launchPayload();

  /// Demande l'autorisation puis programme ; `false` si refusée.
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  });

  /// Rappel chaque semaine, le [weekday] (1 = lundi) à [hour]:[minute],
  /// heure locale.
  Future<bool> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancel(int id);
}

class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> init(void Function(String payload) onOpen) async {
    tz_data.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } on Object {
      // Fuseau inconnu : les rappels ponctuels restent justes (instants UTC).
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload case final payload?) onOpen(payload);
      },
    );
  }

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details!.notificationResponse?.payload
        : null;
  }

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!await _requestPermission()) return false;
    await _plugin.zonedSchedule(
      id: id,
      // Instant absolu : l'heure locale est convertie en UTC.
      scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
    );
    return true;
  }

  @override
  Future<bool> scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!await _requestPermission()) return false;
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (next.weekday != weekday || !next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      payload: payload,
      // Même jour, même heure locale, chaque semaine.
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    return true;
  }

  Future<bool> _requestPermission() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalReminderScheduler(),
);
