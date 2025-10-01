import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminFormsPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AdminFormsPage({super.key, this.userData});

  @override
  State<AdminFormsPage> createState() => _AdminFormsPageState();
}

class _AdminFormsPageState extends State<AdminFormsPage> {
  List<Map<String, dynamic>> _forms = [];
  bool _isLoading = true;
  String _errorMessage = '';

  static const String apiBaseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _fetchForms();
  }

  Future<void> _fetchForms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/forms?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _forms = List<Map<String, dynamic>>.from(data['forms']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load forms';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _showFormDetails(Map<String, dynamic> formData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Form Details: ${formData['form_name'] ?? 'Unknown Form'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Form Type', formData['form_type']),
              _buildDetailRow('Student', formData['student_name']),
              _buildDetailRow('Student Number', formData['student_number']),
              _buildDetailRow('Status', formData['status']),
              _buildDetailRow('Submitted', formData['submitted_at']?.toString().split('T')[0]),
              if (formData['reviewed_at'] != null)
                _buildDetailRow('Reviewed', formData['reviewed_at']?.toString().split('T')[0]),
              if (formData['reviewer_name'] != null)
                _buildDetailRow('Reviewed By', formData['reviewer_name']),
              if (formData['admin_notes'] != null && formData['admin_notes'].isNotEmpty)
                _buildDetailRow('Admin Notes', formData['admin_notes']),
            ],
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
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Forms Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchForms,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Forms list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_errorMessage),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchForms,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _forms.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.assignment, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No forms found'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _forms.length,
                            itemBuilder: (context, index) {
                              final formData = _forms[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ListTile(
                                  title: Text(
                                    formData['form_name'] ?? 'Unknown Form',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Student: ${formData['student_name'] ?? 'N/A'}'),
                                      Text('Type: ${formData['form_type'] ?? 'N/A'}'),
                                      Text('Status: ${formData['status'] ?? 'N/A'}'),
                                      Text('Submitted: ${formData['submitted_at']?.toString().split('T')[0] ?? 'N/A'}'),
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(formData['status']),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      formData['status'] ?? 'Unknown',
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ),
                                  onTap: () => _showFormDetails(formData),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under_review':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
