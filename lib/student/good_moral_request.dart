import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'download_request_slip.dart';
import '../ocr_processor.dart';
import '../document_generator.dart';

class GoodMoralRequest extends StatefulWidget {
  const GoodMoralRequest({super.key});

  @override
  State<GoodMoralRequest> createState() => _GoodMoralRequestState();
}

class _GoodMoralRequestState extends State<GoodMoralRequest> {
  String? _recognizedText;
  bool _isGeneratingDoc = false;
  Map<String, String> _extractedData = {};

  void _navigateToDownloadRequestSlip(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DownloadRequestSlip(),
      ),
    );
  }

  Future<void> _generateAndDownloadDocx(BuildContext context) async {
    if (_extractedData.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Data Available'),
          content: const Text('Please capture and process an image with OCR first to extract student data.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Validate extracted data
    if (!DocumentGenerator.validateOcrData(_extractedData)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incomplete Data'),
          content: const Text('Required student information (name, ID, course) could not be extracted. Please try capturing the image again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingDoc = true;
    });

    try {
      // Request storage permission if needed
      if (Platform.isAndroid && !kIsWeb) {
        final hasPermission = await DocumentGenerator.requestStoragePermission();
        if (!hasPermission) {
          setState(() {
            _isGeneratingDoc = false;
          });
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permission Required'),
              content: const Text('Storage permission is required to save the document. Please grant permission in settings.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          );
          return;
        }
      }

      // Generate the PDF document
      final file = await DocumentGenerator.generateGoodMoralPDF(_extractedData);

      if (file != null) {
        setState(() {
          _isGeneratingDoc = false;
        });

        if (!context.mounted) return;

        // Show success message with file location
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: Text('Good Moral Certificate saved to: ${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await DocumentGenerator.openDocument(file);
                },
                child: const Text('Open File'),
              ),
            ],
          ),
        );
      } else {
        throw Exception('Failed to generate document');
      }
    } catch (e) {
      setState(() {
        _isGeneratingDoc = false;
      });
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to generate document: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickAndRecognizeText(BuildContext context) async {
    final picker = ImagePicker();

    // Show source selection dialog for Android
    ImageSource? source;
    if (Platform.isAndroid) {
      source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose where to get the image from:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } else {
      source = ImageSource.gallery;
    }

    if (source == null) return;

    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 90, // Good quality for OCR
      maxWidth: 1920, // Reasonable size
      maxHeight: 1080,
    );

    if (pickedFile == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Processing image...'),
          ],
        ),
      ),
    );

    try {
      final imageFile = File(pickedFile.path);

      // Validate image
      final isValid = await OcrProcessor.isImageValid(imageFile);
      if (!isValid) {
        throw Exception('Invalid image file');
      }

      // Process OCR
      final extractedData = await OcrProcessor.processImage(imageFile);

      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      setState(() {
        _extractedData = extractedData;
        _recognizedText = extractedData.values.join('\n');
      });

      // Save extracted data to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ocr_extracted_data', extractedData.toString());

      // Show extracted data
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Extracted Student Data'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: extractedData.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${entry.key}: ${entry.value}'),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to process image: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }
  
  void _navigateToCaptureRequestSlip(BuildContext context) {
    _pickAndRecognizeText(context);
  }

  Future<Map<String, String>> _loadExtractedData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString('ocr_extracted_data');
    if (dataString != null) {
      // Parse the string back to map (simplified parsing)
      final Map<String, String> data = {};
      final entries = dataString.replaceAll('{', '').replaceAll('}', '').split(', ');
      for (final entry in entries) {
        final parts = entry.split(': ');
        if (parts.length == 2) {
          data[parts[0]] = parts[1];
        }
      }
      return data;
    }
    return {};
  }

  @override
  void initState() {
    super.initState();
    _loadExtractedData().then((value) {
      setState(() {
        _extractedData = value;
        _recognizedText = value.values.join('\n');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            const Text(
              "Good Moral Request",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 30, 182, 88),
        elevation: 4,
        shadowColor: Colors.green.shade900.withOpacity(0.3),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.lightGreen.withOpacity(0.3),
                    Colors.green.shade900.withOpacity(1.0),
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView( // Wrap with SingleChildScrollView
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 320,
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _navigateToDownloadRequestSlip(context),
                          child: SizedBox(
                            height: 160,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.download, size: 56, color: Colors.blue.shade700),
                                const SizedBox(height: 16),
                                Text(
                                  'Download Request Slip',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 320,
                      child: Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _navigateToCaptureRequestSlip(context),
                          child: SizedBox(
                            height: 160,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 56, color: Colors.green.shade700),
                                const SizedBox(height: 16),
                                Text(
                                  'Capture Request Slip',
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_recognizedText != null) ...[
                      const SizedBox(height: 32),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Last Recognized Text:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  _recognizedText ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: 320,
                        child: Card(
                          elevation: 6,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _generateAndDownloadDocx(context),
                            child: SizedBox(
                              height: 160,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _isGeneratingDoc
                                      ? const CircularProgressIndicator()
                                      : Icon(Icons.description, size: 56, color: Colors.purple.shade700),
                                  const SizedBox(height: 16),
                                  Text(
                                    _isGeneratingDoc ? 'Generating...' : 'Generate Good Moral Certificate',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
