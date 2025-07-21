import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aidx/services/auth_service.dart';
import 'package:aidx/screens/auth/login_screen.dart';
import 'package:aidx/screens/dashboard_screen.dart';
import 'package:aidx/utils/theme.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:aidx/utils/constants.dart';
import 'package:aidx/services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('🔄 SplashScreen initState called');
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );
    
    _controller.forward();
    
    // Set a timeout to ensure we don't get stuck on splash screen
    _timeoutTimer = Timer(const Duration(seconds: 8), () {
      debugPrint('⚠️ Splash screen timeout - forcing navigation to login');
      if (mounted && _isLoading) {
        _forceNavigateToLogin();
      }
    });
    
    // Check authentication status after a delay
    Timer(const Duration(seconds: 2), () {
      _initializeApp();
    });
  }
  
  void _forceNavigateToLogin() {
    debugPrint('🔄 Force navigating to login screen due to timeout');
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
    }
  }
  
  Future<void> _initializeApp() async {
    try {
      debugPrint('🔄 Requesting notification permissions');
      _updateStatus('Requesting permissions...');
      
      debugPrint('🔄 Checking authentication status');
      _updateStatus('Checking login status...');
      await _checkAuthAndNavigate();
    } catch (e) {
      debugPrint('❌ Error in splash screen initialization: $e');
      _setError('Initialization failed: $e');
      // Force navigation to login after error
      _forceNavigateToLogin();
    }
  }
  
  void _updateStatus(String message) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
      });
    }
  }
  
  void _setError(String message) {
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }
  
  Future<void> _checkAuthAndNavigate() async {
    try {
      if (!mounted) return;
      
      AuthService? authService;
      try {
        authService = Provider.of<AuthService>(context, listen: false);
        debugPrint('✅ AuthService retrieved successfully');
      } catch (e) {
        debugPrint('❌ Error getting AuthService: $e');
        throw Exception('Failed to get AuthService: $e');
      }
      
      final bool isLoggedIn = authService.isLoggedIn;
      debugPrint('🔄 Auth check - isLoggedIn: $isLoggedIn');
      
      if (isLoggedIn) {
        debugPrint('✅ User is logged in, navigating to dashboard');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppConstants.routeDashboard);
      } else {
        debugPrint('ℹ️ User is not logged in, navigating to login screen');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error checking auth status: $e');
      _setError('Authentication check failed: $e');
      // Force navigation to login after error
      _forceNavigateToLogin();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timeoutTimer?.cancel();
    debugPrint('🔄 SplashScreen disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔄 SplashScreen build called');
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.bgGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bgGlassLight,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.favorite,
                    color: AppTheme.primaryColor,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                // App name
                const Text(
                  'AidX',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Tagline
                const Text(
                  'Your Personal Health Assistant',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Status message
                Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Loading indicator or error
                if (_isLoading)
                  const SpinKitPulse(
                    color: AppTheme.primaryColor,
                    size: 50.0,
                  )
                else if (_hasError)
                  Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 50,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _hasError = false;
                          });
                          _initializeApp();
                        },
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _forceNavigateToLogin,
                        child: const Text('Skip to Login'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 