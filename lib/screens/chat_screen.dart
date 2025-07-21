import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../utils/app_colors.dart';
import '../utils/theme.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum AssistantState {
  greeting,
  conversation,
  speaking,
  listening,
  idle,
  processing,
  error,
  reconnecting,
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;
  bool _isSpeaking = false;
  AssistantState _state = AssistantState.greeting;
  String _lastUserInput = '';
  String _aiResponse = '';
  // Live transcription text updated in real-time while user is speaking
  String _liveTranscript = '';
  final GeminiService _gemini = GeminiService();
  final List<Map<String, String>> _history = [];
  
  // For image picker
  final ImagePicker _picker = ImagePicker();
  bool _micPermissionGranted = false;
  bool _ttsReady = false;
  String? _errorMsg;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _orbGlowController;
  late Animation<double> _orbGlowAnimation;
  
  // Enhanced robust voice assistant tracking
  int _sessionCount = 0;
  int _errorCount = 0;
  int _consecutiveErrors = 0;
  final int _maxSessionsBeforeReset = 15; // Reset after 15 sessions
  final int _maxErrorsBeforeReset = 3; // Reset after 3 consecutive errors
  final int _maxConsecutiveErrors = 5; // Max consecutive errors before aggressive reset
  bool _isResetting = false;
  DateTime? _lastResetTime;
  DateTime? _lastSuccessfulInteraction;
  
  // Pause functionality
  bool _isPaused = false;
  
  // Conversation context
  String _conversationContext = '';
  bool _isProcessing = false;

  // Enhanced speech locale and noise handling
  String _preferredLocaleId = 'en_US';
  double _soundLevelThreshold = 25.0; // adjust for background noise
  double _confidenceThreshold = 0.35; // adaptive confidence threshold
  
  // Connection monitoring
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isConnected = true;
  Timer? _connectionCheckTimer;
  
  // Adaptive settings
  double _currentSpeechRate = 0.425;
  double _currentPitch = 0.9;
  double _currentVolume = 0.8;
  int _successfulInteractions = 0;
  
  // Recovery mechanisms
  Timer? _autoRecoveryTimer;
  Timer? _healthCheckTimer;
  bool _isInRecoveryMode = false;
  
  // Performance tracking
  final List<Duration> _responseTimes = [];
  final List<double> _confidenceScores = [];
  DateTime? _sessionStartTime;
  
  // Greeting control
  bool _hasGreeted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeVoiceAssistant();
    _setupConnectivityMonitoring();
    _startHealthCheck();
    _orbGlowController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _orbGlowAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _orbGlowController, curve: Curves.easeInOut),
    );
  }

  void _initializeVoiceAssistant() {
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _tts.setCompletionHandler(_onTtsComplete);
    _tts.setErrorHandler((msg) => _onTtsError(msg));
    _initSpeechLocale();
    _initPermissionsAndTts();
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
      
      if (_isConnected && _isInRecoveryMode) {
        _attemptRecovery();
      } else if (!_isConnected) {
        _handleConnectionLoss();
      }
    });
    
    // Check initial connectivity
    Connectivity().checkConnectivity().then((result) {
      setState(() {
        _isConnected = result != ConnectivityResult.none;
      });
    });
  }

  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(Duration(minutes: 2), (timer) {
      _performHealthCheck();
    });
  }

  Future<void> _performHealthCheck() async {
    if (_isResetting || _isProcessing) return;
    
    try {
      // Check TTS health
      if (!_ttsReady) {
        await _initTts(skipGreeting: true);
      }
      
      // Check speech recognition health
      if (!_speech.isAvailable) {
        await _speech.initialize();
      }
      
      // Check for stale sessions
      if (_sessionStartTime != null && 
          DateTime.now().difference(_sessionStartTime!) > Duration(minutes: 30)) {
        await _softReset();
      }
      
      // Adaptive threshold adjustment based on performance
      _adjustConfidenceThreshold();
      
    } catch (e) {
      print('Health check failed: $e');
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        await _aggressiveReset();
      }
    }
  }

  void _adjustConfidenceThreshold() {
    if (_confidenceScores.isEmpty) return;
    
    double avgConfidence = _confidenceScores.reduce((a, b) => a + b) / _confidenceScores.length;
    
    // Adjust threshold based on average confidence
    if (avgConfidence > 0.7) {
      _confidenceThreshold = 0.4; // More strict
    } else if (avgConfidence < 0.5) {
      _confidenceThreshold = 0.25; // More lenient
    } else {
      _confidenceThreshold = 0.35; // Default
    }
    
    // Keep only recent scores
    if (_confidenceScores.length > 20) {
      _confidenceScores.removeRange(0, _confidenceScores.length - 20);
    }
  }

  void _handleConnectionLoss() {
    setState(() {
      _isInRecoveryMode = true;
      _state = AssistantState.error;
    });
    
    _autoRecoveryTimer?.cancel();
    _autoRecoveryTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_isConnected) {
        _attemptRecovery();
        timer.cancel();
      }
    });
  }

  Future<void> _attemptRecovery() async {
    if (!_isConnected) return;
    
    setState(() {
      _state = AssistantState.reconnecting;
    });
    
    try {
      await _softReset();
      setState(() {
        _isInRecoveryMode = false;
        _state = AssistantState.conversation;
      });
      
      // Only greet after recovery if this is not the initial greeting
      if (_hasGreeted) {
      await _speak("I'm back online. How can I help you?");
      }
      
    } catch (e) {
      print('Recovery failed: $e');
      setState(() {
        _state = AssistantState.error;
      });
    }
  }

  Future<void> _softReset() async {
    if (_isResetting) return;
    
    setState(() {
      _isResetting = true;
    });

    try {
      // Stop current operations
      await _stopAllOperations();
      
      // Re-initialize TTS without greeting
      await _initTts(skipGreeting: true);
      
      // Reset speech recognition
      await _speech.initialize();
      
      setState(() {
        _isResetting = false;
        _errorMsg = null;
      });
      
    } catch (e) {
      print('Soft reset failed: $e');
      setState(() {
        _isResetting = false;
      });
      throw e;
    }
  }

  Future<void> _aggressiveReset() async {
    print('Performing aggressive reset due to consecutive errors');
    
    setState(() {
      _isResetting = true;
      _state = AssistantState.error;
    });

    try {
      // Stop all operations
      await _stopAllOperations();
      
      // Dispose and recreate instances
      _speech = stt.SpeechToText();
      _tts = FlutterTts();
      _tts.setCompletionHandler(_onTtsComplete);
      _tts.setErrorHandler((msg) => _onTtsError(msg));

      // Re-initialize everything without greeting
      await _initTts(skipGreeting: true);
      await _speech.initialize();
      
      // Reset all counters
      _sessionCount = 0;
      _errorCount = 0;
      _consecutiveErrors = 0;
      _successfulInteractions = 0;
      _confidenceScores.clear();
      _responseTimes.clear();
      
      setState(() {
        _isResetting = false;
        _state = AssistantState.conversation;
        _errorMsg = null;
      });
      
      // Only greet if this is a reset (not initial greeting)
      if (_hasGreeted) {
      await _speak("I've reset my systems. How can I help you?");
      }
      
    } catch (e) {
      print('Aggressive reset failed: $e');
      setState(() {
        _isResetting = false;
        _state = AssistantState.error;
      });
    }
  }

  Future<void> _stopAllOperations() async {
    try {
      await _speech.stop();
    } catch (e) {
      print('Error stopping speech: $e');
    }

    try {
      await _tts.stop();
    } catch (e) {
      print('Error stopping TTS: $e');
    }

    setState(() {
      _isListening = false;
      _isSpeaking = false;
    });
  }

  // Determine best speech locale for Bangladeshi English accent
  Future<void> _initSpeechLocale() async {
    try {
      var locales = await _speech.locales();
      stt.LocaleName? chosen;
      for (final loc in locales) {
        final id = loc.localeId.toLowerCase();
        if (id == 'en_in') {
          chosen = loc;
          break;
        }
      }
      chosen ??= locales.firstWhere((l) => l.localeId.toLowerCase() == 'en_gb', orElse: () => stt.LocaleName('en_US', 'English'));
      chosen ??= locales.firstWhere((l) => l.localeId.toLowerCase().startsWith('en'), orElse: () => locales.first);
      _preferredLocaleId = chosen.localeId;
    } catch (_) {
      _preferredLocaleId = 'en_US';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Reset voice assistant when app goes to background
      _fullResetVoiceAssistant();
    } else if (state == AppLifecycleState.resumed) {
      // Re-initialize when app comes back to foreground
      if (!_isResetting) {
        _initializeVoiceAssistant();
      }
    }
  }

  // Full reset method for maximum robustness
  Future<void> _fullResetVoiceAssistant() async {
    if (_isResetting) return;
    
    setState(() {
      _isResetting = true;
      _isListening = false;
      _isSpeaking = false;
      _errorMsg = null;
    });

    try {
      // Stop speech recognition
      try {
        await _speech.stop();
      } catch (e) {
        print('Error stopping speech: $e');
      }

      // Stop TTS
      try {
        await _tts.stop();
      } catch (e) {
        print('Error stopping TTS: $e');
      }

      // Dispose and recreate instances
      _speech = stt.SpeechToText();
      _tts = FlutterTts();
      _tts.setCompletionHandler(_onTtsComplete);
      _tts.setErrorHandler((msg) => _onTtsError(msg));

      // Re-initialize TTS without greeting
      await _initTts(skipGreeting: true);

      // Reset counters but keep greeting flag
      _sessionCount = 0;
      _errorCount = 0;
      _lastResetTime = DateTime.now();

      print('Voice assistant fully reset successfully');
    } catch (e) {
      print('Error during full reset: $e');
    } finally {
      setState(() {
        _isResetting = false;
      });
    }
  }

  // Manual reset for user recovery
  Future<void> _manualResetVoiceAssistant() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Resetting voice assistant...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    await _fullResetVoiceAssistant();
    
    // Only greet if this is a manual reset (not initial greeting)
    if (_hasGreeted) {
      await _speak("Voice assistant has been reset. How can I help you?");
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice assistant reset complete!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Enhanced reset logic with multiple recovery strategies
  Future<void> _checkAndResetIfNeeded() async {
    bool shouldReset = false;
    String resetReason = '';
    
    if (_sessionCount >= _maxSessionsBeforeReset) {
      shouldReset = true;
      resetReason = 'session limit reached';
    } else if (_errorCount >= _maxErrorsBeforeReset) {
      shouldReset = true;
      resetReason = 'error limit reached';
    } else if (_consecutiveErrors >= _maxConsecutiveErrors) {
      shouldReset = true;
      resetReason = 'consecutive errors';
    } else if (_lastSuccessfulInteraction != null && 
               DateTime.now().difference(_lastSuccessfulInteraction!) > Duration(minutes: 10)) {
      shouldReset = true;
      resetReason = 'stale session';
    }
    
    if (shouldReset) {
      print('Resetting voice assistant: $resetReason (sessions=$_sessionCount, errors=$_errorCount, consecutive=$_consecutiveErrors)');
      
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        await _aggressiveReset();
      } else {
        await _softReset();
      }
    }
  }

  Future<void> _initPermissionsAndTts() async {
    await _checkMicPermission();
    await _initTts(); // This will handle greeting automatically
    // Fallback greeting if TTS fails
    if (!_ttsReady && !_hasGreeted) {
      setState(() {
        _history.add({'role': 'ai', 'text': 'Hello, I am your personal health assistant. How can I help you?'});
        _hasGreeted = true;
      });
    }
  }

  Future<void> _checkMicPermission() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }
      setState(() {
        _micPermissionGranted = status.isGranted;
      });
      if (!status.isGranted) {
        // For emulator, show a more helpful message
        _showPermissionDialog('Microphone permission is required for voice assistant. On emulator, you may need to enable microphone in emulator settings or use a real device for full voice functionality.');
      }
    } catch (e) {
      setState(() {
        _micPermissionGranted = false;
        _errorMsg = 'Permission check failed: $e';
      });
      _showErrorDialog('Permission check failed. This may be an emulator limitation.');
    }
  }

  Future<void> _initTts({bool skipGreeting = false}) async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.425); // Half as fast as before
      await _tts.setPitch(0.9); // Lower pitch to sound different from Google Assistant
      await _tts.setVolume(0.8); // Slightly lower volume
      
      // Try to set a different voice if available
      try {
        var voices = await _tts.getVoices;
        if (voices != null && voices.isNotEmpty) {
          // Look for a female voice that's not the default Google Assistant voice
          for (var voice in voices) {
            if (voice['name'] != null && 
                voice['name'].toString().toLowerCase().contains('female') &&
                !voice['name'].toString().toLowerCase().contains('google')) {
              await _tts.setVoice({"name": voice['name'], "locale": voice['locale']});
              break;
            }
          }
        }
      } catch (e) {
        // If voice setting fails, continue with default
        print('Could not set custom voice: $e');
      }
      
      setState(() => _ttsReady = true);
      
      // Only greet if this is the initial setup and greeting is not skipped
      if (!skipGreeting && !_hasGreeted && _ttsReady) {
        _greetAndListen();
        _hasGreeted = true;
      }
    } catch (e) {
      setState(() {
        _ttsReady = false;
        _errorMsg = 'Text-to-Speech initialization failed.';
      });
      _showErrorDialog(_errorMsg!);
    }
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    setState(() {
      _errorCount++;
      _sessionCount++;
    });
    _checkAndResetIfNeeded();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Voice Assistant Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            SizedBox(height: 12),
            Text(
              'This might be due to:\n• Microphone being used by another app\n• Device audio system issues\n• Permission problems',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resetSpeechRecognizer();
              _listen();
            },
            child: Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _errorMsg = null);
            },
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _onTtsError(String msg) {
    setState(() {
      _isSpeaking = false;
      _errorMsg = 'TTS Error: $msg';
      _errorCount++;
      _consecutiveErrors++;
    });
    
    // Track error for adaptive recovery
    _logError('TTS', msg);
    
    // Try adaptive recovery first
    if (_consecutiveErrors < 3) {
      _attemptAdaptiveRecovery();
    } else {
      _checkAndResetIfNeeded();
      _showErrorDialog(_errorMsg!);
    }
    
    if (_canListen() && !_isPaused) _listen();
  }

  void _logError(String component, String error) {
    print('[$component Error] $error (consecutive: $_consecutiveErrors, total: $_errorCount)');
    
    // Store error for analysis
    // In a production app, you might want to send this to analytics
  }

  Future<void> _attemptAdaptiveRecovery() async {
    print('Attempting adaptive recovery...');
    
    try {
      // Try adjusting TTS settings
      await _adjustTtsSettings();
      
      // If that doesn't work, try reinitializing TTS
      if (!_ttsReady) {
        await _initTts();
      }
      
      setState(() {
        _errorMsg = null;
      });
      
    } catch (e) {
      print('Adaptive recovery failed: $e');
      _checkAndResetIfNeeded();
    }
  }

  Future<void> _adjustTtsSettings() async {
    try {
      // Try different voice settings based on error patterns
      if (_consecutiveErrors == 1) {
        // First error: try adjusting volume and rate
        await _tts.setVolume(_currentVolume * 0.9);
        await _tts.setSpeechRate(_currentSpeechRate * 0.95);
      } else if (_consecutiveErrors == 2) {
        // Second error: try different pitch
        await _tts.setPitch(_currentPitch * 1.1);
        await _tts.setVolume(_currentVolume);
        await _tts.setSpeechRate(_currentSpeechRate);
      }
    } catch (e) {
      print('Failed to adjust TTS settings: $e');
      throw e;
    }
  }

  void _greetAndListen() async {
    if (!_ttsReady) {
      await _initTts(skipGreeting: true);
      if (!_ttsReady) return;
    }
    _setState(AssistantState.speaking);
    await _speak("Hello, I am your personal health assistant. I can help you with medical questions, symptom analysis, drug information, and health advice. You can also share photos of symptoms or medications for better analysis. How can I help you today?");
  }

  void _setState(AssistantState state) {
    setState(() => _state = state);
  }

  Future<void> _speak(String text) async {
    if (!_ttsReady) {
      await _initTts(skipGreeting: true);
      if (!_ttsReady) return;
    }
    
    final startTime = DateTime.now();
    
    setState(() {
      _isSpeaking = true;
      _aiResponse = text;
      _addMessage({'role': 'ai', 'text': text});
    });
    
    try {
      await _tts.speak(text);
      
      // Track successful interaction
      final responseTime = DateTime.now().difference(startTime);
      _responseTimes.add(responseTime);
      _lastSuccessfulInteraction = DateTime.now();
      _consecutiveErrors = 0; // Reset consecutive errors on success
      _successfulInteractions++;
      
      // Keep only recent response times
      if (_responseTimes.length > 50) {
        _responseTimes.removeRange(0, _responseTimes.length - 50);
      }
      
    } catch (e) {
      setState(() {
        _isSpeaking = false;
        _errorMsg = 'TTS failed: $e';
        _errorCount++;
        _consecutiveErrors++;
      });
      
      _logError('TTS', e.toString());
      _checkAndResetIfNeeded();
      _showErrorDialog(_errorMsg!);
      _listen();
    }
  }

  void _onTtsComplete() {
    setState(() => _isSpeaking = false);
    if (_canListen() && !_isPaused) _listen();
  }

  // Method to change voice settings
  Future<void> _changeVoiceSettings({
    double? speechRate,
    double? pitch,
    double? volume,
    String? voiceName,
  }) async {
    try {
      if (speechRate != null) await _tts.setSpeechRate(speechRate);
      if (pitch != null) await _tts.setPitch(pitch);
      if (volume != null) await _tts.setVolume(volume);
      
      if (voiceName != null) {
        var voices = await _tts.getVoices;
        if (voices != null && voices.isNotEmpty) {
          for (var voice in voices) {
            if (voice['name'] != null && 
                voice['name'].toString().toLowerCase().contains(voiceName.toLowerCase())) {
              await _tts.setVoice({"name": voice['name'], "locale": voice['locale']});
              break;
            }
          }
        }
      }
    } catch (e) {
      print('Error changing voice settings: $e');
    }
  }

  void _showVoiceSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Voice Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Gentle Female Voice'),
              subtitle: Text('Soft, caring tone'),
              onTap: () async {
                Navigator.pop(context);
                await _changeVoiceSettings(
                  speechRate: 0.8,
                  pitch: 0.9,
                  volume: 0.8,
                  voiceName: 'female',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Voice changed to Gentle Female')),
                );
              },
            ),
            ListTile(
              title: Text('Professional Male Voice'),
              subtitle: Text('Clear, authoritative tone'),
              onTap: () async {
                Navigator.pop(context);
                await _changeVoiceSettings(
                  speechRate: 0.9,
                  pitch: 0.8,
                  volume: 0.9,
                  voiceName: 'male',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Voice changed to Professional Male')),
                );
              },
            ),
            ListTile(
              title: Text('Friendly Assistant'),
              subtitle: Text('Warm, approachable tone'),
              onTap: () async {
                Navigator.pop(context);
                await _changeVoiceSettings(
                  speechRate: 0.85,
                  pitch: 1.0,
                  volume: 0.85,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Voice changed to Friendly Assistant')),
                );
              },
            ),
            ListTile(
              title: Text('Medical Professional'),
              subtitle: Text('Calm, reassuring tone'),
              onTap: () async {
                Navigator.pop(context);
                await _changeVoiceSettings(
                  speechRate: 0.75,
                  pitch: 0.85,
                  volume: 0.8,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Voice changed to Medical Professional')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSpeechRecognizer() async {
    try {
      await _speech.stop();
    } catch (e) {
      // Ignore stop errors
    }
    setState(() {
      _isListening = false;
      _errorMsg = null;
    });
    // Small delay to ensure cleanup
    await Future.delayed(Duration(milliseconds: 300));
  }

  // Enhanced helper to check if we can start listening
  bool _canListen() {
    return !_isListening && 
           !_isSpeaking && 
           !_isProcessing && 
           !_isResetting && 
           !_isInRecoveryMode &&
           !_isPaused &&
           _ttsReady && 
           _micPermissionGranted &&
           _isConnected;
  }

  Future<void> _listen() async {
    if (!_canListen()) {
      if (!_isConnected) {
        setState(() {
          _errorMsg = 'No internet connection. Please check your connection and try again.';
        });
        _showErrorDialog(_errorMsg!);
      } else if (_isPaused) {
        return; // Don't show error dialog for pause state
      }
      return;
    }

    // Check if we need to reset before starting
    await _checkAndResetIfNeeded();

    // Always reset before starting
    await _resetSpeechRecognizer();

    if (_isListening) return;

    // Increment session count and start session tracking
    _sessionCount++;
    _sessionStartTime = DateTime.now();

    bool resultHandled = false;

    bool isFinalResult = false;

    bool hasSpoken = false;

    bool debugMode = true; // Set to true for more debug logs

    bool partialResultsEnabled = true; // live transcription

    bool allowEssay = true; // For clarity

    bool allowLongPause = true; // For clarity

    bool allowLongListen = true; // For clarity

    try {
    bool available = await _speech.initialize(
      onStatus: (status) async {
          if (debugMode) debugPrint('Speech status: $status');
        if (status == 'notListening' && !_isSpeaking && !_isProcessing && !_isResetting) {
          setState(() => _isListening = false);
            if (!resultHandled && _liveTranscript.isNotEmpty) {
              // If recognizer stopped but we have transcript, treat as final
              _addMessage({'role': 'user', 'text': _liveTranscript});
              _handleUserInput(_liveTranscript);
              _liveTranscript = '';
              resultHandled = true;
            } else {
              // No transcript – likely noise or premature stop; auto-restart safely
              Future.delayed(Duration(milliseconds: 600), () {
          if (_canListen()) _listen();
              });
            }
        }
      },
      onError: (err) async {
          if (debugMode) debugPrint('Speech error: ${err.errorMsg}');
          final String errLower = err.errorMsg.toLowerCase();
          if (errLower.contains('no_match') || errLower.contains('no_speech') || errLower.contains('timeout')) {
            // Non-critical errors: auto-restart listening without dialog
            await _resetSpeechRecognizer();
        setState(() {
          _isListening = false;
            });
            // Briefly prompt user if needed
            if (!_isSpeaking && !_isProcessing) {
              await _speak("I didn't catch that. Please try again.");
            }
            if (_canListen()) {
              Future.delayed(Duration(seconds: 1), () {
                if (_canListen()) _listen();
              });
            }
        } else {
            // Critical errors: show dialog
            final String errMsg = 'Speech recognition error: ${err.errorMsg}';
            setState(() {
              _isListening = false;
              _errorMsg = errMsg;
              _errorCount++;
            });
            await _resetSpeechRecognizer();
            await _checkAndResetIfNeeded();
            _showErrorDialog(errMsg);
        }
      },
    );

    if (available) {
      setState(() => _isListening = true);
        await _speech.listen(
          onResult: (val) {
            if (debugMode) debugPrint('Speech result: ${val.recognizedWords} (final: ${val.finalResult})');
            // Filter by adaptive confidence threshold
            if (!val.finalResult && val.confidence != null && val.confidence! < _confidenceThreshold) {
              return; // likely noise
            }
            if (partialResultsEnabled && val.recognizedWords.isNotEmpty) {
              setState(() {
                _liveTranscript = val.recognizedWords;
              });
            }
            if (val.finalResult) {
              if (val.confidence != null && val.confidence! < _confidenceThreshold) {
                // low confidence final result, ignore and restart listening
                _liveTranscript = '';
                if (_canListen()) {
                  Future.delayed(Duration(milliseconds: 200), () => _listen());
                }
                return;
              }
              
              // Track confidence score for adaptive threshold
              if (val.confidence != null) {
                _confidenceScores.add(val.confidence!);
              }
              isFinalResult = true;
              resultHandled = true;
              setState(() {
                _isListening = false;
                _lastUserInput = val.recognizedWords;
                _liveTranscript = '';
                _addMessage({'role': 'user', 'text': _lastUserInput});
              });
              _handleUserInput(_lastUserInput);
            }
          },
          listenFor: allowLongListen ? const Duration(minutes: 5) : const Duration(seconds: 30),
          pauseFor: allowLongPause ? const Duration(seconds: 3) : const Duration(seconds: 2),
          localeId: _preferredLocaleId,
          cancelOnError: true,
          partialResults: partialResultsEnabled,
          onSoundLevelChange: (level) {
            // Ignore very low sound levels (background noise)
            if (level < _soundLevelThreshold) return;
          },
        );
      } else {
        setState(() {
          _isListening = false;
          _errorMsg = 'Speech recognition not available on this device.';
        });
        _showErrorDialog(_errorMsg!);
      }
    } catch (e, st) {
      if (debugMode) debugPrint('Exception in _listen: $e\n$st');
      setState(() {
        _isListening = false;
        _errorMsg = 'Failed to start listening: $e';
        _errorCount++;
      });
      _checkAndResetIfNeeded();
      _showErrorDialog(_errorMsg!);
    }
  }

  Future<String> _sendToGemini(String userInput) async {
    try {
      // Build conversation context
      String context = _buildConversationContext();
      
      print('Sending to Gemini: $userInput');
      print('Context length: ${context.length}');
      
      // Use the new robust sendMessage method
      String response = await _gemini.sendMessage(userInput, conversationContext: context);
      
      print('Gemini response received: ${response.length} characters');
      
      // Update conversation context
      _updateConversationContext(userInput, response);
      
      // Remove asterisks from response
      response = response.replaceAll('*', '');
      
      return response;
    } catch (e) {
      print('Error in _sendToGemini: $e');
      
      // Check for specific error types and provide appropriate responses
      if (e.toString().contains('timeout')) {
        return "I'm sorry, the request is taking too long. Please check your internet connection and try again.";
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        return "I'm having trouble connecting to my knowledge base. Please check your internet connection and try again.";
      } else if (e.toString().contains('quota') || e.toString().contains('limit')) {
        return "I'm temporarily unavailable due to high usage. Please try again in a few minutes.";
      } else if (e.toString().contains('API key')) {
        return "I'm sorry, there's a configuration issue with my AI service. Please contact support.";
      } else {
        return "I'm sorry, I'm having technical difficulties right now. Please try again in a moment.";
      }
    }
  }

  void _handleUserInput(String input) async {
    if (_isProcessing) return;
    
    // Check if input is empty or just whitespace
    if (input.trim().isEmpty) {
      await _speak("I didn't hear anything. Could you please repeat what you said?");
      // After prompt, listen again after a short delay
      await Future.delayed(Duration(seconds: 1));
      if (_canListen() && !_isPaused) _listen();
      return;
    }
    
    // Check if input is too short (likely a misheard word)
    if (input.trim().length < 2) {
      await _speak("I heard something but it was very short. Could you please speak more clearly?");
      // After prompt, listen again after a short delay
      await Future.delayed(Duration(seconds: 1));
      if (_canListen() && !_isPaused) _listen();
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _state = AssistantState.processing;
    });

    try {
      // Check if user wants to share a photo
      if (input.toLowerCase().contains('photo') || 
          input.toLowerCase().contains('picture') || 
          input.toLowerCase().contains('image') ||
          input.toLowerCase().contains('camera')) {
        
        await _speak("I can help you analyze photos. Would you like to take a photo or choose from your gallery?");
        _showImagePicker();
        return;
      }

      // Check for common speech recognition errors
      if (_isLikelySpeechError(input)) {
        await _speak("I'm not sure I understood that correctly. Could you please repeat what you said?");
        // After prompt, listen again after a short delay
        await Future.delayed(Duration(seconds: 1));
        if (_canListen()) _listen();
        return;
      }

      // Send to Gemini API for natural conversation
      String response = await _sendToGemini(input);
      
      // Check if response is empty or error-like
      if (response.trim().isEmpty) {
        await _speak("I'm sorry, I didn't get a proper response. Let me try again. Could you please repeat your question?");
        return;
      }
      
      // Check if the query is about searching for doctors, hospitals, or pharmacies
      bool isSearchQuery = input.toLowerCase().contains('search') || 
                          input.toLowerCase().contains('find') || 
                          input.toLowerCase().contains('looking for') || 
                          input.toLowerCase().contains('where') || 
                          input.toLowerCase().contains('nearby');
                          
      bool isHealthcareQuery = input.toLowerCase().contains('doctor') || 
                              input.toLowerCase().contains('hospital') || 
                              input.toLowerCase().contains('pharmacy') || 
                              input.toLowerCase().contains('clinic') || 
                              input.toLowerCase().contains('medical');
      
      // If it's a search query for healthcare facilities, ensure results are displayed
      if (isSearchQuery && isHealthcareQuery) {
        if (input.toLowerCase().contains('doctor') || input.toLowerCase().contains('specialist')) {
          response += "\n\nI'll show you nearby doctors now.";
          // TODO: Implement _showNearbyDoctors() method to display a list of nearby doctors
          // This should use PlacesService or a similar geolocation service to fetch and display results
        } else if (input.toLowerCase().contains('hospital') || input.toLowerCase().contains('clinic')) {
          response += "\n\nI'll show you nearby hospitals now.";
          // TODO: Implement _showNearbyHospitals() method to display a list of nearby hospitals
          // This should use PlacesService or a similar geolocation service to fetch and display results
        } else if (input.toLowerCase().contains('pharmacy') || input.toLowerCase().contains('drug')) {
          response += "\n\nI'll show you nearby pharmacies now.";
          // TODO: Implement _showNearbyPharmacies() method to display a list of nearby pharmacies
          // This should use PlacesService or a similar geolocation service to fetch and display results
        }
      }
      
      // Check if Gemini suggests taking a photo
      if (response.toLowerCase().contains('photo') || 
          response.toLowerCase().contains('picture') || 
          response.toLowerCase().contains('image')) {
        
        // Add a prompt to ask for photo
        response += "\n\nWould you like to share a photo for better analysis?";
      }
      
      await _speak(response);
      
    } catch (e) {
      print('Error processing user input: $e');
      await _speak("I'm sorry, I'm having trouble processing your request right now. Please try again.");
    } finally {
      setState(() {
        _isProcessing = false;
        _state = AssistantState.conversation;
      });
      // Do not call _listen() here; let TTS completion handler handle it
    }
  }

  // Check if the input is likely a speech recognition error
  bool _isLikelySpeechError(String input) {
    String lowerInput = input.toLowerCase();
    
    // Common speech recognition errors
    List<String> errorPatterns = [
      'um', 'uh', 'ah', 'er', 'hmm',
      'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
      'is', 'are', 'was', 'were', 'be', 'been', 'being',
      'have', 'has', 'had', 'do', 'does', 'did',
      'will', 'would', 'could', 'should', 'may', 'might',
      'this', 'that', 'these', 'those',
      'i', 'you', 'he', 'she', 'it', 'we', 'they',
      'me', 'him', 'her', 'us', 'them',
      'my', 'your', 'his', 'her', 'its', 'our', 'their',
      'mine', 'yours', 'his', 'hers', 'ours', 'theirs'
    ];
    
    // If input is just common words, it's likely an error
    List<String> words = lowerInput.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length <= 2) {
      int errorWordCount = words.where((word) => errorPatterns.contains(word)).length;
      if (errorWordCount >= words.length * 0.8) { // 80% are error words
        return true;
      }
    }
    
    // Check for repeated words (common speech recognition error)
    if (words.length > 1) {
      for (int i = 1; i < words.length; i++) {
        if (words[i] == words[i-1]) {
          return true;
        }
      }
    }
    
    return false;
  }

  String _buildConversationContext() {
    if (_history.isEmpty) return "This is the start of our conversation.";
    
    // Capture the last up to 100 messages for context (most recent first)
    int startIndex = _history.length > 100 ? _history.length - 100 : 0;
    List<Map<String, String>> recentHistory = _history.sublist(startIndex);

    StringBuffer buffer = StringBuffer();
    buffer.writeln("Recent conversation:");
    for (var message in recentHistory) {
      String role = message['role'] == 'user' ? 'User' : 'Assistant';
      buffer.writeln("$role: ${message['text']}");
    }
    
    return buffer.toString();
  }

  void _updateConversationContext(String userInput, String aiResponse) {
    // Keep history size manageable (retain last 100 messages)
    if (_history.length > 200) {
      _history.removeRange(0, _history.length - 100);
    }
  }

  void _showImagePicker() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt),
              title: Text('Take a photo'),
              onTap: () async {
                Navigator.pop(context);
                await _processImageFromCamera();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library),
              title: Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _processImageFromGallery();
              },
            ),
            ListTile(
              leading: Icon(Icons.close),
              title: Text('Skip'),
              onTap: () {
                Navigator.pop(context);
                if (!_isPaused) _listen();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processImageFromCamera() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.camera);
      if (picked != null) {
        await _analyzeImage(File(picked.path), "photo taken with camera");
      } else {
        if (!_isPaused) _listen();
      }
    } catch (e) {
      await _speak("Sorry, I couldn't access the camera. Please try again or choose from gallery.");
      if (!_isPaused) _listen();
    }
  }

  Future<void> _processImageFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        await _analyzeImage(File(picked.path), "photo from gallery");
      } else {
        if (!_isPaused) _listen();
      }
    } catch (e) {
      await _speak("Sorry, I couldn't access the gallery. Please try again.");
      if (!_isPaused) _listen();
    }
  }

  Future<void> _analyzeImage(File imageFile, String source) async {
    setState(() {
      _isProcessing = true;
      _state = AssistantState.processing;
    });

    try {
      await _speak("Analyzing the $source. Please wait...");
      
      String analysis = await _gemini.analyzeSymptoms(
        description: "Please analyze this medical image and provide a detailed assessment. This could be a symptom photo, medication, rash, wound, or other medical condition.",
        imageFile: imageFile,
        imageAttached: true,
      );
      
      await _speak(analysis);
      
    } catch (e) {
      await _speak("I'm sorry, I couldn't analyze the image properly. Please try again or describe what you see.");
      print('Error analyzing image: $e');
    } finally {
      setState(() {
        _isProcessing = false;
        _state = AssistantState.conversation;
      });
    }
  }

  void _addMessage(Map<String, String> msg) {
    setState(() {
      _history.add(msg);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel all timers
    _autoRecoveryTimer?.cancel();
    _healthCheckTimer?.cancel();
    _connectionCheckTimer?.cancel();
    
    // Cancel connectivity subscription
    _connectivitySubscription.cancel();
    
    // Stop all operations
    try {
      _speech.stop();
    } catch (e) {
      // Ignore dispose errors
    }
    try {
      _tts.stop();
    } catch (e) {
      // Ignore dispose errors
    }
    
    _orbGlowController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Modern blurred glass background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryColor.withOpacity(0.7),
                  AppColors.accentColor.withOpacity(0.5),
                  Colors.white.withOpacity(0.1),
                ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
          // Decorative blurred circles
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryColor.withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withOpacity(0.12),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentColor.withOpacity(0.13),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentColor.withOpacity(0.10),
                    blurRadius: 80,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          // Main chat content
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: 16),
                // Top bar with settings and counters
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _showVoiceSettings,
                        icon: Icon(Icons.settings_voice, color: Colors.white, size: 28),
                        tooltip: 'Voice Settings',
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                        children: [
                          // Connection status
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isConnected ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isConnected ? Icons.wifi : Icons.wifi_off,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  _isConnected ? 'Online' : 'Offline',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Montserrat'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          // Session counter
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Sessions: $_sessionCount',
                              style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Montserrat'),
                            ),
                          ),
                          SizedBox(width: 8),
                          // Success rate
                          if (_successfulInteractions > 0)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Success: $_successfulInteractions',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Montserrat'),
                              ),
                            ),
                          SizedBox(width: 8),
                          // Error counter
                          if (_errorCount > 0)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Errors: $_errorCount',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Montserrat'),
                              ),
                            ),
                          SizedBox(width: 8),
                          // Recovery mode indicator
                          if (_isInRecoveryMode)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Recovering...',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Montserrat'),
                              ),
                            ),
                          SizedBox(width: 8),
                          IconButton(
                            onPressed: _manualResetVoiceAssistant,
                            icon: Icon(Icons.refresh, color: Colors.white, size: 26),
                            tooltip: 'Reset Voice Assistant',
                          ),
                        ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                // Chat history area
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: _history.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.medical_services,
                                        size: 64,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      SizedBox(height: 16),
                                      Text(
                                        'AidX Health Assistant',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Start talking to get medical advice',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 15,
                                          fontFamily: 'Montserrat',
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  padding: EdgeInsets.all(20),
                                  itemCount: _history.length,
                                  itemBuilder: (context, index) {
                                    final message = _history[index];
                                    final isUser = message['role'] == 'user';
                                    final isError = message['role'] == 'ai' && message['text'] != null && message['text']!.toLowerCase().contains('error');
                                    return Container(
                                      margin: EdgeInsets.only(bottom: 16),
                                      child: Row(
                                        mainAxisAlignment: isUser
                                            ? MainAxisAlignment.end
                                            : MainAxisAlignment.start,
                                        children: [
                                          if (!isUser) ...[
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                gradient: RadialGradient(
                                                  colors: [
                                                    (isError ? Colors.redAccent : AppColors.primaryColor).withOpacity(0.85),
                                                    (isError ? Colors.redAccent : AppColors.primaryColor).withOpacity(0.25),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(18),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: (isError ? Colors.redAccent : AppColors.primaryColor).withOpacity(0.55),
                                                    blurRadius: 16,
                                                    spreadRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                isError ? Icons.error : Icons.medical_services,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                          ],
                                          Flexible(
                                            child: Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 18,
                                                vertical: 14,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: RadialGradient(
                                                        colors: [
                                                    (isError ? Colors.redAccent : AppColors.primaryColor).withOpacity(0.9),
                                                    (isError ? Colors.redAccent : AppColors.primaryColor).withOpacity(0.3),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(18),
                                                boxShadow: [
                                                    BoxShadow(
                                                    color: (isError ? Colors.redAccent : AppColors.primaryColor).withOpacity(0.6),
                                                    blurRadius: 20,
                                                    spreadRadius: 4,
                                                    ),
                                                ],
                                              ),
                                              child: Text(
                                                message['text'] ?? '',
                                                style: TextStyle(
                                                  color: isError ? Colors.redAccent : Colors.white,
                                                  fontSize: 15,
                                                  fontFamily: 'Montserrat',
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (isUser) ...[
                                            SizedBox(width: 10),
                                            Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                gradient: RadialGradient(
                                                  colors: [
                                                    Colors.white.withOpacity(0.9),
                                                    Colors.white.withOpacity(0.2),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(18),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.white.withOpacity(0.6),
                                                    blurRadius: 16,
                                                    spreadRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                      // Loading indicator overlay
                      if (_isProcessing)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                                      strokeWidth: 5,
                                    ),
                                  ),
                                  SizedBox(height: 18),
                                  Text(
                                    'Consulting AI...',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 16,
                                      fontFamily: 'Montserrat',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Live transcription overlay with smooth animation
                      Positioned(
                        bottom: 100,
                        left: 32,
                        right: 32,
                        child: AnimatedSwitcher(
                          duration: Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _isListening && _liveTranscript.isNotEmpty
                              ? Container(
                                  key: ValueKey(_liveTranscript),
                                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    _liveTranscript,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontFamily: 'Montserrat',
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              : SizedBox.shrink(),
                          ),
                        ),
                      // Retry button if last AI response was an error
                      if (_history.isNotEmpty && _history.last['role'] == 'ai' && _history.last['text'] != null && _history.last['text']!.toLowerCase().contains('error'))
                        Positioned(
                          bottom: 24,
                          right: 24,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : () {
                              // Retry last user input
                              if (_history.length >= 2 && _history[_history.length - 2]['role'] == 'user') {
                                final lastUserInput = _history[_history.length - 2]['text'];
                                if (lastUserInput != null) {
                                  _handleUserInput(lastUserInput);
                                }
                              }
                            },
                            icon: Icon(Icons.refresh, color: Colors.white),
                            label: Text('Retry', style: TextStyle(color: Colors.white, fontFamily: 'Montserrat')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Voice orb and manual input button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Voice orb
                      GestureDetector(
                        onTap: _isListening || _isProcessing ? null : _listen,
                        child: AnimatedBuilder(
                          animation: _orbGlowAnimation,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _isProcessing ? 0.5 : 1.0,
                              child: Transform.scale(
                                scale: 0.95 + 0.05 * _orbGlowAnimation.value,
                              child: Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      _getOrbColor().withOpacity(0.85),
                                      _getOrbColor().withOpacity(0.35),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getOrbColor().withOpacity(0.22 * _orbGlowAnimation.value),
                                      blurRadius: 24 * _orbGlowAnimation.value,
                                      spreadRadius: 7 * _orbGlowAnimation.value,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.18),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _getOrbIcon(),
                                  size: 44,
                                  color: Colors.white,
                                   ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 24),
                      // Pause/Resume button
                      Opacity(
                        opacity: _isProcessing ? 0.5 : 1.0,
                        child: FloatingActionButton(
                          onPressed: _isProcessing ? null : _togglePause,
                          backgroundColor: _isPaused ? Colors.orange : AppColors.primaryColor,
                          elevation: 6,
                          child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 28),
                          tooltip: _isPaused ? 'Resume' : 'Pause',
                        ),
                      ),
                      SizedBox(width: 16),
                      // Manual input floating action button
                      Opacity(
                        opacity: _isProcessing ? 0.5 : 1.0,
                        child: FloatingActionButton(
                          onPressed: _isProcessing ? null : _showManualInputDialog,
                          backgroundColor: AppColors.primaryColor,
                          elevation: 6,
                          child: Icon(Icons.keyboard, color: Colors.white, size: 28),
                          tooltip: 'Type a message',
                        ),
                      ),
                    ],
                  ),
                ),
                // Status text
                Container(
                  margin: EdgeInsets.only(bottom: 18),
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Montserrat',
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.13),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Add a manual input dialog for typed messages
  void _showManualInputDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String inputText = '';
        return AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.95),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Type your message', style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold)),
          content: TextField(
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            onChanged: (val) => inputText = val,
            decoration: InputDecoration(
              hintText: 'Enter your message...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(fontFamily: 'Montserrat')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (inputText.trim().isNotEmpty) {
                  _addMessage({'role': 'user', 'text': inputText.trim()});
                  _handleUserInput(inputText.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Send', style: TextStyle(fontFamily: 'Montserrat', color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Toggle pause functionality
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    
    if (_isPaused) {
      // Stop listening and speaking when paused
      _speech.stop();
      _tts.stop();
      setState(() {
        _isListening = false;
        _isSpeaking = false;
      });
    } else {
      // Resume listening when unpaused
      if (_canListen()) {
        _listen();
      }
    }
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryColor.withOpacity(0.8),
            AppColors.secondaryColor.withOpacity(0.6),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        // Chat history
        Expanded(
          child: Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _history.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.medical_services,
                            size: 64,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Your Health Assistant',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start talking to get medical advice',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        final message = _history[index];
                        final isUser = message['role'] == 'user';
                        return Container(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: isUser
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              if (!isUser) ...[
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.medical_services,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? AppColors.primaryColor
                                        : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    message['text'] ?? '',
                                    style: TextStyle(
                                      color: isUser ? Colors.white : Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              if (isUser) ...[
                                SizedBox(width: 8),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
        // Voice orb
        Container(
          margin: EdgeInsets.all(16),
          child: GestureDetector(
            onTap: _isListening ? null : _listen,
            child: AnimatedBuilder(
              animation: _orbGlowAnimation,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _getOrbColor().withOpacity(0.8),
                        _getOrbColor().withOpacity(0.4),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getOrbColor().withOpacity(0.3 * _orbGlowAnimation.value),
                        blurRadius: 20 * _orbGlowAnimation.value,
                        spreadRadius: 5 * _orbGlowAnimation.value,
                      ),
                    ],
                  ),
                  child: Icon(
                    _getOrbIcon(),
                    size: 48,
                    color: Colors.white,
                  ),
                );
              },
            ),
          ),
        ),
        // Status text
        Container(
          margin: EdgeInsets.only(bottom: 16),
          child: Text(
            _getStatusText(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Color _getOrbColor() {
    if (_isResetting) return Colors.orange;
    if (_errorMsg != null) return Colors.red;
    if (_isProcessing) return Colors.blue;
    if (_isSpeaking) return Colors.green;
    if (_isListening) return Colors.red;
    return AppColors.primaryColor;
  }

  IconData _getOrbIcon() {
    if (_isResetting) return Icons.refresh;
    if (_errorMsg != null) return Icons.error;
    if (_isProcessing) return Icons.hourglass_empty;
    if (_isSpeaking) return Icons.volume_up;
    if (_isListening) return Icons.mic;
    return Icons.mic_none;
  }

  String _getStatusText() {
    if (_isPaused) return 'Paused - Tap play to resume';
    if (_isInRecoveryMode) return 'Reconnecting...';
    if (_isResetting) return 'Resetting voice assistant...';
    if (!_isConnected) return 'No internet connection';
    if (_errorMsg != null) return 'Error: Tap to retry';
    if (_isProcessing) return 'Processing your request...';
    if (_isSpeaking) return 'Speaking...';
    if (_isListening) return 'Listening...';
    return 'Tap to speak';
  }
} 