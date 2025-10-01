import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminDisciplinePage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AdminDisciplinePage({super.key, this.userData});

  @override
  State<AdminDisciplinePage> createState() => _AdminDisciplinePageState();
}

class _AdminDisciplinePageState extends State<AdminDisciplinePage> {
  List<Map<String, dynamic>> _cases = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _filterStatus = 'all';
  String _filterSeverity = 'all';

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
        Uri.parse('$apiBaseUrl/api/admin/discipline-cases?admin_id=$adminId'),
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
          _errorMessage = 'Failed to load discipline cases';
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

  Future<void> _updateCaseStatus(int caseId, String status, String? actionTaken, String? notes) async {
    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/admin/discipline-cases/$caseId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': adminId,
          'status': status,
          'action_taken': actionTaken,
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
        title: Text('Discipline Case: ${caseData['student_name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Student Number', caseData['student_number']),
              _buildDetailRow('Incident Date', caseData['incident_date']?.toString().split('T')[0]),
              _buildDetailRow('Location', caseData['incident_location']),
              _buildDetailRow('Severity', caseData['severity']),
              _buildDetailRow('Status', caseData['status']),
              const Divider(),
              const Text('Incident Description:',
                style: TextStyle(fontWeight: FontWeight.bold)),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Text(caseData['incident_description'] ?? 'N/A'),
              ),
              if (caseData['witnesses'] != null && caseData['witnesses'].isNotEmpty) ...[
                const Text('Witnesses:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(caseData['witnesses']),
                ),
              ],
              if (caseData['action_taken'] != null && caseData['action_taken'].isNotEmpty) ...[
                const Text('Action Taken:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(caseData['action_taken']),
                ),
              ],
              if (caseData['admin_notes'] != null && caseData['admin_notes'].isNotEmpty) ...[
                const Text('Admin Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(caseData['admin_notes']),
                ),
              ],
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
    final actionController = TextEditingController(text: caseData['action_taken']);
    final notesController = TextEditingController(text: caseData['admin_notes']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Discipline Case'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedStatus,
              items: const [
                DropdownMenuItem(value: 'open', child: Text('Open')),
                DropdownMenuItem(value: 'under_investigation', child: Text('Under Investigation')),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'closed', child: Text('Closed')),
              ],
              onChanged: (value) => selectedStatus = value!,
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: actionController,
              decoration: const InputDecoration(
                labelText: 'Action Taken',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
              _updateCaseStatus(caseData['id'], selectedStatus, actionController.text, notesController.text);
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredCases {
    List<Map<String, dynamic>> filtered = _cases;

    if (_filterStatus != 'all') {
      filtered = filtered.where((c) => c['status'] == _filterStatus).toList();
    }

    if (_filterSeverity != 'all') {
      filtered = filtered.where((c) => c['severity'] == _filterSeverity).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Discipline Cases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Status: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filterStatus == 'all',
                      onSelected: (selected) => setState(() => _filterStatus = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Open'),
                      selected: _filterStatus == 'open',
                      onSelected: (selected) => setState(() => _filterStatus = 'open'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Resolved'),
                      selected: _filterStatus == 'resolved',
                      onSelected: (selected) => setState(() => _filterStatus = 'resolved'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Severity: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filterSeverity == 'all',
                      onSelected: (selected) => setState(() => _filterSeverity = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Minor'),
                      selected: _filterSeverity == 'minor',
                      onSelected: (selected) => setState(() => _filterSeverity = 'minor'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Major'),
                      selected: _filterSeverity == 'major',
                      onSelected: (selected) => setState(() => _filterSeverity = 'major'),
                    ),
                  ],
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
                                Icon(Icons.gavel, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No discipline cases found'),
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
                                      Text('Incident: ${caseData['incident_date']?.toString().split('T')[0] ?? 'N/A'}'),
                                      Text('Severity: ${caseData['severity'] ?? 'N/A'}'),
                                      Text('Status: ${caseData['status'] ?? 'N/A'}'),
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
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getSeverityColor(caseData['severity']),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          caseData['severity'] ?? 'Unknown',
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showUpdateDialog(caseData),
                                        tooltip: 'Update Case',
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
      case 'open':
        return Colors.orange;
      case 'under_investigation':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Color _getSeverityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'minor':
        return Colors.yellow[700]!;
      case 'moderate':
        return Colors.orange;
      case 'major':
        return Colors.red;
      case 'severe':
        return Colors.red[900]!;
      default:
        return Colors.grey;
    }
  }
}
