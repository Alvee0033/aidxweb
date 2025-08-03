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
import 'firebase_options.dart';
import 'utils/permission_utils.dart';
import 'package:aidx/screens/vitals_screen.dart';

// Global RouteObserver for route aware widgets
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    FirebaseApp? app;
    
    try {
      // Try to get existing app first
      app = Firebase.app();
      debugPrint('ℹ️ Firebase already initialized, reusing existing instance');
    } on FirebaseException catch (e) {
      if (e.code != 'no-app') {
        // Unexpected Firebase error, rethrow
        rethrow;
      }
      // If no app exists, attempt to initialise a new one
      try {
        app = await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('✅ Firebase initialized successfully (cold start)');
      } on FirebaseException catch (e) {
        if (e.code == 'duplicate-app') {
          // Another isolate/thread initialised Firebase in the meantime – reuse it
          debugPrint('ℹ️ Firebase duplicate-app detected, fetching existing instance');
          app = Firebase.app();
        } else {
          rethrow; // Propagate other errors
        }
      }
    }
    
    // Start heavy services in the background to avoid blocking first frame
    _initializeHeavyServices();
    
    debugPrint('🚀 Running app...');
    runApp(const MyApp());
    
    // Also kick off sample data (should run after DB init in _initializeHeavyServices)
    _initializeSampleData();
    
  } catch (e) {
    debugPrint('❌ Error during app initialization: $e');
    // Run app with error state
    runApp(const AppErrorState());
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

    // Notification service
    final notificationService = NotificationService();
    await notificationService.init();
    debugPrint('✅ Notification service initialized');

    // Request critical runtime permissions (notifications, location, Bluetooth)
    await PermissionUtils.requestCriticalPermissions();
    debugPrint('✅ Runtime permissions requested');

    // Set preferred orientations (not critical for first frame)
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    debugPrint('✅ Preferred orientations set');

    // Database initialization
    try {
      final databaseService = DatabaseService();
      await databaseService.initializeDatabase();
      debugPrint('✅ Database structure initialized');
    } catch (e) {
      debugPrint('⚠️ Error initializing database structure in background: $e');
    }
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
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<FirebaseService>.value(value: firebaseService),
        ChangeNotifierProvider<HealthProvider>(create: (_) => HealthProvider()),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
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
          // Add configurations for better text input handling
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaleFactor: 1.0,
                alwaysUse24HourFormat: true,
              ),
              child: child!,
            );
          },
          initialRoute: '/',
          routes: {
            '/': (context) {
              debugPrint('📱 Loading SplashScreen...');
              return const SplashScreen();
            },
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
            AppConstants.routeVitals: (context) => const VitalsScreen(),
          },
        ),
      ),
    );
  }
} 