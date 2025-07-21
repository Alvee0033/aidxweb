import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'medigay_channel';
  static const String _channelName = 'MediGay Notifications';
  static const String _channelDescription = 'General notifications for MediGay app';

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      // Configure local timezone (required for scheduled notifications)
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      await _createNotificationChannel();
      
      _isInitialized = true;
      debugPrint('✅ Local notification service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
      _isInitialized = false;
    }
  }

  Future<void> _createNotificationChannel() async {
    try {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      );

      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      
      debugPrint('✅ Notification channel created successfully');
    } catch (e) {
      debugPrint('❌ Error creating notification channel: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap here if needed
  }

  // Build generic notification details
  NotificationDetails _notificationDetails({String? soundName}) {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      // Remove sound dependency since the file is corrupted
      // sound: soundName != null 
      //     ? RawResourceAndroidNotificationSound(soundName)
      //     : const RawResourceAndroidNotificationSound('notification_sound'),
    );

    return NotificationDetails(android: androidDetails);
  }

  Future<bool> _ensurePermissions() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting notification permissions: $e');
      return false;
    }
  }

  // Show an immediate notification
  Future<void> showNotification({
    required String title, 
    required String body,
    String? soundName,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final hasPermission = await _ensurePermissions();
      if (!hasPermission) {
        debugPrint('❌ Notification permission not granted');
        return;
      }

      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        _notificationDetails(soundName: soundName),
        payload: payload,
      );
      
      debugPrint('✅ Notification shown successfully: $title');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  // Schedule a one-time notification
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? soundName,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final hasPermission = await _ensurePermissions();
      if (!hasPermission) {
        debugPrint('❌ Notification permission not granted');
        return;
      }

      final int id = scheduledTime.millisecondsSinceEpoch.remainder(100000);
      
      // Convert to TZDateTime
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        _notificationDetails(soundName: soundName),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      
      debugPrint('✅ Notification scheduled successfully for ${scheduledTime.toString()}');
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
    }
  }

  // Schedule a recurring notification
  Future<void> scheduleRecurringNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String frequency, // 'daily', 'weekly', 'monthly'
    String? soundName,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await init();
      }

      final hasPermission = await _ensurePermissions();
      if (!hasPermission) {
        debugPrint('❌ Notification permission not granted');
        return;
      }

      final int id = scheduledTime.millisecondsSinceEpoch.remainder(100000);
      
      // Convert to TZDateTime
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      
      // Determine recurrence based on frequency
      tz.TZDateTime? nextScheduledTime;
      switch (frequency.toLowerCase()) {
        case 'daily':
          nextScheduledTime = tzScheduledTime.add(const Duration(days: 1));
          break;
        case 'weekly':
          nextScheduledTime = tzScheduledTime.add(const Duration(days: 7));
          break;
        case 'monthly':
          nextScheduledTime = tzScheduledTime.add(const Duration(days: 30));
          break;
        default:
          nextScheduledTime = tzScheduledTime.add(const Duration(days: 1));
      }
      
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        _notificationDetails(soundName: soundName),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents: _getDateTimeComponents(frequency),
      );
      
      debugPrint('✅ Recurring notification scheduled successfully for ${scheduledTime.toString()}');
    } catch (e) {
      debugPrint('❌ Error scheduling recurring notification: $e');
    }
  }

  DateTimeComponents? _getDateTimeComponents(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return DateTimeComponents.time;
      case 'weekly':
        return DateTimeComponents.dayOfWeekAndTime;
      case 'monthly':
        return DateTimeComponents.dayOfMonthAndTime;
      default:
        return null;
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      debugPrint('✅ Notification cancelled: $id');
    } catch (e) {
      debugPrint('❌ Error cancelling notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      debugPrint('✅ All notifications cancelled');
    } catch (e) {
      debugPrint('❌ Error cancelling all notifications: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  Future<void> showNewsNotification({
    required String title,
    required String body,
  }) async {
    await showNotification(
      title: title, 
      body: body,
      payload: 'news',
    );
  }

  Future<void> showMedicationReminder({
    required String title,
    required String body,
  }) async {
    await showNotification(
      title: title, 
      body: body,
      payload: 'medication',
    );
  }

  Future<void> showEmergencyNotification({
    required String title,
    required String body,
  }) async {
    await showNotification(
      title: title, 
      body: body,
      payload: 'emergency',
    );
  }

  // Test notification method
  Future<void> testNotification() async {
    await showNotification(
      title: 'Test Notification',
      body: 'This is a test notification from MediGay app',
      payload: 'test',
    );
  }
} 