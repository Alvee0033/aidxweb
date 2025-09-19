import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/app_colors.dart';
import '../widgets/app_drawer.dart';
import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../utils/theme.dart';
import '../services/database_init.dart';
import '../services/health_id_service.dart';
import '../models/health_id_model.dart';

class AISymptomScreen extends StatefulWidget {
  const AISymptomScreen({Key? key}) : super(key: key);

  @override
  State<AISymptomScreen> createState() => _AISymptomScreenState();
}

class _AISymptomScreenState extends State<AISymptomScreen> {
  // Controllers
  final TextEditingController _symptomController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Services
  final ImagePicker _picker = ImagePicker();
  final GeminiService _geminiService = GeminiService();

  // State
  int _tabIndex = 0; // 0 = detector, 1 = report analyzer, 2 = history
  String? _gender;
  String _intensity = "mild";
  String _duration = "<1d";
  XFile? _pickedImage;
  bool _isAnalyzing = false;
  Map<String, dynamic>? _analysisResult;
  bool _historyLoading = true;
  final List<Map<String, dynamic>> _history = [];
  Uint8List? _imageBytes;
  String? _imageMimeType;
  bool _useLiveVitals = false;
  bool _useHealthIdProfile = false;
  HealthIdModel? _healthId;
  bool _healthIdLoading = false;

  // Report Analyzer specific state
  final TextEditingController _reportDescriptionController = TextEditingController();
  final TextEditingController _reportAgeController = TextEditingController();
  String? _reportGender;
  String _reportType = "ECG";
  XFile? _reportImage;
  bool _isAnalyzingReport = false;
  Map<String, dynamic>? _reportAnalysisResult;
  Uint8List? _reportImageBytes;
  String? _reportImageMimeType;
  bool _useHealthIdForReport = false;

  @override
  void initState() {
    super.initState();
    print('🚀 AI Symptom Screen initialized');
    _loadHistory();
    _loadHealthIdProfile();
    _initializeReportAnalyzer();
  }

  void _initializeReportAnalyzer() {
    // Pre-fill report age from Health ID if available
    if (_healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
      final ageInt = int.tryParse(_healthId!.age!);
      if (ageInt != null) {
        _reportAgeController.text = ageInt.toString();
      }
    }
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _tabIndex == 0 
                      ? _buildAnalyzerView() 
                      : _tabIndex == 1 
                          ? _buildReportAnalyzerView() 
                          : _buildHistoryView(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  const Icon(Icons.monitor_heart, size: 22, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                    "AI Symptom Analyzer",
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
                    onTap: _logout,
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
          _buildTabButton("Analyzer", 0),
          _buildTabButton("Report Analyzer", 1),
          _buildTabButton("History", 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
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

  // Main content views
  Widget _buildAnalyzerView() {
        return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
            child: _buildAnalyzerCard(),
    );
  }

  Widget _buildReportAnalyzerView() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: _buildReportAnalyzerCard(),
    );
  }

  Widget _buildAnalyzerCard() {
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
                  _buildSectionHeader("Describe your symptoms", Icons.psychology),
                  const SizedBox(height: 16),
                  _buildSymptomInput(),
                  const SizedBox(height: 16),
                  _buildDetailInputs(),
                  const SizedBox(height: 16),
                  _buildImageUploadSection(),
                  const SizedBox(height: 20),
                  _buildAnalyzeButton(),
                  if (_analysisResult != null || _isAnalyzing) ...[
                    const SizedBox(height: 24),
                    _buildResultCard(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportAnalyzerCard() {
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
                  _buildSectionHeader("Medical Report Analyzer", Icons.assignment),
                  const SizedBox(height: 16),
                  _buildReportDescriptionInput(),
                  const SizedBox(height: 16),
                  _buildReportDetailInputs(),
                  const SizedBox(height: 16),
                  _buildReportTypeSelector(),
                  const SizedBox(height: 16),
                  _buildReportImageUploadSection(),
                  const SizedBox(height: 20),
                  _buildAnalyzeReportButton(),
                  if (_reportAnalysisResult != null || _isAnalyzingReport) ...[
                    const SizedBox(height: 24),
                    _buildReportResultCard(),
                  ],
                ],
              ),
            ),
          ),
        ),
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

  Widget _buildSymptomInput() {
    return TextField(
                        controller: _symptomController,
                        style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
                        maxLines: 4,
                        decoration: InputDecoration(
                          filled: true,
        fillColor: Colors.black.withOpacity(0.25),
                          hintText: "Describe your main symptoms...",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Montserrat'),
                          border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
        contentPadding: const EdgeInsets.all(16),
                        ),
    );
  }

