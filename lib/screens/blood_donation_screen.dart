import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/theme.dart';
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'chat_thread_screen.dart';
import 'inbox_screen.dart';

class BloodDonationScreen extends StatefulWidget {
  const BloodDonationScreen({Key? key}) : super(key: key);

  @override
  State<BloodDonationScreen> createState() => _BloodDonationScreenState();
}

class _BloodDonationScreenState extends State<BloodDonationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _citySearchController = TextEditingController();
  
  final FirebaseService _firebaseService = FirebaseService();
  
  String _selectedBloodType = 'A+';
  String _selectedCity = 'Dhaka';
  double _radius = 10.0;
  bool _useGpsRadius = false;
  Position? _currentPosition;
  bool _isLoading = false;
  bool _showPostForm = false;
  List<Map<String, dynamic>> _donationRequests = [];
  List<Map<String, dynamic>> _donors = [];
  bool _loadingRequests = true;
  bool _loadingDonors = true;
  int _selectedTab = 0; // 0 = Find Donor, 1 = Donate
  
  // Error states
  bool _hasError = false;
  String _errorMessage = '';

  // (removed) Likes & comments state
  
  // Retry mechanism
  int _retryCount = 0;
  static const int _maxRetries = 3;
  
  // Bangladesh cities
  final List<String> _bangladeshCities = [
    'Dhaka', 'Chittagong', 'Sylhet', 'Rajshahi', 'Khulna', 'Barisal', 
    'Rangpur', 'Mymensingh', 'Comilla', 'Narayanganj', 'Gazipur', 
    'Tangail', 'Bogra', 'Kushtia', 'Jessore', 'Dinajpur', 'Pabna',
    'Noakhali', 'Feni', 'Cox\'s Bazar', 'Bandarban', 'Rangamati'
  ];

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _nameController.dispose();
    _phoneController.dispose();
    _hospitalController.dispose();
    _citySearchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _retryCount = 0;
    });

    try {
      // Check network connectivity
      await _checkConnectivity();
      
      await Future.wait([
        _loadDonationRequests(),
        _loadDonors(),
      ]);
    } catch (e) {
      if (mounted) {
        _handleError('Error initializing blood donation data: $e');
      }
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      // On web, skip dart:io lookup which is not supported; rely on browser network
      if (kIsWeb) return;
      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        throw Exception('No internet connection');
      }
    } on SocketException catch (_) {
      throw Exception('No internet connection. Please check your network settings.');
    }
  }

  void _handleError(String message) {
    if (!mounted) return;
    
    setState(() {
      _hasError = true;
      _errorMessage = message;
      _loadingRequests = false;
      _loadingDonors = false;
    });
    
    debugPrint('Blood Donation Screen Error: $message');
  }

  

  void _clearError() {
    if (!mounted) return;
    
    setState(() {
      _hasError = false;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildTabToggle(),
              Expanded(
                child: _hasError ? _buildErrorWidget() : _buildMainContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          borderRadius: BorderRadius.circular(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.withOpacity(0.3),
                      Colors.black.withOpacity(0.5)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      "Something went wrong",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                        fontFamily: 'Montserrat',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _retryCount < _maxRetries ? _retry : null,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text("Retry (${_maxRetries - _retryCount} left)"),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppTheme.primaryColor.withOpacity(0.8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _initializeData,
                            icon: const Icon(Icons.home, size: 18),
                            label: const Text("Restart"),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppTheme.accentColor.withOpacity(0.8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_selectedTab == 0) ...[
            _buildFindDonorContent(),
          ] else ...[
            _buildDonateContent(),
          ],
        ],
      ),
    );
  }

  Future<void> _retry() async {
    if (!mounted) return;
    
    setState(() {
      _retryCount++;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      await _initializeData();
    } catch (e) {
      if (mounted) {
        _handleError('Retry failed: $e');
      }
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.bgGlassLight.withOpacity(0.6),
                    Colors.black.withOpacity(0.4)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.bloodtype, size: 22, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Blood Donation",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Inbox icon
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InboxScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Icon(Icons.inbox, size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildLogoutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.accentColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.18),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          "Logout",
          style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Montserrat'),
        ),
      ),
    );
  }

  Widget _buildTabToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildTabButton("Find Donor", 0),
          _buildTabButton("Donate", 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          _loadDonors();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [AppTheme.primaryColor, AppTheme.accentColor])
                : null,
            color: selected ? null : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : Colors.white.withOpacity(0.08),
              width: 1.2,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.13),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Find Donor Content
  Widget _buildFindDonorContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFilters(), // Use existing filters method
        const SizedBox(height: 16),
        _buildDonorsList(),
      ],
    );
  }

  // Donate Content
  Widget _buildDonateContent() {
    return Column(
      children: [
        _buildDonorRegistrationForm(),
        const SizedBox(height: 24),
        _buildDonorsList(),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => setState(() => _showPostForm = !_showPostForm),
            icon: _isLoading 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(_showPostForm ? Icons.close : Icons.add, size: 20),
            label: Text(_isLoading ? 'Loading...' : (_showPostForm ? 'Cancel' : 'Post Request')),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _isLoading 
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : AppTheme.primaryColor.withOpacity(0.6),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: _isLoading ? 0 : 4,
              shadowColor: AppTheme.primaryColor.withOpacity(0.5),
              side: BorderSide(color: AppTheme.primaryColor),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _isLoading || _loadingRequests ? null : _loadDonationRequests,
          icon: _loadingRequests 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.refresh, size: 20),
          label: Text(_loadingRequests ? 'Loading...' : 'Refresh'),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: _loadingRequests 
                ? AppTheme.accentColor.withOpacity(0.3)
                : AppTheme.accentColor.withOpacity(0.6),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: _loadingRequests ? 0 : 4,
            shadowColor: AppTheme.accentColor.withOpacity(0.5),
            side: BorderSide(color: AppTheme.accentColor),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  AppTheme.bgGlassMedium.withOpacity(0.85)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Filters", Icons.filter_list),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: _selectedBloodType,
                          items: _bloodTypes,
                          hint: "Blood Type",
                          icon: Icons.bloodtype,
                          onChanged: (value) {
                            setState(() => _selectedBloodType = value ?? 'A+');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCityDropdown(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRadiusSlider(),
                  const SizedBox(height: 8),
                  _buildGpsToggle(),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _loadDonors,
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text(
                        "Find Donors",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.5),
                        side: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGpsToggle() {
    return InkWell(
      onTap: () async {
        final newVal = !_useGpsRadius;
        if (newVal) {
          final ok = await _ensureLocation();
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission required for GPS radius search')),
            );
            return;
          }
        }
        setState(() => _useGpsRadius = newVal);
        _loadDonors();
      },
      child: Row(
        children: [
          Checkbox(
            value: _useGpsRadius,
            onChanged: (val) async {
              final newVal = val ?? false;
              if (newVal) {
                final ok = await _ensureLocation();
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location permission required for GPS radius search')),
                  );
                  return;
                }
              }
              setState(() => _useGpsRadius = newVal);
              _loadDonors();
            },
            activeColor: AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Use GPS location to search within ${_radius.toInt()} km',
              style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
            ),
          ),
          if (_useGpsRadius && _currentPosition != null)
            Icon(Icons.gps_fixed, color: AppTheme.primaryColor, size: 18),
        ],
      ),
    );
  }

  Future<bool> _ensureLocation() async {
    try {
      if (kIsWeb) {
        // Use low-power best effort on web, and handle lack of permissions gracefully
        try {
          _currentPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(const Duration(seconds: 5));
        } catch (_) {
          return false;
        }
        return true;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return false;
      }
      if (permission == LocationPermission.deniedForever) return false;
      _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return true;
    } catch (_) {
      return false;
    }
  }

  double _distanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  Widget _buildCityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCity,
          icon: Icon(Icons.location_city, color: AppTheme.primaryColor.withOpacity(0.8), size: 18),
          dropdownColor: Colors.black.withOpacity(0.8),
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          hint: Text("Select City", style: TextStyle(color: Colors.white.withOpacity(0.6), fontFamily: 'Montserrat')),
          items: _bangladeshCities
              .map((city) => DropdownMenuItem(
                    value: city,
                    child: Text(city, style: const TextStyle(fontFamily: 'Montserrat')),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() => _selectedCity = value ?? 'Dhaka');
            _loadDonationRequests();
            if (!_useGpsRadius) {
              _loadDonors();
            }
          },
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String hint,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(icon, color: AppTheme.primaryColor.withOpacity(0.8), size: 18),
          dropdownColor: Colors.black.withOpacity(0.8),
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          hint: Text(hint, style: TextStyle(color: Colors.white.withOpacity(0.6), fontFamily: 'Montserrat')),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, style: const TextStyle(fontFamily: 'Montserrat')),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildRadiusSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.radar, color: AppTheme.primaryColor, size: 18),
            const SizedBox(width: 8),
            Text(
              "Search Radius: ${_radius.toInt()} km",
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primaryColor,
            inactiveTrackColor: AppTheme.primaryColor.withOpacity(0.3),
            thumbColor: AppTheme.primaryColor,
            overlayColor: AppTheme.primaryColor.withOpacity(0.2),
            valueIndicatorColor: AppTheme.primaryColor,
            valueIndicatorTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          ),
          child: Slider(
            value: _radius,
            min: 1.0,
            max: 50.0,
            divisions: 49,
            label: "${_radius.toInt()} km",
            onChanged: (value) {
              setState(() => _radius = value);
              _loadDonationRequests();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostForm() {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  AppTheme.bgGlassMedium.withOpacity(0.85)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Post Blood Donation Request", Icons.add_circle),
                  const SizedBox(height: 16),
                  _buildFormField("Full Name", _nameController, Icons.person),
                  const SizedBox(height: 12),
                  _buildFormField("Phone Number", _phoneController, Icons.phone),
                  const SizedBox(height: 12),
                  _buildFormField("Hospital/Clinic", _hospitalController, Icons.local_hospital),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: _selectedBloodType,
                          items: _bloodTypes,
                          hint: "Blood Type",
                          icon: Icons.bloodtype,
                          onChanged: (value) => setState(() => _selectedBloodType = value ?? 'A+'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCityDropdown(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _postRequest,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppTheme.primaryColor.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.5),
                        side: BorderSide(color: AppTheme.primaryColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isLoading 
                              ? const SizedBox(
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  )
                                )
                              : const Icon(Icons.send, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            "Post Request",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonorRegistrationForm() {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  AppTheme.bgGlassMedium.withOpacity(0.85)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Register as Blood Donor", Icons.person_add),
                  const SizedBox(height: 16),
                  _buildFormField("Full Name", _nameController, Icons.person),
                  const SizedBox(height: 12),
                  _buildFormField("Phone Number", _phoneController, Icons.phone),
                  const SizedBox(height: 12),
                  _buildFormField("Address", _hospitalController, Icons.location_on),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: _selectedBloodType,
                          items: _bloodTypes,
                          hint: "Blood Type",
                          icon: Icons.bloodtype,
                          onChanged: (value) => setState(() => _selectedBloodType = value ?? 'A+'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCityDropdown(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _registerAsDonor,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppTheme.accentColor.withOpacity(0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppTheme.accentColor.withOpacity(0.5),
                        side: BorderSide(color: AppTheme.accentColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isLoading 
                              ? const SizedBox(
                                  width: 20, 
                                  height: 20, 
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  )
                                )
                              : const Icon(Icons.save, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            "Register as Donor",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withOpacity(0.25),
        hintText: label,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Montserrat'),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList() {
    if (_loadingRequests) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              "Loading requests...",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Montserrat'),
            ),
          ],
        ),
      );
    }

    if (_donationRequests.isEmpty) {
      return Material(
        color: Colors.transparent,
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.5),
                    AppTheme.bgGlassMedium.withOpacity(0.85)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bloodtype, color: Colors.white.withOpacity(0.5), size: 50),
                  const SizedBox(height: 16),
                  Text(
                    "No blood donation requests found",
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Montserrat'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadDonationRequests,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text("Retry"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _donationRequests.map((request) {
        try {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRequestCard(request),
          );
        } catch (e) {
          debugPrint('Error building request card: $e');
          return const SizedBox.shrink();
        }
      }).toList(),
    );
  }

  Widget _buildDonorsList() {
    if (_loadingDonors) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
            ),
            const SizedBox(height: 16),
            Text(
              "Loading donors...",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Montserrat'),
            ),
          ],
        ),
      );
    }

    if (_donors.isEmpty) {
      return Material(
        color: Colors.transparent,
        elevation: 0,
        borderRadius: BorderRadius.circular(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.5),
                    AppTheme.bgGlassMedium.withOpacity(0.85)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.accentColor.withOpacity(0.2)),
              ),
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedTab == 0 ? Icons.people : Icons.person_add,
                    color: Colors.white.withOpacity(0.5),
                    size: 50
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedTab == 0 
                        ? "No registered donors found in your area"
                        : "You haven't registered as a donor yet",
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Montserrat'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _selectedTab == 0 ? _loadDonors : () {
                      // Focus on the registration form
                      setState(() {
                        // This will trigger the form to be visible
                      });
                    },
                    icon: Icon(_selectedTab == 0 ? Icons.refresh : Icons.add, size: 16),
                    label: Text(_selectedTab == 0 ? "Retry" : "Register Now"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppTheme.accentColor.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _donors.map((donor) {
        try {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDonorCard(donor),
          );
        } catch (e) {
          debugPrint('Error building donor card: $e');
          return const SizedBox.shrink();
        }
      }).toList(),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    // Safety check for null or malformed request data
    if (request == null) {
      return const SizedBox.shrink();
    }
    
    try {
      final timestamp = (request['timestamp'] as Timestamp?)?.toDate();
      final formattedDate = timestamp != null ? DateFormat('MMM dd, yyyy HH:mm').format(timestamp) : 'No date';
      
      // Ensure all required fields have safe defaults
      final name = request['name']?.toString() ?? 'Anonymous';
      final city = request['city']?.toString() ?? 'Unknown City';
      final bloodType = request['bloodType']?.toString() ?? 'Unknown';
      final hospital = request['hospital']?.toString() ?? 'No hospital specified';
      final phone = request['phone']?.toString() ?? 'No phone provided';
    
      return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.bloodtype, color: AppTheme.primaryColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request['name'] ?? 'Anonymous',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                            Text(
                              request['city'] ?? 'Unknown City',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryColor),
                        ),
                        child: Text(
                          request['bloodType'] ?? 'Unknown',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (request['hospital'] != null && request['hospital'].isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.local_hospital, color: Colors.white.withOpacity(0.7), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            request['hospital'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.white.withOpacity(0.7), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        request['phone'] ?? 'No phone provided',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const Spacer(),
                      // Chat button
                      if (request['userId'] != FirebaseAuth.instance.currentUser?.uid) ...[
                        IconButton(
                          icon: Icon(Icons.chat, color: AppTheme.primaryColor, size: 20),
                          onPressed: () => _openChat(request['userId'], request['name'] ?? 'User'),
                        ),
                      ],
                      
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
    } catch (e) {
      debugPrint('Error building request card: $e');
      return const SizedBox.shrink();
    }
  }

  Widget _buildDonorCard(Map<String, dynamic> donor) {
    // Safety check for null or malformed donor data
    if (donor == null) {
      return const SizedBox.shrink();
    }
    
    try {
      final timestamp = (donor['timestamp'] as Timestamp?)?.toDate();
      final formattedDate = timestamp != null ? DateFormat('MMM dd, yyyy').format(timestamp) : 'No date';
      
      // Ensure all required fields have safe defaults
      final name = donor['name']?.toString() ?? 'Anonymous';
      final city = donor['city']?.toString() ?? 'Unknown City';
      final bloodType = donor['bloodType']?.toString() ?? 'Unknown';
      final address = donor['address']?.toString() ?? '';
      final phone = donor['phone']?.toString() ?? 'No phone provided';
    
    return Material(
      color: Colors.transparent,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accentColor.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.person, color: AppTheme.accentColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              donor['name'] ?? 'Anonymous',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                            Text(
                              donor['city'] ?? 'Unknown City',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 14,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accentColor),
                        ),
                        child: Text(
                          donor['bloodType'] ?? 'Unknown',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Montserrat',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (donor['address'] != null && donor['address'].isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.white.withOpacity(0.7), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            donor['address'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontFamily: 'Montserrat',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Icon(Icons.phone, color: Colors.white.withOpacity(0.7), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        donor['phone'] ?? 'No phone provided',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const Spacer(),
                      // Chat button - only show in Find Donor tab and for other users
                      if (_selectedTab == 0 && donor['userId'] != FirebaseAuth.instance.currentUser?.uid) ...[
                        IconButton(
                          icon: Icon(Icons.chat, color: AppTheme.accentColor, size: 20),
                          onPressed: () => _openChat(donor['userId'], donor['name'] ?? 'User'),
                        ),
                      ],
                      
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                    ],
                  ),
                  
                ],
              ),
            ),
          ),
        ),
      ),
    );
    } catch (e) {
      debugPrint('Error building donor card: $e');
      return const SizedBox.shrink();
    }
  }

  Future<void> _postRequest() async {
    if (!mounted) return;
    
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final hospital = _hospitalController.text.trim();

    if (name.isEmpty || phone.isEmpty || hospital.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required fields'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Validate phone number format
    if (phone.length < 10 || phone.length > 15) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid phone number'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Add request with proper error handling
      await FirebaseFirestore.instance.collection('blood_requests').add({
        'userId': user.uid,
        'name': name,
        'phone': phone,
        'hospital': hospital,
        'bloodType': _selectedBloodType,
        'city': _selectedCity,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
      }).timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Request timeout. Please check your connection.');
      });

      if (!mounted) return;

      // Clear form
      _nameController.clear();
      _phoneController.clear();
      _hospitalController.clear();
      setState(() => _showPostForm = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Blood donation request posted successfully'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Reload requests after successful post
      await _loadDonationRequests();
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Error posting request';
      if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your connection.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('quota')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      } else if (e.toString().contains('unavailable')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerAsDonor() async {
    if (!mounted) return;
    
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _hospitalController.text.trim();

    if (name.isEmpty || phone.isEmpty || address.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all required fields'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Validate phone number format
    if (phone.length < 10 || phone.length > 15) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid phone number'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Try to capture coordinates for better discovery in live GPS mode
      double? lat;
      double? lng;
      try {
        final ok = await _ensureLocation();
        if (ok && _currentPosition != null) {
          lat = _currentPosition!.latitude;
          lng = _currentPosition!.longitude;
        }
      } catch (_) {
        // Ignore; proceed without coordinates if unavailable
      }

      // Add donor with proper error handling
      await FirebaseFirestore.instance.collection('blood_donors').add({
        'userId': user.uid,
        'name': name,
        'phone': phone,
        'address': address,
        'bloodType': _selectedBloodType,
        'city': _selectedCity,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'active',
        if (lat != null && lng != null) 'latitude': lat,
        if (lat != null && lng != null) 'longitude': lng,
      }).timeout(const Duration(seconds: 30), onTimeout: () {
        throw Exception('Request timeout. Please check your connection.');
      });

      if (!mounted) return;

      // Clear form
      _nameController.clear();
      _phoneController.clear();
      _hospitalController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Successfully registered as blood donor'),
            backgroundColor: AppTheme.accentColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Reload donors after successful registration
      await _loadDonors();
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Error registering as donor';
      if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your connection.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('quota')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      } else if (e.toString().contains('unavailable')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDonationRequests() async {
    if (!mounted) return;
    
    setState(() => _loadingRequests = true);

    try {
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Simplified query without complex filters to avoid index issues
      final snapshot = await FirebaseFirestore.instance
          .collection('blood_requests')
          .orderBy('timestamp', descending: true)
          .limit(50) // Limit results to avoid performance issues
          .get()
          .timeout(const Duration(seconds: 30), onTimeout: () {
            throw Exception('Request timeout. Please check your connection.');
          });

      if (!mounted) return;

      final requests = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          // Ensure all required fields have default values
          data['name'] = data['name'] ?? 'Anonymous';
          data['city'] = data['city'] ?? 'Unknown City';
          data['bloodType'] = data['bloodType'] ?? 'Unknown';
          data['status'] = data['status'] ?? 'active';
          data['timestamp'] = data['timestamp'] ?? Timestamp.now();
          return data;
        } catch (e) {
          debugPrint('Error processing request document: $e');
          return null;
        }
      }).where((data) => data != null).cast<Map<String, dynamic>>().toList();

      // Filter by blood type and city in memory instead of in query
      // Exclude current user's own requests
      final filteredRequests = requests.where((request) {
        try {
          final matchesBloodType = request['bloodType'] == _selectedBloodType;
          final matchesCity = request['city'] == _selectedCity;
          final isActive = request['status'] == 'active';
          final isNotCurrentUser = request['userId'] != user.uid; // Exclude current user's requests
          return matchesBloodType && matchesCity && isActive && isNotCurrentUser;
        } catch (e) {
          debugPrint('Error filtering request: $e');
          return false;
        }
      }).toList();

      if (mounted) {
        setState(() {
          _donationRequests = filteredRequests;
          _loadingRequests = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _loadingRequests = false);
      
      // Handle specific Firestore errors
      String errorMessage = 'Error loading requests';
      if (e.toString().contains('index')) {
        errorMessage = 'Database index not ready. Please try again in a moment.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your connection.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('unavailable')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _loadDonors() async {
    if (!mounted) return;
    
    setState(() => _loadingDonors = true);

    try {
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Simplified query without complex filters to avoid index issues
      final snapshot = await FirebaseFirestore.instance
          .collection('blood_donors')
          .orderBy('timestamp', descending: true)
          .limit(50) // Limit results to avoid performance issues
          .get()
          .timeout(const Duration(seconds: 30), onTimeout: () {
            throw Exception('Request timeout. Please check your connection.');
          });

      if (!mounted) return;

      final donors = snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          // Ensure all required fields have default values
          data['name'] = data['name'] ?? 'Anonymous';
          data['city'] = data['city'] ?? 'Unknown City';
          data['bloodType'] = data['bloodType'] ?? 'Unknown';
          data['status'] = data['status'] ?? 'active';
          data['timestamp'] = data['timestamp'] ?? Timestamp.now();
          // Optional coordinates
          data['latitude'] = (data['latitude'] is num) ? (data['latitude'] as num).toDouble() : null;
          data['longitude'] = (data['longitude'] is num) ? (data['longitude'] as num).toDouble() : null;
          return data;
        } catch (e) {
          debugPrint('Error processing donor document: $e');
          return null;
        }
      }).where((data) => data != null).cast<Map<String, dynamic>>().toList();

      // Filter based on selected tab
      final filteredDonors = donors.where((donor) {
        try {
          final isActive = donor['status'] == 'active';
          
          if (_selectedTab == 0) {
            // Find Donor tab: Show other users' donors, exclude current user
            final matchesBloodType = donor['bloodType'] == _selectedBloodType;
            final matchesCity = donor['city'] == _selectedCity;
            final isNotCurrentUser = donor['userId'] != user.uid;
            // Decide location filter based on GPS toggle
            bool meetsLocation;
            if (_useGpsRadius && !kIsWeb) {
              if (_currentPosition != null && donor['latitude'] != null && donor['longitude'] != null) {
                final distance = _distanceInKm(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  donor['latitude'] as double,
                  donor['longitude'] as double,
                );
                meetsLocation = distance <= _radius + 0.001; // epsilon
              } else {
                meetsLocation = false; // no coords -> exclude in GPS mode
              }
            } else {
              meetsLocation = matchesCity; // manual city select
            }

            return matchesBloodType && isActive && isNotCurrentUser && meetsLocation;
          } else {
            // Donate tab: Show only current user's donor registration
            final isCurrentUser = donor['userId'] == user.uid;
            return isActive && isCurrentUser;
          }
        } catch (e) {
          debugPrint('Error filtering donor: $e');
          return false;
        }
      }).toList();

      if (mounted) {
        setState(() {
          _donors = filteredDonors;
          _loadingDonors = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _loadingDonors = false);
      
      // Handle specific Firestore errors
      String errorMessage = 'Error loading donors';
      if (e.toString().contains('index')) {
        errorMessage = 'Database index not ready. Please try again in a moment.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Permission denied. Please check your connection.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('unavailable')) {
        errorMessage = 'Service temporarily unavailable. Please try again later.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _openChat(String peerId, String peerName) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || currentUser.uid == peerId) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThreadScreen(
          currentUserId: currentUser.uid,
          peerId: peerId,
          peerName: peerName,
          category: 'blood',
        ),
      ),
    );
  }
} 