import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Initialize database with required collections
  Future<void> initializeDatabase() async {
    try {
      debugPrint('🔄 Initializing database structure...');
      
      // Create users collection if it doesn't exist (no-op if it exists)
      await _safeFirestoreOperation(() async {
        await _firestore.collection('users').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'users collection');

      // Create other necessary collections
      await _safeFirestoreOperation(() async {
        await _firestore.collection('medical_records').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'medical_records collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('medications').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'medications collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('appointments').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'appointments collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('symptoms').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'symptoms collection');
      
      // Initialize new collections for elderly features
      await _safeFirestoreOperation(() async {
        await _firestore.collection('community_posts').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'community_posts collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('health_habits').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'health_habits collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('habit_badges').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'habit_badges collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('sleep_fall_detection').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'sleep_fall_detection collection');
      

      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('community_comments').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'community_comments collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('direct_messages').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'direct_messages collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('chat_conversations').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'chat_conversations collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('user_profiles').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'user_profiles collection');
      
      await _safeFirestoreOperation(() async {
        await _firestore.collection('reported_content').doc('init').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }, 'reported_content collection');
      
      debugPrint('✅ Database initialized successfully');
    } catch (e) {
      debugPrint('⚠️ Error initializing database: $e');
      // Don't rethrow - allow app to continue even with database issues
    }
  }

  // Helper method to safely perform Firestore operations
  Future<void> _safeFirestoreOperation(Future<void> Function() operation, String operationName) async {
    try {
      await operation();
      debugPrint('✅ Successfully initialized $operationName');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('⚠️ Permission denied for $operationName: ${e.message}');
      } else if (e.code == 'unavailable') {
        debugPrint('⚠️ Firestore is unavailable for $operationName: ${e.message}');
      } else {
        debugPrint('⚠️ Firebase error for $operationName: ${e.code} - ${e.message}');
      }
      // Don't rethrow - allow app to continue even with database issues
    } catch (e) {
      debugPrint('⚠️ Error initializing $operationName: $e');
      // Don't rethrow - allow app to continue even with database issues
    }
  }

  // Helper: flatten profile map so each key becomes 'profile.<field>' for deep merge
  Map<String, dynamic> _flattenProfileData(Map<String, dynamic> data) {
    final Map<String, dynamic> flattened = {};
    data.forEach((key, value) {
      if (value != null) {
        flattened['profile.$key'] = value;
      }
    });
    return flattened;
  }

  // Create or update a user profile
  Future<void> createUserProfile(String userId, Map<String, dynamic> userData) async {
    try {
      debugPrint('🔄 Creating/updating user profile for $userId');

      // Ensure timestamps
      userData['updatedAt'] = FieldValue.serverTimestamp();
      userData['createdAt'] ??= FieldValue.serverTimestamp();

      // If lastLogin supplied, keep it
      if (userData['lastLogin'] != null) {
        userData['lastLogin'] = userData['lastLogin'];
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .set(_flattenProfileData(userData), SetOptions(merge: true));

      debugPrint('✅ User profile created/updated successfully');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('⚠️ Permission denied when creating user profile: ${e.message}');
      } else {
        debugPrint('⚠️ Firebase error creating user profile: ${e.code} - ${e.message}');
        rethrow;
      }
    } catch (e) {
      debugPrint('⚠️ Error creating user profile: $e');
      rethrow;
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      debugPrint('🔄 Getting user profile for $userId');
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      
      if (doc.exists && doc.data() != null) {
        debugPrint('✅ User profile found');
        return doc.data() as Map<String, dynamic>;
      } else {
        debugPrint('⚠️ User profile not found');
        return null;
      }
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('⚠️ Permission denied when fetching user profile: ${e.message}');
        // Return null instead of crashing
        return null;
      } else {
        debugPrint('⚠️ Firebase error fetching user profile: ${e.code} - ${e.message}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching user profile: $e');
      return null;
    }
  }

  // Update specific user profile fields
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      debugPrint('🔄 Updating user profile for $userId');
      final Map<String, dynamic> updateData = _flattenProfileData(data);
      updateData['profile.updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(userId).set(updateData, SetOptions(merge: true));

      debugPrint('✅ User profile updated successfully');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('⚠️ Permission denied when updating user profile: ${e.message}');
      } else {
        debugPrint('⚠️ Firebase error updating user profile: ${e.code} - ${e.message}');
        rethrow;
      }
    } catch (e) {
      debugPrint('⚠️ Error updating user profile: $e');
      rethrow;
    }
  }

  // Add a medical record for a user
  Future<void> addMedicalRecord(String userId, Map<String, dynamic> recordData) async {
    try {
      debugPrint('🔄 Adding medical record for $userId');
      await _firestore.collection('medical_records').add({
        'userId': userId,
        'diagnosis': recordData['diagnosis'],
        'doctor': recordData['doctor'],
        'hospital': recordData['hospital'],
        'date': recordData['date'],
        'notes': recordData['notes'],
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Medical record added successfully');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('⚠️ Permission denied when adding medical record: ${e.message}');
      } else {
        debugPrint('⚠️ Firebase error adding medical record: ${e.code} - ${e.message}');
        rethrow;
      }
    } catch (e) {
      debugPrint('⚠️ Error adding medical record: $e');
      rethrow;
    }
  }

  // Get current user ID
  String? getCurrentUserId() {
    final user = _auth.currentUser;
    if (user != null) {
      return user.uid;
    } else {
      debugPrint('⚠️ No current user found when getting user ID');
      return null;
    }
  }

  // Add a medication for a user
  Future<String> addMedication(String userId, Map<String, dynamic> medicationData) async {
    try {
      debugPrint('🔄 Adding medication for $userId');
      
      final docRef = await _firestore.collection('medications').add({
        'userId': userId,
        'name': medicationData['name'] ?? '',
        'dosage': medicationData['dosage'] ?? '',
        'frequency': medicationData['frequency'] ?? '',
        'startDate': medicationData['startDate'],
        'endDate': medicationData['endDate'],
        'instructions': medicationData['instructions'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': medicationData['isActive'] ?? true,
      });
      
      debugPrint('✅ Medication added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('⚠️ Error adding medication: $e');
      rethrow;
    }
  }
  
  // Get medications for a user
  Future<List<Map<String, dynamic>>> getMedications(String userId, {bool activeOnly = false}) async {
    try {
      debugPrint('🔄 Getting medications for $userId');
      
      Query query = _firestore.collection('medications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);
          
      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }
      
      final snapshot = await query.get();
      
      final medications = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      debugPrint('✅ Retrieved ${medications.length} medications');
      return medications;
    } catch (e) {
      debugPrint('⚠️ Error getting medications: $e');
      return [];
    }
  }
  
  // Update a medication
  Future<void> updateMedication(String medicationId, Map<String, dynamic> medicationData) async {
    try {
      debugPrint('🔄 Updating medication $medicationId');
      
      await _firestore.collection('medications').doc(medicationId).update({
        ...medicationData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Medication updated successfully');
    } catch (e) {
      debugPrint('⚠️ Error updating medication: $e');
      rethrow;
    }
  }
  
  // Delete a medication
  Future<void> deleteMedication(String medicationId) async {
    try {
      debugPrint('🔄 Deleting medication $medicationId');
      
      await _firestore.collection('medications').doc(medicationId).delete();
      
      debugPrint('✅ Medication deleted successfully');
    } catch (e) {
      debugPrint('⚠️ Error deleting medication: $e');
      rethrow;
    }
  }
  
  // Add an appointment for a user
  Future<String> addAppointment(String userId, Map<String, dynamic> appointmentData) async {
    try {
      debugPrint('🔄 Adding appointment for $userId');
      
      final docRef = await _firestore.collection('appointments').add({
        'userId': userId,
        'title': appointmentData['title'] ?? '',
        'doctorName': appointmentData['doctorName'] ?? '',
        'location': appointmentData['location'] ?? '',
        'date': appointmentData['date'],
        'time': appointmentData['time'],
        'notes': appointmentData['notes'] ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isCompleted': appointmentData['isCompleted'] ?? false,
      });
      
      debugPrint('✅ Appointment added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('⚠️ Error adding appointment: $e');
      rethrow;
    }
  }
  
  // Get appointments for a user
  Future<List<Map<String, dynamic>>> getAppointments(String userId, {bool upcomingOnly = false}) async {
    try {
      debugPrint('🔄 Getting appointments for $userId');
      
      Query query = _firestore.collection('appointments')
          .where('userId', isEqualTo: userId)
          .orderBy('date');
          
      if (upcomingOnly) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()));
      }
      
      final snapshot = await query.get();
      
      final appointments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      debugPrint('✅ Retrieved ${appointments.length} appointments');
      return appointments;
    } catch (e) {
      debugPrint('⚠️ Error getting appointments: $e');
      return [];
    }
  }
  
  // Update an appointment
  Future<void> updateAppointment(String appointmentId, Map<String, dynamic> appointmentData) async {
    try {
      debugPrint('🔄 Updating appointment $appointmentId');
      
      await _firestore.collection('appointments').doc(appointmentId).update({
        ...appointmentData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Appointment updated successfully');
    } catch (e) {
      debugPrint('⚠️ Error updating appointment: $e');
      rethrow;
    }
  }
  
  // Delete an appointment
  Future<void> deleteAppointment(String appointmentId) async {
    try {
      debugPrint('🔄 Deleting appointment $appointmentId');
      
      await _firestore.collection('appointments').doc(appointmentId).delete();
      
      debugPrint('✅ Appointment deleted successfully');
    } catch (e) {
      debugPrint('⚠️ Error deleting appointment: $e');
      rethrow;
    }
  }

  // Get medical records for a user
  Future<List<Map<String, dynamic>>> getMedicalRecords(String userId) async {
    try {
      debugPrint('🔄 Getting medical records for $userId');
      
      final snapshot = await _firestore.collection('medical_records')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();
      
      final records = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      debugPrint('✅ Retrieved ${records.length} medical records');
      return records;
    } catch (e) {
      debugPrint('⚠️ Error getting medical records: $e');
      return [];
    }
  }
  
  // Update a medical record
  Future<void> updateMedicalRecord(String recordId, Map<String, dynamic> recordData) async {
    try {
      debugPrint('🔄 Updating medical record $recordId');
      
      await _firestore.collection('medical_records').doc(recordId).update({
        ...recordData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Medical record updated successfully');
    } catch (e) {
      debugPrint('⚠️ Error updating medical record: $e');
      rethrow;
    }
  }
  
  // Delete a medical record
  Future<void> deleteMedicalRecord(String recordId) async {
    try {
      debugPrint('🔄 Deleting medical record $recordId');
      
      await _firestore.collection('medical_records').doc(recordId).delete();
      
      debugPrint('✅ Medical record deleted successfully');
    } catch (e) {
      debugPrint('⚠️ Error deleting medical record: $e');
      rethrow;
    }
  }
  
  // Save user location (for emergency/SOS features)
  Future<void> saveUserLocation(String userId, double latitude, double longitude) async {
    try {
      debugPrint('🔄 Saving location for user $userId');
      
      await _firestore.collection('users').doc(userId).set({
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
      
      debugPrint('✅ User location saved successfully');
    } catch (e) {
      debugPrint('⚠️ Error saving user location: $e');
      rethrow;
    }
  }

  // Add a connected wearable device
  Future<String> addWearableDevice(String userId, Map<String, dynamic> deviceData) async {
    try {
      debugPrint('🔄 Adding wearable device for $userId');
      
      final docRef = await _firestore.collection('wearable_devices').add({
        'userId': userId,
        'deviceId': deviceData['deviceId'] ?? '',
        'deviceName': deviceData['deviceName'] ?? '',
        'deviceType': deviceData['deviceType'] ?? 'smartwatch',
        'manufacturer': deviceData['manufacturer'] ?? '',
        'model': deviceData['model'] ?? '',
        'isConnected': deviceData['isConnected'] ?? false,
        'lastConnected': deviceData['lastConnected'] ?? FieldValue.serverTimestamp(),
        'capabilities': deviceData['capabilities'] ?? ['heart_rate', 'spo2'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Wearable device added successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('⚠️ Error adding wearable device: $e');
      rethrow;
    }
  }

  // Get connected wearable devices for a user
  Future<List<Map<String, dynamic>>> getWearableDevices(String userId) async {
    try {
      debugPrint('🔄 Getting wearable devices for $userId');
      
      final snapshot = await _firestore.collection('wearable_devices')
          .where('userId', isEqualTo: userId)
          .orderBy('lastConnected', descending: true)
          .get();
      
      final devices = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      debugPrint('✅ Retrieved ${devices.length} wearable devices');
      return devices;
    } catch (e) {
      debugPrint('⚠️ Error getting wearable devices: $e');
      return [];
    }
  }

  // Update wearable device connection status
  Future<void> updateWearableConnection(String deviceId, bool isConnected) async {
    try {
      debugPrint('🔄 Updating connection status for device $deviceId');
      
      await _firestore.collection('wearable_devices').doc(deviceId).update({
        'isConnected': isConnected,
        'lastConnected': isConnected ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Wearable device connection status updated');
    } catch (e) {
      debugPrint('⚠️ Error updating wearable connection: $e');
      rethrow;
    }
  }

  // Delete a wearable device
  Future<void> deleteWearableDevice(String deviceId) async {
    try {
      debugPrint('🔄 Deleting wearable device $deviceId');
      
      await _firestore.collection('wearable_devices').doc(deviceId).delete();
      
      debugPrint('✅ Wearable device deleted successfully');
    } catch (e) {
      debugPrint('⚠️ Error deleting wearable device: $e');
      rethrow;
    }
  }

  // Save vitals data from wearable device
  Future<String> saveVitalsData(String userId, Map<String, dynamic> vitalsData) async {
    try {
      debugPrint('🔄 Saving vitals data for $userId');
      
      final docRef = await _firestore.collection('vitals_data').add({
        'userId': userId,
        'deviceId': vitalsData['deviceId'] ?? '',
        'heartRate': vitalsData['heartRate'] ?? 0,
        'spo2': vitalsData['spo2'] ?? 0,
        'bloodPressure': vitalsData['bloodPressure'] ?? {},
        'temperature': vitalsData['temperature'] ?? 0.0,
        'steps': vitalsData['steps'] ?? 0,
        'calories': vitalsData['calories'] ?? 0,
        'sleepHours': vitalsData['sleepHours'] ?? 0,
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD format
      });
      
      debugPrint('✅ Vitals data saved successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('⚠️ Error saving vitals data: $e');
      rethrow;
    }
  }

  // Get vitals data for a user (with optional date range)
  Future<List<Map<String, dynamic>>> getVitalsData(String userId, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      debugPrint('🔄 Getting vitals data for $userId');
      
      Query query = _firestore.collection('vitals_data')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit);
      
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final snapshot = await query.get();
      
      final vitalsData = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
      
      debugPrint('✅ Retrieved ${vitalsData.length} vitals records');
      return vitalsData;
    } catch (e) {
      debugPrint('⚠️ Error getting vitals data: $e');
      return [];
    }
  }

  // Get latest vitals data for a user
  Future<Map<String, dynamic>?> getLatestVitals(String userId) async {
    try {
      debugPrint('🔄 Getting latest vitals for $userId');
      
      final snapshot = await _firestore.collection('vitals_data')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data() as Map<String, dynamic>;
        debugPrint('✅ Retrieved latest vitals data');
        return {
          'id': snapshot.docs.first.id,
          ...data,
        };
      }
      
      debugPrint('ℹ️ No vitals data found for user');
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting latest vitals: $e');
      return null;
    }
  }

  // Get vitals summary for a user (daily averages)
  Future<Map<String, dynamic>> getVitalsSummary(String userId, DateTime date) async {
    try {
      debugPrint('🔄 Getting vitals summary for $userId on ${date.toIso8601String()}');
      
      final dateStr = date.toIso8601String().split('T')[0];
      
      final snapshot = await _firestore.collection('vitals_data')
          .where('userId', isEqualTo: userId)
          .where('date', isEqualTo: dateStr)
          .get();
      
      if (snapshot.docs.isEmpty) {
        return {
          'date': dateStr,
          'heartRate': {'avg': 0, 'min': 0, 'max': 0, 'count': 0},
          'spo2': {'avg': 0, 'min': 0, 'max': 0, 'count': 0},
          'steps': 0,
          'calories': 0,
          'sleepHours': 0,
        };
      }
      
      final records = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
      
      // Calculate averages
      final heartRates = records.where((r) => r['heartRate'] != null && r['heartRate'] > 0).map((r) => r['heartRate'] as int).toList();
      final spo2Values = records.where((r) => r['spo2'] != null && r['spo2'] > 0).map((r) => r['spo2'] as int).toList();
      
      final totalSteps = records.fold<int>(0, (sum, r) => sum + ((r['steps'] ?? 0) as int));
      final totalCalories = records.fold<int>(0, (sum, r) => sum + ((r['calories'] ?? 0) as int));
      final totalSleep = records.fold<double>(0, (sum, r) => sum + ((r['sleepHours'] ?? 0.0) as double));
      
      return {
        'date': dateStr,
        'heartRate': {
          'avg': heartRates.isNotEmpty ? heartRates.reduce((a, b) => a + b) ~/ heartRates.length : 0,
          'min': heartRates.isNotEmpty ? heartRates.reduce((a, b) => a < b ? a : b) : 0,
          'max': heartRates.isNotEmpty ? heartRates.reduce((a, b) => a > b ? a : b) : 0,
          'count': heartRates.length,
        },
        'spo2': {
          'avg': spo2Values.isNotEmpty ? spo2Values.reduce((a, b) => a + b) ~/ spo2Values.length : 0,
          'min': spo2Values.isNotEmpty ? spo2Values.reduce((a, b) => a < b ? a : b) : 0,
          'max': spo2Values.isNotEmpty ? spo2Values.reduce((a, b) => a > b ? a : b) : 0,
          'count': spo2Values.length,
        },
        'steps': totalSteps,
        'calories': totalCalories,
        'sleepHours': totalSleep,
      };
    } catch (e) {
      debugPrint('⚠️ Error getting vitals summary: $e');
      return {};
    }
  }
} 