  Widget _buildDetailInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Health ID Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                _healthId != null ? Icons.verified_user : Icons.person_off,
                color: _useHealthIdProfile ? AppTheme.accentColor : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      _healthIdLoading
                          ? "Loading Health ID..."
                          : (_healthId == null
                              ? "Health ID not linked"
                              : (_useHealthIdProfile ? "Using Health ID" : "Use Health ID")),
                      style: TextStyle(
                        color: _healthId == null
                            ? Colors.white54
                            : (_useHealthIdProfile ? Colors.white : Colors.white70),
                        fontSize: 14,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_healthId != null && !_healthIdLoading) ...[
                      const SizedBox(width: 8),
                      Switch(
                        value: _useHealthIdProfile,
                        onChanged: (val) {
                          setState(() {
                            _useHealthIdProfile = val;
                            // Refresh age display when toggle changes
                            _refreshAgeDisplay();
                          });
                        },
                        activeColor: AppTheme.accentColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Age and Gender fields (always visible, but indicate Health ID usage)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            _buildDropdown(
              value: _gender,
              items: const ["Male", "Female", "Other"],
              hint: _useHealthIdProfile && _healthId != null ? "Gender (from Health ID)" : "Gender",
              icon: Icons.person,
              onChanged: (v) => setState(() => _gender = v),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
                enabled: !(_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null)
                      ? Colors.green.withOpacity(0.1)
                      : Colors.white.withOpacity(0.04),
                  hintText: (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null)
                      ? "Age: ${_healthId!.age}"
                      : "Age",
                  hintStyle: TextStyle(
                    color: (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null)
                        ? Colors.greenAccent.withOpacity(0.8)
                        : Colors.white.withOpacity(0.4),
                    fontFamily: 'Montserrat',
                    fontStyle: (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null) ? FontStyle.italic : FontStyle.normal,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null)
                          ? Colors.greenAccent.withOpacity(0.5)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        if (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "✓ Using age ${_healthId!.age} from Health ID profile",
              style: TextStyle(
                color: Colors.greenAccent.withOpacity(0.8),
                fontSize: 12,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // Always visible fields (intensity, duration, live vitals)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            _buildDropdown(
              value: _intensity,
              items: const ["mild", "moderate", "severe"],
              hint: "Intensity",
              icon: Icons.bolt,
              onChanged: (v) => setState(() => _intensity = v ?? "mild"),
            ),
            _buildDropdown(
              value: _duration,
              items: const ["<1d", "1-3d", "1w", ">1w"],
              hint: "Duration",
              icon: Icons.timer,
              onChanged: (v) => setState(() => _duration = v ?? "<1d"),
            ),
            Row(
              children: [
                Switch(
                  value: _useLiveVitals,
                  onChanged: (val) {
                    setState(() {
                      _useLiveVitals = val;
                    });
                  },
                  activeColor: AppTheme.primaryColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 4),
                Text(
                  "Live Vitals",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportDescriptionInput() {
    return TextField(
      controller: _reportDescriptionController,
      style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
      maxLines: 4,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withOpacity(0.25),
        hintText: "Describe your medical report or any specific concerns...",
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Montserrat'),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildReportDetailInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Health ID Toggle for Report
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                _healthId != null ? Icons.verified_user : Icons.person_off,
                color: _useHealthIdForReport ? AppTheme.accentColor : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      _healthIdLoading
                          ? "Loading Health ID..."
                          : (_healthId == null
                              ? "Health ID not linked"
                              : (_useHealthIdForReport ? "Using Health ID" : "Use Health ID")),
                      style: TextStyle(
                        color: _healthId == null
                            ? Colors.white54
                            : (_useHealthIdForReport ? Colors.white : Colors.white70),
                        fontSize: 14,
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_healthId != null && !_healthIdLoading) ...[
                      const SizedBox(width: 8),
                      Switch(
                        value: _useHealthIdForReport,
                        onChanged: (val) {
                          setState(() {
                            _useHealthIdForReport = val;
                            _refreshReportAgeDisplay();
                          });
                        },
                        activeColor: AppTheme.accentColor,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Age and Gender fields for Report
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.start,
          children: [
            _buildDropdown(
              value: _reportGender,
              items: const ["Male", "Female", "Other"],
              hint: _useHealthIdForReport && _healthId != null ? "Gender (from Health ID)" : "Gender",
              icon: Icons.person,
              onChanged: (v) => setState(() => _reportGender = v),
            ),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _reportAgeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
                enabled: !(_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null)
                      ? Colors.green.withOpacity(0.1)
                      : Colors.white.withOpacity(0.04),
                  hintText: (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null)
                      ? "Age: ${_healthId!.age}"
                      : "Age",
                  hintStyle: TextStyle(
                    color: (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null)
                        ? Colors.greenAccent.withOpacity(0.8)
                        : Colors.white.withOpacity(0.4),
                    fontFamily: 'Montserrat',
                    fontStyle: (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null) ? FontStyle.italic : FontStyle.normal,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null)
                          ? Colors.greenAccent.withOpacity(0.5)
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
        if (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty && int.tryParse(_healthId!.age!) != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "✓ Using age ${_healthId!.age} from Health ID profile",
              style: TextStyle(
                color: Colors.greenAccent.withOpacity(0.8),
                fontSize: 12,
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReportTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.medical_services, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Report Type",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Select the type of medical report you're analyzing for better accuracy.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontFamily: 'Montserrat',
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            "ECG", "X-Ray", "CT Scan", "MRI", "Blood Test", "Urine Test", 
            "Ultrasound", "Biopsy", "Pathology", "Other"
          ].map((type) => _buildReportTypeChip(type)).toList(),
        ),
      ],
    );
  }

  Widget _buildReportTypeChip(String type) {
    final isSelected = _reportType == type;
    return GestureDetector(
      onTap: () => setState(() => _reportType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          type,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
    );
  }

  Widget _buildReportImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Upload Medical Report",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Upload photos of your medical reports like ECG, X-ray, blood test results, or any other medical documents for AI analysis.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontFamily: 'Montserrat',
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        _buildReportImageUpload(),
      ],
    );
  }

  Widget _buildReportImageUpload() {
    final hasImage = _reportImage != null && (!kIsWeb || (kIsWeb && _reportImageBytes != null));
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _pickReportImage,
          icon: Icon(hasImage ? Icons.check_circle : Icons.upload_file, size: 20),
          label: Text(hasImage ? "Change Report" : "Upload Report"),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: hasImage 
                ? Colors.green.withOpacity(0.6)
                : AppTheme.primaryColor.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            shadowColor: Colors.transparent,
            side: BorderSide(
              color: hasImage 
                  ? Colors.green.withOpacity(0.8)
                  : AppTheme.primaryColor.withOpacity(0.6),
            ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.18), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.memory(
                      _reportImageBytes!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_reportImage!.path),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _reportImage = null;
                _reportImageBytes = null;
                _reportImageMimeType = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Report image removed'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzeReportButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _isAnalyzingReport ? null : _analyzeReport,
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
            _isAnalyzingReport 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  )
                : const Icon(Icons.analytics, size: 20),
            const SizedBox(width: 8),
            const Text(
              "Analyze Report",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportResultCard() {
    if (_isAnalyzingReport) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentColor),
            ),
            const SizedBox(height: 16),
            Text(
              "Analyzing your medical report...",
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontFamily: 'Montserrat'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.6),
            AppTheme.bgGlassMedium.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      color: AppTheme.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "Report Analysis Results",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildReportResultSection(
                  title: "Report Summary",
                  icon: Icons.summarize,
                  content: _buildReportSummaryContent(_reportAnalysisResult?["summary"] ?? ""),
                ),
                const SizedBox(height: 8),
                _buildReportResultSection(
                  title: "Key Findings",
                  icon: Icons.find_in_page,
                  content: _buildReportFindingsContent(_reportAnalysisResult?["findings"] ?? ""),
                ),
                const SizedBox(height: 8),
                _buildReportResultSection(
                  title: "Recommendations",
                  icon: Icons.recommend,
                  content: _buildReportRecommendationsContent(_reportAnalysisResult?["recommendations"] ?? ""),
                ),
                const SizedBox(height: 8),
                _buildReportResultSection(
                  title: "Next Steps",
                  icon: Icons.next_plan,
                  content: _buildReportNextStepsContent(_reportAnalysisResult?["next_steps"] ?? ""),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportResultSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Montserrat',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildReportSummaryContent(String summaryText) {
    return Text(
      summaryText.isEmpty ? "Report analysis completed successfully" : summaryText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildReportFindingsContent(String findingsText) {
    return Text(
      findingsText.isEmpty ? "No significant abnormalities detected" : findingsText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildReportRecommendationsContent(String recommendationsText) {
    return Text(
      recommendationsText.isEmpty ? "Continue regular monitoring as advised by your healthcare provider" : recommendationsText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildReportNextStepsContent(String nextStepsText) {
    return Text(
      nextStepsText.isEmpty ? "Follow up with your doctor for any concerns" : nextStepsText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
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
          value: value?.isEmpty == true ? null : value,
          icon: Icon(icon, color: AppTheme.primaryColor.withOpacity(0.8), size: 18),
          dropdownColor: Colors.black.withOpacity(0.8),
          style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
          hint: Text(hint, style: TextStyle(color: Colors.white.withOpacity(0.6), fontFamily: 'Montserrat')),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontFamily: 'Montserrat')),
                  ))
              .toList(),
          onChanged: onChanged,
                                  ),
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.photo_camera, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Upload Photo (Optional)",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Add a photo of visible symptoms like rashes, wounds, or skin conditions to get more accurate analysis.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontFamily: 'Montserrat',
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        _buildImageUpload(),
      ],
    );
  }

  Widget _buildImageUpload() {
    final hasImage = _pickedImage != null && (!kIsWeb || (kIsWeb && _imageBytes != null));
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: _pickImage,
          icon: Icon(hasImage ? Icons.check_circle : Icons.image, size: 20),
          label: Text(hasImage ? "Change Photo" : "Upload Photo"),
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: hasImage 
                ? Colors.green.withOpacity(0.6)
                : AppTheme.primaryColor.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            shadowColor: Colors.transparent,
            side: BorderSide(
              color: hasImage 
                  ? Colors.green.withOpacity(0.8)
                  : AppTheme.primaryColor.withOpacity(0.6),
            ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentColor.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.18), width: 1.2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.memory(
                      _imageBytes!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_pickedImage!.path),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _pickedImage = null;
                _imageBytes = null;
                _imageMimeType = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image removed'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAnalyzeButton() {
    return Center(
      child: ElevatedButton(
        onPressed: _isAnalyzing ? null : _analyze,
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
            _isAnalyzing 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  )
                : const Icon(Icons.search, size: 20),
            const SizedBox(width: 8),
            const Text(
              "Analyze Symptoms",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSevereCondition(List conditions) {
    if (conditions.isEmpty) return false;
    final joined = conditions.join(' ').toLowerCase();

    // Check if AI response explicitly indicates severe condition
    if (joined.contains('severity: severe') || joined.contains('severe (emergency)')) {
      return true;
    }

    // Define severe conditions that require immediate medical attention
    const severeKeywords = [
      'heart attack', 'myocardial infarction', 'stroke', 'kidney failure', 'renal failure',
      'sepsis', 'anaphylaxis', 'pulmonary embolism', 'pe', 'aortic dissection',
      'meningitis', 'intracranial hemorrhage', 'hemorrhage', 'gi bleed', 'diabetic ketoacidosis', 'dka',
      'status asthmaticus', 'respiratory failure', 'acute liver failure', 'encephalitis',
      'appendicitis with perforation', 'ectopic pregnancy', 'testicular torsion',
      'acute coronary syndrome', 'acs', 'shock', 'cardiac arrest', 'cancer', 'tumor',
      'pneumonia', 'tuberculosis', 'hiv', 'aids', 'hepatitis', 'cirrhosis',
      'pancreatitis', 'peritonitis', 'osteomyelitis', 'endocarditis', 'myocarditis'
    ];

    for (final kw in severeKeywords) {
      if (joined.contains(kw)) return true;
    }

    // Also check for high confidence with severe intensity
    final hasHighPercent = RegExp(r'\(\s*(9[0-9]|100)\s*%\s*\)').hasMatch(joined);
    if (hasHighPercent && _intensity.toLowerCase() == 'severe') return true;

    return false;
  }

  Widget _buildResultCard() {
    if (_isAnalyzing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              "Analyzing your symptoms...",
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontFamily: 'Montserrat'),
            ),
          ],
        ),
      );
    }

    final conditions = (_analysisResult?["conditions"] as List?) ?? [];
    final bool isSevere = _isSevereCondition(conditions);

    return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                colors: [
            Colors.black.withOpacity(0.6),
            AppTheme.bgGlassMedium.withOpacity(0.6),
                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.medical_information,
                      color: AppTheme.primaryColor,
                      size: 24,
                            ),
                    const SizedBox(width: 10),
                    const Text(
                      "Analysis Results",
                        style: TextStyle(
                          color: Colors.white,
                        fontSize: 20,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                                ),
                              ],
                            ),
                const SizedBox(height: 10),
                if (conditions.isNotEmpty) ...[
                  _buildResultSection(
                    title: "1. Possible Conditions",
                    icon: Icons.coronavirus_outlined,
                    content: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: conditions.map((condition) => _buildConditionBubble(condition)).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                                // Section 2: Medications (concise display)
                _buildResultSection(
                  title: "Medications",
                  icon: Icons.medication_outlined,
                  content: _buildMedicationContent(_analysisResult?["medication"] ?? ""),
                ),
                const SizedBox(height: 8),
                // Section 3: Home Remedies (concise display)
                _buildResultSection(
                  title: "Home Remedies",
                  icon: Icons.local_florist_outlined,
                  content: _buildHomeRemedyContent(_analysisResult?["homemade_remedies"] ?? ""),
                ),
                const SizedBox(height: 8),
                // Section 4: Actions (concise display)
                _buildResultSection(
                  title: "Actions",
                  icon: Icons.healing,
                  content: _buildMeasuresContent(_analysisResult?["measures"] ?? ""),
                ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildConditionBubble(String condition) {
    // Extract percentage if present
    String displayText = condition;
    String percentage = "";
    
    // Look for patterns like "(80%)" or "(80 %)" or "80%"
    final percentageRegex = RegExp(r'\(?\d+\s*%\)?');
    final match = percentageRegex.firstMatch(condition);
    
    if (match != null) {
      percentage = match.group(0) ?? "";
      // Clean up the percentage text
      percentage = percentage.replaceAll(RegExp(r'[()]'), '').trim();
      
      // Remove the percentage from display text if it's in parentheses
      if (condition.contains('(') && condition.contains(')')) {
        displayText = condition.replaceAll(RegExp(r'\s*\(\d+\s*%\)'), '').trim();
      }
    }
    
    // Remove any bullet points or dashes
    displayText = displayText.replaceAll(RegExp(r'^[-•]\s*'), '').trim();
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.7),
            AppTheme.accentColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            displayText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'Montserrat',
            ),
          ),
          if (percentage.isNotEmpty) ...[
            const SizedBox(width: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                percentage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
                Icon(
                  icon,
                  color: AppTheme.accentColor,
                  size: 20,
                ),
            const SizedBox(width: 8),
            Text(
              title,
                  style: TextStyle(
                    color: AppTheme.accentColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
            const SizedBox(height: 6),
            content,
          ],
        ),
        ),
    );
  }

  // Simplified content builders for concise display
  Widget _buildMedicationContent(String medicationText) {
    return Text(
      medicationText.isEmpty ? "Paracetamol 500mg every 4-6h, Ibuprofen 200mg every 4-6h" : medicationText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildHomeRemedyContent(String remedyText) {
    return Text(
      remedyText.isEmpty ? "Rest, hydrate, cool compress for fever" : remedyText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }

  Widget _buildMeasuresContent(String measuresText) {
    return Text(
      measuresText.isEmpty ? "Monitor symptoms, seek care if worsens" : measuresText,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Montserrat',
        height: 1.4,
      ),
    );
  }





  Widget _buildResultTextSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(color: Colors.white70, fontFamily: 'Montserrat'),
          softWrap: true,
        ),
      ],
    );
  }

  Widget _buildChip(String label) {
    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontFamily: 'Montserrat'),
      ),
      backgroundColor: Colors.white.withOpacity(0.1),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildHistoryView() {
    if (_historyLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading symptom history...',
              style: TextStyle(
                color: Colors.white70, 
                fontFamily: 'Montserrat'
              ),
            ),
          ],
        ),
      );
    }
    
        if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: Colors.white.withOpacity(0.5), size: 50),
            const SizedBox(height: 8),
            Text(
              "No symptom history yet",
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'Montserrat',
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Your AI symptom analyses will appear here",
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontFamily: 'Montserrat',
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _refreshHistory,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _tabIndex = 0),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Analyze Symptoms'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: AppTheme.accentColor.withOpacity(0.6),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Tip: Complete a symptom analysis to start building your health history",
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontFamily: 'Montserrat',
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Debug section
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    "Debug Info",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontFamily: 'Montserrat',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "User: ${FirebaseService().currentUser?.email ?? 'Not logged in'}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "History count: ${_history.length}",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontFamily: 'Montserrat',
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _createTestRecord,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.orange.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text(
                      'Create Test Record',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshHistory,
      color: AppTheme.primaryColor,
      backgroundColor: Colors.black,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildHistoryItem(_history[index]),
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> record) {
    final timestamp = (record['timestamp'] as Timestamp?)?.toDate();
    final formattedDate = timestamp != null ? DateFormat('MMM dd, yyyy').format(timestamp) : 'No date';
    
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                      Icon(Icons.medical_services, color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                          record['name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Montserrat',
                    ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                  if (record['analysis'] != null) ...[
                    const SizedBox(height: 8),
                    _buildAnalysisSummary(record['analysis']),
                  ],
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisSummary(Map<String, dynamic> analysis) {
    final List<String> summaryParts = [];

    try {
      // Handle conditions - can be List<String> or List<Map> with name/likelihood
      if (analysis['conditions'] != null) {
        final conditions = analysis['conditions'];
        String conditionsText = '';

        if (conditions is List) {
          if (conditions.isNotEmpty && conditions.first is Map) {
            // New format: [{"name": "...", "likelihood": 70}]
            conditionsText = conditions.map((c) {
              if (c is Map && c['name'] != null) {
                final likelihood = c['likelihood'] ?? '';
                return likelihood.isNotEmpty ? '${c['name']} (${likelihood}%)' : c['name'];
              }
              return c.toString();
            }).join(', ');
          } else {
            // Old format: ["condition1", "condition2"]
            conditionsText = conditions.join(', ');
          }
        } else if (conditions is String) {
          conditionsText = conditions;
        }

        if (conditionsText.isNotEmpty) {
          summaryParts.add("Conditions: $conditionsText");
        }
      }

      // Handle medications
      final meds = analysis['medication'] ?? analysis['medications'];
      if (meds != null) {
        String medsText = '';
        if (meds is List) {
          medsText = meds.join(', ');
        } else if (meds is String) {
          medsText = meds;
        }
        if (medsText.isNotEmpty) {
          summaryParts.add("Medications: $medsText");
        }
      }

      // Handle home remedies
      if (analysis['homemade_remedies'] != null) {
        final remedies = analysis['homemade_remedies'];
        String remediesText = '';
        if (remedies is List) {
          remediesText = remedies.join(', ');
        } else if (remedies is String) {
          remediesText = remedies;
        }
        if (remediesText.isNotEmpty) {
          summaryParts.add("Home Remedies: $remediesText");
        }
      }

      // Handle measures/actions
      final measures = analysis['measures'] ?? analysis['actions'];
      if (measures != null) {
        String measuresText = '';
        if (measures is List) {
          measuresText = measures.join(', ');
        } else if (measures is String) {
          measuresText = measures;
        }
        if (measuresText.isNotEmpty) {
          summaryParts.add("Actions: $measuresText");
        }
      }

      // Handle severity if not shown elsewhere
      if (analysis['severity'] != null && !summaryParts.any((part) => part.contains('Severity'))) {
        summaryParts.add("Severity: ${analysis['severity']}");
      }

    } catch (e) {
      print('Error building analysis summary: $e');
      summaryParts.add("Analysis data available");
    }

    if (summaryParts.isEmpty) {
      return const Text(
        "Analysis data available",
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Montserrat',
          fontSize: 13,
        ),
      );
    }

    return Text(
      summaryParts.join('\n'),
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Montserrat',
        fontSize: 13,
        height: 1.3,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 4,
    );
  }

  // Logic methods
  Future<void> _loadHealthIdProfile() async {
    setState(() => _healthIdLoading = true);
    try {
      final svc = HealthIdService();
      final profile = await svc.getHealthId();
      if (!mounted) return;
      print('Symptom Screen - Loaded Health ID: ${profile?.name}, Age: ${profile?.age}');
      setState(() {
        _healthId = profile;
        _healthIdLoading = false;

        // Pre-fill age from Health ID if available and valid
        if (profile != null && profile.age != null && profile.age!.isNotEmpty) {
          final ageInt = int.tryParse(profile.age!);
          if (ageInt != null) {
            _ageController.text = ageInt.toString();
            print('Symptom Screen - Pre-filled age: $ageInt');
          } else {
            print('Symptom Screen - Could not parse age: ${profile.age}');
          }
        } else {
          print('Symptom Screen - No age in Health ID profile');
        }
      });
    } catch (e) {
      print('Symptom Screen - Error loading Health ID: $e');
      setState(() => _healthIdLoading = false);
      // Silently ignore profile load errors
    }
  }

  void _refreshAgeDisplay() {
    // Update age field display based on Health ID toggle state
    if (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
      final ageInt = int.tryParse(_healthId!.age!);
      if (ageInt != null && ageInt > 0 && ageInt <= 150) {
        // Valid age in Health ID, update the controller
        _ageController.text = ageInt.toString();
      }
    }
  }

  void _refreshReportAgeDisplay() {
    // Update report age field display based on Health ID toggle state
    if (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
      final ageInt = int.tryParse(_healthId!.age!);
      if (ageInt != null && ageInt > 0 && ageInt <= 150) {
        // Valid age in Health ID, update the controller
        _reportAgeController.text = ageInt.toString();
      }
    }
  }

  String _appendPatientProfile(String baseDescription) {
    if (_healthId == null || !_useHealthIdProfile) return baseDescription;
    final profile = _healthId!;
    final List<String> lines = [];
    if ((profile.bloodGroup ?? '').trim().isNotEmpty) {
      lines.add('Blood Group: ${profile.bloodGroup}');
    }
    if (profile.allergies.isNotEmpty) {
      lines.add('Allergies: ${profile.allergies.join(', ')}');
    }
    if (profile.activeMedications.isNotEmpty) {
      lines.add('Active Medications: ${profile.activeMedications.join(', ')}');
    }
    if ((profile.medicalConditions ?? '').trim().isNotEmpty) {
      lines.add('Known Conditions: ${profile.medicalConditions}');
    }
    if ((profile.notes ?? '').trim().isNotEmpty) {
      lines.add('Notes: ${profile.notes}');
    }
    if (lines.isEmpty) return baseDescription;
    return baseDescription +
        '\n\nPatient Profile (from Digital Health ID):\n' +
        lines.join('\n');
  }

  Future<void> _pickImage() async {
    try {
      // Show bottom sheet with options
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.8),
                  AppTheme.bgGlassMedium.withOpacity(0.9),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Choose Image Source",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildImageSourceOption(
                            icon: Icons.camera_alt,
                            label: "Camera",
                            onTap: () async {
                              Navigator.pop(context);
                              await _getImageFromSource(ImageSource.camera);
                            },
                          ),
                          _buildImageSourceOption(
                            icon: Icons.photo_library,
                            label: "Gallery",
                            onTap: () async {
                              Navigator.pop(context);
                              await _getImageFromSource(ImageSource.gallery);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing image options: ${e.toString()}')),
      );
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.7),
                  AppTheme.accentColor.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Montserrat',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getImageFromSource(ImageSource source) async {
    try {
      // Check permissions first
      if (source == ImageSource.camera && !kIsWeb) {
        // For camera, we need to check camera permission
        final hasPermission = await _checkCameraPermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to take photos'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } else if (source == ImageSource.gallery && !kIsWeb) {
        // For gallery, check storage permission
        final hasPermission = await _checkStoragePermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to access photos'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing image...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final img = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Slightly higher quality
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (img != null) {
        setState(() => _pickedImage = img);
        
        try {
          // Read bytes (works on web and mobile)
          final bytes = await img.readAsBytes();
          
          // Validate size (< 4MB) for safer upload/analysis
          if (bytes.lengthInBytes > 4 * 1024 * 1024) {
            setState(() {
              _pickedImage = null;
              _imageBytes = null;
              _imageMimeType = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image too large. Please select an image under 4MB.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Detect mime type: use provided, else infer from file name extension
          String? mime = img.mimeType;
          if (mime == null || mime.isEmpty) {
            final name = img.name.isNotEmpty ? img.name : img.path;
            final lower = name.toLowerCase();
            if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) mime = 'image/jpeg';
            else if (lower.endsWith('.png')) mime = 'image/png';
            else if (lower.endsWith('.webp')) mime = 'image/webp';
            else if (lower.endsWith('.gif')) mime = 'image/gif';
            else mime = 'image/jpeg';
          }

          setState(() {
            _imageBytes = bytes;
            _imageMimeType = mime;
          });

          // Success feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image uploaded successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print('Error processing image: $e');
          setState(() {
            _pickedImage = null;
            _imageBytes = null;
            _imageMimeType = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in image picker: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _analyze() async {
    final desc = _symptomController.text.trim();
    if (desc.isEmpty && _pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe symptoms or attach an image')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });
    try {
      File? imageFile;
      if (!kIsWeb && _pickedImage != null) {
        imageFile = File(_pickedImage!.path);
        if (!imageFile.existsSync()) {
          throw Exception('Selected image file no longer exists');
        }
        final fileSize = await imageFile.length();
        if (fileSize > 4 * 1024 * 1024) {
          throw Exception('Image file is too large. Please use an image smaller than 4MB.');
        }
      }
      Map<String, dynamic>? vitals;
      if (_useLiveVitals) {
        final dbService = DatabaseService();
        final userId = dbService.getCurrentUserId();
        if (userId != null) {
          vitals = await dbService.getLatestVitals(userId);
        }
      }

      // Enrich description with patient profile from Digital Health ID for accuracy
      final enrichedDesc = _appendPatientProfile(desc);

      // Use health ID data if available and enabled, otherwise use manual inputs
      int? analysisAge;
      String? analysisGender;

      // First try to get age from Health ID if enabled
      if (_useHealthIdProfile && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
        analysisAge = int.tryParse(_healthId!.age!.trim());
        if (analysisAge != null && analysisAge > 0 && analysisAge <= 150) {
          // Successfully parsed valid age from Health ID
          print('Using Health ID age: $analysisAge');
        } else {
          // Invalid age in Health ID, fall back to manual input
          print('Invalid Health ID age: ${_healthId!.age}, falling back to manual input');
          analysisAge = int.tryParse(_ageController.text.trim());
        }
      } else {
        // Health ID not enabled or no age data, use manual input
        analysisAge = int.tryParse(_ageController.text.trim());
      }

      // Validate that age is provided and valid
      if (analysisAge == null || analysisAge <= 0 || analysisAge > 150) {
        setState(() => _isAnalyzing = false);
        String errorMessage = 'Age field is required. ';
        if (_useHealthIdProfile && _healthId != null) {
          errorMessage += 'Please add a valid age to your Health ID profile or enter it manually.';
        } else {
          errorMessage += 'Please enter your age.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      analysisGender = _gender;

      // Ensure mime type fallback on web if missing
      final mimeForAnalysis = _imageMimeType == null || _imageMimeType!.isEmpty
          ? (kIsWeb ? 'image/jpeg' : null)
          : _imageMimeType;

      print('🔍 Starting symptom analysis...');
      print('📝 Description: $enrichedDesc');
      print('👤 Age: $analysisAge, Gender: $analysisGender');
      print('📊 Intensity: $_intensity, Duration: $_duration');
      print('🖼️ Image attached: ${_pickedImage != null}, Image bytes: ${_imageBytes?.length ?? 0}');
      
      final resText = await _geminiService.analyzeSymptoms(
        description: enrichedDesc,
        age: analysisAge,
        gender: analysisGender,
        intensity: _intensity,
        duration: _duration,
        imageAttached: _pickedImage != null,
        imageFile: imageFile,
        imageBytes: _imageBytes,
        imageMimeType: mimeForAnalysis,
        vitals: vitals,
      );
      
      print('✅ Gemini response received: ${resText.length} characters');
      // If the result is a user-friendly error string, show error and return
      if (resText.startsWith('Sorry, the AI analysis could not be completed')) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resText),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      print('🔧 Parsing Gemini response...');
      final parsed = _geminiService.parseResponse(resText);
      print('📋 Parsed result: $parsed');
      setState(() {
        _analysisResult = parsed;
        _isAnalyzing = false;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
      await _saveRecord(desc, parsed);
    } catch (e) {
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorry, the AI analysis could not be completed at this time. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  Future<void> _saveRecord(String name, Map<String, dynamic> analysis) async {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user != null) {
      try {
        print('💾 Saving symptom record for user: ${user.uid}');
        print('📝 Record data: name="$name", severity="$_intensity", duration="$_duration"');
        print('🔍 Analysis data keys: ${analysis.keys.toList()}');

        final recordData = {
          'userId': user.uid,
          'name': name,
          'analysis': analysis,
          'severity': _intensity,
          'duration': _duration,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'hasImage': _pickedImage != null,
          'age': _ageController.text.isNotEmpty ? int.tryParse(_ageController.text) : null,
          'gender': _gender,
        };

        print('📊 Complete record data: $recordData');

        await firebaseService.saveSymptomRecord(user.uid, recordData);
        print('✅ Symptom record saved successfully');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Symptom analysis saved to history!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Add a small delay before loading history to ensure Firestore sync
        await Future.delayed(const Duration(milliseconds: 1000));
        await _loadHistory();
      } catch (e) {
        print('❌ Error saving symptom record: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving record: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _saveRecord(name, analysis),
              ),
            ),
          );
        }
      }
    } else {
      print('⚠️ Cannot save record: User not logged in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to save your analysis'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;

    if (user != null) {
      try {
        print('🔍 Loading symptom history for user: ${user.uid}');
        print('🔍 User email: ${user.email}');
        
        final hist = await firebaseService.getSymptomHistory(user.uid);

        print('📊 Loaded ${hist.length} symptom history records');

        if (hist.isNotEmpty) {
          print('📋 Sample record structure:');
          print('   - Name: ${hist.first['name']}');
          print('   - Timestamp: ${hist.first['timestamp']}');
          print('   - Has analysis: ${hist.first['analysis'] != null}');
          print('   - Severity: ${hist.first['severity']}');
          print('   - Duration: ${hist.first['duration']}');
          if (hist.first['analysis'] != null) {
            print('   - Analysis keys: ${hist.first['analysis'].keys.join(', ')}');
          }
        } else {
          print('ℹ️ No symptom history found for user');
          print('🔍 Checking if user document exists...');
          
          // Try to check if user exists in Firestore
          try {
            final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
            print('🔍 User document exists: ${userDoc.exists}');
          } catch (e) {
            print('❌ Error checking user document: $e');
          }
        }

        if (mounted) {
          setState(() {
            _history
              ..clear()
              ..addAll(hist);
            _historyLoading = false;
          });
        }
        print('✅ History loaded and state updated');
      } catch (e) {
        print('❌ Error loading symptom history: $e');
        print('❌ Error type: ${e.runtimeType}');
        print('❌ Error toString: ${e.toString()}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading symptom history: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: _loadHistory,
              ),
            ),
          );
          setState(() {
            _history.clear();
            _historyLoading = false;
          });
        }
      }
    } else {
      print('⚠️ No user logged in, cannot load symptom history');
      if (mounted) {
        setState(() {
          _history.clear();
          _historyLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to view symptom history'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Add a method to manually refresh history
  Future<void> _refreshHistory() async {
    await _loadHistory();
  }

  // Test method to create a test record
  Future<void> _createTestRecord() async {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user != null) {
      try {
        print('🧪 Creating test symptom record...');
        
        final testAnalysis = {
          'conditions': ['Test Condition (85%)', 'Another Condition (60%)'],
          'medication': 'Test medication 500mg every 6 hours',
          'homemade_remedies': 'Rest and hydration',
          'measures': 'Monitor symptoms and consult doctor if worsens',
        };

        await _saveRecord('Test Symptom Analysis', testAnalysis);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test record created successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Error creating test record: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating test record: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to create test records'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _logout() async {
    final firebaseService = FirebaseService();
    await firebaseService.signOut();
    if (mounted) Navigator.pop(context);
  }

  // Permission checking methods
  Future<bool> _checkCameraPermission() async {
    if (kIsWeb) return true; // Web doesn't need explicit permission
    
    try {
      final permission = await Permission.camera.request();
      return permission == PermissionStatus.granted;
    } catch (e) {
      print('Error checking camera permission: $e');
      return false;
    }
  }

  Future<bool> _checkStoragePermission() async {
    if (kIsWeb) return true; // Web doesn't need explicit permission
    
    try {
      // For Android 13+ (API 33+), we need READ_MEDIA_IMAGES
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          final permission = await Permission.photos.request();
          return permission == PermissionStatus.granted;
        }
      }
      
      // For older Android versions and iOS
      final permission = await Permission.photos.request();
      return permission == PermissionStatus.granted;
    } catch (e) {
      print('Error checking storage permission: $e');
      return false;
    }
  }

  // Report Analyzer Methods
  Future<void> _pickReportImage() async {
    try {
      // Show bottom sheet with options
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.8),
                  AppTheme.bgGlassMedium.withOpacity(0.9),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Choose Report Image Source",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildImageSourceOption(
                            icon: Icons.camera_alt,
                            label: "Camera",
                            onTap: () async {
                              Navigator.pop(context);
                              await _getReportImageFromSource(ImageSource.camera);
                            },
                          ),
                          _buildImageSourceOption(
                            icon: Icons.photo_library,
                            label: "Gallery",
                            onTap: () async {
                              Navigator.pop(context);
                              await _getReportImageFromSource(ImageSource.gallery);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error showing image options: ${e.toString()}')),
      );
    }
  }

  Future<void> _getReportImageFromSource(ImageSource source) async {
    try {
      // Check permissions first
      if (source == ImageSource.camera && !kIsWeb) {
        final hasPermission = await _checkCameraPermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to take photos'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } else if (source == ImageSource.gallery && !kIsWeb) {
        final hasPermission = await _checkStoragePermission();
        if (!hasPermission) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to access photos'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing report image...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final img = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (img != null) {
        setState(() => _reportImage = img);
        
        try {
          // Read bytes (works on web and mobile)
          final bytes = await img.readAsBytes();
          
          // Validate size (< 4MB) for safer upload/analysis
          if (bytes.lengthInBytes > 4 * 1024 * 1024) {
            setState(() {
              _reportImage = null;
              _reportImageBytes = null;
              _reportImageMimeType = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image too large. Please select an image under 4MB.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Detect mime type
          String? mime = img.mimeType;
          if (mime == null || mime.isEmpty) {
            final name = img.name.isNotEmpty ? img.name : img.path;
            final lower = name.toLowerCase();
            if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) mime = 'image/jpeg';
            else if (lower.endsWith('.png')) mime = 'image/png';
            else if (lower.endsWith('.webp')) mime = 'image/webp';
            else if (lower.endsWith('.gif')) mime = 'image/gif';
            else mime = 'image/jpeg';
          }

          setState(() {
            _reportImageBytes = bytes;
            _reportImageMimeType = mime;
          });

          // Success feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report image uploaded successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print('Error processing report image: $e');
          setState(() {
            _reportImage = null;
            _reportImageBytes = null;
            _reportImageMimeType = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing report image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in report image picker: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking report image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _analyzeReport() async {
    final desc = _reportDescriptionController.text.trim();
    if (desc.isEmpty && _reportImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the report or attach an image')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isAnalyzingReport = true;
      _reportAnalysisResult = null;
    });
    try {
      File? imageFile;
      if (!kIsWeb && _reportImage != null) {
        imageFile = File(_reportImage!.path);
        if (!imageFile.existsSync()) {
          throw Exception('Selected report image file no longer exists');
        }
        final fileSize = await imageFile.length();
        if (fileSize > 4 * 1024 * 1024) {
          throw Exception('Report image file is too large. Please use an image smaller than 4MB.');
        }
      }

      // Enrich description with patient profile from Digital Health ID for accuracy
      final enrichedDesc = _appendReportPatientProfile(desc);

      // Use health ID data if available and enabled, otherwise use manual inputs
      int? analysisAge;
      String? analysisGender;

      // First try to get age from Health ID if enabled
      if (_useHealthIdForReport && _healthId != null && _healthId!.age != null && _healthId!.age!.isNotEmpty) {
        analysisAge = int.tryParse(_healthId!.age!.trim());
        if (analysisAge != null && analysisAge > 0 && analysisAge <= 150) {
          print('Using Health ID age for report: $analysisAge');
        } else {
          analysisAge = int.tryParse(_reportAgeController.text.trim());
        }
      } else {
        analysisAge = int.tryParse(_reportAgeController.text.trim());
      }

      // Validate that age is provided and valid
      if (analysisAge == null || analysisAge <= 0 || analysisAge > 150) {
        setState(() => _isAnalyzingReport = false);
        String errorMessage = 'Age field is required for report analysis. ';
        if (_useHealthIdForReport && _healthId != null) {
          errorMessage += 'Please add a valid age to your Health ID profile or enter it manually.';
        } else {
          errorMessage += 'Please enter your age.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      analysisGender = _reportGender;

      // Ensure mime type fallback on web if missing
      final mimeForAnalysis = _reportImageMimeType == null || _reportImageMimeType!.isEmpty
          ? (kIsWeb ? 'image/jpeg' : null)
          : _reportImageMimeType;

      final resText = await _geminiService.analyzeMedicalReport(
        description: enrichedDesc,
        reportType: _reportType,
        age: analysisAge,
        gender: analysisGender,
        imageAttached: _reportImage != null,
        imageFile: imageFile,
        imageBytes: _reportImageBytes,
        imageMimeType: mimeForAnalysis,
      );

      // If the result is a user-friendly error string, show error and return
      if (resText.startsWith('Sorry, the AI analysis could not be completed')) {
        setState(() => _isAnalyzingReport = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resText),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final parsed = _geminiService.parseReportResponse(resText);
      setState(() {
        _reportAnalysisResult = parsed;
        _isAnalyzingReport = false;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });

      await _saveReportRecord(desc, parsed);
    } catch (e) {
      setState(() => _isAnalyzingReport = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sorry, the report analysis could not be completed at this time. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _appendReportPatientProfile(String baseDescription) {
    if (_healthId == null || !_useHealthIdForReport) return baseDescription;
    final profile = _healthId!;
    final List<String> lines = [];
    if ((profile.bloodGroup ?? '').trim().isNotEmpty) {
      lines.add('Blood Group: ${profile.bloodGroup}');
    }
    if (profile.allergies.isNotEmpty) {
      lines.add('Allergies: ${profile.allergies.join(', ')}');
    }
    if (profile.activeMedications.isNotEmpty) {
      lines.add('Active Medications: ${profile.activeMedications.join(', ')}');
    }
    if ((profile.medicalConditions ?? '').trim().isNotEmpty) {
      lines.add('Known Conditions: ${profile.medicalConditions}');
    }
    if ((profile.notes ?? '').trim().isNotEmpty) {
      lines.add('Notes: ${profile.notes}');
    }
    if (lines.isEmpty) return baseDescription;
    return baseDescription +
        '\n\nPatient Profile (from Digital Health ID):\n' +
        lines.join('\n');
  }

  Future<void> _saveReportRecord(String description, Map<String, dynamic> analysis) async {
    final firebaseService = FirebaseService();
    final user = firebaseService.currentUser;
    if (user != null) {
      try {
        print('💾 Saving report analysis record for user: ${user.uid}');
        print('📝 Report data: description="$description", type="$_reportType"');
        print('🔍 Analysis data keys: ${analysis.keys.toList()}');

        final recordData = {
          'userId': user.uid,
          'description': description,
          'reportType': _reportType,
          'analysis': analysis,
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'hasImage': _reportImage != null,
          'age': _reportAgeController.text.isNotEmpty ? int.tryParse(_reportAgeController.text) : null,
          'gender': _reportGender,
        };

        print('📊 Complete report record data: $recordData');

        await firebaseService.saveReportRecord(user.uid, recordData);
        print('✅ Report analysis record saved successfully');

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report analysis saved to history!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Error saving report record: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving report record: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _saveReportRecord(description, analysis),
              ),
            ),
          );
        }
      }
    } else {
      print('⚠️ Cannot save report record: User not logged in');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to save your report analysis'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
} 