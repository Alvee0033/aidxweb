import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';

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
  StreamSubscription<QuerySnapshot>? _chatSubscription;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<RemoteMessage>? _fgMessageSub;

  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('✅ Notification service already initialized');
      return;
    }

    try {
      debugPrint('🔄 Initializing notification service...');

      // Configure local timezone (required for scheduled notifications)
      tz.initializeTimeZones();
      debugPrint('✅ Timezone initialized');

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      final bool? initResult = await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initResult == false) {
        throw Exception('FlutterLocalNotificationsPlugin initialization failed');
      }

      debugPrint('✅ FlutterLocalNotificationsPlugin initialized');

      // Create notification channel for Android
      if (!kIsWeb) {
        await _createNotificationChannel();
      }

      _isInitialized = true;
      debugPrint('✅ Local notification service initialized successfully');

      // Start listening to auth changes and then watch chats when logged in
      _startAuthListener();

      // Initialize FCM (skip Web unless specifically handled)
      if (!kIsWeb) {
        await _initFcm();
      } else {
        debugPrint('ℹ️ Skipping FCM initialization on Web (not configured)');
      }

      // Test if notifications work by checking pending notifications
      try {
        final pending = await getPendingNotifications();
        debugPrint('📊 Pending notifications count: ${pending.length}');
      } catch (e) {
        debugPrint('⚠️ Could not check pending notifications: $e');
      }

      debugPrint('🎉 Notification service fully initialized and ready!');
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
      _isInitialized = false;
      rethrow; // Re-throw to allow caller to handle the error
    }
  }

  // Ensure the service is initialized before use
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      debugPrint('🔄 Notification service not initialized, initializing now...');
      await init();
    }
  }

  Future<void> _initFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission with detailed logging
      debugPrint('🔔 Requesting FCM permissions...');
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: true,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint('🔔 FCM permission status:');
      debugPrint('  - Alert: ${settings.alert}');
      debugPrint('  - Badge: ${settings.badge}');
      debugPrint('  - Sound: ${settings.sound}');
      debugPrint('  - Authorization: ${settings.authorizationStatus}');

      // Get and save FCM token
      debugPrint('🔑 Getting FCM token...');
      final token = await messaging.getToken();
      if (token != null) {
        debugPrint('✅ FCM token obtained: ${token.substring(0, 20)}...');
        await _saveFcmToken(token);
      } else {
        debugPrint('❌ Failed to get FCM token');
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM token refreshed');
        _saveFcmToken(newToken);
      });

      // Handle foreground messages
      debugPrint('👂 Setting up foreground message listener...');
      _fgMessageSub?.cancel();
      _fgMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📱 Foreground FCM message received: ${message.messageId}');
        _handleRemoteMessage(message);
      });

      // Handle background/terminated message tap
      debugPrint('👂 Setting up background message tap listener...');
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔙 App opened from background FCM message: ${message.messageId}');
        _handleRemoteMessage(message);
      });

      // Check for initial message (app opened from terminated state)
      debugPrint('🔍 Checking for initial FCM message...');
      final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMsg != null) {
        debugPrint('📬 Initial FCM message found: ${initialMsg.messageId}');
        _handleRemoteMessage(initialMsg);
      }

      debugPrint('✅ FCM initialization completed successfully');
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  Future<void> _saveFcmToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcm': {
          'token': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
      debugPrint('✅ FCM token saved');
    } catch (e) {
      debugPrint('⚠️ Failed to save FCM token: $e');
    }
  }

  void _handleRemoteMessage(RemoteMessage message) async {
    try {
      debugPrint('📨 Handling FCM message: ${message.messageId}');
      debugPrint('📨 Message data: ${message.data}');
      debugPrint('📨 Notification: ${message.notification?.title} - ${message.notification?.body}');

      final title = message.notification?.title ?? (message.data['title'] ?? 'AidX');
      final body = message.notification?.body ?? (message.data['body'] ?? '');
      final payload = message.data['payload'] as String?;

      debugPrint('🔔 Preparing to show notification: "$title" - "$body"');

      // Ensure service is initialized before showing notification
      if (!_isInitialized) {
        debugPrint('🔄 Notification service not initialized, initializing...');
        await init();
      }

      await showNotification(
        title: title,
        body: body,
        payload: payload,
      );

      debugPrint('✅ FCM message handled and notification shown');
    } catch (e) {
      debugPrint('❌ Error handling remote message: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
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

  void _onNotificationTapped(NotificationResponse response) async {
    try {
      final payload = response.payload ?? '';
      debugPrint('Notification tapped: $payload');
      // For fall detection / SOS alerts, route to SOS screen
      if (payload.contains('fall') || payload.contains('sos')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_open_sos', true);
        if (Platform.isAndroid) {
          final intent = AndroidIntent(
            action: 'android.intent.action.MAIN',
            category: 'android.intent.category.LAUNCHER',
            package: 'com.aidx.health.app',
            componentName: 'com.aidx.health.app.MainActivity',
          );
          await intent.launch();
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  }

  void _startAuthListener() {
    try {
      _authSubscription?.cancel();
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        _chatSubscription?.cancel();
        if (user != null) {
          _startChatListenerForUser(user.uid);
        }
      });
    } catch (e) {
      debugPrint('❌ Error starting auth listener: $e');
    }
  }

  void _startChatListenerForUser(String userId) {
    try {
      _chatSubscription?.cancel();
      _chatSubscription = FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: userId)
          .snapshots()
          .listen((snapshot) async {
        for (final doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.modified || doc.type == DocumentChangeType.added) {
            final data = doc.doc.data() as Map<String, dynamic>;
            final lastSenderId = data['lastSenderId'] as String?;
            final lastMessage = data['lastMessage'] as String? ?? '';
            final participants = List<String>.from(data['participants'] ?? []);
            final unreadBy = List<String>.from(data['unreadBy'] ?? []);
            if (lastSenderId != null && lastSenderId != userId && lastMessage.isNotEmpty && unreadBy.contains(userId)) {
              final peerId = participants.firstWhere((id) => id != userId, orElse: () => '');
              String peerName = 'New message';
              if (peerId.isNotEmpty) {
                try {
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(peerId).get();
                  final profile = (userDoc.data() ?? {})['profile'] as Map<String, dynamic>?;
                  if (profile != null && (profile['name'] as String?)?.isNotEmpty == true) {
                    peerName = profile['name'] as String;
                  }
                } catch (_) {}
              }
              await showNotification(title: peerName, body: lastMessage, payload: 'chat');
            }
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Error starting chat listener: $e');
    }
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
      // Check notification permission
      final notificationStatus = await Permission.notification.status;
      debugPrint('🔔 Notification permission status: $notificationStatus');

      if (!notificationStatus.isGranted) {
        debugPrint('🔄 Requesting notification permission...');
        final result = await Permission.notification.request();
        debugPrint('🔔 Notification permission result: $result');

        if (!result.isGranted) {
          if (result.isPermanentlyDenied) {
            debugPrint('❌ Notification permission permanently denied, opening app settings...');
            // Try to open app settings
            try {
              await openAppSettings();
            } catch (settingsError) {
              debugPrint('❌ Error opening app settings: $settingsError');
            }
          }
          return false;
        }
      }

      // Check exact alarm permission for Android 12+
      if (Platform.isAndroid) {
        final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
        debugPrint('⏰ Exact alarm permission status: $exactAlarmStatus');

        if (!exactAlarmStatus.isGranted) {
          debugPrint('🔄 Requesting exact alarm permission...');
          final exactAlarmResult = await Permission.scheduleExactAlarm.request();
          debugPrint('⏰ Exact alarm permission result: $exactAlarmResult');

          if (!exactAlarmResult.isGranted) {
            debugPrint('⚠️ Exact alarm permission not granted - scheduled notifications may not work reliably');
            // Still allow to continue, but log the issue
          }
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  // Request notification permissions with user feedback
  Future<bool> requestPermissions() async {
    try {
      debugPrint('🔄 Requesting notification permissions...');
      final status = await Permission.notification.request();
      final granted = status.isGranted;
      debugPrint('🔔 Notification permission ${granted ? 'granted' : 'denied'}');
      return granted;
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  // Check if permissions are granted
  Future<bool> hasPermissions() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
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
      debugPrint('🔔 Attempting to show notification: "$title" - "$body"');

      if (!_isInitialized) {
        debugPrint('🔄 Notification service not initialized, initializing...');
        await init();
      }

      final hasPermission = await _ensurePermissions();
      if (!hasPermission) {
        debugPrint('❌ Notification permission not granted - cannot show notification');
        return;
      }

      // Ensure notification channel exists
      await _createNotificationChannel();

      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      debugPrint('🆔 Generated notification ID: $id');

      final details = _notificationDetails(soundName: soundName);
      debugPrint('📋 Notification details prepared');

      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Notification shown successfully: "$title"');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
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
      // Ensure service is initialized
      await _ensureInitialized();

      final hasPermission = await _ensurePermissions();
      if (!hasPermission) {
        debugPrint('❌ Notification permission not granted');
        throw Exception('Notification permission not granted');
      }

      // Validate scheduled time is in the future
      final now = DateTime.now();
      if (scheduledTime.isBefore(now)) {
        debugPrint('❌ Cannot schedule notification for past time: $scheduledTime');
        throw Exception('Cannot schedule notification for past time');
      }

      // Generate a unique ID based on title and scheduled time to avoid conflicts
      final int id = (title.hashCode + scheduledTime.millisecondsSinceEpoch.hashCode).abs() % 999999;

      // Ensure notification channel is created before scheduling
      await _createNotificationChannel();

      // Convert to TZDateTime
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      debugPrint('📅 Scheduling notification: ID=$id, Time=$tzScheduledTime, Title="$title"');

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        _notificationDetails(soundName: soundName),
        androidAllowWhileIdle: true,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      debugPrint('✅ Notification scheduled successfully for ${scheduledTime.toString()} (ID: $id)');
    } catch (e) {
      debugPrint('❌ Error scheduling notification: $e');
      rethrow; // Re-throw to allow caller to handle the error
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

      // Generate a unique ID based on title, frequency, and scheduled time to avoid conflicts
      final int id = (title.hashCode + frequency.hashCode + scheduledTime.millisecondsSinceEpoch.hashCode).abs() % 999999;

      // Ensure notification channel is created before scheduling
      await _createNotificationChannel();

      // Convert to TZDateTime
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      debugPrint('🔄 Scheduling recurring notification: ID=$id, Time=$tzScheduledTime, Title="$title", Frequency="$frequency"');

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        _notificationDetails(soundName: soundName),
        androidAllowWhileIdle: true,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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

  // Topic subscriptions for habits reminders
  Future<void> subscribeToTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Topic subscribe failed: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Topic unsubscribe failed: $e');
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
    try {
      await _ensureInitialized();

      await showNotification(
        title: 'Test Notification',
        body: 'This is a test notification from AidX app',
        payload: 'test',
      );

      debugPrint('✅ Test notification sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending test notification: $e');
      rethrow;
    }
  }

  // Test scheduled notification method
  Future<void> testScheduledNotification() async {
    try {
      await _ensureInitialized();

      final testTime = DateTime.now().add(const Duration(seconds: 10));
      await scheduleNotification(
        title: 'Test Scheduled Notification',
        body: 'This notification was scheduled 10 seconds ago',
        scheduledTime: testTime,
      );

      debugPrint('✅ Test scheduled notification set for $testTime');
    } catch (e) {
      debugPrint('❌ Error scheduling test notification: $e');
      rethrow;
    }
  }

  // Get notification service status
  Future<Map<String, dynamic>> getServiceStatus() async {
    return {
      'isInitialized': _isInitialized,
      'hasPermissions': await hasPermissions(),
      'pendingNotifications': await getPendingNotifications().then((list) => list.length),
    };
  }
} 