import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final urls = [
    'http://localhost:8080',
    'http://10.0.2.2:8080',
    'http://127.0.0.1:8080'
  ];

  for (final url in urls) {
    try {
      final response = await http.get(Uri.parse('$url/health'));
      print('$url: ${response.statusCode == 200 ? "SUCCESS" : "FAILED"}');
    } catch (e) {
      print('$url: ERROR - $e');
    }
  }
}
