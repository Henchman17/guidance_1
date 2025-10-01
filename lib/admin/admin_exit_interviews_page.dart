import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AdminExitInterviewsPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AdminExitInterviewsPage({super.key, this.userData});

  @override
  State<AdminExitInterviewsPage> createState() => _AdminExitInterviewsPageState();
}

class _AdminExitInterviewsPageState extends State<AdminExitInterviewsPage> {
  List<Map<String, dynamic>> _interviews = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _filterType = 'all';
  String _filterStatus = 'all';

  static const String apiBaseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _fetchInterviews();
  }

  Future<void> _fetchInterviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/exit-interviews?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _interviews = List<Map<String, dynamic>>.from(data['interviews']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load exit interviews';
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

  Future<void> _updateInterviewStatus(int interviewId, String status, String? notes) async {
    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/admin/exit-interviews/$interviewId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': adminId,
          'status': status,
          'admin_notes': notes,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Interview updated successfully')),
        );
        _fetchInterviews();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update interview')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating interview: $e')),
      );
    }
  }

  void _showInterviewDetails(Map<String, dynamic> interviewData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Exit Interview: ${interviewData['student_name']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Student Number', interviewData['student_number']),
              _buildDetailRow('Interview Type', interviewData['interview_type']),
              _buildDetailRow('Interview Date', interviewData['interview_date']?.toString().split('T')[0]),
              _buildDetailRow('Status', interviewData['status']),
              const Divider(),
              const Text('Reason for Leaving:',
                style: TextStyle(fontWeight: FontWeight.bold)),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Text(interviewData['reason_for_leaving'] ?? 'N/A'),
              ),
              if (interviewData['satisfaction_rating'] != null) ...[
                _buildDetailRow('Satisfaction Rating', '${interviewData['satisfaction_rating']}/5'),
              ],
              if (interviewData['academic_experience'] != null && interviewData['academic_experience'].isNotEmpty) ...[
                const Text('Academic Experience:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(interviewData['academic_experience']),
                ),
              ],
              if (interviewData['support_services_experience'] != null && interviewData['support_services_experience'].isNotEmpty) ...[
                const Text('Support Services Experience:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(interviewData['support_services_experience']),
                ),
              ],
              if (interviewData['facilities_experience'] != null && interviewData['facilities_experience'].isNotEmpty) ...[
                const Text('Facilities Experience:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(interviewData['facilities_experience']),
                ),
              ],
              if (interviewData['overall_improvements'] != null && interviewData['overall_improvements'].isNotEmpty) ...[
                const Text('Suggested Improvements:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(interviewData['overall_improvements']),
                ),
              ],
              if (interviewData['future_plans'] != null && interviewData['future_plans'].isNotEmpty) ...[
                const Text('Future Plans:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(interviewData['future_plans']),
                ),
              ],
              if (interviewData['contact_info'] != null && interviewData['contact_info'].isNotEmpty) ...[
                _buildDetailRow('Contact Info', interviewData['contact_info']),
              ],
              if (interviewData['admin_notes'] != null && interviewData['admin_notes'].isNotEmpty) ...[
                const Text('Admin Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(interviewData['admin_notes']),
                ),
              ],
              _buildDetailRow('Created', interviewData['created_at']?.toString().split('T')[0]),
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

  void _showUpdateDialog(Map<String, dynamic> interviewData) {
    String selectedStatus = interviewData['status'];
    final notesController = TextEditingController(text: interviewData['admin_notes']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Interview Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedStatus,
              items: const [
                DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
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
              _updateInterviewStatus(interviewData['id'], selectedStatus, notesController.text);
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredInterviews {
    List<Map<String, dynamic>> filtered = _interviews;

    if (_filterType != 'all') {
      filtered = filtered.where((i) => i['interview_type'] == _filterType).toList();
    }

    if (_filterStatus != 'all') {
      filtered = filtered.where((i) => i['status'] == _filterStatus).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Exit Interviews',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchInterviews,
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
                    const Text('Type: '),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filterType == 'all',
                      onSelected: (selected) => setState(() => _filterType = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Graduating'),
                      selected: _filterType == 'graduating',
                      onSelected: (selected) => setState(() => _filterType = 'graduating'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Transferring'),
                      selected: _filterType == 'transferring',
                      onSelected: (selected) => setState(() => _filterType = 'transferring'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                      label: const Text('Scheduled'),
                      selected: _filterStatus == 'scheduled',
                      onSelected: (selected) => setState(() => _filterStatus = 'scheduled'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Completed'),
                      selected: _filterStatus == 'completed',
                      onSelected: (selected) => setState(() => _filterStatus = 'completed'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Interviews list
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
                              onPressed: _fetchInterviews,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredInterviews.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.exit_to_app, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text('No exit interviews found'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredInterviews.length,
                            itemBuilder: (context, index) {
                              final interviewData = _filteredInterviews[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ListTile(
                                  title: Text(
                                    interviewData['student_name'] ?? 'Unknown Student',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Student #: ${interviewData['student_number'] ?? 'N/A'}'),
                                      Text('Type: ${interviewData['interview_type'] ?? 'N/A'}'),
                                      Text('Date: ${interviewData['interview_date']?.toString().split('T')[0] ?? 'N/A'}'),
                                      Text('Status: ${interviewData['status'] ?? 'N/A'}'),
                                      if (interviewData['satisfaction_rating'] != null)
                                        Text('Rating: ${interviewData['satisfaction_rating']}/5'),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(interviewData['status']),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          interviewData['status'] ?? 'Unknown',
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getTypeColor(interviewData['interview_type']),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          interviewData['interview_type'] ?? 'Unknown',
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () => _showUpdateDialog(interviewData),
                                        tooltip: 'Update Status',
                                      ),
                                    ],
                                  ),
                                  onTap: () => _showInterviewDetails(interviewData),
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
      case 'scheduled':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'graduating':
        return Colors.blue;
      case 'transferring':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
