import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../widgets/glass_container.dart';
import '../utils/theme.dart';
import 'dart:ui'; // Added for ImageFilter
import 'package:auto_size_text/auto_size_text.dart';

class DrugScreen extends StatefulWidget {
  const DrugScreen({Key? key}) : super(key: key);

  @override
  State<DrugScreen> createState() => _DrugScreenState();
}

class _DrugScreenState extends State<DrugScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final FirebaseService _firebaseService = FirebaseService();
  Map<String, dynamic>? _drugInfo;
  String? _error;
  bool _loading = false;
  bool _saving = false;
  String? _saveMessage;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _drugInfo = null;
      _saveMessage = null;
    });
    try {
      final info = await _geminiService.searchDrug(name, brief: true);
      if (info.containsKey('error')) {
        setState(() {
          _error = info['error'];
          _loading = false;
        });
      } else {
        setState(() {
          _drugInfo = info;
          _loading = false;
        });
        _animController.forward(from: 0);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch information.';
        _loading = false;
      });
    }
  }

  Future<void> _saveMedication() async {
    if (_drugInfo == null) return;
    setState(() {
      _saving = true;
      _saveMessage = null;
    });
    try {
      // Get the current authenticated user
      final user = _firebaseService.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Save medication to database
      await _firebaseService.addMedication(user.uid, {
        'name': _drugInfo!['name'] ?? '',
        'dosage': _drugInfo!['dosage'] ?? '',
        'frequency': 'as needed',
        'startDate': DateTime.now(),
        'endDate': null,
        'instructions': _drugInfo!['warnings'] ?? '',
        'isActive': true,
      });
      
      // Create a reminder for the medication (1 hour from now)
      final reminderDateTime = DateTime.now().add(const Duration(hours: 1));
      final reminderData = {
        'title': 'Take ${_drugInfo!['name']}',
        'description': 'Dosage: ${_drugInfo!['dosage'] ?? 'As prescribed'}\nUses: ${_drugInfo!['uses'] ?? 'As needed'}',
        'type': 'medication',
        'dateTime': reminderDateTime,
        'frequency': 'once',
        'isActive': true,
        'dosage': _drugInfo!['dosage'] ?? 'As prescribed',
        'relatedId': null,
      };
      
      // Save reminder to database
      await _firebaseService.addReminder(user.uid, reminderData);
      
      setState(() {
        _saveMessage = 'Medication saved and reminder set!';
        _saving = false;
      });
    } catch (e) {
      setState(() {
        _saveMessage = 'Failed to save medication: ${e.toString()}';
        _saving = false;
      });
    }
  }

  Widget _buildInfoCard() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    if (_error != null) {
      return FadeTransition(
        opacity: _fadeAnim,
        child: GlassContainer(
          borderRadius: 22,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppTheme.dangerColor, size: 44),
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: AppTheme.dangerColor, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _search,
                style: AppTheme.primaryButtonStyle,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_drugInfo == null) return const SizedBox.shrink();
    return FadeTransition(
      opacity: _fadeAnim,
      child: GlassContainer(
        borderRadius: 28,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryColor.withOpacity(0.25), AppTheme.accentColor.withOpacity(0.18)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.18),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.medication, color: AppTheme.primaryColor, size: 30),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AutoSizeText(
                    _drugInfo!['name']?.toString().toUpperCase() ?? '',
                    style: AppTheme.headlineLarge.copyWith(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontFamily: 'Montserrat', shadows: [Shadow(blurRadius: 12, color: AppTheme.primaryColor.withOpacity(0.18), offset: Offset(0, 4))]),
                    maxLines: 2,
                    minFontSize: 16,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_drugInfo!['generic_formula'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 4, bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.textTeal.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text('Generic: ${_drugInfo!['generic_formula']}', style: AppTheme.bodyText.copyWith(color: AppTheme.textTeal, fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Montserrat')),
                ),
              ),
            const SizedBox(height: 18),
            _infoSection('Uses', _drugInfo!['uses'], Icons.info_outline, AppTheme.infoColor, 0),
            _infoSection('Dosage', _drugInfo!['dosage'], Icons.medical_services_outlined, AppTheme.primaryColor, 1),
            _infoSection('Warnings', _drugInfo!['warnings'], Icons.warning_amber_rounded, AppTheme.warningColor, 2),
            const SizedBox(height: 22),
            if (_saveMessage != null)
              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _saveMessage == 'Medication saved!' ? AppTheme.successColor.withOpacity(0.15) : AppTheme.dangerColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_saveMessage == 'Medication saved!' ? Icons.check_circle : Icons.error, color: _saveMessage == 'Medication saved!' ? AppTheme.successColor : AppTheme.dangerColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _saveMessage!,
                        style: TextStyle(
                          color: _saveMessage == 'Medication saved!' ? AppTheme.successColor : AppTheme.dangerColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Center(
              child: GestureDetector(
                onTapDown: (_) => setState(() {}),
                onTapUp: (_) => setState(() {}),
                child: AnimatedScale(
                  scale: _saving ? 0.95 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveMedication,
                    icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.bookmark_add),
                    label: const Text('Save Medication', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.92),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 10,
                      shadowColor: AppTheme.primaryColor.withOpacity(0.18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value) {
    if (value == null || value == 'Information not available') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary, fontSize: 15),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(String label, String? value, IconData icon, Color color, int index) {
    if (value == null || value == 'Information not available') return const SizedBox.shrink();
    return AnimatedSlide(
      offset: Offset(0, 0.1 * (index + 1)),
      duration: Duration(milliseconds: 350 + index * 100),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: Duration(milliseconds: 350 + index * 100),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.13), Colors.white.withOpacity(0.03)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.13)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Montserrat')),
                    const SizedBox(height: 2),
                    Text(value!, style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w500, fontSize: 15, fontFamily: 'Montserrat')),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Padding(
          padding: const EdgeInsets.only(top: 16, left: 8, right: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.bgGlassLight.withOpacity(0.8), Colors.black.withOpacity(0.2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.10)),
                ),
                child: AppBar(
                  title: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppTheme.primaryColor.withOpacity(0.25), AppTheme.accentColor.withOpacity(0.18)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.18),
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.medication, color: AppTheme.primaryColor, size: 26),
                        ],
                      ),
                      const SizedBox(width: 12),
                      const Text('Drug Information', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat', fontSize: 20)),
                    ],
                  ),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  automaticallyImplyLeading: true,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Soft background pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: Image.asset(
                'assets/images/background_pattern.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.bgGradient,
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero Card
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Material(
                        color: Colors.transparent,
                        elevation: 0,
                        borderRadius: BorderRadius.circular(28),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
                              height: 90,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.bgGlassLight.withOpacity(0.7), Colors.white.withOpacity(0.08)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.08)),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withOpacity(0.10),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 18),
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [AppTheme.primaryColor.withOpacity(0.25), AppTheme.accentColor.withOpacity(0.18)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryColor.withOpacity(0.18),
                                              blurRadius: 18,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.medication, color: AppTheme.primaryColor, size: 32),
                                    ],
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Text(
                                      'Find trusted, real medication info instantly.',
                                      style: AppTheme.headlineMedium.copyWith(fontWeight: FontWeight.bold, fontFamily: 'Montserrat', fontSize: 17),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Input Field
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: Colors.transparent,
                        elevation: 0,
                        borderRadius: BorderRadius.circular(30),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppTheme.bgGlassLight.withOpacity(0.8), Colors.white.withOpacity(0.10)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.10)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  const Icon(Icons.search, color: AppTheme.primaryColor, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _controller,
                                      style: AppTheme.bodyText.copyWith(color: AppTheme.textPrimary, fontSize: 17, fontFamily: 'Montserrat'),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter drug name',
                                        hintStyle: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w500, fontFamily: 'Montserrat'),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 18),
                                      ),
                                      onSubmitted: (_) => _search(),
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 350),
                                    child: _loading
                                        ? const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 16),
                                            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)),
                                          )
                                        : IconButton(
                                            key: ValueKey(_loading),
                                            icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryColor, size: 26),
                                            onPressed: _search,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Info Card
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildInfoCard(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 