import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';
import '../utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:aidx/utils/theme.dart';
import 'package:aidx/widgets/glass_container.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({Key? key}) : super(key: key);

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  List<Map<String, dynamic>> _timelineEvents = [];
  bool _isLoading = true;
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
  
  Future<void> _loadTimelineEvents() async {
    setState(() => _isLoading = true);
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      final uid = user.uid;
      final List<Map<String, dynamic>> events = [];

      // Fetch medications
      final medsSnap = await _firestore
          .collection('medications')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in medsSnap.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          'title': data['name'] ?? 'Medication',
          'description':
              '${data['dosage'] ?? ''} ${data['frequency'] ?? ''}\n${data['instructions'] ?? ''}',
          'date': _toDate(data['startDate'] ?? data['createdAt']),
          'type': 'medication',
          'doctor': data['doctor'] ?? '',
        });
      }

      // Fetch medical records
      final recordSnap = await _firestore
          .collection('medical_records')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in recordSnap.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          'title': data['diagnosis'] ?? 'Medical Record',
          'description': data['notes'] ?? data['hospital'] ?? '',
          'date': _toDate(data['date'] ?? data['createdAt']),
          'type': 'diagnosis',
          'doctor': data['doctor'] ?? '',
        });
      }

      // Fetch appointments
      final appointSnap = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in appointSnap.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          'title': data['title'] ?? 'Appointment',
          'description': data['notes'] ?? '',
          'date': _toDate(data['date'] ?? data['createdAt']),
          'type': 'appointment',
          'doctor': data['doctor'] ?? '',
        });
      }

      // Fetch symptoms and AI analysis
      final symptomSnap = await _firestore
          .collection('symptoms')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in symptomSnap.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          'title': data['name'] ?? 'Symptom Analysis',
          'description': data['analysis'] ?? data['notes'] ?? '',
          'date': _toDate(data['timestamp'] ?? data['createdAt']),
          'type': 'symptom',
          'severity': data['severity'] ?? '',
        });
      }

      // Fetch health data entries
      final healthSnap = await _firestore
          .collection('health_data')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in healthSnap.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          'title': '${data['type'] ?? 'Health'} Reading',
          'description': '${data['value']} ${data['unit'] ?? ''}\n${data['notes'] ?? ''}',
          'date': _toDate(data['timestamp'] ?? data['createdAt']),
          'type': 'health_data',
          'value': data['value'],
          'unit': data['unit'],
        });
      }

      // Fetch reminders
      final reminderSnap = await _firestore
          .collection('reminders')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in reminderSnap.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          'title': data['title'] ?? 'Reminder',
          'description': data['description'] ?? '',
          'date': _toDate(data['dateTime'] ?? data['createdAt']),
          'type': 'reminder',
          'frequency': data['frequency'] ?? '',
        });
      }

      // Fetch mood entries
      final moodSnap = await _firestore
          .collection('mood_entries')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in moodSnap.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          'title': 'Mood: ${data['mood'] ?? 'Recorded'}',
          'description': data['notes'] ?? '',
          'date': _toDate(data['timestamp'] ?? data['createdAt']),
          'type': 'mood',
          'mood': data['mood'],
          'energy': data['energy'],
        });
      }

      // Fetch chat interactions
      final chatSnap = await _firestore
          .collection('chat_history')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in chatSnap.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          'title': 'AI Consultation',
          'description': data['query'] ?? 'Health consultation with AI',
          'date': _toDate(data['timestamp'] ?? data['createdAt']),
          'type': 'chat',
          'response': data['response'],
        });
      }

      // Fetch drug searches
      final drugSnap = await _firestore
          .collection('drug_searches')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in drugSnap.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          'title': 'Drug Info: ${data['drug_name'] ?? 'Searched'}',
          'description': data['dosage'] ?? 'Drug information retrieved',
          'date': _toDate(data['timestamp'] ?? data['createdAt']),
          'type': 'drug_search',
          'drug_name': data['drug_name'],
        });
      }

      // Sort events by date descending
      events.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      setState(() {
        _timelineEvents = events;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading timeline: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addMoodEntry() async {
    if (_selectedMood.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood')),
      );
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not signed in');
      }

      await _firestore.collection('mood_entries').add({
        'userId': user.uid,
        'mood': _selectedMood,
        'notes': _moodNoteController.text.trim(),
        'energy': _getEnergyLevel(_selectedMood),
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      _moodNoteController.clear();
      _selectedMood = '';
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mood recorded successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadTimelineEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording mood: $e')),
      );
    }
  }

  int _getEnergyLevel(String mood) {
    switch (mood.toLowerCase()) {
      case 'excellent':
      case 'great':
        return 5;
      case 'good':
        return 4;
      case 'okay':
        return 3;
      case 'tired':
        return 2;
      case 'exhausted':
        return 1;
      default:
        return 3;
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

  Widget _buildMoodChip(String mood, String emoji) {
    final isSelected = _selectedMood == mood;
    return ChoiceChip(
      label: Text('$emoji $mood'),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedMood = selected ? mood : '';
        });
      },
      backgroundColor: Colors.transparent,
      selectedColor: AppTheme.primaryColor.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
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
      case 'health_data':
        return Icons.favorite;
      case 'reminder':
        return Icons.alarm;
      case 'mood':
        return Icons.sentiment_satisfied;
      case 'chat':
        return Icons.chat;
      case 'drug_search':
        return Icons.search;
      case 'test':
        return Icons.science;
      case 'consultation':
        return Icons.people;
      default:
        return Icons.event_note;
    }
  }

  // Helper to safely convert Firestore Timestamp or DateTime to DateTime
  DateTime _toDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
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
            IconButton(
              icon: const Icon(Icons.sentiment_satisfied, color: Colors.white),
              onPressed: _showMoodDialog,
              tooltip: 'Record Mood',
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
                        Icon(Icons.timeline, size: 64, color: Colors.white.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'No timeline events found',
                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showMoodDialog,
                          icon: const Icon(Icons.sentiment_satisfied),
                          label: const Text('Record Your Mood'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                        ),
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