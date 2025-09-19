import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/widgets/glass_container.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> _timelineEvents = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String _selectedMood = '';
  final TextEditingController _moodNoteController = TextEditingController();
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  @override
  void initState() {
    super.initState();
    _loadTimelineEvents();
  }
  
  @override
  void dispose() {
    _moodNoteController.dispose();
    super.dispose();
  }

  // Save timeline data to offline storage
  Future<void> _saveTimelineOffline(List<Map<String, dynamic>> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = events.map((event) => {
        ...event,
        'date': event['date'].millisecondsSinceEpoch,
      }).toList();
      await prefs.setString('timeline_events', jsonEncode(eventsJson));
      await prefs.setInt('timeline_last_sync', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving timeline offline: $e');
    }
  }

  // Load timeline data from offline storage
  Future<List<Map<String, dynamic>>> _loadTimelineOffline() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsString = prefs.getString('timeline_events');
      if (eventsString != null) {
        final eventsList = jsonDecode(eventsString) as List;
        return eventsList.map<Map<String, dynamic>>((event) {
          final eventMap = Map<String, dynamic>.from(event);
          eventMap['date'] = DateTime.fromMillisecondsSinceEpoch(eventMap['date']);
          return eventMap;
        }).toList();
      }
    } catch (e) {
      print('Error loading timeline offline: $e');
    }
    return [];
  }
  
  // Method to add sample data for testing timeline
  Future<void> _addSampleTimelineData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final uid = user.uid;
      final now = DateTime.now();

      print('📝 Adding sample timeline data for testing...');

      // Add sample AI symptom analysis (matching the expected data structure)
      await _firestore.collection('users').doc(uid).collection('symptomRecords').add({
        'name': 'Headache and Fatigue',
        'analysis': {
          'summary': 'AI analysis suggests possible tension headache with fatigue. Recommended rest and hydration.',
          'possible_conditions': ['Tension Headache', 'Dehydration'],
          'severity': 'mild'
        },
        'severity': 'mild',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add sample drug search (matching the expected data structure)
      await _firestore.collection('users').doc(uid).collection('drugs').add({
        'name': 'Ibuprofen',
        'description': 'Non-steroidal anti-inflammatory drug used for pain relief and reducing inflammation',
        'dosage': '200-400mg every 4-6 hours as needed',
        'information': 'Common uses: headache, menstrual pain, arthritis',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add sample chat message (matching the expected data structure)
      await _firestore.collection('direct_messages').add({
        'senderId': uid,
        'message': 'What are the symptoms of dehydration?',
        'response': 'Dehydration symptoms include dry mouth, decreased urination, fatigue, dizziness, and dry skin.',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Sample data added successfully!');
      await Future.delayed(const Duration(seconds: 2)); // Wait for Firestore to sync
      _loadTimelineEvents(); // Reload timeline to show new data
    } catch (e) {
      print('❌ Error adding sample data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding sample data: $e')),
      );
    }
  }

  // Debug method to generate comprehensive sample timeline data
  Future<void> _debugGenerateSampleTimelineData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ DEBUG: No current user found');
        return;
      }

      final uid = user.uid;
      final now = DateTime.now();

      print('🐞 DEBUG: Generating comprehensive sample timeline data');
      print('🆔 User ID: $uid');

      // Detailed logging for each data generation step
      try {
        await _firestore.collection('users').doc(uid).collection('symptomRecords').add({
          'name': 'Comprehensive Symptom Analysis',
          'analysis': {
            'summary': 'Detailed AI-powered symptom breakdown',
            'possible_conditions': ['Test Condition 1', 'Test Condition 2'],
            'severity': 'moderate'
          },
          'timestamp': FieldValue.serverTimestamp(),
          'debugInfo': 'Sample data generation at ${DateTime.now()}'
        });
        print('✅ DEBUG: Symptom records sample data added successfully');
      } catch (e) {
        print('❌ DEBUG: Failed to add symptom records: $e');
      }

      try {
        await _firestore.collection('users').doc(uid).collection('drugs').add({
          'name': 'Debug Drug Entry',
          'description': 'Sample drug for timeline debugging',
          'timestamp': FieldValue.serverTimestamp(),
          'debugInfo': 'Sample data generation at ${DateTime.now()}'
        });
        print('✅ DEBUG: Drug sample data added successfully');
      } catch (e) {
        print('❌ DEBUG: Failed to add drug data: $e');
      }

      try {
        await _firestore.collection('direct_messages').add({
          'senderId': uid,
          'message': 'Debug timeline data generation test',
          'timestamp': FieldValue.serverTimestamp(),
          'debugInfo': 'Sample data generation at ${DateTime.now()}'
        });
        print('✅ DEBUG: Direct messages sample data added successfully');
      } catch (e) {
        print('❌ DEBUG: Failed to add direct messages: $e');
      }

      print('🎉 DEBUG: Sample timeline data generation complete');
      
      // Reload timeline to reflect new data
      _loadTimelineEvents();
    } catch (e) {
      print('❌ DEBUG: Comprehensive error in sample data generation: $e');
    }
  }

  Future<void> _loadTimelineEvents() async {
    print('🔄 Starting timeline load...');
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        setState(() {
          _timelineEvents = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to view timeline'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final uid = user.uid;
      print('🆔 Current User ID: $uid');

      // Comprehensive list of collections to query with fallback handling
      final collectionsToQuery = [
        {'name': 'medications', 'query': _firestore.collection('medications').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'medical_records', 'query': _firestore.collection('medical_records').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'appointments', 'query': _firestore.collection('appointments').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'symptoms', 'query': _firestore.collection('symptoms').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'symptomRecords', 'query': _firestore.collection('users').doc(uid).collection('symptomRecords').limit(100)},
        {'name': 'reports', 'query': _firestore.collection('reports').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'health_data', 'query': _firestore.collection('health_data').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'reminders', 'query': _firestore.collection('reminders').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'mood_entries', 'query': _firestore.collection('mood_entries').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'chat_history', 'query': _firestore.collection('chat_history').where('userId', isEqualTo: uid).limit(25)},
        {'name': 'direct_messages', 'query': _firestore.collection('direct_messages').where('senderId', isEqualTo: uid).limit(25)},
        {'name': 'drugs', 'query': _firestore.collection('users').doc(uid).collection('drugs').limit(50)},
        {'name': 'sos_events', 'query': _firestore.collection('sos_events').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'sleep_fall_detection', 'query': _firestore.collection('sleep_fall_detection').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'health_habits', 'query': _firestore.collection('health_habits').where('userId', isEqualTo: uid).limit(100)},
        {'name': 'community_posts', 'query': _firestore.collection('community_posts').where('userId', isEqualTo: uid).limit(50)},
        {'name': 'wearable_data', 'query': _firestore.collection('wearable_data').where('userId', isEqualTo: uid).limit(200)},
        {'name': 'motion_monitoring', 'query': _firestore.collection('motion_monitoring').where('userId', isEqualTo: uid).limit(200)},
      ];

      // Comprehensive event collection
      final List<Map<String, dynamic>> events = [];

      // Detailed query execution with comprehensive logging and fallback handling
      for (var collection in collectionsToQuery) {
        try {
          final querySnapshot = await (collection['query'] as Query).get();
          print('📊 Collection: ${collection['name']} - Found ${querySnapshot.docs.length} documents');

          for (var doc in querySnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Enhanced event creation with more robust type detection
            Map<String, dynamic>? event = _createEventFromData(
              collection['name'] as String, 
              doc.id, 
              data
            );
            
            if (event != null) {
              events.add(event);
              print('✅ Added event from ${collection['name']}: ${event['title']}');
            }
          }
        } catch (e) {
          print('❌ Error querying ${collection['name']}: $e');
          
          // Special handling for health_habits collection with fallback
          if (collection['name'] == 'health_habits') {
            try {
              print('🔄 Trying fallback query for health_habits...');
              final fallbackQuery = _firestore
                  .collection('health_habits')
                  .where('userId', isEqualTo: uid)
                  .limit(100);
              
              final fallbackSnapshot = await fallbackQuery.get();
              print('📊 Fallback health_habits query: Found ${fallbackSnapshot.docs.length} documents');
              
              for (var doc in fallbackSnapshot.docs) {
                final data = doc.data() as Map<String, dynamic>;
                Map<String, dynamic>? event = _createEventFromData('health_habits', doc.id, data);
                if (event != null) {
                  events.add(event);
                  print('✅ Added fallback event from health_habits: ${event['title']}');
                }
              }
            } catch (fallbackError) {
              print('❌ Fallback query for health_habits also failed: $fallbackError');
            }
          }
        }
      }

      // Sort events by timestamp
      events.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

        setState(() {
          _timelineEvents = events;
          _isLoading = false;
      });

      print('🎉 Total timeline events loaded: ${events.length}');

      // If no events, show a helpful message
      if (events.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No timeline events found. Try adding some activities!'),
            action: SnackBarAction(
              label: 'Add Mood',
              onPressed: _showMoodDialog,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Comprehensive timeline loading error: $e');
        setState(() {
        _timelineEvents = [];
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading timeline: $e'),
            backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Enhanced event creation method
  Map<String, dynamic>? _createEventFromData(String collectionName, String docId, Map<String, dynamic> data) {
    try {
      DateTime eventDate = _toDate(data['timestamp'] ?? data['createdAt'] ?? data['date'] ?? DateTime.now());
      
      switch (collectionName) {
        case 'medications':
          return {
            'id': docId,
            'title': data['name'] ?? 'Medication',
            'description': '${data['dosage'] ?? ''} ${data['frequency'] ?? ''}\n${data['instructions'] ?? ''}',
            'date': eventDate,
            'type': 'medication',
            'doctor': data['doctor'] ?? '',
          };
        case 'medical_records':
          return {
            'id': docId,
            'title': data['diagnosis'] ?? 'Medical Record',
            'description': data['notes'] ?? data['hospital'] ?? '',
            'date': eventDate,
            'type': 'diagnosis',
            'doctor': data['doctor'] ?? '',
          };
        case 'appointments':
          return {
            'id': docId,
            'title': data['title'] ?? 'Appointment',
            'description': data['notes'] ?? '',
            'date': eventDate,
            'type': 'appointment',
            'doctor': data['doctor'] ?? '',
          };
        case 'symptomRecords':
          final analysis = data['analysis'];
          String description = '';
          if (analysis is Map<String, dynamic>) {
            description = analysis['summary'] ?? analysis['possible_conditions'] ?? analysis.toString();
          } else if (analysis is String) {
            description = analysis;
          }
          return {
            'id': docId,
            'title': 'AI Symptom Analysis: ${data['name'] ?? 'Analysis'}',
            'description': description.isNotEmpty ? description : 'AI-powered symptom analysis',
            'date': eventDate,
            'type': 'symptom_analysis',
            'severity': data['severity'] ?? '',
          };
        case 'symptoms':
          final analysis = data['analysis'];
          String description = '';
          if (analysis is Map<String, dynamic>) {
            description = analysis['summary'] ?? analysis['possible_conditions'] ?? analysis.toString();
          } else if (analysis is String) {
            description = analysis;
          }
          return {
            'id': docId,
            'title': 'Symptom Analysis: ${data['name'] ?? 'Analysis'}',
            'description': description.isNotEmpty ? description : 'AI-powered symptom analysis',
            'date': eventDate,
            'type': 'symptom_analysis',
            'severity': data['severity'] ?? '',
          };
        case 'reports':
          final analysis = data['analysis'];
          String description = '';
          if (analysis is Map<String, dynamic>) {
            description = analysis['summary'] ?? analysis['findings'] ?? analysis.toString();
          } else if (analysis is String) {
            description = analysis;
          }
          return {
            'id': docId,
            'title': 'Report Analysis: ${data['reportType'] ?? 'Medical Report'}',
            'description': description.isNotEmpty ? description : 'AI-powered medical report analysis',
            'date': eventDate,
            'type': 'report_analysis',
            'reportType': data['reportType'] ?? '',
          };
        case 'mood_entries':
          return {
            'id': docId,
            'title': 'Mood: ${data['mood'] ?? 'Recorded'}',
            'description': data['notes'] ?? '',
            'date': eventDate,
            'type': 'mood',
            'mood': data['mood'],
          };
        // Add more cases as needed
        default:
          // Generic event for other collections
          return {
            'id': docId,
            'title': data['title'] ?? _toTitleCase(collectionName.replaceAll('_', ' ')),
            'description': data['description'] ?? data['notes'] ?? 'No description',
            'date': eventDate,
            'type': collectionName.toLowerCase().replaceAll(' ', '_'),
          };
      }
    } catch (e) {
      print('❌ Error creating event from $collectionName: $e');
      return null;
    }
  }

  // Helper method for title case conversion
  String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input.split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  // Helper method to safely execute Firestore queries with proper error handling
  Future<QuerySnapshot?> _safeQuery(Future<QuerySnapshot> query, String collectionName) {
    return query.then((snapshot) {
      print('✅ Successfully fetched ${snapshot.docs.length} documents from $collectionName');
      return snapshot;
    }).catchError((error) {
      print('❌ Error fetching $collectionName: $error');
      if (collectionName.contains('subcollection') || collectionName.contains('AI analyses')) {
        print('ℹ️ This is normal if user has no $collectionName data yet');
      }
      return null; // Return null to indicate error occurred
    });
  }

  // Helper to safely convert Firestore Timestamp or DateTime to DateTime
  DateTime _toDate(dynamic value) {
    if (value == null) {
      print('⚠️ Null date value, using current time');
      return DateTime.now();
    }

    try {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is DateTime) {
        return value;
      } else if (value is String) {
        // Handle string dates
        return DateTime.parse(value);
      } else if (value is int) {
        // Handle millisecond timestamps
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else if (value is Map && value.containsKey('_seconds')) {
        // Handle Firestore timestamp format
        final seconds = value['_seconds'] as int?;
        final nanoseconds = value['_nanoseconds'] as int? ?? 0;
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + (nanoseconds ~/ 1000000));
        }
      }

      print('⚠️ Unknown date format: ${value.runtimeType} - $value, using current time');
      return DateTime.now();
    } catch (e) {
      print('❌ Error parsing date: $e, value: $value, using current time');
      return DateTime.now();
    }
  }

  void _showMoodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.bgGlassLight,
        title: const Text('How are you feeling today?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: [
                _buildMoodChip('Excellent', '😊'),
                _buildMoodChip('Great', '😃'),
                _buildMoodChip('Good', '🙂'),
                _buildMoodChip('Okay', '😐'),
                _buildMoodChip('Tired', '😴'),
                _buildMoodChip('Exhausted', '😫'),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _moodNoteController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Add a note (optional)',
                hintStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addMoodEntry();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Color _getEventColor(String type) {
    switch (type) {
      case 'diagnosis':
        return AppTheme.dangerColor;
      case 'medication':
        return AppTheme.primaryColor;
      case 'appointment':
        return AppTheme.accentColor;
      case 'symptom':
        return AppTheme.warningColor;
      case 'symptom_analysis':
        return Colors.deepOrange; // AI Analysis - distinctive color
      case 'health_data':
        return Colors.blue;
      case 'reminder':
        return Colors.purple;
      case 'mood':
        return Colors.pink;
      case 'chat':
        return Colors.teal;
      case 'drug_search':
        return Colors.orange;
      case 'test':
        return Colors.purpleAccent;
      case 'consultation':
        return AppTheme.warningColor;
      case 'sos_event':
        return AppTheme.dangerColor;
      case 'sleep_fall':
        return Colors.indigo;
      case 'health_habit':
        return Colors.green;
      case 'community_post':
        return Colors.blueAccent;
      case 'blood_request':
        return Colors.red;
      case 'blood_donor':
        return Colors.redAccent;
      case 'health_id_scan':
        return Colors.cyan;
      case 'motion_monitoring':
        return Colors.lime;
      case 'wearable_data':
        return Colors.deepPurple;
      default:
        return AppTheme.textMuted;
    }
  }
  
  IconData _getEventIcon(String type) {
    switch (type) {
      case 'diagnosis':
        return Icons.medical_services;
      case 'medication':
        return Icons.medication;
      case 'appointment':
        return Icons.calendar_today;
      case 'symptom':
        return Icons.sick;
      case 'symptom_analysis':
        return Icons.psychology; // AI brain icon for AI analysis
      case 'health_data':
        return Icons.favorite;
      case 'reminder':
        return Icons.alarm;
      case 'mood':
        return Icons.sentiment_satisfied;
      case 'chat':
        return Icons.chat;
      case 'drug_search':
        return Icons.local_pharmacy; // Pharmacy icon for drug searches
      case 'test':
        return Icons.science;
      case 'consultation':
        return Icons.people;
      case 'sos_event':
        return Icons.emergency;
      case 'sleep_fall':
        return Icons.nightlight_round;
      case 'health_habit':
        return Icons.track_changes;
      case 'community_post':
        return Icons.forum;
      case 'blood_request':
        return Icons.bloodtype;
      case 'blood_donor':
        return Icons.volunteer_activism;
      case 'health_id_scan':
        return Icons.qr_code_scanner;
      case 'motion_monitoring':
        return Icons.directions_walk;
      case 'wearable_data':
        return Icons.watch;
      default:
        return Icons.event_note;
    }
  }

  Widget _buildMoodChip(String mood, String emoji) {
    return ActionChip(
      label: Text(
        '$emoji $mood',
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: _selectedMood == mood ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent,
      onPressed: () {
        setState(() {
          _selectedMood = mood;
          _moodNoteController.clear();
        });
      },
    );
  }

  Future<void> _addMoodEntry() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in.')),
      );
      return;
    }

    final uid = user.uid;
    final now = DateTime.now();

    final moodEntry = {
      'userId': uid,
      'mood': _selectedMood,
      'energy': 50, // Default energy level
      'notes': _moodNoteController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('mood_entries').add(moodEntry);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mood entry saved: $_selectedMood')),
      );
      _loadTimelineEvents(); // Reload timeline to show new mood entry
    } catch (e) {
      print('❌ Error adding mood entry: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving mood entry: $e')),
      );
    }
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
            'Medical Timeline',
            style: TextStyle(
              color: AppTheme.textTeal,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (_isOffline)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, color: Colors.orange, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.sentiment_satisfied, color: Colors.white),
              onPressed: _showMoodDialog,
              tooltip: 'Record Mood',
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.white),
              onPressed: _addSampleTimelineData,
              tooltip: 'Add Sample Data (for testing)',
            ),
          ],
        ),
        drawer: const AppDrawer(),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _timelineEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isOffline ? Icons.cloud_off : Icons.timeline, 
                          size: 64, 
                          color: Colors.white.withOpacity(0.5)
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isOffline 
                            ? 'No offline data available'
                            : 'No timeline events found',
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                        if (_isOffline) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Check your internet connection',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showMoodDialog,
                          icon: const Icon(Icons.sentiment_satisfied),
                          label: const Text('Record Your Mood'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                        ),
                        if (_isOffline) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadTimelineEvents,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Connection'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _timelineEvents.length,
                    itemBuilder: (context, index) {
                      final event = _timelineEvents[index];
                      final isFirst = index == 0;
                      final isLast = index == _timelineEvents.length - 1;
                      final eventColor = _getEventColor(event['type']);
                      final eventIcon = _getEventIcon(event['type']);
                      
                      return TimelineTile(
                        alignment: TimelineAlign.manual,
                        lineXY: 0.2,
                        isFirst: isFirst,
                        isLast: isLast,
                        indicatorStyle: IndicatorStyle(
                          width: 40,
                          height: 40,
                          indicator: Container(
                            decoration: BoxDecoration(
                              color: eventColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              eventIcon,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        beforeLineStyle: LineStyle(
                            color: Colors.white.withOpacity(0.1),
                          thickness: 2,
                        ),
                        afterLineStyle: LineStyle(
                            color: Colors.white.withOpacity(0.1),
                          thickness: 2,
                        ),
                        startChild: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                          alignment: Alignment.centerRight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('MMM dd, yyyy').format(event['date']),
                                  style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('h:mm a').format(event['date']),
                                style: TextStyle(
                                  fontSize: 12,
                                    color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                          endChild: GlassContainer(
                          padding: const EdgeInsets.all(16),
                            backgroundColor: AppTheme.bgGlassLight,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: eventColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      event['type'][0].toUpperCase() + event['type'].substring(1),
                                      style: TextStyle(
                                        color: eventColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (event['mood'] != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '${event['mood']} ${_getMoodEmoji(event['mood'])}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                event['title'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                    color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                                if (event['description'] != null && event['description'].toString().isNotEmpty)
                              Text(
                                event['description'],
                                style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                              const SizedBox(height: 8),
                                if (event['doctor'] != null && event['doctor'].toString().isNotEmpty)
                              Row(
                                children: [
                                      const Icon(
                                    Icons.person,
                                    size: 16,
                                        color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    event['doctor'],
                                        style: const TextStyle(
                                          color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.refresh),
            onPressed: _loadTimelineEvents,
          ),
      ),
    );
  }

  String _getMoodEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'excellent':
        return '😊';
      case 'great':
        return '😃';
      case 'good':
        return '🙂';
      case 'okay':
        return '😐';
      case 'tired':
        return '😴';
      case 'exhausted':
        return '😫';
      default:
        return '😐';
    }
  }
} 