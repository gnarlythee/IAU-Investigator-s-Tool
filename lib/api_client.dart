import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  ApiClient({required String serverIp}) : baseUrl = 'http://$serverIp:8080';

  Future<List<dynamic>> getCases() async {
    final response = await http.get(Uri.parse('$baseUrl/cases'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load cases');
  }

  Future<Map<String, dynamic>> getCase(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/cases/$id'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load case');
  }

  Future<void> downloadFile(String filePath) async {
    final response = await http.get(Uri.parse('$baseUrl/files/$filePath'));
    if (response.statusCode == 200) {
      // Save to device or open
    } else {
      throw Exception('Failed to download file');
    }
  }

  Future<void> updateCase(int id, Map<String, dynamic> updates) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cases/$id'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(updates),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update case');
    }
  }
}