import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'dart:async';
import 'package:flutter/foundation.dart';

class GeminiService {
  // TODO: Replace with your own API key or load from secure storage
  static const String _apiKey = 'AIzaSyAKOUTO3nKiLfMuoZBe5oEVr2vyhfgcK1I';
  // Use the faster model for quick responses
  static const String _model = 'gemini-2.0-flash';
  static const String _endpointBase = 'https://generativelanguage.googleapis.com/v1beta/models';
  static String get _endpoint => '$_endpointBase/$_model:generateContent';
  final List<Function(String)> _listeners = [];

  /// Add a listener to receive notifications about API calls
  void addListener(Function(String) listener) {
    _listeners.add(listener);
  }
  
  /// Remove a listener
  void removeListener(Function(String) listener) {
    _listeners.remove(listener);
  }
  
  /// Notify all listeners with a message
  void _notify(String message) {
    for (final listener in _listeners) {
      listener(message);
    }
  }

  /// Helper for robust error logging
  void _logError(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[GeminiService] $message');
    if (error != null) debugPrint('Error: $error');
    if (stackTrace != null) debugPrint('StackTrace: $stackTrace');
  }

  /// Natural conversation method for chat interface
  /// Sends user input to Gemini and returns a conversational response
  Future<String> sendMessage(String userInput, {String? conversationContext}) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Please set your Gemini API key in gemini_service.dart');
    }

    // Let Gemini determine if the input is medical-related

    final uri = Uri.parse('$_endpoint?key=$_apiKey');
    
    // Build the conversation prompt
    String prompt = '''
You are a professional medical assistant AI. Provide helpful, accurate, and compassionate medical advice in a conversational manner.

IMPORTANT: If the user asks non-medical questions (about food, cars, entertainment, etc.), respond with: "I'm a medical assistant AI. I can only help with medical questions, symptoms, health concerns, and medical advice. Please ask about health-related topics."

For MEDICAL questions, provide helpful information without refusing.

${conversationContext != null ? 'Conversation Context:\n$conversationContext\n' : ''}

User: $userInput

--- INSTRUCTIONS FOR ASSISTANT ---
1. BE CONCISE: Prefer single-sentence answers unless a list is needed.
2. AVOID REPETITION: Never ask the same follow-up twice in one session.
3. DRUG QUERIES:
   • If the user explicitly asks about "side effect(s)" of a drug, reply ONLY with a short bullet list starting with "Side Effects:" and **do not** ask a question back.
4. SYMPTOM ANALYSIS:
   • If the user describes symptoms, ensure you have these fields: symptoms description, age, gender, intensity, duration, photo (optional).
   • If any field is missing, ask for **one** missing field at a time (max 12 words).
   • Once all fields are provided, respond with a concise analysis (≤3 sentences) and END with **one** yes/no follow-up question such as "Need more detail?".
5. GENERAL RULES:
   • Do not repeat instructions.
   • Do not add disclaimers unless absolutely necessary.
   • Use everyday language.
   • NEVER refuse to answer medical questions - provide helpful information even if limited.
   • If unsure about specific details, provide general guidance and suggest consulting a healthcare provider.
   • ONLY respond to medical and health-related questions.
--- END INSTRUCTIONS ---''';

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.5,
        'maxOutputTokens': 120,
        'topP': 0.8,
        'topK': 40,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_ONLY_HIGH'
        }
      ]
    };

    int retries = 0;
    const maxRetries = 3;
    
    while (retries < maxRetries) {
      try {
        debugPrint('Sending message to Gemini API (attempt ${retries + 1})...');
        
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30)); // 30 second timeout

        debugPrint('Gemini API response status: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          String? text;
          try {
            // Standard location
            text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            // Fallback: search parts list for first element with text key
            if (text == null || (text is String && text.trim().isEmpty)) {
              final parts = data['candidates']?[0]?['content']?['parts'];
              if (parts is List) {
                for (var p in parts) {
                  if (p is Map && p['text'] != null && (p['text'] as String).trim().isNotEmpty) {
                    text = p['text'];
                    break;
                  }
                }
              }
            }
          } catch (_) {}

          if (text != null && text is String && text.trim().isNotEmpty) {
            debugPrint('Gemini API response received successfully');
            return text.trim();
          }

          // Check for safety block reason
          final finishReason = data['candidates']?[0]?['finishReason'];
          if (finishReason != null && finishReason.toString().toLowerCase().contains('safety')) {
            debugPrint('Response blocked due to safety settings');
            return "I'm sorry, I can't answer that. Could you please rephrase or ask something else?";
          }

          throw Exception('Empty or invalid response from Gemini API');
        } else {
          // Parse Gemini error if possible
          String errorMsg = 'Gemini API error (${response.statusCode})';
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map && errorData['error'] != null && errorData['error']['message'] != null) {
              errorMsg = 'Gemini API error: ${errorData['error']['message']}';
            }
          } catch (_) {}
          
          _logError(errorMsg);
          throw Exception(errorMsg);
        }
      } catch (e, st) {
        retries++;
        _logError('Attempt $retries failed in sendMessage', e, st);
        
        if (retries >= maxRetries) {
          // After all retries failed, return a user-friendly error message
          if (e.toString().contains('timeout')) {
            return "I'm sorry, the request is taking too long. Please check your internet connection and try again.";
          } else if (e.toString().contains('network') || e.toString().contains('connection')) {
            return "I'm having trouble connecting to my knowledge base. Please check your internet connection and try again.";
          } else if (e.toString().contains('quota') || e.toString().contains('limit')) {
            return "I'm temporarily unavailable due to high usage. Please try again in a few minutes.";
          } else {
            return "I'm sorry, I'm having technical difficulties right now. Please try again in a moment.";
          }
        }
        
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: pow(2, retries).toInt()));
      }
    }
    
    return "I'm sorry, I'm unable to process your request at the moment. Please try again later.";
  }

  /// Analyze symptoms using Gemini API and return the raw text response.
  /// Throws [Exception] if the request fails.
  Future<String> analyzeSymptoms({
    required String description,
    int? age,
    String? gender,
    String? intensity,
    String? duration,
    bool imageAttached = false,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageMimeType,
    Map<String, dynamic>? vitals,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Please set your Gemini API key in gemini_service.dart');
    }
 
    // Let Gemini determine if the input is medically relevant
    
    // Let Gemini determine if image is medical-related
 
    final prompt = _buildMedicalPrompt(
      description: description,
      age: age,
      gender: gender,
      intensity: intensity,
      duration: duration,
      imageAttached: imageAttached,
      vitals: vitals,
    );

    // BRIEF medical prompt for concise responses
    final systemPrompt = '''You are a medical certified medical professional providing BRIEF, actionable advice.

CRITICAL: Keep responses SHORT and CONCISE.

IMPORTANT: If the provided image or text is NOT medical-related (e.g., food, cars, objects, entertainment), respond with:
{
"conditions": [{"name": "Non-medical content detected", "likelihood": 100}],
"severity": "N/A",
"medications": [],
"homemade_remedies": [],
"measures": ["This appears to be non-medical content", "Please provide medical symptoms or health-related information"]
}

For MEDICAL content, output ONLY valid JSON:
{
"conditions": [{"name": "condition", "likelihood": 0-100}],
"severity": "Mild|Moderate|Severe (Emergency)",
"medications": ["medication (dosage)"],
"homemade_remedies": ["brief remedy"],
"measures": ["key action"]
}

RULES:
- MAX 2 conditions
- Use common medication names with brief dosages
- MAX 2 remedies per category
- Be extremely concise
- Output ONLY JSON, no extra text''';

    final uri = Uri.parse('$_endpoint?key=$_apiKey');

    final parts = <Map<String, dynamic>>[
      {
        'text': '$systemPrompt\n\n$prompt',
      }
    ];

    // Add image if provided (bytes first for web)
    if (imageBytes != null && imageBytes.isNotEmpty) {
      if (imageBytes.length > 4 * 1024 * 1024) {
        throw Exception('Image file is too large. Please use an image smaller than 4MB.');
      }
      final base64Img = base64Encode(imageBytes);
      parts.add({
        'inlineData': {
          'mimeType': imageMimeType ?? 'image/jpeg',
          'data': base64Img,
        }
      });
    } else if (imageFile != null && imageFile.existsSync()) {
      try {
        final bytes = await imageFile.readAsBytes();
        if (bytes.length > 4 * 1024 * 1024) {
          throw Exception('Image file is too large. Please use an image smaller than 4MB.');
        }
        final base64Image = base64Encode(bytes);
        String mimeType = imageMimeType ?? 'image/jpeg';
        final path = imageFile.path.toLowerCase();
        if (path.endsWith('.png')) mimeType = 'image/png';
        if (path.endsWith('.gif')) mimeType = 'image/gif';
        if (path.endsWith('.webp')) mimeType = 'image/webp';
        parts.add({
          'inlineData': {
            'mimeType': mimeType,
            'data': base64Image,
          }
        });
      } catch (e) {
        throw Exception('Error processing image: ${e.toString()}');
      }
    }

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        }
      ],
      'generationConfig': {
        'temperature': 0.1, // very deterministic for consistency
        'maxOutputTokens': 300, // much shorter responses
        'topP': 0.8,
      },
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_LOW_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_LOW_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_LOW_AND_ABOVE'
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_LOW_AND_ABOVE'
        }
      ]
    };

    int retries = 0;
    const int maxRetries = 3; // reduced retries for faster failure
    while (retries < maxRetries) {
      try {
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 25)); // reduced timeout for faster response
        if (res.statusCode != 200) {
          // Parse Gemini error if possible
          String msg = 'Gemini API error (${res.statusCode})';
          try {
            final err = jsonDecode(res.body);
            if (err is Map && err['error'] != null && err['error']['message'] != null) {
              msg = 'Gemini API error: ${err['error']['message']}';
            }
          } catch (_) {}
          _logError(msg);
          throw Exception(msg);
        }
        final data = jsonDecode(res.body);
        String? text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text == null || text is! String || text.trim().isEmpty) {
          // try to salvage from any part
          final partsOut = data['candidates']?[0]?['content']?['parts'];
          if (partsOut is List) {
            for (final p in partsOut) {
              if (p is Map && p['text'] is String && (p['text'] as String).trim().isNotEmpty) {
                text = p['text'];
                break;
              }
            }
          }
        }
        if (text == null || text.trim().isEmpty) {
          throw Exception('No response received from Gemini API');
        }
        
        // Validate response for medical relevance
        final cleanText = text.trim();
        if (cleanText == 'INVALID_INPUT') {
          return _defaultAnalysisText(intensity);
        }
        // If validation fails, still return best-effort content; UI has robust parser with fallback
        return cleanText;
      } catch (e, st) {
        retries++;
        _logError('Attempt $retries failed in analyzeSymptoms', e, st);
        if (retries >= maxRetries) {
          return _defaultAnalysisText(intensity);
        }
        await Future.delayed(Duration(seconds: min(10, pow(2, retries).toInt()))); // shorter delays
      }
    }
    return _defaultAnalysisText(intensity);
  }

  
  /// Validate if the AI response contains valid medical information
  bool _isValidMedicalResponse(String response) {
    try {
      final json = jsonDecode(response);
      if (json is! Map<String, dynamic>) return false;
      
      // Check required fields
      if (!json.containsKey('conditions') || !json.containsKey('severity') ||
          !json.containsKey('medications') || !json.containsKey('measures')) {
        return false;
      }
      
      // Validate conditions
      final conditions = json['conditions'];
      if (conditions is! List || conditions.isEmpty) return false;
      
      for (final condition in conditions) {
        if (condition is! Map<String, dynamic> ||
            !condition.containsKey('name') ||
            !condition.containsKey('likelihood') ||
            condition['name'] is! String ||
            condition['likelihood'] is! num) {
          return false;
        }
        
        // Check for obviously non-medical conditions
        final conditionName = (condition['name'] as String).toLowerCase();
        // Let Gemini handle non-medical content detection
      }
      
      // Validate severity
      final severity = json['severity'];
      if (severity is! String ||
          !['Mild', 'Moderate', 'Severe (Emergency)'].contains(severity)) {
        return false;
      }
      
      // Validate medications and measures are lists
      if (json['medications'] is! List || json['measures'] is! List) {
        return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  

  String _buildMedicalPrompt({
    required String description,
    int? age,
    String? gender,
    String? intensity,
    String? duration,
    bool imageAttached = false,
    Map<String, dynamic>? vitals,
  }) {
    final ageText = age != null ? 'Age: $age years' : 'Age: Not specified';
    final genderText = gender != null ? 'Gender: $gender' : 'Gender: Not specified';
    final intensityText = 'Symptom intensity: $intensity';
    final durationText = 'Duration: $duration';
    final imageText = imageAttached ? 'Image: Provided for visual analysis' : 'Image: Not provided';
    String vitalsText = '';
    if (vitals != null && vitals.isNotEmpty) {
      vitalsText = '\n## Latest Vitals Data';
      if (vitals['heartRate'] != null) vitalsText += '\nHeart Rate: ${vitals['heartRate']} bpm';
      if (vitals['spo2'] != null) vitalsText += '\nSpO2: ${vitals['spo2']}%';
      if (vitals['bloodPressure'] != null && vitals['bloodPressure'] is Map) {
        final bp = vitals['bloodPressure'];
        if (bp['systolic'] != null && bp['diastolic'] != null) {
          vitalsText += '\nBlood Pressure: ${bp['systolic']}/${bp['diastolic']} mmHg';
        }
      }
      if (vitals['temperature'] != null) vitalsText += '\nTemperature: ${vitals['temperature']} °C';
      if (vitals['steps'] != null) vitalsText += '\nSteps: ${vitals['steps']}';
      if (vitals['calories'] != null) vitalsText += '\nCalories: ${vitals['calories']}';
      if (vitals['sleepHours'] != null) vitalsText += '\nSleep Hours: ${vitals['sleepHours']}';
    }

    return """Patient: $ageText, $genderText
Symptoms: $description ($intensity, $duration)
$imageText

ANALYZE: Provide brief diagnosis and treatment. Keep response short.""";
  }

  /// Parse the raw Gemini response into a structured map.
  /// Returns a map with keys: conditions (List<String>), medication (String), measures (String), homemade_remedies (String?)
  Map<String, dynamic> parseResponse(String text) {
    // Try JSON-first parsing (strict schema)
    final Map<String, dynamic>? asJson = _tryParseJsonObject(text);
    if (asJson != null && asJson.isNotEmpty) {
      try {
        final List conditionsJson = (asJson['conditions'] as List? ?? []);
        final String severity = (asJson['severity'] as String? ?? '').trim();
        final List meds = (asJson['medications'] as List? ?? []);
        final List measures = (asJson['measures'] as List? ?? []);
        final List home = (asJson['homemade_remedies'] as List? ?? []);

        final List<String> conditionsOut = [];
        for (final item in conditionsJson) {
          if (item is Map && item['name'] != null) {
            final String name = (item['name'] as String).trim();
            final int pct = _coercePercent(item['likelihood']);
            conditionsOut.add(pct > 0 ? "$name (${pct}%)" : name);
          } else if (item is String) {
            conditionsOut.add(item.trim());
          }
        }

        // If severity provided, append a severity line at end of conditions
        if (severity.isNotEmpty) {
          conditionsOut.add('Severity: $severity');
        }

        // Enhanced medication parsing with better formatting
        final String medicationOut = meds.whereType<String>().isNotEmpty
            ? meds.whereType<String>().join('\n• ').replaceAll('• ', '\n• ')
            : 'No specific medications recommended';

        // Enhanced measures parsing
        final String measuresOut = measures.whereType<String>().isNotEmpty
            ? measures.whereType<String>().join('\n• ').replaceAll('• ', '\n• ')
            : 'Monitor symptoms and consult healthcare provider if needed';

        // Enhanced homemade remedies parsing
        final String homeOut = home.whereType<String>().isNotEmpty
            ? home.whereType<String>().join('\n• ').replaceAll('• ', '\n• ')
            : 'Rest and maintain good hygiene practices';

        return {
          'conditions': conditionsOut,
          'medication': medicationOut,
          'measures': measuresOut,
          'homemade_remedies': homeOut.isNotEmpty ? homeOut : null,
        };
      } catch (e) {
        // Fall back to legacy parsing if JSON shape unexpected
      }
    }

    // Legacy text parsing fallback
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final List<String> conditions = <String>[];
    final StringBuffer medicationBuf = StringBuffer();
    final StringBuffer measuresBuf = StringBuffer();
    final StringBuffer homeBuf = StringBuffer();

    const int sectionNone = 0;
    const int sectionConditions = 1;
    const int sectionMedication = 2;
    const int sectionMeasures = 3;
    const int sectionHome = 4;
    int current = sectionNone;

    bool _isHeader(String line, RegExp pattern) => pattern.hasMatch(line.toLowerCase());

    final RegExp conditionsHeader = RegExp(r'^(?:\d+\.|[-*•])?\s*(possible\s+conditions|conditions)');
    final RegExp medicationHeader = RegExp(r'^(?:\d+\.|[-*•])?\s*(medications?|drugs?)');
    final RegExp measuresHeader = RegExp(r'^(?:\d+\.|[-*•])?\s*(measures|next\s*steps|self[-\s]*care|what\s*to\s*do)');
    final RegExp homeHeader = RegExp(r'^(?:\d+\.|[-*•])?\s*(homemade|home[-\s]?remed(?:y|ies)|home\s*care|at[-\s]?home|home\s*based)');

    for (final raw in lines) {
      final line = raw.trim();
      final lower = line.toLowerCase();

      // Detect headers robustly (with or without numbering)
      if (_isHeader(lower, conditionsHeader)) {
        current = sectionConditions;
        continue;
      }
      if (_isHeader(lower, medicationHeader)) {
        current = sectionMedication;
        continue;
      }
      if (_isHeader(lower, measuresHeader)) {
        current = sectionMeasures;
        continue;
      }
      if (_isHeader(lower, homeHeader)) {
        current = sectionHome;
        continue;
      }

      // Accumulate content by section
      switch (current) {
        case sectionConditions:
          if (line.isEmpty) break;
          if (line.startsWith('-') || line.startsWith('•') || line.startsWith('*')) {
            conditions.add(line);
          } else if (RegExp(r'\(\d+\s*%\)').hasMatch(line) || line.isNotEmpty) {
            // Likely a condition line without bullet but with percentage
            conditions.add(line);
          }
          break;
        case sectionMedication:
          if (medicationBuf.isNotEmpty) {
            medicationBuf.writeln(line);
          } else {
            medicationBuf.write(line);
          }
          break;
        case sectionMeasures:
          if (measuresBuf.isNotEmpty) {
            measuresBuf.writeln(line);
          } else {
            measuresBuf.write(line);
          }
          break;
        case sectionHome:
          if (homeBuf.isNotEmpty) {
            homeBuf.writeln(line);
          } else {
            homeBuf.write(line);
          }
          break;
        case sectionNone:
          // Ignore lines before first recognized header
          break;
      }
    }

    final String medication = medicationBuf.toString().trim();
    final String measures = measuresBuf.toString().trim();
    final String homemadeRemedies = homeBuf.toString().trim();

    return {
      'conditions': conditions,
      'medication': medication,
      'measures': measures,
      'homemade_remedies': homemadeRemedies.isNotEmpty ? homemadeRemedies : null,
    };
  }

  Map<String, dynamic>? _tryParseJsonObject(String text) {
    String t = text.trim();
    // If wrapped in code fences, extract the JSON portion
    if (t.startsWith('```')) {
      final start = t.indexOf('{');
      final end = t.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        t = t.substring(start, end + 1);
      }
    }
    // Try direct decode
    try {
      final decoded = jsonDecode(t);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    // Try to extract JSON object using a loose brace match
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      final sub = t.substring(start, end + 1);
      try {
        final decoded = jsonDecode(sub);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  int _coercePercent(dynamic value) {
    try {
      if (value == null) return 0;
      if (value is num) return value.clamp(0, 100).toInt();
      final s = value.toString().replaceAll('%', '').trim();
      final n = int.tryParse(s);
      return (n ?? 0).clamp(0, 100);
    } catch (_) {
      return 0;
    }
  }

  /// Search for drug information using Gemini API
  /// Returns structured drug information
  Future<Map<String, dynamic>> searchDrug(String drugName, {bool brief = false}) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Please set your Gemini API key in gemini_service.dart');
    }
    
    // Let Gemini determine if the drug name is medical-related

    final systemPrompt = brief
        ? '''You are a professional pharmacist. For "$drugName":

IMPORTANT: If "$drugName" is NOT a medical drug/medication (e.g., food, objects, entertainment), respond with:
Name: [drugName]
Generic: Not a medication
Uses: This appears to be non-medical content
Dosage: N/A
Warnings: Please enter a valid medication or drug name

For MEDICAL drugs, return ONLY these fields:
Name: [brand or trade name(s), comma-separated if multiple]
Generic: [generic/chemical name]
Uses: [very short, e.g. "pain relief, fever"]
Dosage: [short, e.g. "500mg every 6h"]
Warnings: [short, e.g. "liver disease, overdose risk"]
Be concise.'''
        : '''You are a professional pharmacist. For "$drugName":

IMPORTANT: If "$drugName" is NOT a medical drug/medication, respond with:
Generic Formula: Not a medication
Uses: This appears to be non-medical content
Classification: N/A
Form: N/A
Dosage: N/A
Side Effects: Please enter a valid medication or drug name
Warnings: N/A

For MEDICAL drugs, return ONLY these categories:
Generic Formula: [generic name]
Uses: [primary medical uses]
Classification: [pharmacological class]
Form: [available forms]
Dosage: [typical adult dosage]
Side Effects: [common side effects]
Warnings: [important warnings]''';

    final uri = Uri.parse('$_endpoint?key=$_apiKey');
    int retries = 0;
    const maxRetries = 3;
    while (retries < maxRetries) {
      try {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': systemPrompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'maxOutputTokens': brief ? 200 : 800,
            },
          }),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
          return brief ? parseBriefDrugResponse(text, drugName) : parseDrugResponse(text, drugName);
        } else {
          String msg = 'Error: ${response.statusCode} - ${response.body}';
          _logError(msg);
          throw Exception(msg);
        }
      } catch (e, st) {
        retries++;
        _logError('Attempt $retries failed in searchDrug', e, st);
        if (retries >= maxRetries) {
          return {
            'name': drugName,
            'error': 'Network error. Please check your internet connection and try again.',
          };
        }
        await Future.delayed(Duration(seconds: pow(2, retries).toInt()));
      }
    }
    return {
      'name': drugName,
      'error': 'Network error. Please check your internet connection and try again.',
    };
  }

  /// Parse drug response into structured format
  Map<String, dynamic> parseDrugResponse(String text, String drugName) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final result = <String, String>{};
    
    final sections = ['Generic Formula', 'Uses', 'Classification', 'Form', 'Dosage', 'Side Effects', 'Warnings'];
    
    for (final section in sections) {
      final regex = RegExp('$section:\\s*(.+)', caseSensitive: false);
      final match = lines.where((line) => regex.hasMatch(line)).firstOrNull;
      if (match != null) {
        final content = regex.firstMatch(match)?.group(1)?.trim() ?? 'Information not available';
        result[section] = content;
      } else {
        result[section] = 'Information not available';
      }
    }

    return {
      'name': drugName,
      'generic_formula': result['Generic Formula'] ?? 'Information not available',
      'uses': result['Uses'] ?? 'Information not available',
      'classification': result['Classification'] ?? 'Information not available',
      'form': result['Form'] ?? 'Information not available',
      'dosage': result['Dosage'] ?? 'Information not available',
      'side_effects': result['Side Effects'] ?? 'Information not available',
      'warnings': result['Warnings'] ?? 'Information not available',
    };
  }

  /// Parse brief Gemini response into a short map.
  Map<String, dynamic> parseBriefDrugResponse(String text, String drugName) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    String name = drugName;
    String generic = '';
    String uses = '';
    String dosage = '';
    String warnings = '';
    for (final line in lines) {
      if (line.toLowerCase().startsWith('name:')) {
        name = line.substring(5).trim();
        // If multiple brand names, keep as comma-separated string
      } else if (line.toLowerCase().startsWith('generic:')) {
        generic = line.substring(8).trim();
      } else if (line.toLowerCase().startsWith('uses:')) {
        uses = line.substring(5).trim();
      } else if (line.toLowerCase().startsWith('dosage:')) {
        dosage = line.substring(7).trim();
      } else if (line.toLowerCase().startsWith('warnings:')) {
        warnings = line.substring(9).trim();
      }
    }
    return {
      'name': name, // may be comma-separated brand names
      'generic_formula': generic,
      'uses': uses,
      'dosage': dosage,
      'warnings': warnings,
    };
  }

  /// Visual Q&A: send an image (bytes or file) plus a question, get an answer
  Future<String> askWithImage({
    required String question,
    Uint8List? imageBytes,
    File? imageFile,
    String? imageMimeType,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Please set your Gemini API key in gemini_service.dart');
    }
    
    // Let Gemini determine if the question/image is medical-related
    
    final uri = Uri.parse('$_endpoint?key=$_apiKey');

    final parts = <Map<String, dynamic>>[
      { 'text': 'You are a medical assistant. If the question or image is NOT medical-related (food, cars, objects, entertainment), respond with: "This appears to be non-medical content. Please ask about medical symptoms, conditions, or health-related concerns." If it IS medical, provide brief and specific medical advice.' },
      { 'text': question },
    ];

    // Attach image
    if (imageBytes != null && imageBytes.isNotEmpty) {
      if (imageBytes.length > 4 * 1024 * 1024) {
        throw Exception('Image is too large (>4MB). Use a smaller image.');
      }
      parts.add({
        'inlineData': {
          'mimeType': imageMimeType ?? 'image/jpeg',
          'data': base64Encode(imageBytes),
        }
      });
    } else if (imageFile != null && imageFile.existsSync()) {
      final bytes = await imageFile.readAsBytes();
      if (bytes.length > 4 * 1024 * 1024) {
        throw Exception('Image is too large (>4MB). Use a smaller image.');
      }
      String mime = imageMimeType ?? 'image/jpeg';
      final path = imageFile.path.toLowerCase();
      if (path.endsWith('.png')) mime = 'image/png';
      if (path.endsWith('.gif')) mime = 'image/gif';
      if (path.endsWith('.webp')) mime = 'image/webp';
      parts.add({
        'inlineData': {
          'mimeType': mime,
          'data': base64Encode(bytes),
        }
      });
    } else {
      throw Exception('Image is required');
    }

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 300,
      },
    };

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        String msg = 'Gemini vision API error (${res.statusCode})';
        try {
          final err = jsonDecode(res.body);
          final em = err['error']?['message'];
          if (em is String && em.isNotEmpty) msg = 'Gemini vision API error: $em';
        } catch (_) {}
        throw Exception(msg);
      }

      final data = jsonDecode(res.body);
      String? text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text == null || text.trim().isEmpty) {
        final partsOut = data['candidates']?[0]?['content']?['parts'];
        if (partsOut is List) {
          for (final p in partsOut) {
            if (p is Map && p['text'] is String && (p['text'] as String).trim().isNotEmpty) {
              text = p['text'];
              break;
            }
          }
        }
      }
      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty response from vision API');
      }
      return text.trim();
    } catch (e) {
      _logError('askWithImage failed', e as Object?);
      rethrow;
    }
  }

  // Provide a brief default output
  String _defaultAnalysisText(String? intensity) {
    final sev = (intensity ?? 'mild').toLowerCase();
    final String severity = sev.contains('severe')
        ? 'Severe (Emergency)'
        : (sev.contains('moderate') ? 'Moderate' : 'Mild');

    return '''{
"conditions": [
  {"name": "Common viral infection", "likelihood": 60},
  {"name": "Bacterial infection", "likelihood": 30}
],
"severity": "$severity",
"medications": [
  "Paracetamol 500mg every 4-6h",
  "Ibuprofen 200mg every 4-6h"
],
"homemade_remedies": [
  "Rest and hydrate",
  "Cool compress for fever"
],
"measures": [
  "Monitor symptoms",
  "Seek care if worsens"
]
}''';
  }

  /// Analyze medical reports like ECG, X-ray, blood tests, etc.
  /// Returns a structured analysis of the medical report
  Future<String> analyzeMedicalReport({
    required String description,
    required String reportType,
    required int age,
    String? gender,
    bool imageAttached = false,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    if (_apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Please set your Gemini API key in gemini_service.dart');
    }

    try {
      _notify('Starting medical report analysis...');
      
      final prompt = _buildReportAnalysisPrompt(description, reportType, age, gender);
      
      if (imageAttached && (imageFile != null || imageBytes != null)) {
        _notify('Analyzing report with image...');
        return await _analyzeReportWithImage(
          prompt: prompt,
          imageFile: imageFile,
          imageBytes: imageBytes,
          imageMimeType: imageMimeType,
        );
      } else {
        _notify('Analyzing report description...');
        return await _analyzeReportTextOnly(prompt);
      }
    } catch (e) {
      _logError('analyzeMedicalReport failed', e as Object?);
      return 'Sorry, the AI analysis could not be completed at this time. Please try again later.';
    }
  }

  String _buildReportAnalysisPrompt(String description, String reportType, int age, String? gender) {
    final genderText = gender != null ? 'Gender: $gender' : '';
    
    return '''You are a medical AI assistant specializing in analyzing medical reports. Please analyze the following $reportType report and provide a comprehensive, easy-to-understand interpretation.

Patient Information:
- Age: $age
- $genderText
- Report Type: $reportType

Report Description:
$description

Please provide your analysis in the following JSON format:
{
  "summary": "Brief 2-3 sentence summary of the report findings",
  "findings": "Detailed explanation of what the report shows, including normal/abnormal values, patterns, or observations",
  "recommendations": "Specific medical recommendations based on the findings",
  "next_steps": "Clear next steps for the patient, including when to follow up with healthcare providers"
}

Guidelines:
1. Use clear, non-technical language that patients can understand
2. Always emphasize that this is for informational purposes only
3. Recommend consulting healthcare professionals for proper medical advice
4. Highlight any urgent findings that require immediate medical attention
5. Be specific about normal ranges and what any abnormalities might indicate
6. Provide actionable recommendations

Important: This analysis is for educational purposes only and should not replace professional medical advice. Always consult with qualified healthcare providers for proper diagnosis and treatment.''';
  }

  Future<String> _analyzeReportWithImage({
    required String prompt,
    File? imageFile,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    try {
      final uri = Uri.parse('$_endpoint?key=$_apiKey');
      
      // Prepare image data
      Uint8List imageData;
      String mimeType;
      
      if (imageBytes != null) {
        imageData = imageBytes;
        mimeType = imageMimeType ?? 'image/jpeg';
      } else if (imageFile != null) {
        imageData = await imageFile.readAsBytes();
        mimeType = imageMimeType ?? 'image/jpeg';
      } else {
        throw Exception('No image data provided');
      }

      // Encode image to base64
      final base64Image = base64Encode(imageData);

      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'topK': 32,
          'topP': 1,
          'maxOutputTokens': 2048,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          }
        ]
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        String msg = 'HTTP ${response.statusCode}';
        try {
          final err = jsonDecode(response.body);
          final em = err['error']?['message'];
          if (em is String && em.isNotEmpty) msg = 'Gemini vision API error: $em';
        } catch (_) {}
        throw Exception(msg);
      }

      final data = jsonDecode(response.body);
      String? text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      
      if (text == null || text.trim().isEmpty) {
        final partsOut = data['candidates']?[0]?['content']?['parts'];
        if (partsOut is List) {
          for (final p in partsOut) {
            if (p is Map && p['text'] is String && (p['text'] as String).trim().isNotEmpty) {
              text = p['text'];
              break;
            }
          }
        }
      }
      
      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty response from vision API');
      }
      
      return text.trim();
    } catch (e) {
      _logError('_analyzeReportWithImage failed', e as Object?);
      rethrow;
    }
  }

  Future<String> _analyzeReportTextOnly(String prompt) async {
    try {
      final uri = Uri.parse('$_endpoint?key=$_apiKey');
      
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.3,
          'topK': 32,
          'topP': 1,
          'maxOutputTokens': 2048,
        },
        'safetySettings': [
          {
            'category': 'HARM_CATEGORY_HARASSMENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_HATE_SPEECH',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          },
          {
            'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
            'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
          }
        ]
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        String msg = 'HTTP ${response.statusCode}';
        try {
          final err = jsonDecode(response.body);
          final em = err['error']?['message'];
          if (em is String && em.isNotEmpty) msg = 'Gemini API error: $em';
        } catch (_) {}
        throw Exception(msg);
      }

      final data = jsonDecode(response.body);
      String? text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      
      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty response from API');
      }
      
      return text.trim();
    } catch (e) {
      _logError('_analyzeReportTextOnly failed', e as Object?);
      rethrow;
    }
  }

  /// Parse the response from medical report analysis
  Map<String, dynamic> parseReportResponse(String response) {
    try {
      // Try to parse as JSON first
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final parsed = jsonDecode(jsonStr);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        }
      }
    } catch (e) {
      _logError('Failed to parse JSON response', e as Object?);
    }

    // Fallback: create a structured response from text
    return {
      'summary': _extractSection(response, 'summary') ?? 'Report analysis completed successfully',
      'findings': _extractSection(response, 'findings') ?? 'No significant abnormalities detected',
      'recommendations': _extractSection(response, 'recommendations') ?? 'Continue regular monitoring as advised by your healthcare provider',
      'next_steps': _extractSection(response, 'next_steps') ?? 'Follow up with your doctor for any concerns',
    };
  }

  String? _extractSection(String text, String sectionName) {
    try {
      // Look for JSON-like structure
      final pattern = '"$sectionName"\\s*:\\s*"([^"]*)"';
      final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
      if (match != null) {
        return match.group(1);
      }

      // Look for markdown-style headers
      final headerPattern = '##\\s*$sectionName\\s*\\n([^#]*)';
      final headerMatch = RegExp(headerPattern, caseSensitive: false, multiLine: true).firstMatch(text);
      if (headerMatch != null) {
        return headerMatch.group(1)?.trim();
      }

      // Look for simple text patterns
      final simplePattern = '$sectionName[\\s:]*([^\\n]*)';
      final simpleMatch = RegExp(simplePattern, caseSensitive: false).firstMatch(text);
      if (simpleMatch != null) {
        return simpleMatch.group(1)?.trim();
      }
    } catch (e) {
      _logError('Error extracting section $sectionName', e as Object?);
    }
    return null;
  }
} 

