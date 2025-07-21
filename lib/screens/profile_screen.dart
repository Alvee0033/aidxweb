import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aidx/services/auth_service.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/widgets/glass_container.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:aidx/utils/constants.dart';
import 'package:aidx/services/database_init.dart';
import 'package:aidx/main.dart' show routeObserver;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with RouteAware {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isEditing = false;
  File? _pickedImage;
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  String _selectedGender = '';
  String? _profileImageUrl;
  final DatabaseService _databaseService = DatabaseService();
  bool _dataChanged = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    
    // Add listeners to detect changes
    _nameController.addListener(_markAsChanged);
    _ageController.addListener(_markAsChanged);
    _emailController.addListener(_markAsChanged);
    _phoneController.addListener(_markAsChanged);
    _genderController.addListener(_markAsChanged);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }
  
  @override
  void didPop() {
    // Save data when navigating back
    if (_dataChanged && (_formKey.currentState?.validate() ?? false)) {
      _saveProfileData();
    }
    super.didPop();
  }
  
  @override
  void didPushNext() {
    // Save data when navigating to another screen
    if (_dataChanged && (_formKey.currentState?.validate() ?? false)) {
      _saveProfileData();
    }
    super.didPushNext();
  }
  
  void _markAsChanged() {
    setState(() {
      _dataChanged = true;
    });
  }
  
  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    
    // Remove listeners
    _nameController.removeListener(_markAsChanged);
    _ageController.removeListener(_markAsChanged);
    _emailController.removeListener(_markAsChanged);
    _phoneController.removeListener(_markAsChanged);
    _genderController.removeListener(_markAsChanged);
    
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
    super.dispose();
  }
  
  // Method to save profile data without requiring edit mode
  Future<void> _saveProfileData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null && _dataChanged) {
        // Only save if data has changed
        // Upload image first if a new one was chosen
        if (_pickedImage != null) {
          await _uploadProfileImage(user.uid);
        }
        
        await _databaseService.updateUserProfile(user.uid, {
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'gender': _selectedGender,
          'age': _ageController.text.isNotEmpty ? _ageController.text : null,
          'photo': _profileImageUrl,
        });
        
        // Update display name in Firebase Auth
        if (_nameController.text != user.displayName) {
          await user.updateDisplayName(_nameController.text);
        }
        
        debugPrint('✅ Profile data saved automatically');
        _dataChanged = false;
      }
    } catch (e) {
      debugPrint('⚠️ Error auto-saving profile: $e');
    }
  }
  
  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _dataChanged = false;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user != null) {
        // Get user profile from Firestore
        final profileData = await _databaseService.getUserProfile(user.uid);
        
        if (profileData != null && profileData['profile'] != null) {
          final profile = profileData['profile'] as Map<String, dynamic>;
          
          setState(() {
            _nameController.text = profile['name'] ?? user.displayName ?? '';
            _emailController.text = profile['email'] ?? user.email ?? '';
            _genderController.text = profile['gender'] ?? '';
            _selectedGender = profile['gender'] ?? '';
            _ageController.text = profile['age']?.toString() ?? '';
            _phoneController.text = profile['phone'] ?? '';
            _profileImageUrl = profile['photo'] ?? user.photoURL;
          });
        } else {
          // If no profile exists, use data from Firebase Auth
          setState(() {
            _nameController.text = user.displayName ?? '';
            _emailController.text = user.email ?? '';
            _profileImageUrl = user.photoURL;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _updateProfile() async {
    if (!_isEditing) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        // Upload image if a new one has been picked
        if (_pickedImage != null) {
          await _uploadProfileImage(user.uid);
        }

        // Update user profile in Firestore
        await _databaseService.updateUserProfile(user.uid, {
          'name': _nameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'gender': _selectedGender,
          'age': _ageController.text.isNotEmpty ? _ageController.text : null,
          'photo': _profileImageUrl,
        });

        // Update display name in Firebase Auth
        if (_nameController.text != user.displayName) {
          await user.updateDisplayName(_nameController.text);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        
        _dataChanged = false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isEditing = false;
      });
    }
  }
  
  Future<void> _signOut() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      
      if (mounted) {
        // Navigate to the login screen and remove all previous routes
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.routeLogin,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign out: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file != null) {
      setState(() {
        _pickedImage = File(file.path);
        _dataChanged = true; // Mark data as changed when a new image is selected
      });
    }
  }

  Future<void> _changePasswordDialog() async {
    final _passwordController = TextEditingController();
    final _confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'New Password'),
                      validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Confirm Password'),
                      validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setState(() => loading = true);
                          try {
                            final authService = Provider.of<AuthService>(context, listen: false);
                            await authService.updatePassword(_passwordController.text);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Password updated successfully')),
                              );
                            }
                          } catch (e) {
                            setState(() => loading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed: $e')),
                            );
                          }
                        },
                  child: loading
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Upload the selected profile image to Firebase Storage and return the download URL
  Future<String?> _uploadProfileImage(String userId) async {
    if (_pickedImage == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      // Upload the file
      await ref.putFile(_pickedImage!);

      // Retrieve the download URL
      final url = await ref.getDownloadURL();

      setState(() {
        _profileImageUrl = url;
        _pickedImage = null; // Clear picked image once uploaded
      });

      return url;
    } catch (e) {
      debugPrint('⚠️ Error uploading profile image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final theme = Theme.of(context);
    
    return WillPopScope(
      onWillPop: () async {
        // Save profile data when leaving the page if form is valid
        if (_dataChanged && (_formKey.currentState?.validate() ?? false)) {
          await _saveProfileData();
        }
        return true;
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.bgGradient,
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text('Profile', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: GlassContainer(
                      borderRadius: 32,
                      blur: 16,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Column(
                          children: [
                            // Avatar
                            Center(
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 48,
                                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                                    backgroundImage: _pickedImage != null
                                        ? FileImage(_pickedImage!)
                                        : _profileImageUrl != null
                                            ? NetworkImage(_profileImageUrl!) as ImageProvider
                                            : null,
                                    child: _profileImageUrl == null && _pickedImage == null
                                        ? Text(
                                            user?.displayName != null && user!.displayName!.isNotEmpty
                                                ? user.displayName![0].toUpperCase()
                                                : '?',
                                            style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                                          )
                                        : null,
                                  ),
                                  if (_isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: GestureDetector(
                                        onTap: _pickImage,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          child: const Icon(Icons.edit, color: Colors.white, size: 20),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Name
                            Text(
                              _nameController.text.isNotEmpty ? _nameController.text : (user?.displayName ?? ''),
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            // Email subtitle
                            Text(
                              _emailController.text.isNotEmpty ? _emailController.text : (user?.email ?? ''),
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            Divider(color: Colors.white24, thickness: 1),
                            const SizedBox(height: 16),
                            // Form
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Name
                                  TextFormField(
                                    controller: _nameController,
                                    enabled: _isEditing,
                                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Name',
                                      labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.08),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Enter your name';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Email
                                  TextFormField(
                                    controller: _emailController,
                                    enabled: _isEditing,
                                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.08),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Enter your email';
                                      if (!value.contains('@')) return 'Enter a valid email';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Phone
                                  TextFormField(
                                    controller: _phoneController,
                                    enabled: _isEditing,
                                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Phone',
                                      labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.08),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Enter your phone number';
                                      if (value.length < 8) return 'Enter a valid phone number';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Age
                                  TextFormField(
                                    controller: _ageController,
                                    enabled: _isEditing,
                                    style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Age',
                                      labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.08),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    keyboardType: TextInputType.number,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Enter your age';
                                      if (int.tryParse(value) == null) return 'Enter a valid age';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  // Gender
                                  DropdownButtonFormField<String>(
                                    value: _selectedGender.isEmpty ? null : _selectedGender,
                                    items: ['Male', 'Female', 'Other']
                                        .map((g) => DropdownMenuItem(
                                              value: g,
                                              child: Text(g, style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white)),
                                            ))
                                        .toList(),
                                    onChanged: _isEditing
                                        ? (value) => setState(() => _selectedGender = value ?? '')
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: 'Gender',
                                      labelStyle: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                                      filled: true,
                                      fillColor: Colors.white.withOpacity(0.08),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    dropdownColor: theme.colorScheme.surface.withOpacity(0.95),
                                  ),
                                  const SizedBox(height: 24),
                                  // Buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      if (_isEditing)
                                        OutlinedButton(
                                          onPressed: _isLoading ? null : () => setState(() => _isEditing = false),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: theme.colorScheme.secondary,
                                            side: BorderSide(color: theme.colorScheme.secondary),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                      if (_isEditing)
                                        ElevatedButton(
                                          onPressed: _isLoading ? null : _updateProfile,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: theme.colorScheme.primary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                              : const Text('Save'),
                                        ),
                                      if (!_isEditing)
                                        OutlinedButton(
                                          onPressed: _isLoading ? null : () => setState(() => _isEditing = true),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: theme.colorScheme.primary,
                                            side: BorderSide(color: theme.colorScheme.primary),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: const Text('Edit'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Change Password Button
                                  if (_isEditing)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: _changePasswordDialog,
                                        icon: const Icon(Icons.lock_outline, color: Colors.white70),
                                        label: Text('Change Password', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Divider(color: Colors.white24, thickness: 1),
                            const SizedBox(height: 16),
                            // Logout
                            OutlinedButton.icon(
                              onPressed: _signOut,
                              icon: const Icon(Icons.logout, color: Colors.white70),
                              label: Text('Logout', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                                side: BorderSide(color: theme.colorScheme.error),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
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
} 