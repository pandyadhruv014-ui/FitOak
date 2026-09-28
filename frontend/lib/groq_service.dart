import 'dart:convert';
import 'package:http/http.dart' as http;

class BackendAIService {
  // Replace with your local machine IP if testing on a physical device (e.g., http://192.168.1.5:8000/api/ai/chat)
  // Or use 10.0.2.2 for Android Emulator
  static const String _backendUrl = 'http://10.168.226.120:8000/api/ai/chat'; 

  static Future<String> getAIResponse(String prompt) async {
    final response = await http.post(
      Uri.parse(_backendUrl),
      headers: {
        'Content-Type': 'application/json',
        // Optional: Include user Auth Bearer token here if your backend requires login
      },
      body: jsonEncode({
        "prompt": prompt,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response'];
    } else {
      throw Exception('Failed to fetch from backend: ${response.body}');
    }
  }
}