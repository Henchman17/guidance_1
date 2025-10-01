import 'dart:io' show Platform;

class AppConfig {
  static Future<String> get apiBaseUrl async {
    if (Platform.isAndroid || Platform.isIOS) {
      // Use the computer's local network IP
      return 'http://192.168.1.10:8080';  // Update this to your computer's Wi-Fi IP
    }
    return 'http://localhost:8080';
  }
}
