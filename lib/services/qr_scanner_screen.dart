import 'dart:convert';
import 'package:flutter/material.dart';
// import 'package:qr_code_scanner/qr_code_scanner.dart' if (dart.library.html) 'package:aidx/services/web_qr_stub.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import '../widgets/glass_container.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with TickerProviderStateMixin {
  bool isScanning = true;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  bool _handlingResult = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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

    _scanController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _scanAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.linear),
    );
    _scanController.repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  Future<void> _handleScannedData(String data) async {
    try {
      final jsonData = jsonDecode(data);
      if (jsonData is Map<String, dynamic>) {
        await _saveScannedHealthData(jsonData);
        _showHealthDataDialog(jsonData);
      } else {
        _showErrorDialog('Invalid QR code format');
      }
    } catch (e) {
      _showErrorDialog('Invalid QR code data');
    }
  }

  Future<void> _saveScannedHealthData(Map<String, dynamic> data) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final doc = <String, dynamic>{
        'scannedBy': user?.uid,
        'data': data,
        'scannedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('scanned_health_ids').add(doc);
    } catch (e) {
      // Non-fatal
    }
  }

  void _showHealthDataDialog(Map<String, dynamic> healthData) {
    final List<dynamic> allergies = (healthData['allergies'] as List?) ?? [];
    final List<dynamic> meds = (healthData['activeMedications'] as List?) ?? [];
    final List<dynamic> contacts = (healthData['emergencyContacts'] as List?) ?? [];
    final String? notes = healthData['notes'] as String?;
    final String? userId = healthData['userId'] as String?;
    final String? lastUpdatedStr = healthData['lastUpdated'] as String?;
    DateTime? lastUpdated;
    if (lastUpdatedStr != null) {
      try { lastUpdated = DateTime.tryParse(lastUpdatedStr); } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: GlassContainer(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primaryColor, AppColors.secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.medical_services,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Health ID Found',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildHealthInfoRow('Name', healthData['name']?.toString() ?? 'N/A'),
                  _buildHealthInfoRow('Blood Group', healthData['bloodGroup']?.toString() ?? 'N/A'),
                  if (healthData['medicalConditions'] != null)
                    _buildHealthInfoRow('Medical Conditions', healthData['medicalConditions'].toString()),
                  if (notes != null && notes.trim().isNotEmpty)
                    _buildHealthInfoRow('Notes', notes),
                  if (userId != null)
                    _buildHealthInfoRow('User ID', userId),
                  if (lastUpdated != null)
                    _buildHealthInfoRow('Last Updated', lastUpdated.toString().split('.').first),

                  if (allergies.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSectionTitle('Allergies'),
                    _buildBullets(allergies.map((e) => e.toString()).toList()),
                  ],

                  if (meds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSectionTitle('Active Medications'),
                    _buildBullets(meds.map((e) => e.toString()).toList()),
                  ],

                  if (contacts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSectionTitle('Emergency Contacts'),
                    ...contacts.map((c) {
                      final m = (c as Map).map((k, v) => MapEntry(k.toString(), v));
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (m['name'] != null) _buildHealthInfoRow('Name', m['name'].toString()),
                            if (m['relationship'] != null) _buildHealthInfoRow('Relationship', m['relationship'].toString()),
                            if (m['phone'] != null) _buildHealthInfoRow('Phone', m['phone'].toString()),
                            if (m['email'] != null) _buildHealthInfoRow('Email', m['email'].toString()),
                          ],
                        ),
                      );
                    }).toList(),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() { isScanning = true; });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Scan Another'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Close'),
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
  }

  Widget _buildHealthInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  Widget _buildBullets(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((e) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(color: Colors.white)),
            Expanded(child: Text(e, style: const TextStyle(color: Colors.white))),
          ],
        ),
      )).toList(),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: GlassContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Scan Error',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    isScanning = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Modern Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryColor, AppColors.secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                      Text(
                        'QR Code Scanner',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the back button
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Modern Scanner Interface
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 260,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: FutureBuilder<bool>(
                              future: _ensureCameraPermission(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState != ConnectionState.done) {
                                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                                }
                                if (snapshot.data != true) {
                                  return Center(
                                    child: Text(
                                      'Camera permission is required to scan QR codes',
                                      style: const TextStyle(color: Colors.white),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                }
                                return QRView(
                                  key: qrKey,
                                  overlay: QrScannerOverlayShape(
                                    borderColor: Colors.white,
                                    borderRadius: 12,
                                    borderLength: 24,
                                    borderWidth: 8,
                                    cutOutSize: 220,
                                  ),
                                  onQRViewCreated: (controller) {
                                    _controller = controller;
                                    controller.scannedDataStream.listen((scanData) async {
                                      if (_handlingResult) return;
                                      _handlingResult = true;
                                      await controller.pauseCamera();
                                      await _handleScannedData(scanData.code ?? '');
                                      _handlingResult = false;
                                      if (mounted) {
                                        await controller.resumeCamera();
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Instructions Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  color: AppColors.primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Step 1: Open Camera App',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.qr_code,
                                  color: AppColors.secondaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Step 2: Scan Health ID QR',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.medical_services,
                                  color: AppColors.successColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Step 3: View Health Data',
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // The live scanner replaces external camera button
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 