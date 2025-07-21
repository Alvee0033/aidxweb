import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutter_blue;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ESP32MAX30102Service {
  // Singleton pattern
  static final ESP32MAX30102Service _instance = ESP32MAX30102Service._internal();
  factory ESP32MAX30102Service() => _instance;
  ESP32MAX30102Service._internal();

  // ESP32 MAX30102 Smart Band specific UUIDs
  static const String _esp32ServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String _heartRateCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
  static const String _spo2CharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a9";
  static const String _temperatureCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26aa";
  static const String _batteryCharUuid = "beb5483e-36e1-4688-b7f5-ea07361b26ab";
  static const String _deviceName = "ESP32_SmartBand";

  // Device state
  flutter_blue.BluetoothDevice? _connectedDevice;
  SharedPreferences? _prefs;
  static const String _pairedDeviceKey = 'esp32_smartband_device_id';
  bool _isScanning = false;
  bool _isConnected = false;

  // Vital signs data
  int _heartRate = 0;
  int _spo2 = 0;
  double _temperature = 0.0;
  int _batteryLevel = 0;
  DateTime _lastUpdate = DateTime.now();

  // Streams for real-time data
  final _heartRateController = StreamController<int>.broadcast();
  final _spo2Controller = StreamController<int>.broadcast();
  final _temperatureController = StreamController<double>.broadcast();
  final _batteryController = StreamController<int>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _dataUpdateController = StreamController<Map<String, dynamic>>.broadcast();

  // Subscriptions
  StreamSubscription<List<flutter_blue.ScanResult>>? _scanSubscription;
  StreamSubscription<flutter_blue.BluetoothConnectionState>? _deviceStateSubscription;
  List<StreamSubscription>? _characteristicSubscriptions = [];

  // Getters
  Stream<int> get heartRateStream => _heartRateController.stream;
  Stream<int> get spo2Stream => _spo2Controller.stream;
  Stream<double> get temperatureStream => _temperatureController.stream;
  Stream<int> get batteryStream => _batteryController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get dataUpdateStream => _dataUpdateController.stream;

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  flutter_blue.BluetoothDevice? get connectedDevice => _connectedDevice;
  int get heartRate => _heartRate;
  int get spo2 => _spo2;
  double get temperature => _temperature;
  int get batteryLevel => _batteryLevel;
  DateTime get lastUpdate => _lastUpdate;

  // Initialize service
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final savedId = _prefs!.getString(_pairedDeviceKey);
    if (savedId != null && !_isConnected) {
      _attemptReconnect(savedId);
    }
  }

  // Check permissions
  Future<bool> checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return !statuses.values.any((status) => !status.isGranted);
  }

  // Start scanning for ESP32 Smart Band
  Future<void> startScan() async {
    if (_isScanning) return;

    await init();

    if (!await checkPermissions()) {
      debugPrint('Bluetooth permissions not granted');
      return;
    }

    _isScanning = true;
    _connectionStateController.add(false);

    // Start scanning
    _scanSubscription = flutter_blue.FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        final device = result.device;
        final deviceName = device.platformName;
        
        // Look for ESP32 Smart Band
        if (deviceName.contains('ESP32') || 
            deviceName.contains('SmartBand') || 
            deviceName.contains('MAX30102') ||
            deviceName == _deviceName) {
          debugPrint('Found ESP32 Smart Band: ${device.platformName} (${device.id.id})');
        }
      }
    });

    await flutter_blue.FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    // Stop scanning after 15 seconds
    Future.delayed(const Duration(seconds: 15), () {
      stopScan();
    });
  }

  // Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;

    _scanSubscription?.cancel();
    await flutter_blue.FlutterBluePlus.stopScan();
    _isScanning = false;
  }

  // Connect to ESP32 Smart Band
  Future<bool> connectToDevice(flutter_blue.BluetoothDevice device) async {
    if (_connectedDevice != null) {
      await disconnectFromDevice();
    }

    _connectedDevice = device;

    try {
      await device.connect();

      _deviceStateSubscription = device.connectionState.listen((state) {
        _isConnected = state == flutter_blue.BluetoothConnectionState.connected;
        
        if (state == flutter_blue.BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }

        _connectionStateController.add(_isConnected);
      });

      // Discover services
      List<flutter_blue.BluetoothService> services = await device.discoverServices();
      _processServices(services);

      // Persist paired device ID
      await _prefs?.setString(_pairedDeviceKey, device.id.id);
      return true;
    } catch (e) {
      debugPrint('Error connecting to ESP32 Smart Band: $e');
      _handleDisconnect();
      return false;
    }
  }

  // Disconnect from device
  Future<void> disconnectFromDevice() async {
    if (_connectedDevice == null) return;

    _cancelCharacteristicSubscriptions();
    _deviceStateSubscription?.cancel();

    try {
      await _connectedDevice!.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }

    _handleDisconnect();
  }

  // Handle disconnect event
  void _handleDisconnect() {
    _connectedDevice = null;
    _isConnected = false;
    _heartRate = 0;
    _spo2 = 0;
    _temperature = 0.0;
    _batteryLevel = 0;

    // Attempt auto-reconnect in background if we have a saved device
    final savedId = _prefs?.getString(_pairedDeviceKey);
    if (savedId != null) {
      _attemptReconnect(savedId);
    }

    _heartRateController.add(0);
    _spo2Controller.add(0);
    _temperatureController.add(0.0);
    _batteryController.add(0);
    _connectionStateController.add(false);
  }

  // Try to reconnect to a previously paired device
  Future<void> _attemptReconnect(String deviceId) async {
    // First, check already connected devices
    final connected = await flutter_blue.FlutterBluePlus.connectedSystemDevices;
    for (final d in connected) {
      if (d.id.id == deviceId) {
        await connectToDevice(d);
        return;
      }
    }

    // If not connected, scan briefly for the specific device
    if (_isScanning) return;
    _isScanning = true;
    _scanSubscription = flutter_blue.FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final d = r.device;
        if (d.id.id == deviceId) {
          stopScan();
          connectToDevice(d);
          break;
        }
      }
    });
    await flutter_blue.FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  // Cancel characteristic subscriptions
  void _cancelCharacteristicSubscriptions() {
    for (var subscription in _characteristicSubscriptions ?? []) {
      subscription.cancel();
    }
    _characteristicSubscriptions = [];
  }

  // Process discovered services for ESP32 MAX30102
  void _processServices(List<flutter_blue.BluetoothService> services) {
    _cancelCharacteristicSubscriptions();

    for (var service in services) {
      debugPrint('Found service: ${service.uuid}');

      // ESP32 MAX30102 custom service
      if (service.uuid.toString().toLowerCase() == _esp32ServiceUuid.toLowerCase()) {
        for (var characteristic in service.characteristics) {
          debugPrint('Found characteristic: ${characteristic.uuid}');

          // Heart Rate characteristic
          if (characteristic.uuid.toString().toLowerCase() == _heartRateCharUuid.toLowerCase()) {
            final subscription = characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                _heartRate = _parseHeartRate(Uint8List.fromList(value));
                _heartRateController.add(_heartRate);
                _updateLastUpdate();
                _broadcastDataUpdate();
              }
            });

            characteristic.setNotifyValue(true);
            _characteristicSubscriptions?.add(subscription);
          }

          // SpO2 characteristic
          if (characteristic.uuid.toString().toLowerCase() == _spo2CharUuid.toLowerCase()) {
            final subscription = characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                _spo2 = _parseSpO2(Uint8List.fromList(value));
                _spo2Controller.add(_spo2);
                _updateLastUpdate();
                _broadcastDataUpdate();
              }
            });

            characteristic.setNotifyValue(true);
            _characteristicSubscriptions?.add(subscription);
          }

          // Temperature characteristic
          if (characteristic.uuid.toString().toLowerCase() == _temperatureCharUuid.toLowerCase()) {
            final subscription = characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                _temperature = _parseTemperature(Uint8List.fromList(value));
                _temperatureController.add(_temperature);
                _updateLastUpdate();
                _broadcastDataUpdate();
              }
            });

            characteristic.setNotifyValue(true);
            _characteristicSubscriptions?.add(subscription);
          }

          // Battery characteristic
          if (characteristic.uuid.toString().toLowerCase() == _batteryCharUuid.toLowerCase()) {
            final subscription = characteristic.value.listen((value) {
              if (value.isNotEmpty) {
                _batteryLevel = _parseBatteryLevel(Uint8List.fromList(value));
                _batteryController.add(_batteryLevel);
                _updateLastUpdate();
                _broadcastDataUpdate();
              }
            });

            characteristic.setNotifyValue(true);
            _characteristicSubscriptions?.add(subscription);
          }
        }
      }
    }
  }

  // Parse heart rate from ESP32 data
  int _parseHeartRate(Uint8List data) {
    if (data.length >= 2) {
      return data[0] | (data[1] << 8); // 16-bit heart rate
    }
    return data.isNotEmpty ? data[0] : 0;
  }

  // Parse SpO2 from ESP32 data
  int _parseSpO2(Uint8List data) {
    return data.isNotEmpty ? data[0] : 0; // SpO2 percentage
  }

  // Parse temperature from ESP32 data
  double _parseTemperature(Uint8List data) {
    if (data.length >= 4) {
      // Convert 4 bytes to float (ESP32 sends float)
      final buffer = ByteData(4);
      buffer.setUint8(0, data[0]);
      buffer.setUint8(1, data[1]);
      buffer.setUint8(2, data[2]);
      buffer.setUint8(3, data[3]);
      return buffer.getFloat32(0, Endian.little);
    }
    return 0.0;
  }

  // Parse battery level from ESP32 data
  int _parseBatteryLevel(Uint8List data) {
    return data.isNotEmpty ? data[0] : 0; // Battery percentage
  }

  // Update last update timestamp
  void _updateLastUpdate() {
    _lastUpdate = DateTime.now();
  }

  // Broadcast all data updates
  void _broadcastDataUpdate() {
    _dataUpdateController.add({
      'heartRate': _heartRate,
      'spo2': _spo2,
      'temperature': _temperature,
      'batteryLevel': _batteryLevel,
      'timestamp': _lastUpdate.toIso8601String(),
      'isConnected': _isConnected,
    });
  }

  // Get current vital signs as a map
  Map<String, dynamic> getCurrentVitals() {
    return {
      'heartRate': _heartRate,
      'spo2': _spo2,
      'temperature': _temperature,
      'batteryLevel': _batteryLevel,
      'lastUpdate': _lastUpdate.toIso8601String(),
      'isConnected': _isConnected,
    };
  }

  // Manually clear the saved paired device
  Future<void> unpairDevice() async {
    await disconnectFromDevice();
    await _prefs?.remove(_pairedDeviceKey);
  }

  // Dispose resources
  void dispose() {
    _scanSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _cancelCharacteristicSubscriptions();

    _heartRateController.close();
    _spo2Controller.close();
    _temperatureController.close();
    _batteryController.close();
    _connectionStateController.close();
    _dataUpdateController.close();
  }
} 