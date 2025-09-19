import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async' show unawaited;

class FirebaseService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collections
  static const String usersCollection = 'users';
  static const String healthDataCollection = 'health_data';
  static const String medicationsCollection = 'medications';
  static const String appointmentsCollection = 'appointments';
  static const String remindersCollection = 'reminders';
  static const String symptomsCollection = 'symptoms';
  static const String hospitalsCollection = 'hospitals';
  static const String pharmaciesCollection = 'pharmacies';
  static const String wearableDataCollection = 'wearable_data';
  static const String emergencyContactsCollection = 'emergency_contacts';

  // Create Firestore indexes to prevent preconditions errors
  Future<void> createFirestoreIndexes() async {
    try {
      // Create indexes for medications collection
      await _firestore.collection(medicationsCollection).doc('indexes').set({
        'userId_index': true,
        'userId_isActive_index': true,
        'createdAt_index': true,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Create indexes for reminders collection
      await _firestore.collection(remindersCollection).doc('indexes').set({
        'userId_index': true,
        'userId_isActive_index': true,
        'dateTime_index': true,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Create indexes for symptoms collection
      await _firestore.collection(symptomsCollection).doc('indexes').set({
        'userId_timestamp_index': true,
        'userId_index': true,
        'timestamp_index': true,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Create indexes for emergency contacts collection
      await _firestore.collection(emergencyContactsCollection).doc('indexes').set({
        'userId_isPrimary_index': true,
        'userId_index': true,
        'isPrimary_index': true,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Create indexes for health habits collection
      await _firestore.collection('health_habits').doc('indexes').set({
        'userId_date_index': true,
        'userId_habitType_index': true,
        'userId_index': true,
        'date_index': true,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Create indexes for reports collection
      await _firestore.collection('reports').doc('indexes').set({
        'userId_timestamp_index': true,
        'userId_index': true,
        'timestamp_index': true,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Firestore indexes created successfully');
    } catch (e) {
      debugPrint('⚠️ Error creating Firestore indexes: $e');
      // Don't throw here, as this is not critical for app functionality
    }
  }

  // Initialize Firestore collections
  Future<void> initializeCollections() async {
    try {
      // Create Firestore indexes first
      await createFirestoreIndexes();
      
      // Create a dummy document in each collection to ensure they exist
      final collections = [
        medicationsCollection,
        remindersCollection,
        appointmentsCollection,
        symptomsCollection,
        healthDataCollection,
        'reports',
        'health_habits',
        emergencyContactsCollection,
      ];

      for (final collection in collections) {
        try {
          await _firestore.collection(collection).doc('init').set({
            'initialized': true,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('✅ Initialized collection: $collection');
        } catch (e) {
          debugPrint('⚠️ Error initializing collection $collection: $e');
        }
      }
    } catch (e) {
      debugPrint('Error initializing collections: $e');
    }
  }

  // Test Firebase connectivity and indexes
  Future<void> testFirebaseConnectivity() async {
    try {
      debugPrint('🔍 Testing Firebase connectivity...');
      
      final user = currentUser;
      if (user == null) {
        debugPrint('⚠️ No user logged in for connectivity test');
        return;
      }

      // Test basic connectivity
      await _firestore.collection('users').doc(user.uid).get();
      debugPrint('✅ Basic Firebase connectivity: OK');

      // Test symptom history query (with fallback)
      try {
        await getSymptomHistory(user.uid);
        debugPrint('✅ Symptom history query: OK');
      } catch (e) {
        debugPrint('⚠️ Symptom history query failed: $e');
      }

      // Test health habits query (with fallback)
      try {
        await getHealthHabits(user.uid);
        debugPrint('✅ Health habits query: OK');
      } catch (e) {
        debugPrint('⚠️ Health habits query failed: $e');
      }

      debugPrint('🎉 Firebase connectivity test completed');
    } catch (e) {
      debugPrint('❌ Firebase connectivity test failed: $e');
    }
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // User Profile Management
  Future<void> createUserProfile(String userId, Map<String, dynamic> userData) async {
    await _firestore.collection(usersCollection).doc(userId).set({
      'profile': {
        'name': userData['name'] ?? '',
        'email': userData['email'] ?? '',
        'phone': userData['phone'] ?? '',
        'dateOfBirth': userData['dateOfBirth'],
        'gender': userData['gender'] ?? '',
        'bloodType': userData['bloodType'] ?? '',
        'height': userData['height'],
        'weight': userData['weight'],
        'photo': userData['photo'] ?? '',
        'emergencyContact': userData['emergencyContact'] ?? '',
        'allergies': userData['allergies'] ?? [],
        'medicalConditions': userData['medicalConditions'] ?? [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      'preferences': {
        'notifications': true,
        'locationServices': true,
        'dataSharing': false,
        'theme': 'system',
        'language': 'en',
      },
      'subscription': {
        'plan': 'free',
        'expiresAt': null,
        'features': ['basic_health_tracking', 'medication_reminders'],
      }
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection(usersCollection).doc(userId).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> updates) async {
    final Map<String, dynamic> data = {};
    
    // Update profile fields
    if (updates.containsKey('profile')) {
      data['profile'] = updates['profile'];
      data['profile.updatedAt'] = FieldValue.serverTimestamp();
    }
    
    // Update preferences
    if (updates.containsKey('preferences')) {
      data['preferences'] = updates['preferences'];
    }
    
    await _firestore.collection(usersCollection).doc(userId).update(data);
    notifyListeners();
  }

  // Health Data Management
  // New: Latest vitals document per user at collection `health_data` with fields
  // heart_rate (int), spo2 (int), blood_pressure (string "SYS/DIA"), timestamp (server)
  Future<void> setLatestVitals({
    required String userId,
    required int? heartRate,
    required int? spo2,
    required String? bloodPressure,
    String source = 'wearable',
  }) async {
    try {
      await _firestore.collection(healthDataCollection).doc(userId).set({
        'userId': userId,
        'heart_rate': heartRate,
        'spo2': spo2,
        'blood_pressure': bloodPressure,
        'timestamp': FieldValue.serverTimestamp(),
        'source': source,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error writing latest vitals: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getLatestVitalsOnce(String userId) async {
    try {
      final doc = await _firestore.collection(healthDataCollection).doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error fetching latest vitals: $e');
      return null;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getLatestVitalsStream(String userId) {
    return _firestore.collection(healthDataCollection).doc(userId).snapshots();
  }

  Future<void> addHealthData(String userId, Map<String, dynamic> healthData) async {
    await _firestore.collection(healthDataCollection).add({
      'userId': userId,
      'type': healthData['type'], // 'blood_pressure', 'heart_rate', 'temperature', etc.
      'value': healthData['value'],
      'unit': healthData['unit'],
      'timestamp': healthData['timestamp'] ?? FieldValue.serverTimestamp(),
      'source': healthData['source'] ?? 'manual', // 'manual', 'wearable', 'doctor'
      'notes': healthData['notes'] ?? '',
    });
  }

  Stream<QuerySnapshot> getHealthDataStream(String userId, {String? type}) {
    Query query = _firestore
        .collection(healthDataCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true);
    
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    
    return query.snapshots();
  }

  // Medication Management
  Future<void> addMedication(String userId, Map<String, dynamic> medication) async {
    await _firestore.collection(medicationsCollection).add({
      'userId': userId,
      'name': medication['name'],
      'dosage': medication['dosage'],
      'frequency': medication['frequency'],
      'startDate': medication['startDate'],
      'endDate': medication['endDate'],
      'instructions': medication['instructions'] ?? '',
      'prescribedBy': medication['prescribedBy'] ?? '',
      'pharmacy': medication['pharmacy'] ?? '',
      'isActive': medication['isActive'] ?? true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMedicationsStream(String userId) {
    try {
      return _firestore
          .collection(medicationsCollection)
          .where('userId', isEqualTo: userId)
          .snapshots();
    } catch (e) {
      debugPrint('Error in getMedicationsStream: $e');
      return Stream.empty();
    }
  }

  // Alternative method for getting medications without ordering
  Stream<QuerySnapshot> getMedicationsStreamSimple(String userId) {
    try {
      return _firestore
          .collection(medicationsCollection)
          .where('userId', isEqualTo: userId)
          .snapshots();
    } catch (e) {
      debugPrint('Error in getMedicationsStreamSimple: $e');
      return Stream.empty();
    }
  }

  // Get medications without any filters (most basic method)
  Stream<QuerySnapshot> getMedicationsStreamBasic(String userId) {
    try {
      return _firestore
          .collection(medicationsCollection)
          .snapshots();
    } catch (e) {
      debugPrint('Error in getMedicationsStreamBasic: $e');
      return Stream.empty();
    }
  }

  Future<void> updateMedication(String medicationId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection(medicationsCollection).doc(medicationId).update(updates);
  }

  Future<void> deleteMedication(String medicationId) async {
    await _firestore.collection(medicationsCollection).doc(medicationId).delete();
  }

  // Appointment Management
  Future<void> addAppointment(String userId, Map<String, dynamic> appointment) async {
    await _firestore.collection(appointmentsCollection).add({
      'userId': userId,
      'title': appointment['title'],
      'description': appointment['description'] ?? '',
      'dateTime': appointment['dateTime'],
      'duration': appointment['duration'] ?? 60, // minutes
      'location': appointment['location'] ?? '',
      'doctor': appointment['doctor'] ?? '',
      'type': appointment['type'] ?? 'general', // 'general', 'specialist', 'emergency'
      'status': appointment['status'] ?? 'scheduled', // 'scheduled', 'confirmed', 'completed', 'cancelled'
      'reminderTime': appointment['reminderTime'], // minutes before appointment
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getAppointmentsStream(String userId) {
    return _firestore
        .collection(appointmentsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('dateTime', descending: false)
        .snapshots();
  }

  // Reminder Management
  Future<void> addReminder(String userId, Map<String, dynamic> reminder) async {
    await _firestore.collection(remindersCollection).add({
      'userId': userId,
      'title': reminder['title'],
      'description': reminder['description'] ?? '',
      'type': reminder['type'], // 'medication', 'appointment', 'exercise', 'custom'
      'dateTime': reminder['dateTime'],
      'frequency': reminder['frequency'] ?? 'once', // 'once', 'daily', 'weekly', 'monthly'
      'isActive': reminder['isActive'] ?? true,
      'relatedId': reminder['relatedId'], // ID of related medication/appointment
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getRemindersStream(String userId) {
    try {
      return _firestore
          .collection(remindersCollection)
          .where('userId', isEqualTo: userId)
          .snapshots();
    } catch (e) {
      debugPrint('Error in getRemindersStream: $e');
      return Stream.empty();
    }
  }

  // Get reminders without any filters (fallback method)
  Stream<QuerySnapshot> getRemindersStreamBasic(String userId) {
    try {
      return _firestore
          .collection(remindersCollection)
          .snapshots();
    } catch (e) {
      debugPrint('Error in getRemindersStreamBasic: $e');
      return Stream.empty();
    }
  }

  Future<void> updateReminder(String reminderId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection(remindersCollection).doc(reminderId).update(updates);
  }

  Future<void> deleteReminder(String reminderId) async {
    await _firestore.collection(remindersCollection).doc(reminderId).delete();
  }

  Future<void> toggleReminderStatus(String reminderId, bool isActive) async {
    await _firestore.collection(remindersCollection).doc(reminderId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Symptom Tracking
  Future<void> addSymptom(String userId, Map<String, dynamic> symptom) async {
    await _firestore.collection(symptomsCollection).add({
      'userId': userId,
      'name': symptom['name'],
      'severity': symptom['severity'], // 1-10 scale
      'description': symptom['description'] ?? '',
      'location': symptom['location'] ?? '',
      'duration': symptom['duration'] ?? '',
      'triggers': symptom['triggers'] ?? [],
      'reliefMethods': symptom['reliefMethods'] ?? [],
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getSymptomsStream(String userId) {
    return _firestore
        .collection(symptomsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Emergency Contacts
  Future<void> addEmergencyContact(String userId, Map<String, dynamic> contact) async {
    await _firestore.collection(emergencyContactsCollection).add({
      'userId': userId,
      'name': contact['name'],
      'relationship': contact['relationship'] ?? '',
      'phone': contact['phone'],
      'email': contact['email'] ?? '',
      'isPrimary': contact['isPrimary'] ?? false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getEmergencyContactsStream(String userId) {
    try {
      return _firestore
          .collection(emergencyContactsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('isPrimary', descending: true)
          .snapshots();
    } catch (e) {
      debugPrint('Error creating emergency contacts stream: $e');
      // Fallback: Simple query without ordering
      try {
        return _firestore
            .collection(emergencyContactsCollection)
            .where('userId', isEqualTo: userId)
            .snapshots();
      } catch (fallbackError) {
        debugPrint('Fallback emergency contacts stream also failed: $fallbackError');
        return Stream.empty();
      }
    }
  }

  Future<void> updateEmergencyContact(String contactId, Map<String, dynamic> updates) async {
    await _firestore.collection(emergencyContactsCollection).doc(contactId).update(updates);
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    await _firestore.collection(emergencyContactsCollection).doc(contactId).delete();
  }

  // SOS Events
  Future<void> addSosEvent(String userId, Map<String, dynamic> sosData) async {
    await _firestore.collection('sos_events').add({
      'userId': userId,
      'type': sosData['type'], // 'manual', 'auto'
      'triggeredAt': FieldValue.serverTimestamp(),
      'location': sosData['location'], // GeoPoint
      'vitals': sosData['vitals'] ?? {}, // heart_rate, spo2, etc.
      'emergencyContacts': sosData['emergencyContacts'] ?? [],
      'status': sosData['status'] ?? 'triggered', // 'triggered', 'cancelled', 'dispatched'
      'cancelledAt': sosData['cancelledAt'],
      'dispatchedAt': sosData['dispatchedAt'],
      'notes': sosData['notes'] ?? '',
    });
  }

  Stream<QuerySnapshot> getSosEventsStream(String userId) {
    return _firestore
        .collection('sos_events')
        .where('userId', isEqualTo: userId)
        .orderBy('triggeredAt', descending: true)
        .snapshots();
  }

  Future<void> updateSosEvent(String eventId, Map<String, dynamic> updates) async {
    await _firestore.collection('sos_events').doc(eventId).update(updates);
  }

  // User SOS Settings
  Future<void> saveSosSettings(String userId, Map<String, dynamic> settings) async {
    await _firestore.collection(usersCollection).doc(userId).update({
      'sosSettings': {
        'autoSosEnabled': settings['autoSosEnabled'] ?? false,
        'heartRateThreshold': settings['heartRateThreshold'] ?? 100,
        'spo2Threshold': settings['spo2Threshold'] ?? 95,
        'abnormalDurationSeconds': settings['abnormalDurationSeconds'] ?? 30,
        'primaryEmergencyContact': settings['primaryEmergencyContact'],
        'emergencyNumber': settings['emergencyNumber'] ?? '112',
        'locationSharing': settings['locationSharing'] ?? true,
        'updatedAt': FieldValue.serverTimestamp(),
      }
    });
  }

  Future<Map<String, dynamic>?> getSosSettings(String userId) async {
    try {
      final doc = await _firestore.collection(usersCollection).doc(userId).get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('sosSettings')) {
        final settings = doc.data()!['sosSettings'];
        if (settings is Map<String, dynamic>) {
          return settings;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting SOS settings: $e');
      return null;
    }
  }

  // Wearable Data
  Future<void> addWearableData(String userId, Map<String, dynamic> data) async {
    await _firestore.collection(wearableDataCollection).add({
      'userId': userId,
      'deviceId': data['deviceId'],
      'deviceType': data['deviceType'], // 'smartwatch', 'fitness_tracker', 'heart_monitor'
      'dataType': data['dataType'], // 'heart_rate', 'steps', 'sleep', 'blood_oxygen'
      'value': data['value'],
      'unit': data['unit'],
      'timestamp': FieldValue.serverTimestamp(),
      'batteryLevel': data['batteryLevel'],
      'isConnected': data['isConnected'] ?? true,
    });
  }

  Stream<QuerySnapshot> getWearableDataStream(String userId, {String? dataType}) {
    Query query = _firestore
        .collection(wearableDataCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true);
    
    if (dataType != null) {
      query = query.where('dataType', isEqualTo: dataType);
    }
    
    return query.snapshots();
  }

  // Hospital and Pharmacy Data (for nearby search)
  Future<void> addHospital(Map<String, dynamic> hospital) async {
    await _firestore.collection(hospitalsCollection).add({
      'name': hospital['name'],
      'address': hospital['address'],
      'phone': hospital['phone'] ?? '',
      'website': hospital['website'] ?? '',
      'specialties': hospital['specialties'] ?? [],
      'rating': hospital['rating'] ?? 0.0,
      'location': GeoPoint(hospital['latitude'], hospital['longitude']),
      'isOpen24Hours': hospital['isOpen24Hours'] ?? false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addPharmacy(Map<String, dynamic> pharmacy) async {
    await _firestore.collection(pharmaciesCollection).add({
      'name': pharmacy['name'],
      'address': pharmacy['address'],
      'phone': pharmacy['phone'] ?? '',
      'website': pharmacy['website'] ?? '',
      'services': pharmacy['services'] ?? [],
      'rating': pharmacy['rating'] ?? 0.0,
      'location': GeoPoint(pharmacy['latitude'], pharmacy['longitude']),
      'isOpen24Hours': pharmacy['isOpen24Hours'] ?? false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Search nearby hospitals/pharmacies
  Future<QuerySnapshot> searchNearbyHospitals(double latitude, double longitude, double radiusKm) async {
    // Note: This is a simplified search. For production, consider using Firebase GeoFirestore
    return await _firestore
        .collection(hospitalsCollection)
        .get();
  }

  Future<QuerySnapshot> searchNearbyPharmacies(double latitude, double longitude, double radiusKm) async {
    return await _firestore
        .collection(pharmaciesCollection)
        .get();
  }

  // Analytics and Reports
  Future<Map<String, dynamic>> getUserHealthSummary(String userId) async {
    // Get health data for the last 30 days
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    final healthData = await _firestore
        .collection(healthDataCollection)
        .where('userId', isEqualTo: userId)
        .where('timestamp', isGreaterThan: thirtyDaysAgo)
        .get();

    final medications = await _firestore
        .collection(medicationsCollection)
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    final appointments = await _firestore
        .collection(appointmentsCollection)
        .where('userId', isEqualTo: userId)
        .where('dateTime', isGreaterThan: DateTime.now())
        .get();

    return {
      'healthDataCount': healthData.docs.length,
      'activeMedications': medications.docs.length,
      'upcomingAppointments': appointments.docs.length,
      'lastHealthCheck': healthData.docs.isNotEmpty ? healthData.docs.first.data()['timestamp'] : null,
    };
  }

  // Data Export
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    final userProfile = await getUserProfile(userId);
    final healthData = await _firestore
        .collection(healthDataCollection)
        .where('userId', isEqualTo: userId)
        .get();
    final medications = await _firestore
        .collection(medicationsCollection)
        .where('userId', isEqualTo: userId)
        .get();
    final appointments = await _firestore
        .collection(appointmentsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    return {
      'profile': userProfile,
      'healthData': healthData.docs.map((doc) => doc.data()).toList(),
      'medications': medications.docs.map((doc) => doc.data()).toList(),
      'appointments': appointments.docs.map((doc) => doc.data()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  // Cleanup and maintenance
  Future<void> deleteUserData(String userId) async {
    // Delete all user data (for GDPR compliance)
    final collections = [
      healthDataCollection,
      medicationsCollection,
      appointmentsCollection,
      remindersCollection,
      symptomsCollection,
      wearableDataCollection,
      emergencyContactsCollection,
    ];

    for (String collection in collections) {
      final docs = await _firestore
          .collection(collection)
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var doc in docs.docs) {
        await doc.reference.delete();
      }
    }

    // Delete user profile
    await _firestore.collection(usersCollection).doc(userId).delete();
  }

  // Drug management
  Future<void> addDrug(String name, String dosage, String frequency, String time) async {
    if (currentUser == null) return;
    
    await _firestore.collection('users').doc(currentUser!.uid).collection('drugs').add({
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'time': time,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getDrugs() async {
    if (currentUser == null) return [];
    
    final snapshot = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('drugs')
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => {
      'id': doc.id,
      ...doc.data(),
    }).toList();
  }

  Future<void> deleteDrug(String drugId) async {
    if (currentUser == null) return;
    
    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('drugs')
        .doc(drugId)
        .delete();
  }

  // Symptom record management (for AI analysis)
  Future<void> saveSymptomRecord(String userId, Map<String, dynamic> recordData) async {
    await _firestore.collection(symptomsCollection).add({
      ...recordData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getSymptomHistory(String userId) async {
    print('🔍 Retrieving symptom history for user: $userId');
    
    try {
      // First try the optimized query with composite index
      final query = _firestore
          .collection(symptomsCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50);
      
      try {
        // Try cache first for instant UI
        try {
          final cacheSnap = await query.get(const GetOptions(source: Source.cache));
          print('📦 Cache query results: ${cacheSnap.docs.length} documents');
          
          if (cacheSnap.docs.isNotEmpty) {
            // Refresh cache in background
            unawaited(query.get());
            final cacheResults = cacheSnap.docs.map((doc) => {
              'id': doc.id,
              ...doc.data(),
            }).toList();
            
            print('✅ Returning ${cacheResults.length} records from cache');
            return cacheResults;
          }
        } catch (cacheError) {
          print('❌ Cache query error: $cacheError');
        }
        
        // Fallback to server
        print('🌐 Fetching symptom history from server');
        final snapshot = await query.get();
        
        print('📊 Server query results: ${snapshot.docs.length} documents');
        
        final results = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        
        if (results.isEmpty) {
          print('⚠️ No symptom records found for user');
        }
        
        return results;
      } catch (indexError) {
        print('❌ Index error, trying fallback query: $indexError');
        
        // Fallback: Simple query without ordering (no composite index needed)
        final fallbackQuery = _firestore
            .collection(symptomsCollection)
            .where('userId', isEqualTo: userId)
            .limit(50);
        
        final fallbackSnapshot = await fallbackQuery.get();
        print('📊 Fallback query results: ${fallbackSnapshot.docs.length} documents');
        
        final fallbackResults = fallbackSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        
        // Sort manually by timestamp
        fallbackResults.sort((a, b) {
          final aTime = a['timestamp'] as Timestamp?;
          final bTime = b['timestamp'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        
        print('✅ Returning ${fallbackResults.length} records from fallback query');
        return fallbackResults;
      }
    } catch (e) {
      print('❌ Comprehensive error retrieving symptom history: $e');
      
      // Additional error context
      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          print('⚠️ User document does not exist');
        }
      } catch (userDocError) {
        print('❌ Error checking user document: $userDocError');
      }
      
      return []; // Return empty list on error
    }
  }

  // Save report analysis record
  Future<void> saveReportRecord(String userId, Map<String, dynamic> recordData) async {
    try {
      print('💾 Saving report record for user: $userId');
      await _firestore.collection('reports').add(recordData);
      print('✅ Report record saved successfully');
    } catch (e) {
      print('❌ Error saving report record: $e');
      rethrow;
    }
  }

  // Get report analysis history
  Future<List<Map<String, dynamic>>> getReportHistory(String userId) async {
    try {
      print('🔍 Retrieving report history for user: $userId');
      
      final query = _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50);
      
      final snapshot = await query.get();
      
      print('📊 Retrieved ${snapshot.docs.length} report records');
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      print('❌ Error retrieving report history: $e');
      return [];
    }
  }

  // Get health habits with fallback
  Future<List<Map<String, dynamic>>> getHealthHabits(String userId) async {
    try {
      print('🔍 Retrieving health habits for user: $userId');
      
      // Try optimized query first
      final query = _firestore
          .collection('health_habits')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .limit(100);
      
      try {
        final snapshot = await query.get();
        print('📊 Retrieved ${snapshot.docs.length} health habit records');
        
        return snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
      } catch (indexError) {
        print('❌ Index error, trying fallback query: $indexError');
        
        // Fallback: Simple query without ordering
        final fallbackQuery = _firestore
            .collection('health_habits')
            .where('userId', isEqualTo: userId)
            .limit(100);
        
        final fallbackSnapshot = await fallbackQuery.get();
        print('📊 Fallback query results: ${fallbackSnapshot.docs.length} documents');
        
        final fallbackResults = fallbackSnapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
        
        // Sort manually by date
        fallbackResults.sort((a, b) {
          final aDate = a['date'] as Timestamp?;
          final bDate = b['date'] as Timestamp?;
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
        
        return fallbackResults;
      }
    } catch (e) {
      print('❌ Error retrieving health habits: $e');
      return [];
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
} 