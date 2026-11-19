import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../utils/reminder_planner.dart';
import 'clinic_store.dart';
import 'prescription_store.dart';
import 'reminder_schedule_store.dart';

// Puts a patient's medicine and appointment reminders on the phone as notifications.
// What to remind about is decided in planReminders (lib/utils/reminder_planner.dart).
//
// TODO(backend): when the data comes from a server, call refreshFor after every sync.
// Messages that start on the server, such as "your appointment was approved" or "a new
// request is waiting" for the doctor, need server push notifications, not this class.
class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Android notification channel configuration for Healthbook reminders.
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'healthbook_reminders',
      'Reminders',
      channelDescription: 'Medicine and appointment reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // Initializes the local notification plugin once per app lifecycle.
  Future<void> _init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  // Plans the patient's reminders again from what the stores hold now, replacing the
  // old ones. Safe to call as often as needed. It never throws, because a problem with
  // reminders must not break the app.
  Future<void> refreshFor(String patientId) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await _init();

      final plan = planReminders(
        now: DateTime.now(),
        medications: prescriptionStore.medicationsFor(patientId),
        appointments: clinicStore.appointmentsForPatient(patientId),
        doctorName: (id) => clinicStore.doctorById(id)?.name ?? 'Your doctor',
        customHoursByFrequency: reminderScheduleStore.customHoursMap,
      );

      // Clear previously scheduled local notifications before writing the fresh plan.
      await _plugin.cancelAllPendingNotifications();
      if (plan.isEmpty) return;

      // Android 13 and newer ask the person before an app may show notifications.
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      var allowed = await android?.areNotificationsEnabled() ?? false;
      if (!allowed) {
        allowed = await android?.requestNotificationsPermission() ?? false;
      }
      if (!allowed) return;

      var id = 1;
      for (final reminder in plan) {
        await _plugin.zonedSchedule(
          id: id++,
          title: reminder.title,
          body: reminder.body,
          // Only the moment in time matters here, so UTC is used.
          scheduledDate: tz.TZDateTime.from(reminder.time, tz.UTC),
          notificationDetails: _details,
          // Battery-friendly: can be a few minutes late, but needs no special permission.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (e) {
      debugPrint('Could not plan reminders: $e');
    }
  }
}

// App-wide singleton notification scheduler.
final ReminderService reminderService = ReminderService();
