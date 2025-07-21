import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aidx/services/auth_service.dart';
import 'package:aidx/screens/dashboard_screen.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/widgets/glass_container.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:aidx/utils/constants.dart';
import 'dart:ui';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String _errorMessage = '';
  bool _isKeyboardVisible = false;

  // Login form controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Register form controllers
  final TextEditingController _regNameController = TextEditingController();
  final TextEditingController _regEmailController = TextEditingController();
  final TextEditingController _regPasswordController = TextEditingController();
  final TextEditingController _regConfirmController = TextEditingController();

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;
  bool _isRegPasswordVisible = false;
  bool _isRegConfirmVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Removed test credentials for production
    // _emailController.text = 'test@medigay.com';
    // _passwordController.text = 'test123456';
    // Listen for keyboard visibility changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkKeyboardVisibility();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _regNameController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmController.dispose();
    super.dispose();
  }

  void _checkKeyboardVisibility() {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;
    
    if (isKeyboardVisible != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = isKeyboardVisible;
      });
    }
  }

  void _clearError() {
    if (_errorMessage.isNotEmpty) {
      setState(() {
        _errorMessage = '';
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    
    setState(() {
      _errorMessage = message;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _login() async {
    if (!mounted) return;
    
    // Clear previous errors
    _clearError();
    
    // Validate form
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }
    
    // Validate email format
    final email = _emailController.text.trim();
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.signInWithEmailAndPassword(
        email,
        _passwordController.text.trim(),
      );
      
      if (!mounted) return;
      
      if (user != null) {
        _showSuccess('Login successful!');
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        _showError('Login failed: Invalid credentials');
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Login failed';
      if (e.toString().contains('user-not-found')) {
        errorMessage = 'No account found with this email';
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = 'Incorrect password';
      } else if (e.toString().contains('too-many-requests')) {
        errorMessage = 'Too many failed attempts. Please try again later';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection';
      } else {
        errorMessage = 'Login failed: ${e.toString()}';
      }
      
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!mounted) return;
    
    // Clear previous errors
    _clearError();
    
    // Validate form
    if (!_registerFormKey.currentState!.validate()) {
      return;
    }
    
    // Validate email format
    final email = _regEmailController.text.trim();
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }
    
    // Validate password strength
    final password = _regPasswordController.text;
    if (password.length < 8) {
      _showError('Password must be at least 8 characters long');
      return;
    }
    
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      _showError('Password must contain at least one uppercase letter, one lowercase letter, and one number');
      return;
    }
    
    // Validate password confirmation
    if (_regPasswordController.text != _regConfirmController.text) {
      _showError('Passwords do not match');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.registerWithEmailAndPassword(
        email,
        password,
        _regNameController.text.trim(),
      );
      
      if (!mounted) return;
      
      if (user != null) {
        _showSuccess('Registration successful! Please login.');
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          _tabController.animateTo(0);
          // Clear register form
          _regNameController.clear();
          _regEmailController.clear();
          _regPasswordController.clear();
          _regConfirmController.clear();
        }
      } else {
        _showError('Registration failed: Unknown error');
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Registration failed';
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'An account with this email already exists';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Password is too weak';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Invalid email address';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection';
      } else {
        errorMessage = 'Registration failed: ${e.toString()}';
      }
      
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    
    // Clear previous errors
    _clearError();
    
    setState(() {
      _isGoogleLoading = true;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      _showSuccess('Connecting to Google...');
      
      final user = await authService.signInWithGoogle();
      
      if (!mounted) return;
      
      if (user == null) {
        _showError('Google sign-in was canceled or failed. Please try again.');
        return;
      }
      
      _showSuccess('Google sign-in successful!');
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'Google sign-in failed';
      if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection';
      } else if (e.toString().contains('cancelled')) {
        errorMessage = 'Sign-in was cancelled';
      } else {
        errorMessage = 'Google sign-in error: ${e.toString()}';
      }
      
      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final isLandscape = size.width > size.height;
    
    return Scaffold(
      // Enhanced gradient background
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            // Modern gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F2027),
                    Color(0xFF2C5364),
                    Color(0xFF1A2980),
                  ],
                ),
              ),
            ),
            // Decorative blurred circles (more elegant)
            Positioned(
              top: isSmallScreen ? -60 : -120,
              left: isSmallScreen ? -50 : -100,
              child: _buildBlurCircle(
                isSmallScreen ? 180 : 260, 
                AppTheme.primaryColor.withOpacity(0.30),
              ),
            ),
            Positioned(
              bottom: isSmallScreen ? -80 : -160,
              right: isSmallScreen ? -40 : -80,
              child: _buildBlurCircle(
                isSmallScreen ? 220 : 320, 
                AppTheme.accentColor.withOpacity(0.22),
              ),
            ),
            // Main content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 16.0 : 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo with shadow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                        'assets/images/icon.png',
                          width: isSmallScreen ? 80 : 110,
                          height: isSmallScreen ? 80 : 110,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.favorite,
                              size: isSmallScreen ? 80 : 110,
                            color: AppTheme.primaryColor,
                          );
                        },
                      ),
                      ),
                      SizedBox(height: isSmallScreen ? 18 : 24),
                      Text(
                        'AidX',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 30 : 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 8 : 12),
                      Text(
                        'Your Personal Health Assistant',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isSmallScreen ? 22 : 32),
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          margin: EdgeInsets.only(bottom: isSmallScreen ? 16 : 20),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.4), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 22),
                              SizedBox(width: isSmallScreen ? 8 : 10),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isSmallScreen ? 14 : 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                onPressed: _clearError,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isSmallScreen ? double.infinity : 420,
                          maxHeight: isLandscape 
                            ? size.height * 0.85 
                            : size.height * 0.7,
                        ),
                        child: GlassContainer(
                          borderRadius: 24,
                          blur: 18,
                          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.5),
                          boxShadow: BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 18 : 32,
                              vertical: isSmallScreen ? 18 : 28,
                            ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(12),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  indicatorColor: AppTheme.primaryColor,
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: Colors.white70,
                                  labelStyle: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      fontWeight: FontWeight.w700,
                                  ),
                                  tabs: const [
                                    Tab(text: 'Login'),
                                    Tab(text: 'Register'),
                                  ],
                                ),
                              ),
                                SizedBox(height: isSmallScreen ? 18 : 24),
                              Flexible(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: [
                                    SingleChildScrollView(
                                      padding: EdgeInsets.zero,
                                      child: _buildLoginForm(),
                                    ),
                                    SingleChildScrollView(
                                      padding: EdgeInsets.zero,
                                      child: _buildRegisterForm(),
                                    ),
                                  ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildBlurCircle(double size, Color color) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withOpacity(0.05)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                hintText: 'Enter your email address',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  FeatherIcons.mail,
                  size: 22,
                  color: AppTheme.primaryColor.withOpacity(0.85),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor.withOpacity(0.35),
                    width: 1.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.32),
                    width: 1.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2.4,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.red.withOpacity(0.8),
                    width: 1.8,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.red,
                    width: 2.4,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 22,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}\$').hasMatch(value.trim())) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
              onChanged: (_) => _clearError(),
            ),
          ),
          SizedBox(height: isSmallScreen ? 18 : 22),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              textInputAction: TextInputAction.done,
              enableSuggestions: false,
              autocorrect: false,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                hintText: 'Enter your password',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  FeatherIcons.lock,
                  size: 22,
                  color: AppTheme.primaryColor.withOpacity(0.85),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? FeatherIcons.eye : FeatherIcons.eyeOff,
                    size: 22,
                    color: AppTheme.primaryColor.withOpacity(0.85),
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor.withOpacity(0.35),
                    width: 1.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.32),
                    width: 1.8,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppTheme.primaryColor,
                    width: 2.4,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.red.withOpacity(0.8),
                    width: 1.8,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.red,
                    width: 2.4,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 22,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
              onChanged: (_) => _clearError(),
              onFieldSubmitted: (_) => _login(),
            ),
          ),
          SizedBox(height: isSmallScreen ? 26 : 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isLoading || _isGoogleLoading) ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 18 : 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: AppTheme.primaryColor,
                elevation: 5,
                shadowColor: AppTheme.primaryColor.withOpacity(0.28),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Login',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 19 : 21,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 18 : 22),
          _buildGoogleSignInButton(),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Form(
      key: _registerFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _regNameController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'Full Name',
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              hintText: 'Enter your full name',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                FeatherIcons.user, 
                size: 18,
                color: Colors.white.withOpacity(0.7),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red.withOpacity(0.7),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
            onChanged: (_) => _clearError(),
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          TextFormField(
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              hintText: 'Enter your email address',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                FeatherIcons.mail, 
                size: 18,
                color: Colors.white.withOpacity(0.7),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red.withOpacity(0.7),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
            onChanged: (_) => _clearError(),
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          TextFormField(
            controller: _regPasswordController,
            obscureText: !_isRegPasswordVisible,
            textInputAction: TextInputAction.next,
            enableSuggestions: false,
            autocorrect: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              hintText: 'Create a strong password',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                FeatherIcons.lock, 
                size: 18,
                color: Colors.white.withOpacity(0.7),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isRegPasswordVisible ? FeatherIcons.eye : FeatherIcons.eyeOff,
                  size: 18,
                  color: Colors.white.withOpacity(0.7),
                ),
                onPressed: () {
                  setState(() {
                    _isRegPasswordVisible = !_isRegPasswordVisible;
                  });
                },
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red.withOpacity(0.7),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
                return 'Password must contain uppercase, lowercase & number';
              }
              return null;
            },
            onChanged: (_) => _clearError(),
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          TextFormField(
            controller: _regConfirmController,
            obscureText: !_isRegConfirmVisible,
            textInputAction: TextInputAction.done,
            enableSuggestions: false,
            autocorrect: false,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              hintText: 'Confirm your password',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                FeatherIcons.lock, 
                size: 18,
                color: Colors.white.withOpacity(0.7),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isRegConfirmVisible ? FeatherIcons.eye : FeatherIcons.eyeOff,
                  size: 18,
                  color: Colors.white.withOpacity(0.7),
                ),
                onPressed: () {
                  setState(() {
                    _isRegConfirmVisible = !_isRegConfirmVisible;
                  });
                },
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red.withOpacity(0.7),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _regPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            onChanged: (_) => _clearError(),
            onFieldSubmitted: (_) => _register(),
          ),
          SizedBox(height: isSmallScreen ? 16 : 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_isLoading || _isGoogleLoading) ? null : _register,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Register',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 12),
      child: ElevatedButton.icon(
        onPressed: (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
        icon: _isGoogleLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.login, size: 22),
        label: Text(
          _isGoogleLoading ? 'Signing in...' : 'Sign in with Google',
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.13),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 14 : 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }
} 