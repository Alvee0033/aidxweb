import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class HospitalCard extends StatelessWidget {
  final Map<String, dynamic> hospital;
  final VoidCallback? onDirectionsPressed;
  final BuildContext parentContext;

  const HospitalCard({
    super.key,
    required this.hospital,
    required this.parentContext,
    this.onDirectionsPressed,
  });

  Future<void> _launchPhone(String phone) async {
    final url = 'tel:$phone';
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Show error message if phone app can't be launched
      debugPrint('Could not launch phone app');
    }
  }

  Future<void> _launchDirections(double lat, double lon) async {
    try {
      // Comprehensive list of URLs to try
      final urls = [
        // Google Maps app/web direct navigation
        'google.navigation:q=$lat,$lon', // Google Maps app navigation
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon', // Google Maps web directions
        'https://maps.google.com/maps?daddr=$lat,$lon', // Alternative Google Maps web link
        'geo:$lat,$lon', // Geo URI for map apps
        'https://www.google.com/maps/search/?api=1&query=$lat,$lon', // Google Maps search
      ];
      
      bool launched = false;
      
      // Try launching methods in order
      for (final url in urls) {
        try {
          final uri = Uri.parse(url);
          
          // First, try external app launch
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            break;
          }
        } catch (e) {
          debugPrint('Failed to launch external app with URL $url: $e');
          continue;
        }
      }
      
      // If external app launch fails, try web browser
      if (!launched) {
        try {
          final webUrls = [
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon',
            'https://maps.google.com/maps?daddr=$lat,$lon',
          ];
          
          for (final webUrl in webUrls) {
            final uri = Uri.parse(webUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.platformDefault);
              launched = true;
              break;
            }
          }
        } catch (e) {
          debugPrint('Failed to launch web browser: $e');
        }
      }
      
      // Final fallback: show error message
      if (!launched) {
        // Show a dialog or snackbar with error and manual coordinates
        _showDirectionsErrorDialog(lat, lon);
      }
    } catch (e) {
      debugPrint('Comprehensive directions launch error: $e');
      _showDirectionsErrorDialog(lat, lon);
    }
  }

  void _showDirectionsErrorDialog(double lat, double lon) {
    // Implement a custom error dialog with manual copy-paste option
    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Directions Unavailable'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Could not open directions automatically.'),
              const SizedBox(height: 8),
              const Text('Coordinates:'),
              SelectableText(
                'Latitude: $lat\nLongitude: $lon',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('You can manually enter these coordinates in Google Maps.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = hospital['center'];
    final distance = hospital['distance'] as double;
    final km = (distance / 1000).toStringAsFixed(1);
    final name = hospital['tags']?['name'] ?? 'Unnamed Hospital';
    final phone = hospital['tags']?['phone'] ?? 
                hospital['tags']?['contact:phone'];
    final email = hospital['tags']?['contact:email'] ?? 'No email available';
    final website = hospital['tags']?['website'] ?? 'No website available';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration.copyWith(
        color: AppTheme.bgGlassLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hospital Name
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Distance
          Row(
            children: [
              const Icon(
                FeatherIcons.mapPin,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '$km km away',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Contact Information Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgGlassMedium,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.textSecondary.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Phone Number
                if (phone != null) ...[
                  Row(
                    children: [
                      const Icon(
                        FeatherIcons.phone,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _launchPhone(phone),
                          child: Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Email
                Row(
                  children: [
                    const Icon(
                      FeatherIcons.mail,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                // Website
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      FeatherIcons.globe,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        website,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Get Directions Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchDirections(
                center['lat'].toDouble(),
                center['lon'].toDouble(),
              ),
              icon: const Icon(FeatherIcons.navigation, size: 16),
              label: const Text(
                'Get Directions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGradient.colors.first,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 