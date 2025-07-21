import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math';
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../widgets/hospital_card.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class HospitalScreen extends StatefulWidget {
  const HospitalScreen({Key? key}) : super(key: key);

  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
  List<Map<String, dynamic>> _hospitals = [];
  bool _isLoading = false;
  String _statusMessage = '';
  Position? _currentPosition;
  
  // Helper function to compute distance using Haversine formula
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371e3; // Earth's radius in meters
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
  
  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Get coordinates using both live GPS location and IP geolocation
  Future<Map<String, dynamic>> _getCoordinates() async {
    Map<String, double>? gpsLocation;
    Map<String, double>? ipLocation;
    String locationSource = '';
    
    // Try GPS location first (most accurate)
    try {
      print('Trying GPS location...');
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      gpsLocation = {
        'lat': position.latitude,
        'lon': position.longitude,
      };
      print('GPS location successful: ${position.latitude}, ${position.longitude}');
      locationSource = 'GPS';
    } catch (e) {
      print('GPS location failed: $e');
    }

    // Always try IP geolocation as backup or for additional context
    try {
      print('Trying IP geolocation...');
    final ipServices = [
      'https://ipapi.co/json/',
      'https://ipinfo.io/json',
        'https://api.myip.com/api/v1/ip',
    ];

    for (final service in ipServices) {
      try {
        print('Trying IP geolocation with: $service');
        final response = await http.get(
          Uri.parse(service),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          ).timeout(const Duration(seconds: 8));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          // Handle different API response formats
          double? lat, lon;
          
          if (service.contains('ipapi.co')) {
            lat = data['latitude']?.toDouble();
            lon = data['longitude']?.toDouble();
          } else if (service.contains('ipinfo.io')) {
            final loc = data['loc']?.split(',');
            if (loc != null && loc.length == 2) {
              lat = double.tryParse(loc[0]);
              lon = double.tryParse(loc[1]);
            }
            } else if (service.contains('myip.com')) {
              lat = data['latitude']?.toDouble();
              lon = data['longitude']?.toDouble();
          }
          
          if (lat != null && lon != null) {
              ipLocation = {'lat': lat, 'lon': lon};
            print('IP geolocation successful: $lat, $lon');
              break;
          }
        }
      } catch (e) {
        print('IP geolocation failed with $service: $e');
        continue;
      }
    }
    } catch (e) {
      print('IP geolocation completely failed: $e');
    }

    // Determine which location to use
    if (gpsLocation != null) {
      // GPS is available - use it as primary, IP as backup info
      return {
        'lat': gpsLocation['lat']!,
        'lon': gpsLocation['lon']!,
        'source': 'GPS',
        'accuracy': 'High',
        'ip_lat': ipLocation?['lat'],
        'ip_lon': ipLocation?['lon'],
        'has_backup': ipLocation != null,
      };
    } else if (ipLocation != null) {
      // Only IP location available
      return {
        'lat': ipLocation['lat']!,
        'lon': ipLocation['lon']!,
        'source': 'IP',
        'accuracy': 'Approximate',
        'ip_lat': ipLocation['lat'],
        'ip_lon': ipLocation['lon'],
        'has_backup': false,
      };
    } else {
      // Fallback to default location
    print('Using default location');
    return {
      'lat': 40.7128, // New York City coordinates as fallback
      'lon': -74.0060,
        'source': 'Default',
        'accuracy': 'Unknown',
        'ip_lat': null,
        'ip_lon': null,
        'has_backup': false,
    };
    }
      }

  // Fallback sample hospitals
  List<Map<String, dynamic>> _getSampleHospitals(double userLat, double userLon) {
    // Generate sample hospitals around the user's location with more detailed contact info
    final hospitals = [
      {
        'tags': {
          'name': 'City General Hospital', 
          'phone': '+1 (555) 123-4567',
          'contact:phone': '+1 (555) 123-4567',
          'contact:email': 'info@citygeneral.com',
          'website': 'www.citygeneral.com'
        },
        'distance': 1200.0,
        'center': {'lat': userLat + 0.01, 'lon': userLon + 0.01},
      },
      {
        'tags': {
          'name': 'Community Medical Center', 
          'phone': '+1 (555) 987-6543',
          'contact:phone': '+1 (555) 987-6543',
          'contact:email': 'contact@communitymed.org',
          'website': 'www.communitymed.org'
        },
        'distance': 2500.0,
        'center': {'lat': userLat - 0.008, 'lon': userLon + 0.015},
      },
      {
        'tags': {
          'name': 'University Hospital', 
          'phone': '+1 (555) 456-7890',
          'contact:phone': '+1 (555) 456-7890',
          'contact:email': 'info@universityhospital.edu',
          'website': 'www.universityhospital.edu'
        },
        'distance': 3800.0,
        'center': {'lat': userLat + 0.015, 'lon': userLon - 0.012},
      },
      {
        'tags': {
          'name': 'Riverside Health Clinic', 
          'phone': '+1 (555) 789-0123',
          'contact:phone': '+1 (555) 789-0123',
          'contact:email': 'contact@riversidehealth.com',
          'website': 'www.riversidehealth.com'
        },
        'distance': 4200.0,
        'center': {'lat': userLat - 0.012, 'lon': userLon - 0.008},
      },
      {
        'tags': {
          'name': 'Emergency Care Center', 
          'phone': '+1 (555) 321-6540',
          'contact:phone': '+1 (555) 321-6540',
          'contact:email': 'emergency@carecenters.org',
          'website': 'www.emergencycarecenters.org'
        },
        'distance': 5500.0,
        'center': {'lat': userLat + 0.018, 'lon': userLon + 0.020},
      },
    ];
    
    return hospitals;
  }

  // Modify hospital fetching to extract more contact details
  Future<List<Map<String, dynamic>>> _fetchHospitalsRadius(
      double lat, double lon, int radius) async {
    final query = '[out:json];(node["amenity"="hospital"](around:$radius,$lat,$lon);way["amenity"="hospital"](around:$radius,$lat,$lon);relation["amenity"="hospital"](around:$radius,$lat,$lon););out center 50;';
    final url = 'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}';
    
    try {
      print('Fetching hospitals with radius ${radius}m...');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hospitals = (data['elements'] as List).cast<Map<String, dynamic>>();
        
        // Enhance hospital data with additional contact information
        final enhancedHospitals = hospitals.map((hospital) {
          // Combine different possible phone number tags
          final phone = hospital['tags']?['phone'] ?? 
                        hospital['tags']?['contact:phone'] ?? 
                        hospital['tags']?['contact:mobile'] ?? 
                        'No phone available';
          
          // Add more contact details if available
          final email = hospital['tags']?['contact:email'] ?? 
                        hospital['tags']?['email'] ?? 
                        'No email available';
          
          final website = hospital['tags']?['website'] ?? 
                          hospital['tags']?['contact:website'] ?? 
                          'No website available';
          
          return {
            ...hospital,
            'tags': {
              ...?hospital['tags'],
              'phone': phone,
              'contact:email': email,
              'website': website,
            }
          };
        }).toList();
        
        print('Found ${enhancedHospitals.length} hospitals with radius ${radius}m');
        return enhancedHospitals;
      } else {
        print('Overpass API error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Overpass API request failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchHospitals(double lat, double lon) async {
    // Try different radii: 5km, 10km, 20km
    for (final radius in [5000, 10000, 20000]) {
      final hospitals = await _fetchHospitalsRadius(lat, lon, radius);
      if (hospitals.isNotEmpty) {
        return hospitals;
      }
      // Add a small delay between requests to be respectful to the API
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    return [];
  }

  Future<void> _findHospitals() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Getting your location...';
      _hospitals.clear();
    });
    
    try {
      final locationData = await _getCoordinates();
      final coords = {'lat': locationData['lat'], 'lon': locationData['lon']};
      
      // Update status message based on location source
      String statusMsg = 'Searching for nearby hospitals...';
      if (locationData['source'] == 'GPS') {
        statusMsg = 'Using GPS location (high accuracy) - searching for hospitals...';
      } else if (locationData['source'] == 'IP') {
        statusMsg = 'Using IP location (approximate) - searching for hospitals...';
      } else {
        statusMsg = 'Using default location - searching for hospitals...';
      }
      
      setState(() {
        _statusMessage = statusMsg;
      });
      
      final hospitals = await _fetchHospitals(coords['lat']!, coords['lon']!);
      
      if (hospitals.isEmpty) {
        // Fallback to sample hospitals if API fails
        print('No hospitals found via API, using sample data');
        final sampleHospitals = _getSampleHospitals(coords['lat']!, coords['lon']!);
        setState(() {
          _hospitals = sampleHospitals;
          _statusMessage = 'Showing sample hospitals (real-time data unavailable)';
        });
        return;
      }

      // Calculate distances and sort
      final processedHospitals = hospitals.map((hospital) {
        final center = hospital['type'] == 'node' ? hospital : hospital['center'];
        final distance = _haversineDistance(
          coords['lat']!,
          coords['lon']!,
          center['lat'].toDouble(),
          center['lon'].toDouble(),
        );
        return {
          ...hospital,
          'distance': distance,
          'center': center,
        };
      }).toList();

      processedHospitals.sort((a, b) => a['distance'].compareTo(b['distance']));

      // Create final status message with location info
      String finalStatus = '';
      if (locationData['source'] == 'GPS') {
        finalStatus = 'Found ${processedHospitals.length} hospitals using GPS location (high accuracy)';
        if (locationData['has_backup'] == true) {
          finalStatus += ' • IP location also available as backup';
        }
      } else if (locationData['source'] == 'IP') {
        finalStatus = 'Found ${processedHospitals.length} hospitals using IP location (approximate)';
      } else {
        finalStatus = 'Found ${processedHospitals.length} hospitals using default location';
      }

      setState(() {
        _hospitals = processedHospitals; // Show all hospitals, not just 10
        _statusMessage = finalStatus;
      });
    } catch (e) {
      print('Error in _findHospitals: $e');
      setState(() {
        _statusMessage = 'Unable to find hospitals. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppTheme.bgGlassLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FeatherIcons.arrowLeft, color: AppTheme.textTeal),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FeatherIcons.mapPin, color: AppTheme.textTeal, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: const Text(
                'Nearby Hospital Finder',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTeal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              // Logout functionality
              Navigator.of(context).pushReplacementNamed(AppConstants.routeLogin);
            },
            icon: const Icon(FeatherIcons.logOut, size: 16, color: Colors.white),
            label: const Text(
              'Logout',
              style: TextStyle(color: Colors.white),
            ),
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
                ),
              ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Find Hospitals Button
              Container(
                width: double.infinity,
              child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _findHospitals,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(FeatherIcons.search, size: 16),
                  label: Text(_isLoading ? 'Finding Hospitals...' : 'Find Hospitals Near Me'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ).copyWith(
                    backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
                      if (states.contains(MaterialState.disabled)) {
                        return AppTheme.primaryColor.withOpacity(0.5);
                      }
                      return AppTheme.primaryGradient.colors.first;
                    }),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Help Text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: AppTheme.cardDecoration.copyWith(
                  color: AppTheme.bgGlassLight.withOpacity(0.5),
                ),
                child: Column(
                  children: [
                                        Text(
                      'This will use both GPS location (high accuracy) and IP location (backup) to find nearby hospitals. All found hospitals will be displayed.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'GPS: Most accurate • IP: Fallback option',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Status Message
              if (_statusMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: AppTheme.cardDecoration.copyWith(
                    color: _statusMessage.contains('Error') || _statusMessage.contains('Unable')
                        ? AppTheme.dangerColor.withOpacity(0.1)
                        : AppTheme.bgGlassLight,
                ),
                  child: Column(
                    children: [
                      Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusMessage.contains('Error') || _statusMessage.contains('Unable')
                              ? AppTheme.dangerColor
                              : AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_statusMessage.contains('Unable to obtain location'))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Please allow location access in your browser settings or check your internet connection.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
              ),
                            textAlign: TextAlign.center,
            ),
                        ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 12),
              
                            // Hospitals List
          if (_hospitals.isNotEmpty || _isLoading)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _hospitals.length,
              itemBuilder: (context, index) {
                final hospital = _hospitals[index];
                return HospitalCard(
                  hospital: hospital,
                  parentContext: context,
                );
              },
            ),
            ],
          ),
        ),
      ),
    );
  }
} 