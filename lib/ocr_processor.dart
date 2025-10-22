import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'dart:ui' as ui;

class OcrProcessor {
  static Future<Map<String, String>> processImage(File imageFile) async {
    try {
      Map<String, String> extractedData = {};

      if (Platform.isAndroid || Platform.isIOS) {
        // Use Google ML Kit for mobile platforms
        extractedData = await _processWithGoogleMLKit(imageFile);
      } else {
        // Use Tesseract for desktop platforms
        extractedData = await _processWithTesseract(imageFile);
      }

      // Structure and clean the extracted data
      return _structureExtractedData(extractedData);
    } catch (e) {
      print('Error processing OCR: $e');
      return {};
    }
  }

  static Future<Map<String, String>> _processWithGoogleMLKit(File imageFile) async {
    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFile(imageFile);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      return _parseRecognizedText(recognizedText.text);
    } catch (e) {
      await textRecognizer.close();
      throw e;
    }
  }

  static Future<Map<String, String>> _processWithTesseract(File imageFile) async {
    try {
      final String recognizedText = await FlutterTesseractOcr.extractText(
        imageFile.path,
        language: 'eng',
        args: {
          "psm": "6",
          "oem": "3",
        },
      );

      return _parseRecognizedText(recognizedText);
    } catch (e) {
      print('Tesseract OCR error: $e');
      return {};
    }
  }

  static Map<String, String> _parseRecognizedText(String text) {
    final Map<String, String> data = {};
    final lines = text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);

    for (final line in lines) {
      // Look for common patterns in student documents
      if (_containsKeywords(line, ['name', 'student name'])) {
        data['studentName'] = _extractValue(line);
      } else if (_containsKeywords(line, ['id', 'student id', 'student number'])) {
        data['studentId'] = _extractValue(line);
      } else if (_containsKeywords(line, ['course', 'program'])) {
        data['course'] = _extractValue(line);
      } else if (_containsKeywords(line, ['year', 'level', 'grade'])) {
        data['yearLevel'] = _extractValue(line);
      } else if (_containsKeywords(line, ['address'])) {
        data['address'] = _extractValue(line);
      }
    }

    return data;
  }

  static bool _containsKeywords(String text, List<String> keywords) {
    final lowerText = text.toLowerCase();
    return keywords.any((keyword) => lowerText.contains(keyword.toLowerCase()));
  }

  static String _extractValue(String line) {
    // Try to extract value after colon or common separators
    final colonIndex = line.indexOf(':');
    if (colonIndex != -1 && colonIndex < line.length - 1) {
      return line.substring(colonIndex + 1).trim();
    }

    // Try to extract after common patterns
    final patterns = [' - ', ' : ', ' – '];
    for (final pattern in patterns) {
      final index = line.indexOf(pattern);
      if (index != -1 && index < line.length - pattern.length) {
        return line.substring(index + pattern.length).trim();
      }
    }

    return line.trim();
  }

  static Map<String, String> _structureExtractedData(Map<String, String> rawData) {
    final Map<String, String> structuredData = {};

    // Clean and validate extracted data
    rawData.forEach((key, value) {
      if (value.isNotEmpty) {
        // Remove extra whitespace and special characters
        final cleanedValue = value.replaceAll(RegExp(r'[^\w\s\-\.]'), '').trim();
        if (cleanedValue.isNotEmpty) {
          structuredData[key] = cleanedValue;
        }
      }
    });

    return structuredData;
  }

  static Future<bool> isImageValid(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      // Check if file size is reasonable (not too small or too large)
      if (bytes.length < 1000) return false; // Too small
      if (bytes.length > 50 * 1024 * 1024) return false; // Too large (>50MB)

      // Try to decode as image
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();

      return true;
    } catch (e) {
      return false;
    }
  }
}
