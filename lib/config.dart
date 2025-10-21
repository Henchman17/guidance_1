import 'dart:io' show Platform;

class AppConfig {
  static Future<String> get apiBaseUrl async {
    if (Platform.isAndroid) {
      // For Android emulator, use 10.0.2.2 to reach host machine
      return 'http://10.0.2.2:8080';
    } else if (Platform.isIOS) {
      // For iOS, use local network IP (update this to your computer's Wi-Fi IP)
      return 'http://192.168.1.11:8080';
    }
    return 'http://localhost:8080';
  }
}
