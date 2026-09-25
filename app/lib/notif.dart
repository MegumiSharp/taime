import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Notification plumbing: one ongoing notification for the live timer and one
/// scheduled reminder at a time (whatever the current segment is waiting for).
const int kOngoingId = 1;
const int kReminderId = 2;

const _liveChannel = AndroidNotificationDetails(
  'live',
  'Timer in corso',
  channelDescription: 'Mostra il timer attivo',
  importance: Importance.low,
  priority: Priority.low,
  ongoing: true,
  autoCancel: false,
  onlyAlertOnce: true,
  silent: true,
  showWhen: true,
  usesChronometer: true,
  category: AndroidNotificationCategory.stopwatch,
);

final plugin = FlutterLocalNotificationsPlugin();
bool _tzReady = false;

Future<void> initTz() async {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  final local = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(local.identifier));
  _tzReady = true;
}

Future<void> initNotifications({
  DidReceiveNotificationResponseCallback? onTap,
  DidReceiveBackgroundNotificationResponseCallback? onBackgroundTap,
}) async {
  await initTz();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: onTap,
    onDidReceiveBackgroundNotificationResponse: onBackgroundTap,
  );
  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
}

/// The persistent timer notification. Android runs the chronometer itself, so
/// it keeps ticking with the app closed and costs us nothing.
Future<void> showOngoing({
  required String title,
  required String body,
  required DateTime since,
  required List<AndroidNotificationAction> actions,
}) => plugin.show(
  id: kOngoingId,
  title: title,
  body: body,
  notificationDetails: NotificationDetails(
    android: AndroidNotificationDetails(
      _liveChannel.channelId,
      _liveChannel.channelName,
      channelDescription: _liveChannel.channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      silent: true,
      showWhen: true,
      when: since.millisecondsSinceEpoch,
      usesChronometer: true,
      category: AndroidNotificationCategory.stopwatch,
      actions: actions,
    ),
  ),
);

Future<void> hideOngoing() => plugin.cancel(id: kOngoingId);

Future<void> scheduleReminder({
  required DateTime at,
  required String title,
  required String body,
  required List<AndroidNotificationAction> actions,
}) async {
  await initTz();
  await plugin.cancel(id: kReminderId);
  if (!at.isAfter(DateTime.now())) return;
  await plugin.zonedSchedule(
    id: kReminderId,
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    title: title,
    body: body,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'reminders',
        'Promemoria',
        channelDescription: 'Pause e fine pomodoro',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        actions: actions,
      ),
    ),
  );
}

Future<void> cancelReminder() => plugin.cancel(id: kReminderId);

AndroidNotificationAction action(String id, String title) =>
    AndroidNotificationAction(id, title, showsUserInterface: false);
