import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:artoku_app/core/services/logger_service.dart';

class NotificationPermissionResult {
  final bool notificationGranted;
  final bool exactAlarmGranted;

  const NotificationPermissionResult({
    required this.notificationGranted,
    required this.exactAlarmGranted,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _dailyChannelId = 'channel_daily_reminder_artoku_v2';
  static const String _dailyChannelName = 'Pengingat Harian';

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    tz.initializeTimeZones();

    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      LoggerService.info('Timezone diset manual ke Asia/Jakarta');
    } catch (e) {
      LoggerService.error('Gagal set timezone', e);
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

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
        LoggerService.info('Notifikasi diklik user: ${details.payload}');
      },
    );

    // Pastikan channel dibuat dengan konfigurasi high importance + sound.
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _dailyChannelId,
        _dailyChannelName,
        description: 'Notifikasi jadwal rutin',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  Future<NotificationPermissionResult> requestPermissions() async {
    bool notificationGranted = true;
    bool exactAlarmGranted = true;

    if (_isAndroid) {
      if (await Permission.notification.isDenied) {
        final status = await Permission.notification.request();
        notificationGranted = status.isGranted;
      } else {
        final status = await Permission.notification.status;
        notificationGranted = status.isGranted || status.isLimited;
      }

      // Exact alarm boleh tidak granted, karena kita bisa fallback ke inexact.
      final exactStatus = await Permission.scheduleExactAlarm.status;
      if (exactStatus.isDenied) {
        LoggerService.warning('Izin Exact Alarm belum aktif, meminta izin...');
        final requested = await Permission.scheduleExactAlarm.request();
        exactAlarmGranted = requested.isGranted;
      } else {
        exactAlarmGranted = exactStatus.isGranted;
      }
    }

    return NotificationPermissionResult(
      notificationGranted: notificationGranted,
      exactAlarmGranted: exactAlarmGranted,
    );
  }

  Future<bool> _hasNotificationPermission() async {
    if (!_isAndroid) return true;

    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited;
  }

  Future<bool> _canUseExactAlarm() async {
    if (!_isAndroid) return true;

    final status = await Permission.scheduleExactAlarm.status;
    return status.isGranted;
  }

  Future<bool> scheduleAllReminders() async {
    final hasNotifPermission = await _hasNotificationPermission();
    if (!hasNotifPermission) {
      LoggerService.warning(
        'Notifikasi tidak dijadwalkan: izin POST_NOTIFICATIONS belum diberikan.',
      );
      return false;
    }

    await cancelAllNotifications();
    LoggerService.info('Menjadwalkan ulang notifikasi...');

    final bool canExact = await _canUseExactAlarm();
    final AndroidScheduleMode scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    if (canExact) {
      LoggerService.info('Mode jadwal: exactAllowWhileIdle');
    } else {
      LoggerService.warning(
        'Exact alarm tidak tersedia, fallback ke inexactAllowWhileIdle.',
      );
    }

    final ok1 = await _scheduleDaily(
      id: 101,
      title: 'Waktunya Makan Siang! 🍛',
      body: 'Jangan lupa catat pengeluaran makanmu ya!',
      hour: 12,
      minute: 15,
      scheduleMode: scheduleMode,
    );

    final ok2 = await _scheduleDaily(
      id: 102,
      title: 'Rekap Harian 🌙',
      body: 'Cek dompetmu, ada pengeluaran tak terduga hari ini?',
      hour: 20,
      minute: 00,
      scheduleMode: scheduleMode,
    );

    return ok1 && ok2;
  }

  Future<bool> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required AndroidScheduleMode scheduleMode,
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
            _dailyChannelId,
            _dailyChannelName,
            channelDescription: 'Notifikasi jadwal rutin',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            visibility: NotificationVisibility.public,
            category: AndroidNotificationCategory.reminder,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      LoggerService.info('Jadwal ID $id BERHASIL: $scheduledDate');
      return true;
    } catch (e, stack) {
      LoggerService.error('GAGAL jadwal notifikasi ID $id', e, stack);
      return false;
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

  Future<void> debugPendingNotifications() async {
    try {
      final pending = await flutterLocalNotificationsPlugin
          .pendingNotificationRequests();
      LoggerService.info('=== PENDING NOTIFICATIONS: ${pending.length} ===');
      for (var n in pending) {
        LoggerService.info('  ID: ${n.id}, Title: ${n.title}');
      }
      if (pending.isEmpty) {
        LoggerService.warning(
          'TIDAK ADA notifikasi terjadwal! Kemungkinan dibatalkan OS/izin.',
        );
      }
    } catch (e) {
      LoggerService.error('Gagal cek pending notifications', e);
    }
  }

  Future<void> showInstantNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'channel_test_instant',
          'Tes Instan',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await flutterLocalNotificationsPlugin.show(
      999,
      '🔔 Tes Notifikasi',
      'Sistem notifikasi berjalan normal.',
      details,
    );
  }
}
