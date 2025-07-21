import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/app_colors.dart';
import '../services/firebase_service.dart';
import '../services/gemini_service.dart';
import '../services/database_init.dart';
import '../services/notification_service.dart';
import '../widgets/glass_container.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SymptomScreen extends StatefulWidget {
  const SymptomScreen({Key? key}) : super(key: key);

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  final TextEditingController _symptomController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final GeminiService _geminiService = GeminiService();
  
  int _selectedTab = 0; // 0 = Detector, 1 = History
  bool _isAnalyzing = false;
  bool _showResult = false;
  Map<String, dynamic>? _analysisResult;
  String? _selectedGender;
  String _selectedIntensity = 'mild';
  String _selectedDuration = '<1d';
  XFile? _selectedImage;
  List<Map<String, dynamic>> _symptomHistory = [];
  bool _isLoadingHistory = false;
  late DatabaseService _databaseService;
  bool _savingMedication = false;
  
  @override
  void initState() {
    super.initState();
    _loadSymptomHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _databaseService = Provider.of<DatabaseService>(context);
  }

  Future<void> _saveMedicationFromAnalysis() async {
    if (_analysisResult == null || _analysisResult!['medication'] == null) return;
    
    try {
      setState(() {
        _savingMedication = true;
      });
      
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final medicationData = {
          'name': _analysisResult!['medication'],
          'dosage': 'As prescribed by doctor',
          'frequency': 'As needed',
          'instructions': 'Take as recommended for symptoms',
          'startDate': DateTime.now(),
          'isActive': true,
          'source': 'AI Symptom Analysis',
        };
        
        // Save medication to database
        await _databaseService.addMedication(userId, medicationData);
        
        // Create a reminder for the medication (1 hour from now)
        final reminderDateTime = DateTime.now().add(const Duration(hours: 1));
        final reminderData = {
          'title': 'Take ${_analysisResult!['medication']}',
          'description': 'Dosage: As prescribed by doctor\nInstructions: Take as recommended for symptoms',
          'type': 'medication',
          'dateTime': reminderDateTime,
          'frequency': 'once',
          'isActive': true,
          'dosage': 'As prescribed by doctor',
          'relatedId': null, // Will be linked to the medication
        };
        
        // Save reminder to database
        final firebaseService = FirebaseService();
        await firebaseService.addReminder(userId, reminderData);
        
        // Schedule notification
        final notificationService = NotificationService();
        notificationService.showNotification(
          title: 'Symptom Tracking',
          body: 'New symptom recorded',
          soundName: 'medication_reminder',
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Medication saved and reminder set for ${_analysisResult!['medication']}'),
            backgroundColor: AppColors.primaryColor,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving medication: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save medication: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _savingMedication = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
              Color(0xFF0F172A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Navigation Bar
              Container(
                margin: const EdgeInsets.all(8),
                child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.monitor_heart, color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'AI Symptom Detector',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                ),
              ),
              
              // Tab Navigation
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildTabButton('Symptom Detector', 0),
                    _buildTabButton('Symptom History', 1),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: _selectedTab == 0 ? _buildDetectorContent() : _buildHistoryContent(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primaryColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDetectorContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Describe your symptoms below and click "Analyze" to get preliminary insights powered by AI.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          
          // Symptom Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _symptomController,
              style: TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Describe your main symptoms...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Image Upload Section
          if (_selectedImage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                          children: [
                      Icon(Icons.image, color: AppColors.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Attached Image',
                              style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                        child: Icon(Icons.close, color: Colors.white.withOpacity(0.7), size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedImage!.path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                              ),
                            ),
                            const SizedBox(height: 16),
          ],
          
          // Settings and Analyze Buttons
          Row(
            children: [
              // Settings Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryColor,
                      AppColors.accentColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(50),
                              ),
                child: IconButton(
                  onPressed: _showSettingsModal,
                  icon: Icon(Icons.settings, color: Colors.white, size: 20),
                ),
                            ),
              const SizedBox(width: 12),
              
              // Analyze Button
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryColor, AppColors.accentColor],
                              ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                              child: ElevatedButton(
                    onPressed: _isAnalyzing ? null : _analyzeSymptoms,
                                style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Analyze',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                                ),
                              ),
                            ),
                          ],
                        ),
          
          // Analysis Result
          if (_showResult) ...[
            const SizedBox(height: 24),
            if (_isAnalyzing)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Consulting AI...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_analysisResult != null)
              _buildAnalysisResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisResult() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.medical_services, color: AppColors.primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Analysis Results',
                    style: TextStyle(
                          color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                      if (_selectedImage != null)
                        Text(
                          'Image analysis included',
                          style: TextStyle(
                            color: AppColors.primaryColor,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Conditions Section
            _buildResultCard(
              'Possible Conditions',
              Icons.health_and_safety,
              _analysisResult!['conditions'].join('\n• '),
              AppColors.primaryColor,
            ),
            const SizedBox(height: 16),
            
            // Medication Section
            _buildMedicationCard(
              'Recommended Medication',
              Icons.medication,
              _analysisResult!['medication'],
              Colors.green,
            ),
            const SizedBox(height: 16),
            
            // Measures Section
            _buildResultCard(
              'Self-Care Measures',
              Icons.healing,
              _analysisResult!['measures'],
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String title, IconData icon, String content, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                              style: TextStyle(
                  color: color,
                                fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(String title, IconData icon, String content, Color color) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _savingMedication ? null : _saveMedicationFromAnalysis,
                icon: _savingMedication 
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(Icons.save, size: 16),
                label: Text(_savingMedication ? 'Saving...' : 'Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Symptom History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: _isLoadingHistory
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading your symptom history...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : _symptomHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            color: Colors.white.withOpacity(0.5),
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No symptom history yet',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ],
                          ),
                        )
                      : ListView.builder(
                      itemCount: _symptomHistory.length,
                          itemBuilder: (context, index) {
                        final record = _symptomHistory[index];
                        return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.medical_services, color: AppColors.primaryColor, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        record['name'] ?? 'Unknown symptoms',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(
                                        (record['timestamp'] as Timestamp).toDate(),
                                      ),
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                if (record['analysis'] != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Conditions:',
                                          style: TextStyle(
                                            color: AppColors.primaryColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                        Text(
                                          (record['analysis']['conditions'] as List).join(', '),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.8),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              Row(
                                          children: [
                                            Text(
                    'Additional Details',
                                              style: TextStyle(
                                                color: AppColors.primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                                              ),
                                            ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.white.withOpacity(0.7)),
                                            ),
                                          ],
                                        ),
              const SizedBox(height: 24),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildSettingsField(
                        'Age',
                        TextField(
                          controller: _ageController,
                          style: TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g., 30',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: AppColors.primaryColor),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                          ),
                        ),
                      ),
                      
                      _buildSettingsField(
                        'Gender',
                        DropdownButtonFormField<String>(
                          value: _selectedGender,
                          style: TextStyle(color: Colors.white),
                          dropdownColor: const Color(0xFF1E293B),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: AppColors.primaryColor),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                          ),
                          items: [
                            DropdownMenuItem(value: null, child: Text('Choose', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
                            DropdownMenuItem(value: 'male', child: Text('Male')),
                            DropdownMenuItem(value: 'female', child: Text('Female')),
                            DropdownMenuItem(value: 'other', child: Text('Other')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedGender = value;
                            });
                          },
                        ),
                      ),
                      
                      _buildSettingsField(
                        'Intensity',
                        DropdownButtonFormField<String>(
                          value: _selectedIntensity,
                          style: TextStyle(color: Colors.white),
                          dropdownColor: const Color(0xFF1E293B),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: AppColors.primaryColor),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                          ),
                          items: [
                            DropdownMenuItem(value: 'mild', child: Text('Mild')),
                            DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
                            DropdownMenuItem(value: 'severe', child: Text('Severe')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedIntensity = value!;
                            });
                          },
                        ),
                      ),
                      
                      _buildSettingsField(
                        'Duration',
                        DropdownButtonFormField<String>(
                          value: _selectedDuration,
                          style: TextStyle(color: Colors.white),
                          dropdownColor: const Color(0xFF1E293B),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide(color: AppColors.primaryColor),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.1),
                          ),
                          items: [
                            DropdownMenuItem(value: '<1d', child: Text('< 1 day')),
                            DropdownMenuItem(value: '1-3d', child: Text('1-3 days')),
                            DropdownMenuItem(value: '1w', child: Text('~1 week')),
                            DropdownMenuItem(value: '>1w', child: Text('> 1 week')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedDuration = value!;
                            });
                          },
                        ),
                      ),
                      
                      _buildSettingsField(
                        'Upload Photo (optional)',
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            title: Text(
                              _selectedImage != null ? 'Image selected' : 'Choose image',
                              style: TextStyle(color: Colors.white),
                            ),
                            trailing: Icon(Icons.camera_alt, color: Colors.white.withOpacity(0.7)),
                            onTap: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primaryColor, AppColors.accentColor],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Done',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
                                ),
                              ),
                            );
  }

  Widget _buildSettingsField(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
          ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        Navigator.pop(context); // Close modal after image selection
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _analyzeSymptoms() async {
    final symptoms = _symptomController.text.trim();
    if (symptoms.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe your symptoms or upload an image.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _showResult = true;
    });

    try {
      final result = await _geminiService.analyzeSymptoms(
        description: symptoms,
        age: int.tryParse(_ageController.text),
        gender: _selectedGender,
        intensity: _selectedIntensity,
        duration: _selectedDuration,
        imageAttached: _selectedImage != null,
        imageFile: _selectedImage != null ? File(_selectedImage!.path) : null,
      );

      final parsedResult = _geminiService.parseResponse(result);
      
      setState(() {
        _analysisResult = parsedResult;
        _isAnalyzing = false;
      });

      // Save to Firebase
      await _saveSymptomRecord(symptoms, parsedResult);
      
    } catch (error) {
      setState(() {
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveSymptomRecord(String symptoms, Map<String, dynamic> analysis) async {
    try {
      final firebaseService = FirebaseService();
      final user = firebaseService.currentUser;
      if (user != null) {
        await firebaseService.saveSymptomRecord(user.uid, {
          'name': symptoms,
          'severity': _selectedIntensity,
          'duration': _selectedDuration,
          'analysis': analysis,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      print('Error saving symptom record: $error');
    }
  }

  Future<void> _loadSymptomHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final firebaseService = FirebaseService();
      final user = firebaseService.currentUser;
      if (user != null) {
        final history = await firebaseService.getSymptomHistory(user.uid);
        setState(() {
          _symptomHistory = history;
          _isLoadingHistory = false;
        });
      }
    } catch (error) {
      setState(() {
        _isLoadingHistory = false;
      });
      print('Error loading symptom history: $error');
    }
  }
} 