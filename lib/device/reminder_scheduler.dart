import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> cancel(int id);
}

class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();

  @override
  Future<void> init(void Function(String payload) onOpen) async {
    tz_data.initializeTimeZones();
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
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await ios?.requestPermissions(alert: true, sound: true) ?? false;
    if (!granted) return false;
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
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => LocalReminderScheduler(),
);
