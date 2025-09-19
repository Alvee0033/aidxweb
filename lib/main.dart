import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:aidx/services/auth_service.dart';
import 'package:aidx/services/firebase_service.dart';
import 'package:aidx/services/database_init.dart';
import 'package:aidx/providers/health_provider.dart';
import 'package:aidx/services/notification_service.dart';
import 'package:aidx/screens/splash_screen.dart';
import 'package:aidx/utils/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:aidx/utils/constants.dart';
import 'package:aidx/screens/dashboard_screen.dart';
import 'package:aidx/screens/auth/login_screen.dart';
import 'package:aidx/screens/profile_screen.dart';
import 'package:aidx/screens/wearable_screen.dart';
import 'package:aidx/screens/sos_screen.dart';
import 'package:aidx/screens/drug_screen.dart';
import 'package:aidx/screens/symptom_screen.dart';
import 'package:aidx/screens/chat_screen.dart';
import 'package:aidx/screens/hospital_screen.dart';
import 'package:aidx/screens/pharmacy_screen.dart';
import 'package:aidx/screens/professionals_pharmacy_screen.dart';
import 'package:aidx/screens/reminder_screen.dart';
import 'package:aidx/screens/timeline_screen.dart';
import 'package:aidx/screens/ai_symptom_screen.dart';
import 'package:aidx/screens/blood_donation_screen.dart';
import 'package:aidx/screens/health_id_screen.dart';
import 'package:aidx/screens/qr_scanner_screen.dart';
import 'package:aidx/services/social_media_service.dart';
import 'package:aidx/screens/health_habits_screen.dart';
import 'package:aidx/screens/sleep_fall_detection_screen.dart';
import 'package:aidx/providers/community_provider.dart';

import 'package:aidx/screens/community_support_screen.dart';
import 'package:aidx/services/background_service.dart';
import 'package:aidx/services/app_state_service.dart';
import 'package:aidx/services/data_persistence_service.dart';
import 'dart:async' show unawaited;

import 'firebase_options.dart';
import 'utils/permission_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aidx/screens/vitals_screen.dart';
import 'package:aidx/services/android_wearable_service.dart';
import 'package:aidx/services/wear_os_channel.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:aidx/screens/inbox_screen.dart';
import 'package:aidx/screens/ai_vision_screen.dart';
import 'package:aidx/screens/ai_video_call_screen.dart';

// Global RouteObserver for route aware widgets
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    WearOsChannel.init();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  
  // Add debug output
  debugPrint('🚀 Starting app initialization...');
  
  // Configure system UI and text input handling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  
  // Configure text input handling
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );
  
  try {
    // Initialize Firebase
    debugPrint('📱 Initializing Firebase...');
    FirebaseApp app;

    // Prefer a safe, non-exception control flow especially for Web
    if (Firebase.apps.isEmpty) {
      app = await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully (cold start)');
    } else {
      app = Firebase.apps.first;
      debugPrint('ℹ️ Firebase already initialized, reusing existing instance');
    }
    
    // Start heavy services in the background to avoid blocking first frame
    // Use unawaited to prevent blocking the main thread
    unawaited(_initializeHeavyServices());
    
    debugPrint('🚀 Running app...');
    runApp(const MyApp());
    
  } catch (e) {
    debugPrint('❌ Error during app initialization: $e');
    // Run app with error state
    runApp(const AppErrorState());
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 FCM Background message received: ${message.messageId}');

  // Ensure Firebase is initialized in background isolate
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('✅ Firebase initialized in background');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed in background: $e');
    return;
  }

  try {
    final notificationService = NotificationService();
    await notificationService.init();
    debugPrint('✅ Notification service initialized in background');

    final title = message.notification?.title ?? (message.data['title'] ?? 'AidX');
    final body = message.notification?.body ?? (message.data['body'] ?? '');

    debugPrint('🔔 Showing notification - Title: $title, Body: $body');

    await notificationService.showNotification(
      title: title,
      body: body,
      payload: message.data['payload'] as String?,
    );

    debugPrint('✅ Background notification shown successfully');
  } catch (e) {
    debugPrint('❌ Error handling background message: $e');
  }
}

// Initialize Firestore sample data without blocking UI startup
Future<void> _initializeSampleData() async {
  try {
    debugPrint('📱 Initializing sample data in background...');
    final dbInit = DatabaseService();
    // Don't initialize database again, just use the existing instance
    // await dbInit.initializeDatabase(); - removing this line to avoid duplicate initialization
    debugPrint('✅ Sample data initialization complete');
  } catch (e) {
    debugPrint('⚠️ Error initializing sample data: $e');
  }
}

