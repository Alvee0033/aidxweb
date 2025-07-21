import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/utils/constants.dart';
import 'package:aidx/widgets/glass_container.dart';
import 'package:aidx/services/database_init.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class WearableScreen extends StatefulWidget {
  const WearableScreen({super.key});

  @override
  State<WearableScreen> createState() => _WearableScreenState();
}

class _WearableScreenState extends State<WearableScreen> {
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;
  List<ScanResult> _scanResults = [];
  
  // Health metrics with real-time updates
  int _heartRate = 0;
  int _spo2 = 0;
  bool _isMonitoring = false;
  
  // Stream subscriptions
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  List<StreamSubscription<List<int>>>? _characteristicSubscriptions;
  
  // Timer for simulated data (fallback)
  Timer? _simulationTimer;
  
  // Database service
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Connected devices from database
  List<Map<String, dynamic>> _connectedDevices = [];
  Map<String, dynamic>? _currentDevice;
  
  // Vitals data storage
  Timer? _vitalsSaveTimer;
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initializeBluetooth();
    _loadConnectedDevices();
    // Start a demo simulation so the screen shows sample vitals even without a device
    setState(() {
      _isMonitoring = true;
    });
    _startSimulation();
  }
  
  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _characteristicSubscriptions?.forEach((sub) => sub.cancel());
    _simulationTimer?.cancel();
    _vitalsSaveTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });
    
    if (!allGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth and location permissions are required'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _initializeBluetooth() async {
    // Check if Bluetooth is on
    if (await FlutterBluePlus.isSupported == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth not supported on this device')),
      );
      return;
    }
    
    // Listen for Bluetooth state changes
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        setState(() {
          _isConnected = false;
          _isMonitoring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please turn on Bluetooth')),
        );
      }
    });
  }
  
  void _startScan() async {
    if (_isScanning) return;
    
    setState(() {
      _scanResults = [];
      _isScanning = true;
    });
    
    try {
    // Start scanning
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      setState(() {
          _scanResults = results.where((result) => 
            result.device.name.isNotEmpty || 
            result.advertisementData.serviceUuids.isNotEmpty
          ).toList();
      });
    });
    
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    
      // Stop scanning after timeout
      Future.delayed(const Duration(seconds: 15), () {
      _stopScan();
    });
    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }
  
  void _stopScan() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);
  }
  
  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return;
    
    setState(() {
      _isConnecting = true;
      _connectedDevice = device;
    });
    
    try {
      await device.connect(timeout: const Duration(seconds: 10));
      
      // Listen for connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });
      
      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      await _setupHealthMonitoring(services);
      
      // Save device to database
      await _saveDeviceToDatabase(device);
      
      setState(() {
        _isConnecting = false;
        _isConnected = true;
        _isMonitoring = true;
      });
      
      // Start saving vitals data
      _startVitalsSaving();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${device.name}')),
      );
    } catch (e) {
      setState(() => _isConnecting = false);
      _handleDisconnect();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    }
  }
  
  Future<void> _setupHealthMonitoring(List<BluetoothService> services) async {
    _characteristicSubscriptions?.forEach((sub) => sub.cancel());
    _characteristicSubscriptions = [];
    
    for (var service in services) {
      // Heart Rate Service
      if (service.uuid.toString().toLowerCase() == AppConstants.heartRateServiceUuid.toLowerCase()) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() == AppConstants.heartRateMeasurementCharUuid.toLowerCase()) {
            await characteristic.setNotifyValue(true);
            
            final subscription = characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                _parseHeartRateData(value);
              }
            });
            
            _characteristicSubscriptions?.add(subscription);
          }
        }
      }
      
      // Pulse Oximeter Service
      if (service.uuid.toString().toLowerCase() == AppConstants.pulseOximeterServiceUuid.toLowerCase()) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString().toLowerCase() == AppConstants.spo2MeasurementCharUuid.toLowerCase()) {
            await characteristic.setNotifyValue(true);
            
            final subscription = characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                _parseSpO2Data(value);
              }
            });
            
            _characteristicSubscriptions?.add(subscription);
          }
        }
      }
    }
    
    // If no health services found, start simulation
    if (_characteristicSubscriptions?.isEmpty == true) {
      _startSimulation();
    }
  }
  
  void _parseHeartRateData(List<int> data) {
    if (data.length < 2) return;
    
    // Standard heart rate measurement format
    int flags = data[0];
    int heartRate = 0;
    
    if ((flags & 0x01) == 0) {
      // UINT8 format
      heartRate = data[1];
    } else {
      // UINT16 format
      if (data.length >= 3) {
        heartRate = (data[2] << 8) | data[1];
      }
    }
    
    if (heartRate > 0 && heartRate < 300) { // Valid range
      setState(() => _heartRate = heartRate);
    }
  }
  
  void _parseSpO2Data(List<int> data) {
    if (data.isNotEmpty) {
      int spo2 = data[0];
      if (spo2 >= 0 && spo2 <= 100) { // Valid range
        setState(() => _spo2 = spo2);
      }
    }
  }
  
  void _startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isMonitoring) {
        setState(() {
          // Simulate realistic heart rate (60-100 BPM)
          _heartRate = 70 + (DateTime.now().millisecond % 30);
          // Simulate realistic SpO2 (95-99%)
          _spo2 = 95 + (DateTime.now().millisecond % 5);
        });
      }
    });
  }
  
  Future<void> _disconnectFromDevice() async {
    _simulationTimer?.cancel();
    _characteristicSubscriptions?.forEach((sub) => sub.cancel());
    _connectionSubscription?.cancel();
    
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        debugPrint('Disconnect error: $e');
      }
    }
    
    _handleDisconnect();
  }
  
  void _handleDisconnect() {
    _vitalsSaveTimer?.cancel();
    
    // Update device connection status in database
    if (_currentDevice != null) {
      _databaseService.updateWearableConnection(_currentDevice!['id'], false);
    }
    
    setState(() {
      _connectedDevice = null;
      _currentDevice = null;
      _isConnecting = false;
      _isConnected = false;
      _isMonitoring = false;
      _heartRate = 0;
      _spo2 = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.bgGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: AppTheme.bgGlassLight,
          elevation: 0,
          title: const Text(
            'Wearable Connect',
                          style: TextStyle(
              color: AppTheme.textTeal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.textTeal),
            onPressed: () => Navigator.pop(context),
                    ),
                  ),
        body: SafeArea(
          child: Column(
            children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Health Metrics Card
                      GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                                const Icon(Icons.favorite, color: AppTheme.primaryColor, size: 24),
                              const SizedBox(width: 8),
                    const Text(
                                "Live Health Metrics",
                      style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                        fontWeight: FontWeight.bold,
                                ),
                      ),
                            ],
                    ),
                          const SizedBox(height: 20),
                    
                          // Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                                  icon: Icons.favorite,
                            value: _heartRate.toString(),
                                  unit: "BPM",
                                  color: Colors.red,
                                  isActive: _isMonitoring,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                                  icon: Icons.water_drop,
                            value: _spo2.toString(),
                                  unit: "%",
                                  color: Colors.blue,
                                  isActive: _isMonitoring,
                          ),
                        ),
                      ],
                    ),
                    
                          const SizedBox(height: 20),
                    
                          // Connection Status
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: _isConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isConnected ? Colors.green : Colors.red,
                                width: 1,
                              ),
                          ),
                            child: Row(
                              children: [
                                Icon(
                                  _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                                  color: _isConnected ? Colors.green : Colors.red,
                                  size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                                  _isConnected 
                                    ? "Connected to ${_connectedDevice?.name ?? 'Device'}"
                                    : "Not Connected",
                          style: TextStyle(
                                    color: _isConnected ? Colors.green : Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                            ),
                    ),
                    
                          const SizedBox(height: 20),
                    
                          // Action Button
                    SizedBox(
                      width: double.infinity,
                            child: _isConnected
                          ? ElevatedButton.icon(
                              onPressed: _disconnectFromDevice,
                                    icon: const Icon(Icons.bluetooth_disabled),
                                    label: const Text("Disconnect"),
                              style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _isScanning ? null : _startScan,
                                    icon: Icon(_isScanning ? Icons.hourglass_empty : Icons.bluetooth_searching),
                                    label: Text(_isScanning ? "Scanning..." : "Scan for Devices"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                            ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
                    // Available Devices
              if (_isScanning || _scanResults.isNotEmpty) ...[
                const Text(
                        "Available Devices",
                  style: TextStyle(
                          color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                      const SizedBox(height: 12),
                      
                        GlassContainer(
                  child: _isScanning && _scanResults.isEmpty
                      ? const Padding(
                                padding: EdgeInsets.all(32),
                          child: Center(
                                  child: Column(
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text(
                                        "Scanning for devices...",
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _scanResults.length,
                                separatorBuilder: (context, index) => Divider(
                                  color: Colors.white.withOpacity(0.1),
                                  height: 1,
                                ),
                          itemBuilder: (context, index) {
                            final result = _scanResults[index];
                            final device = result.device;
                                  final name = device.name.isNotEmpty ? device.name : "Unknown Device";
                                  final rssi = result.rssi;
                            
                            return ListTile(
                                    leading: Icon(
                                      Icons.watch,
                                        color: AppTheme.primaryColor,
                                    ),
                              title: Text(
                                name,
                                style: const TextStyle(color: Colors.white),
                              ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                device.id.id,
                                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                        ),
                                        Text(
                                          "Signal: ${rssi} dBm",
                                          style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                        ),
                                      ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: _isConnecting ? null : () => _connectToDevice(device),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primaryColor,
                                      ),
                                      child: Text(
                                        _isConnecting && _connectedDevice?.id == device.id
                                            ? "Connecting..."
                                            : "Connect",
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
              
              const SizedBox(height: 24),
              
                      // Connected Devices from Database
                      if (_connectedDevices.isNotEmpty) ...[
                        const Text(
                          "Previously Connected Devices",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        GlassContainer(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _connectedDevices.length,
                            separatorBuilder: (context, index) => Divider(
                              color: Colors.white.withOpacity(0.1),
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final device = _connectedDevices[index];
                              final isConnected = device['isConnected'] ?? false;
                              
                              return ListTile(
                                leading: Icon(
                                  Icons.watch,
                                  color: isConnected ? Colors.green : AppTheme.textMuted,
                                ),
                                title: Text(
                                  device['deviceName'] ?? 'Unknown Device',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device['deviceId'] ?? '',
                                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                                    ),
                                    Text(
                                      isConnected ? 'Connected' : 'Last connected: ${_formatLastConnected(device['lastConnected'])}',
                                      style: TextStyle(
                                        color: isConnected ? Colors.green : Colors.white.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                    Container(
                                      width: 8,
                                      height: 8,
                      decoration: BoxDecoration(
                                        color: isConnected ? Colors.green : Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removeDevice(device['id']),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ),
                        
                        const SizedBox(height: 24),
                      ],
                      
                      // Instructions
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                                const Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                "How to Connect",
                      style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                        fontWeight: FontWeight.bold,
                                ),
                      ),
                            ],
                    ),
                          const SizedBox(height: 16),
                          _buildInstructionStep("1", "Turn on your wearable device and enable Bluetooth"),
                          _buildInstructionStep("2", "Tap 'Scan for Devices' to find available devices"),
                          _buildInstructionStep("3", "Select your device from the list and tap 'Connect'"),
                          _buildInstructionStep("4", "Your health metrics will update automatically"),
                            _buildInstructionStep("5", "Vitals data is automatically saved to your health profile"),
                        ],
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
    );
  }
  
  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? color.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? color.withOpacity(0.3) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isActive ? color : Colors.white.withOpacity(0.5),
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isActive ? color : Colors.white.withOpacity(0.5),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 14,
              color: isActive ? color.withOpacity(0.8) : Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadConnectedDevices() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final devices = await _databaseService.getWearableDevices(user.uid);
        setState(() {
          _connectedDevices = devices;
        });
      }
    } catch (e) {
      debugPrint('Error loading connected devices: $e');
    }
  }

  Future<void> _saveDeviceToDatabase(BluetoothDevice device) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final deviceData = {
          'deviceId': device.id.id,
          'deviceName': device.name.isNotEmpty ? device.name : 'Unknown Device',
          'deviceType': 'smartwatch',
          'manufacturer': 'Unknown',
          'model': device.name,
          'isConnected': true,
          'lastConnected': FieldValue.serverTimestamp(),
          'capabilities': ['heart_rate', 'spo2'],
        };
        
        final deviceId = await _databaseService.addWearableDevice(user.uid, deviceData);
        await _loadConnectedDevices();
        
        setState(() {
          _currentDevice = {
            'id': deviceId,
            ...deviceData,
          };
        });
      }
    } catch (e) {
      debugPrint('Error saving device to database: $e');
    }
  }

  Future<void> _saveVitalsToDatabase() async {
    try {
      final user = _auth.currentUser;
      if (user != null && _currentDevice != null && _isMonitoring) {
        final vitalsData = {
          'deviceId': _currentDevice!['deviceId'],
          'heartRate': _heartRate,
          'spo2': _spo2,
          'timestamp': FieldValue.serverTimestamp(),
        };
        
        await _databaseService.saveVitalsData(user.uid, vitalsData);
      }
    } catch (e) {
      debugPrint('Error saving vitals to database: $e');
    }
  }

  void _startVitalsSaving() {
    _vitalsSaveTimer?.cancel();
    _vitalsSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isMonitoring) {
        _saveVitalsToDatabase();
      }
    });
  }

  String _formatLastConnected(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else {
        date = DateTime.parse(timestamp.toString());
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _removeDevice(String deviceId) async {
    try {
      await _databaseService.deleteWearableDevice(deviceId);
      await _loadConnectedDevices();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device removed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing device: $e')),
      );
    }
  }
}