import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

class TelegramService {
  // Singleton
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  String get _token => AppConstants.telegramBotToken;
  String get _chatId => AppConstants.telegramChatId;

  bool get _isConfigured =>
      _token.isNotEmpty && !_token.contains('YOUR_TELEGRAM_BOT_TOKEN') &&
      _chatId.isNotEmpty && !_chatId.contains('YOUR_CHAT_ID');

  Future<bool> sendMessage(String text, {String? chatId}) async {
    if (!_isConfigured) {
      debugPrint('[TelegramService] Bot token or chat ID not configured.');
      return false;
    }

    final uri = Uri.parse(
        'https://api.telegram.org/bot${Uri.encodeComponent(_token)}/sendMessage');

    final Map<String, String> body = {
      'chat_id': chatId ?? _chatId,
      'text': text,
    };
    // Use markdown only for default/group chat; avoid in direct DMs to prevent silent drops
    if (chatId == null) {
      body['parse_mode'] = 'Markdown';
    }

    final resp = await http.post(uri, body: body)
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      return true;
    }

    debugPrint('[TelegramService] Failed to send message: ${resp.body}');
    return false;
  }

  Future<bool> sendSosAlert({
    required String userName,
    required int heartRate,
    required int spo2,
    required String locationText,
    double? latitude,
    double? longitude,
    String? chatId,
  }) async {
    final message = '*🚨 SOS Alert*\n'
        'User: $userName\n'
        'Heart Rate: ${heartRate > 0 ? '$heartRate bpm' : 'N/A'}\n'
        'SpO₂: ${spo2 > 0 ? '$spo2%' : 'N/A'}\n'
        'Location: $locationText';

    bool ok = await sendMessage(message, chatId: chatId);

    if (ok && latitude != null && longitude != null) {
      await sendLocation(latitude, longitude, chatId: chatId);
    }

    return ok;
  }

  Future<bool> sendLocation(double latitude, double longitude, {String? chatId}) async {
    if (!_isConfigured) return false;

    final uri = Uri.parse(
        'https://api.telegram.org/bot${Uri.encodeComponent(_token)}/sendLocation');

    final resp = await http.post(uri, body: {
      'chat_id': chatId ?? _chatId,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
    }).timeout(const Duration(seconds: 10));

    return resp.statusCode == 200;
  }
} 