// Initializes services that can run in the background after the first frame.
Future<void> _initializeHeavyServices() async {
  try {
    debugPrint('🛠️ Background initializing services...');

    // Notification service - initialize synchronously for reliability
    try {
      final notificationService = NotificationService();
      await notificationService.init();
      debugPrint('✅ Notification service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
      // Retry notification initialization after a short delay
      try {
        await Future.delayed(const Duration(seconds: 2));
        final notificationService = NotificationService();
        await notificationService.init();
        debugPrint('✅ Notification service initialized on retry');
      } catch (retryError) {
        debugPrint('❌ Notification service retry failed: $retryError');
      }
    }

    // Set preferred orientations (not critical for first frame)
    if (!kIsWeb) {
      try {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        debugPrint('✅ Preferred orientations set');
      } catch (e) {
        debugPrint('⚠️ Error setting orientations: $e');
      }
    }

    // Database initialization - run in background
    try {
      final databaseService = DatabaseService();
      await databaseService.initializeDatabase();
      debugPrint('✅ Database structure initialized');
    } catch (e) {
      debugPrint('⚠️ Error initializing database structure in background: $e');
    }
    
    // Initialize sample data in background
    _initializeSampleData();
  } catch (e) {
    debugPrint('⚠️ Background service initialization error: $e');
  }
}

// Error state widget to show when app initialization fails
class AppErrorState extends StatelessWidget {
  const AppErrorState({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your internet connection and try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Restart app
                  main();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('📱 Building MyApp widget...');

    // Create services once and reuse them
    final authService = AuthService();
    final firebaseService = FirebaseService();

    debugPrint('📱 Auth service created, isLoggedIn: ${authService.isLoggedIn}');

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final prefs = snapshot.data!;
        final appStateService = AppStateService(prefs);
        final dataPersistenceService = DataPersistenceService();

        return MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: authService),
            ChangeNotifierProvider<FirebaseService>.value(value: firebaseService),
            ChangeNotifierProvider<HealthProvider>(create: (_) => HealthProvider()),
            ChangeNotifierProvider<CommunityProvider>(create: (_) => CommunityProvider()),
            if (!kIsWeb)
              ChangeNotifierProvider<AndroidWearableService>(
                create: (_) {
                  final svc = AndroidWearableService();
                  // Initialize and attempt auto-reconnect in background
                  // ignore: unawaited_futures
                  svc.initialize().then((_) => svc.autoReconnect());
                  return svc;
                },
              ),
            Provider<DatabaseService>(create: (_) => DatabaseService()),
            ChangeNotifierProvider<AppStateService>.value(value: appStateService),
            Provider<DataPersistenceService>.value(value: dataPersistenceService),
            Provider<SocialMediaService>(create: (_) => SocialMediaService()),
          ],
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.bgGradient,
            ),
            child: MaterialApp(
              title: 'AidX',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              navigatorObservers: [routeObserver],
              builder: (context, child) {
                return AppLifecycleWrapper(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaleFactor: 1.0,
                      alwaysUse24HourFormat: true,
                    ),
                    child: child!,
                  ),
                );
              },
              initialRoute: '/',
              routes: {
                '/': (context) {
                  debugPrint('📱 Loading SplashScreen...');
                  return const SplashScreen();
                },
                AppConstants.routeAiVision: (context) => const AiVisionScreen(),
                AppConstants.routeAiVideoCall: (context) => const AiVideoCallScreen(),
                AppConstants.routeLogin: (context) => const LoginScreen(),
                AppConstants.routeDashboard: (context) => const DashboardScreen(),
                AppConstants.routeProfile: (context) => const ProfileScreen(),
                AppConstants.routeWearable: (context) => const WearableScreen(),
                AppConstants.routeSos: (context) => const SosScreen(),
                AppConstants.routeDrug: (context) => const DrugScreen(),
                AppConstants.routeSymptom: (context) => const SymptomScreen(),
                AppConstants.routeSymptomAI: (context) => const AISymptomScreen(),
                AppConstants.routeChat: (context) => const ChatScreen(),
                AppConstants.routeHospital: (context) => const HospitalScreen(),
                AppConstants.routePharmacy: (context) => const PharmacyScreen(),
                AppConstants.routeProfessionalsPharmacy: (context) => const ProfessionalsPharmacyScreen(),
                AppConstants.routeReminder: (context) => const ReminderScreen(),
                AppConstants.routeTimeline: (context) => const TimelineScreen(),
                AppConstants.routeBloodDonation: (context) => const BloodDonationScreen(),
                AppConstants.routeHealthId: (context) => const HealthIdScreen(),
                '/qr-scanner': (context) => const QRScannerScreen(),
                AppConstants.routeVitals: (context) => const VitalsScreen(),
                '/inbox': (context) => const InboxScreen(),
                AppConstants.routeHealthHabits: (context) => const HealthHabitsScreen(),
                AppConstants.routeSleepFallDetection: (context) => const SleepFallDetectionScreen(),
                AppConstants.routeCommunitySupport: (context) => const CommunityFacebookScreen(),
              },
            ),
          ),
        );
      },
    );
  }
}


class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;
  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Also check immediately on first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingOpenSos());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingOpenSos();
    }
  }

  Future<void> _checkPendingOpenSos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check for pending SOS
      final bool openSos = prefs.getBool('pending_open_sos') ?? false;
      if (openSos) {
        await prefs.setBool('pending_open_sos', false);
        if (!mounted) return;
        // Use pushNamedAndRemoveUntil to ensure we navigate to SOS screen directly
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppConstants.routeSos,
          (route) => false, // Remove all routes
        );
        return;
      }
      
      // Check for pending chat
      final String? pendingChat = prefs.getString('pending_open_chat');
      if (pendingChat != null && pendingChat.isNotEmpty) {
        await prefs.remove('pending_open_chat');
        if (!mounted) return;
        // Navigate to inbox screen for chat notifications
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/inbox', // We'll need to add this route
          (route) => false, // Remove all routes
        );
      }
    } catch (e) {
      // Ignore navigation errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}