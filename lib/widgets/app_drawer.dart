import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '/';
    final authService = Provider.of<AuthService>(context);
    
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Logo and Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Image.asset(
                              'assets/images/icon.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AidX',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Healthcare Companion',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // User Info
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authService.currentUser?.displayName ?? 'User',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    authService.currentUser?.email ?? 'user@example.com',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Menu Items
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 20),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  children: [
                    _buildMenuSection('Main Features', [
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.dashboard_rounded,
                        title: 'Dashboard',
                        subtitle: 'Overview & Analytics',
                        route: AppConstants.routeDashboard,
                        isSelected: currentRoute == AppConstants.routeDashboard,
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.watch_rounded,
                        title: 'Wearable',
                        subtitle: 'Device Integration',
                        route: AppConstants.routeWearable,
                        isSelected: currentRoute == AppConstants.routeWearable,
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.medication_rounded,
                        title: 'Medications',
                        subtitle: 'Drug Management',
                        route: AppConstants.routeDrug,
                        isSelected: currentRoute == AppConstants.routeDrug,
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.sick_rounded,
                        title: 'Symptoms',
                        subtitle: 'Health Tracking',
                        route: AppConstants.routeSymptom,
                        isSelected: currentRoute == AppConstants.routeSymptom,
                      ),
                    ]),
                    
                    const SizedBox(height: 20),
                    
                    _buildMenuSection('Healthcare Services', [
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.chat_rounded,
                        title: 'Chat with Doctor',
                        subtitle: 'AI Consultation',
                        route: AppConstants.routeChat,
                        isSelected: currentRoute == AppConstants.routeChat,
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.local_hospital_rounded,
                        title: 'Hospitals',
                        subtitle: 'Find Medical Centers',
                        route: AppConstants.routeHospital,
                        isSelected: currentRoute == AppConstants.routeHospital,
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.local_pharmacy_rounded,
                        title: 'Professionals & Pharmacy',
                        subtitle: 'Doctors & Medicines',
                        route: AppConstants.routeProfessionalsPharmacy,
                        isSelected: currentRoute == AppConstants.routeProfessionalsPharmacy,
                      ),
                    ]),
                    
                    const SizedBox(height: 20),
                    
                    _buildMenuSection('Tools & Utilities', [
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.alarm_rounded,
                        title: 'Reminders',
                        subtitle: 'Medication Alerts',
                        route: AppConstants.routeReminder,
                        isSelected: currentRoute == AppConstants.routeReminder,
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.timeline_rounded,
                        title: 'Medical Timeline',
                        subtitle: 'Health History',
                        route: AppConstants.routeTimeline,
                        isSelected: currentRoute == AppConstants.routeTimeline,
                      ),
                      _buildDrawerItem(
                        context: context,
                        icon: Icons.emergency_rounded,
                        title: 'SOS Emergency',
                        subtitle: 'Emergency Contacts',
                        route: AppConstants.routeSos,
                        isSelected: currentRoute == AppConstants.routeSos,
                      ),
                    ]),
                    
                    const SizedBox(height: 20),
                    
                    // Profile and Logout
                    _buildDrawerItem(
                      context: context,
                      icon: Icons.person_rounded,
                      title: 'Profile',
                      subtitle: 'Account Settings',
                      route: AppConstants.routeProfile,
                      isSelected: currentRoute == AppConstants.routeProfile,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Logout Button
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.dangerColor.withOpacity(0.1),
                            AppTheme.dangerColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.dangerColor.withOpacity(0.3),
                        ),
                      ),
                      child: _buildDrawerItem(
                        context: context,
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        subtitle: 'Sign out of account',
                        onTap: () async {
                          await authService.signOut();
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, AppConstants.routeLogin);
                          }
                        },
                        isLogout: true,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    String? route,
    bool isSelected = false,
    bool isLogout = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: isSelected 
            ? AppTheme.primaryGradient
            : isLogout
                ? null
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.02),
                    ],
                  ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? AppTheme.primaryColor.withOpacity(0.3)
              : isLogout
                  ? AppTheme.dangerColor.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
        ),
        boxShadow: isSelected ? [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap ?? () {
            Navigator.pop(context); // Close drawer
            if (route != null && route != ModalRoute.of(context)?.settings.name) {
              Navigator.pushReplacementNamed(context, route);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.2)
                        : isLogout
                            ? AppTheme.dangerColor.withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected 
                        ? Colors.white
                        : isLogout
                            ? AppTheme.dangerColor
                            : Colors.white.withOpacity(0.8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected 
                              ? Colors.white
                              : isLogout
                                  ? AppTheme.dangerColor
                                  : Colors.white,
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: isSelected 
                                ? Colors.white.withOpacity(0.8)
                                : isLogout
                                    ? AppTheme.dangerColor.withOpacity(0.7)
                                    : Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 