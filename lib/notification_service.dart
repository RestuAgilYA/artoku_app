import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
// import 'package:flutter_timezone/flutter_timezone.dart'; <--- HAPUS INI
import 'package:artoku_app/services/logger_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Init Database Timezone
    tz.initializeTimeZones();

    // 2. Set Timezone Manual ke Asia/Jakarta (WIB)
    // Ini lebih stabil daripada menggunakan plugin yang sering error compile
    try {
      // Kita paksa ke WIB karena target user di Indonesia
      // Jika nanti butuh WITA/WIT, bisa dikembangkan lagi tanpa plugin external
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      LoggerService.info("Timezone diset manual ke Asia/Jakarta");
    } catch (e) {
      LoggerService.error("Gagal set timezone", e);
    }

    // 3. Init Android
    // Pastikan icon 'launcher_icon' ada di android/app/src/main/res/mipmap-*
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    // 4. Init iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        LoggerService.info("Notifikasi diklik user: ${details.payload}");
      },
    );
  }

  // --- CEK IZIN ---
  Future<bool> requestPermissions() async {
    bool granted = true;

    // 1. Notifikasi (Android 13+)
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      if (!status.isGranted) granted = false;
    }

    // 2. Exact Alarm (Android 12+)
    if (await Permission.scheduleExactAlarm.status.isDenied) {
      LoggerService.warning("Izin Exact Alarm belum aktif.");
      // await Permission.scheduleExactAlarm.request(); // Opsional
    }

    return granted;
  }

  // --- JADWAL UTAMA ---
  Future<void> scheduleAllReminders() async {
    await cancelAllNotifications();

    LoggerService.info("Menjadwalkan ulang notifikasi...");

    // Jadwal 1: Makan Siang (12:15)
    await _scheduleDaily(
      id: 101,
      title: "Waktunya Makan Siang! 🍛",
      body: "Jangan lupa catat pengeluaran makanmu ya!",
      hour: 12,
      minute: 15,
    );

    // Jadwal 2: Rekap Malam (20:00)
    await _scheduleDaily(
      id: 102,
      title: "Rekap Harian 🌙",
      body: "Cek dompetmu, ada pengeluaran tak terduga hari ini?",
      hour: 20,
      minute: 00,
    );
  }

  Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      final scheduledDate = _nextInstanceOfTime(hour, minute);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_daily_reminder_artoku',
            'Pengingat Harian',
            channelDescription: 'Notifikasi jadwal rutin',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      LoggerService.info("Jadwal ID $id BERHASIL: $scheduledDate");
    } catch (e, stack) {
      LoggerService.error("GAGAL jadwal notifikasi ID $id", e, stack);
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> showInstantNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'channel_test_instant',
          'Tes Instan',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await flutterLocalNotificationsPlugin.show(
      999,
      '🔔 Tes Notifikasi',
      'Sistem notifikasi berjalan normal.',
      details,
    );
  }
}
