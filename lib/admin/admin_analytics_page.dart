import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminAnalyticsPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AdminAnalyticsPage({super.key, this.userData});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  Map<String, dynamic>? analyticsData;
  bool isLoading = true;
  String errorMessage = '';

  static const String apiBaseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    fetchAnalytics();
  }

  Future<void> fetchAnalytics() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/analytics?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          analyticsData = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load analytics';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Widget buildDataTable(String title, List<dynamic>? data, List<String> columns) {
    if (data == null || data.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('$title: No data available'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: columns.map((col) => DataColumn(label: Text(col))).toList(),
                rows: data.map((row) {
                  return DataRow(
                    cells: columns.map((col) => DataCell(Text(row[col]?.toString() ?? ''))).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(child: Text(errorMessage));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAnalytics,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildDataTable(
              'Daily Appointment Summary',
              analyticsData?['daily_appointment_summary'],
              ['appointment_day', 'total_appointments', 'scheduled', 'completed', 'cancelled'],
            ),
            buildDataTable(
              'Monthly User Registrations',
              analyticsData?['monthly_user_registrations'],
              ['registration_month', 'total_registrations', 'student_registrations', 'counselor_registrations', 'admin_registrations'],
            ),
            buildDataTable(
              'Appointment Purpose Distribution',
              analyticsData?['appointment_purpose_distribution'],
              ['purpose_category', 'appointment_count', 'percentage'],
            ),
          ],
        ),
      ),
    );
  }
}
