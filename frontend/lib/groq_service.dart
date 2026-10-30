import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../main.dart';

class GroqService {
  static const String _backendUrl = 'https://backend-um5a.onrender.com/api/ai/chat';

  static Future<String> sendMessage(String userMessage) async {
    final response = await http.post(
      Uri.parse(_backendUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'prompt': userMessage}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['response'] ?? 'No response from AI';
    } else {
      debugPrint('Backend error: ${response.body}');
      throw Exception('Failed to fetch from backend: ${response.body}');
    }
  }
}