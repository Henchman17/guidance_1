import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminReAdmissionPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AdminReAdmissionPage({super.key, this.userData});

  @override
  State<AdminReAdmissionPage> createState() => _AdminReAdmissionPageState();
}

class _AdminReAdmissionPageState extends State<AdminReAdmissionPage> {
  List<Map<String, dynamic>> _cases = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _filterStatus = 'all';

  static const String apiBaseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _fetchCases();
  }

  Future<void> _fetchCases() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/re-admission-cases?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _cases = List<Map<String, dynamic>>.from(data['cases']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load re-admission cases';
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

  Future<void> _updateCaseStatus(int caseId, String status, String? notes) async {
    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/admin/re-admission-cases/$caseId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': adminId,
          'status': status,
          'admin_notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case updated successfully')),
        );
        _fetchCases();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update case')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating case: $e')),
      );
    }
  }

  void _showCaseDetails(Map<String, dynamic> caseData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Re-admission Case: ${caseData['student_name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Student Number', caseData['student_number']),
              _buildDetailRow('Previous Program', caseData['previous_program']),
              _buildDetailRow('Reason for Leaving', caseData['reason_for_leaving']),
              _buildDetailRow('Reason for Return', caseData['reason_for_return']),
              _buildDetailRow('Academic Standing', caseData['academic_standing']),
              _buildDetailRow('GPA', caseData['gpa']?.toString()),
              _buildDetailRow('Status', caseData['status']),
              if (caseData['admin_notes'] != null && caseData['admin_notes'].isNotEmpty)
                _buildDetailRow('Admin Notes', caseData['admin_notes']),
              _buildDetailRow('Created', caseData['created_at']?.toString().split('T')[0]),
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

  void _showUpdateDialog(Map<String, dynamic> caseData) {
    String selectedStatus = caseData['status'];
    final notesController = TextEditingController(text: caseData['admin_notes']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Case Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedStatus,
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'under_review', child: Text('Under Review')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) => selectedStatus = value!,
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Admin Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateCaseStatus(caseData['id'], selectedStatus, notesController.text);
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredCases {
    if (_filterStatus == 'all') return _cases;
    return _cases.where((c) => c['status'] == _filterStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Re-Admission Cases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCases,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter buttons
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Row(
              children: [
                const Text('Filter: '),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filterStatus == 'all',
                  onSelected: (selected) => setState(() => _filterStatus = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Pending'),
                  selected: _filterStatus == 'pending',
                  onSelected: (selected) => setState(() => _filterStatus = 'pending'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Approved'),
                  selected: _filterStatus == 'approved',
                  onSelected: (selected) => setState(() => _filterStatus = 'approved'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Rejected'),
                  selected: _filterStatus == 'rejected',
                  onSelected: (selected) => setState(() => _filterStatus = 'rejected'),
                ),
              ],
            ),
          ),

          // Cases list
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
                              onPressed: _fetchCases,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredCases.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No re-admission cases found'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredCases.length,
                            itemBuilder: (context, index) {
                              final caseData = _filteredCases[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ListTile(
                                  title: Text(
                                    caseData['student_name'] ?? 'Unknown Student',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Student #: ${caseData['student_number'] ?? 'N/A'}'),
                                      Text('Previous Program: ${caseData['previous_program'] ?? 'N/A'}'),
                                      Text('Status: ${caseData['status'] ?? 'N/A'}'),
                                      Text('Created: ${caseData['created_at']?.toString().split('T')[0] ?? 'N/A'}'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(caseData['status']),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          caseData['status'] ?? 'Unknown',
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showUpdateDialog(caseData),
                                        tooltip: 'Update Status',
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showCaseDetails(caseData),
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
      case 'under_review':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
