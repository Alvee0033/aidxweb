import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/news_service.dart';
import '../services/bluetooth_service.dart';
import '../services/esp32_max30102_service.dart';
import '../services/notification_service.dart';
import '../models/news_model.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../widgets/app_drawer.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:aidx/screens/news_detail_screen.dart';
import 'dart:ui';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ecgController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _ecgAnimation;
  // Animated gradient background
  late AnimationController _bgController;
  late Animation<Alignment> _bgAlignment1;
  late Animation<Alignment> _bgAlignment2;

  String _selectedMood = '';
  // Demo placeholders so the UI shows sample vitals even when no device is connected
  String _heartRate = '72'; // bpm
  String _spo2 = '98'; // %
  String _temperature = '--';
  String _batteryLevel = '--';
  bool _isESP32Connected = false;
  NewsArticle? _currentNews;
  bool _isLoadingNews = false;
  List<NewsArticle> _newsPool = [];
  Timer? _newsRotationTimer;

  final NewsService _newsService = NewsService();
  final BluetoothService _bluetoothService = BluetoothService();
  final ESP32MAX30102Service _esp32Service = ESP32MAX30102Service();
  final NotificationService _notificationService = NotificationService();
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserMood();
    _loadHealthNews();
    _initializeESP32Service();
    _startNewsRotation();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _ecgController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _ecgAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ecgController, curve: Curves.linear),
    );
    _ecgController.repeat();

    // Background gradient animation
    _bgController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat(reverse: true);
    _bgAlignment1 = AlignmentTween(
      begin: Alignment.topLeft,
      end: Alignment.topRight,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
    _bgAlignment2 = AlignmentTween(
      begin: Alignment.bottomRight,
      end: Alignment.bottomLeft,
    ).animate(CurvedAnimation(parent: _bgController, curve: Curves.easeInOut));
  }

  Future<void> _loadUserMood() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedMood = prefs.getString('user_mood') ?? '';
    });
  }

  Future<void> _saveUserMood(String mood) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_mood', mood);
    setState(() {
      _selectedMood = mood;
    });
  }

  Future<void> _loadHealthNews({bool force = false}) async {
    setState(() {
      _isLoadingNews = true;
    });

    try {
      if (force || _newsPool.isEmpty) {
        _newsPool = await _newsService.getHealthNews();
        
        // If API returned 0 articles, use fallback data
        if (_newsPool.isEmpty) {
          _newsPool = _getFallbackNews();
        }
      }
      
      if (_newsPool.isNotEmpty) {
        // Select a random article from the pool
        final randomIndex = math.Random().nextInt(_newsPool.length);
        final selectedNews = _newsPool[randomIndex];
        
        setState(() {
          _currentNews = selectedNews;
        });
        
        // Show notification for new health news (only when forced refresh)
        if (force) {
          _notificationService.showNewsNotification(
            title: 'New Health Update',
            body: selectedNews.title,
          );
        }
      }
    } catch (e) {
      // If API fails, use fallback data
      _newsPool = _getFallbackNews();
      if (_newsPool.isNotEmpty) {
        final randomIndex = math.Random().nextInt(_newsPool.length);
        setState(() {
          _currentNews = _newsPool[randomIndex];
        });
      }
    } finally {
      setState(() {
        _isLoadingNews = false;
      });
    }
  }
  
  List<NewsArticle> _getFallbackNews() {
    return [
      NewsArticle(
        title: "WHO warns about rising flu cases this season",
        description: "Health authorities recommend vaccination",
        url: "",
        imageUrl: "https://source.unsplash.com/96x96/?virus",
        source: "WHO",
        publishedAt: DateTime.now().toIso8601String(),
      ),
      NewsArticle(
        title: "New study links walking 30 mins/day to better heart health",
        description: "Research shows significant cardiovascular benefits",
        url: "",
        imageUrl: "https://source.unsplash.com/96x96/?heart",
        source: "Health Research",
        publishedAt: DateTime.now().toIso8601String(),
      ),
      NewsArticle(
        title: "Researchers develop painless glucose monitoring patch",
        description: "Breakthrough in diabetes management technology",
        url: "",
        imageUrl: "https://source.unsplash.com/96x96/?glucose",
        source: "Medical Innovation",
        publishedAt: DateTime.now().toIso8601String(),
      ),
      NewsArticle(
        title: "Meditation shown to reduce stress hormones by 25%",
        description: "Study confirms mental health benefits",
        url: "",
        imageUrl: "https://source.unsplash.com/96x96/?meditation",
        source: "Wellness Research",
        publishedAt: DateTime.now().toIso8601String(),
      ),
    ];
  }

  void _startNewsRotation() {
    // Auto-rotate news every 12 seconds like the web version
    _newsRotationTimer = Timer.periodic(const Duration(seconds: 12), (timer) {
      if (mounted && _newsPool.isNotEmpty) {
        final randomIndex = math.Random().nextInt(_newsPool.length);
          setState(() {
          _currentNews = _newsPool[randomIndex];
          });
        }
    });
  }
  
  void _initializeESP32Service() async {
    await _esp32Service.init();
    
    // Listen to ESP32 connection state
    _esp32Service.connectionStateStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isESP32Connected = isConnected;
          // Reset values when disconnected
          if (!isConnected) {
            // Re-apply demo placeholders when device disconnects
            _heartRate = '72';
            _spo2 = '98';
            _temperature = '--';
            _batteryLevel = '--';
          }
        });
      }
    });
    
    // Listen to heart rate updates
    _esp32Service.heartRateStream.listen((heartRate) {
      if (mounted && heartRate > 0) {
        setState(() {
          _heartRate = heartRate.toString();
        });
      }
    });
    
    // Listen to SpO2 updates
    _esp32Service.spo2Stream.listen((spo2) {
      if (mounted && spo2 > 0) {
        setState(() {
          _spo2 = spo2.toString();
        });
      }
    });
    
    // Listen to temperature updates
    _esp32Service.temperatureStream.listen((temperature) {
      if (mounted && temperature > 0) {
        setState(() {
          _temperature = temperature.toStringAsFixed(1);
        });
      }
    });
    
    // Listen to battery updates
    _esp32Service.batteryStream.listen((battery) {
      if (mounted && battery > 0) {
        setState(() {
          _batteryLevel = battery.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ecgController.dispose();
    _newsRotationTimer?.cancel();
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.bgGlassLight,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF1F2937), Color(0xFF374151), Color(0xFF4B5563)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                FeatherIcons.activity,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'AidX',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textTeal,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<AuthService>(
            builder: (context, authService, child) {
              final user = authService.currentUser;
              final String initials = (user?.displayName != null && user!.displayName!.isNotEmpty)
                  ? user.displayName![0].toUpperCase()
                  : 'U';
              return GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppConstants.routeProfile),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF1F2937), Color(0xFF374151), Color(0xFF4B5563)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.bgDark,
                    backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                        ? NetworkImage(user.photoURL!) as ImageProvider
                        : null,
                    child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                        ? Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vitals Card
                      _buildVitalsCard(),
                      const SizedBox(height: 16),
                      
                      // News Card
                      _buildNewsCard(),
                      const SizedBox(height: 16),
                      
                      // Mood Selector
                      _buildMoodSelector(),
                      const SizedBox(height: 16),
                      
                      // Quick Actions Grid
                      _buildQuickActionsGrid(),
                      
                      // Optional: Health Tips (if you want to include it)
                      // const SizedBox(height: 16),
                      // _buildHealthTips(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ],
      ),
    );
  }

  Widget _buildVitalsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // Glassmorphism background
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(),
          ),
          Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.13),
                  AppTheme.bgGlassMedium.withOpacity(0.18),
                  Colors.white.withOpacity(0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                width: 1.8,
                color: AppTheme.successColor.withOpacity(0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.successColor.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated heart icon with glow
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.dangerColor.withOpacity(0.25 * _pulseAnimation.value),
                            blurRadius: 12 * _pulseAnimation.value,
                            spreadRadius: 1.5 * _pulseAnimation.value,
                          ),
                        ],
                      ),
                      child: Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF472B6), Color(0xFFFB7185)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pinkAccent.withOpacity(0.18),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            FeatherIcons.heart,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                // Title and badge
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Live Vitals',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isESP32Connected ? AppTheme.successColor : AppTheme.dangerColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(
                        color: _isESP32Connected 
                            ? AppTheme.successColor.withOpacity(0.16)
                            : AppTheme.dangerColor.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isESP32Connected ? 'ESP32 Connected' : 'No Device',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: _isESP32Connected ? AppTheme.successColor : AppTheme.dangerColor,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Heart Rate Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.dangerColor.withOpacity(0.18), Colors.white.withOpacity(0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.dangerColor.withOpacity(0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 10,
                        height: 7,
                        child: AnimatedBuilder(
                          animation: _ecgAnimation,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: ECGPainter(_ecgAnimation.value),
                              size: const Size(10, 7),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _heartRate,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.dangerColor,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'bpm',
                        style: TextStyle(
                          fontSize: 7,
                          color: AppTheme.dangerColor.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 1.2,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // SpO2 Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryColor.withOpacity(0.18), Colors.white.withOpacity(0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(FeatherIcons.droplet, size: 8, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _spo2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 7,
                          color: AppTheme.primaryColor.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 1.2,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Temperature Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.warningColor.withOpacity(0.18), Colors.white.withOpacity(0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.warningColor.withOpacity(0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(FeatherIcons.thermometer, size: 8, color: AppTheme.warningColor),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _temperature,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '°C',
                        style: TextStyle(
                          fontSize: 7,
                          color: AppTheme.warningColor.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
                // Divider
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 1.2,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Battery Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.infoColor.withOpacity(0.18), Colors.white.withOpacity(0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.infoColor.withOpacity(0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.infoColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(FeatherIcons.battery, size: 8, color: AppTheme.infoColor),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _batteryLevel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.infoColor,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 7,
                          color: AppTheme.infoColor.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                ),
                // Scan button when not connected
                if (!_isESP32Connected) ...[
                  // Divider
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 1.2,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Scan Button
                  GestureDetector(
                    onTap: () {
                      _esp32Service.startScan();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Scanning for ESP32 Smart Band...'),
                          backgroundColor: AppTheme.infoColor,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.infoColor.withOpacity(0.18), Colors.white.withOpacity(0.08)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.infoColor.withOpacity(0.10),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bluetooth_searching,
                            size: 10,
                            color: AppTheme.infoColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Scan',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.infoColor,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodSelector() {
    final moods = [
      {'emoji': '😁', 'label': 'Great'},
      {'emoji': '🙂', 'label': 'Good'},
      {'emoji': '😐', 'label': 'Okay'},
      {'emoji': '😕', 'label': 'Not Good'},
      {'emoji': '😞', 'label': 'Bad'},
    ];
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.sentiment_satisfied,
            color: AppTheme.warningColor,
            size: 16,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'How do you feel?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        ...moods.map((mood) {
          final isSelected = _selectedMood == mood['emoji'];
          return GestureDetector(
            onTap: () => _saveUserMood(mood['emoji']!),
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: isSelected ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF1F2937), Color(0xFF374151), Color(0xFF4B5563)],
                ) : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                mood['emoji']!,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      {
        'title': 'AI Symptoms\nAnalysis',
        'icon': Icons.sick_rounded,
        'color': AppTheme.warningColor,
        'route': AppConstants.routeSymptomAI,
      },
      {
        'title': 'AI Voice\nChat',
        'icon': Icons.chat_rounded,
        'color': AppTheme.accentColor,
        'route': AppConstants.routeChat,
      },
      {
        'title': 'Drug\nInfo',
        'icon': Icons.medication_rounded,
        'color': AppTheme.primaryColor,
        'route': AppConstants.routeDrug,
      },
      {
        'title': 'Hospital\nFinder',
        'icon': Icons.local_hospital_rounded,
        'color': AppTheme.dangerColor,
        'route': AppConstants.routeHospital,
      },
      {
        'title': 'Doctor & \nPharmacy',
        'icon': Icons.local_pharmacy_rounded,
        'color': AppTheme.successColor,
        'route': AppConstants.routeProfessionalsPharmacy,
      },
      {
        'title': 'Blood\nDonation',
        'icon': Icons.bloodtype_rounded,
        'color': AppTheme.dangerColor,
        'route': AppConstants.routeBloodDonation,
      },
      {
        'title': 'Medication\nReminder',
        'icon': Icons.alarm_rounded,
        'color': AppTheme.accentColor,
        'route': AppConstants.routeReminder,
      },
      {
        'title': 'Medical\nTimeline',
        'icon': Icons.timeline_rounded,
        'color': AppTheme.primaryColor,
        'route': AppConstants.routeTimeline,
      },
      {
        'title': 'Wearable\nTracker',
        'icon': Icons.watch_rounded,
        'color': AppTheme.infoColor,
        'route': AppConstants.routeWearable,
      },
      {
        'title': 'Emergency\nSOS',
        'icon': Icons.emergency_rounded,
        'color': AppTheme.dangerColor,
        'route': AppConstants.routeSos,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.flash_on,
                color: AppTheme.accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return _buildActionCard(
              title: action['title'] as String,
              icon: action['icon'] as IconData,
              color: action['color'] as Color,
              onTap: () => Navigator.pushNamed(context, action['route'] as String),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: 1),
        duration: const Duration(milliseconds: 200),
        builder: (context, scale, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.18),
                  Colors.white.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withOpacity(0.22), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.13),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.25), color.withOpacity(0.12)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontFamily: 'Montserrat',
                    letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHealthTips() {
    final tips = [
      'Stay hydrated - Drink 8 glasses of water daily',
      'Take regular breaks from screen time',
      'Practice deep breathing exercises',
      'Get 7-8 hours of sleep every night',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.successColor.withOpacity(0.1),
            AppTheme.successColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.successColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.lightbulb,
                  color: AppTheme.successColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Health Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...tips.map((tip) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildNewsCard() {
    if (_currentNews == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        if (_currentNews != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewsDetailScreen(article: _currentNews!),
            ),
          );
        }
      },
      child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.hardEdge,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.13),
              AppTheme.accentColor.withOpacity(0.13),
              Colors.white.withOpacity(0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            width: 1.5,
            color: AppTheme.accentColor.withOpacity(0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentColor.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Health News',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                    fontFamily: 'Montserrat',
                  ),
                ),
                if (_currentNews?.source != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accentColor.withOpacity(0.18), Colors.white.withOpacity(0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withOpacity(0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      _currentNews!.source!,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentColor,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                // News Content
                Expanded(
                  child: Text(
                    _currentNews!.title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.15,
                      fontFamily: 'Montserrat',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Large News Image Thumbnail on the right
                if (_currentNews!.imageUrl != null && _currentNews!.imageUrl!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentColor.withOpacity(0.13),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withOpacity(0.13),
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          _currentNews!.imageUrl!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 36,
                              height: 36,
                              color: Colors.grey.withOpacity(0.2),
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 14,
                              ),
                            );
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 36,
                              height: 36,
                              color: Colors.grey.withOpacity(0.2),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.accentColor.withOpacity(0.7),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                // View Full Article Button
                GestureDetector(
                  onTap: _currentNews != null
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NewsDetailScreen(article: _currentNews!),
                            ),
                          );
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryColor.withOpacity(0.18), Colors.white.withOpacity(0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.article,
                          size: 10,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View Full',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Reload Button
                GestureDetector(
                  onTap: _isLoadingNews ? null : () => _loadHealthNews(force: true),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accentColor.withOpacity(0.18), Colors.white.withOpacity(0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor.withOpacity(0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: _isLoadingNews
                        ? SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentColor,
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            size: 10,
                            color: AppTheme.accentColor,
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                // Notification Button
                GestureDetector(
                  onTap: _currentNews != null
                      ? () {
                          _notificationService.showNewsNotification(
                            title: 'Health News',
                            body: _currentNews!.title,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Notification sent'),
                              backgroundColor: AppTheme.successColor,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.warningColor.withOpacity(0.18), Colors.white.withOpacity(0.08)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.warningColor.withOpacity(0.10),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.notifications,
                      size: 10,
                      color: AppTheme.warningColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  // Animated background widget
  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: _bgAlignment1.value,
              end: _bgAlignment2.value,
              colors: [
                AppTheme.bgMedium,
                AppTheme.bgDark,
              ],
            ),
          ),
        );
      },
    );
  }
}

class ECGPainter extends CustomPainter {
  final double animationValue;

  ECGPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF472B6)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = [
      Offset(0, size.height * 0.5),
      Offset(size.width * 0.1, size.height * 0.5),
      Offset(size.width * 0.2, size.height * 0.17),
      Offset(size.width * 0.3, size.height * 0.83),
      Offset(size.width * 0.4, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.5),
      Offset(size.width * 0.6, size.height * 0.17),
      Offset(size.width * 0.7, size.height * 0.83),
      Offset(size.width * 0.8, size.height * 0.5),
      Offset(size.width * 0.9, size.height * 0.5),
      Offset(size.width, size.height * 0.5),
    ];

    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 