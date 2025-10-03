import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminAppointmentsPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AdminAppointmentsPage({super.key, this.userData});

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  List<dynamic> appointments = [];
  List<dynamic> filteredAppointments = [];
  bool isLoading = true;
  String errorMessage = '';

  // Filter states
  String? selectedStatus;
  DateTime? startDate;
  DateTime? endDate;
  bool showFilters = true;

  static const String apiBaseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    fetchAppointments();
  }

  Future<void> fetchAppointments() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/appointments?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          appointments = data['appointments'] ?? [];
          filteredAppointments = List.from(appointments);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load appointments';
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

  void applyFilters() {
    setState(() {
      filteredAppointments = appointments.where((appointment) {
        // Status filter
        if (selectedStatus != null && selectedStatus!.isNotEmpty) {
          if (appointment['apt_status']?.toString().toLowerCase() != selectedStatus!.toLowerCase()) {
            return false;
          }
        }

        // Date range filter
        if (startDate != null || endDate != null) {
          final appointmentDate = DateTime.tryParse(appointment['appointment_date']?.toString() ?? '');
          if (appointmentDate == null) return false;

          if (startDate != null && appointmentDate.isBefore(startDate!)) {
            return false;
          }
          if (endDate != null && appointmentDate.isAfter(endDate!)) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  void clearFilters() {
    setState(() {
      selectedStatus = null;
      startDate = null;
      endDate = null;
      filteredAppointments = List.from(appointments);
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      applyFilters();
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'overdue':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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
          'Appointment Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchAppointments,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            if (showFilters)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.filter_list, color: Color(0xFF1E88E5)),
                        const SizedBox(width: 8),
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: clearFilters,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear All'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Status Dropdown
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Appointment Status',
                          labelStyle: const TextStyle(color: Color(0xFF1E88E5)),
                          prefixIcon: const Icon(Icons.assignment, color: Color(0xFF1E88E5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        value: selectedStatus,
                        items: <String>[
                          '',
                          'Scheduled',
                          'Completed',
                          'Cancelled',
                          'Overdue',
                        ].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value.isEmpty ? null : value,
                            child: Row(
                              children: [
                                Icon(
                                  value.isEmpty ? Icons.all_inclusive :
                                  value == 'Scheduled' ? Icons.schedule :
                                  value == 'Completed' ? Icons.check_circle :
                                  value == 'Cancelled' ? Icons.cancel :
                                  Icons.warning,
                                  color: getStatusColor(value.isEmpty ? 'all' : value),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(value.isEmpty ? 'All Statuses' : value),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStatus = value;
                          });
                          applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Date Range Picker
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _selectDateRange(context),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.date_range, color: Color(0xFF1E88E5)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        startDate != null && endDate != null
                                            ? '${startDate!.toLocal().toString().split(' ')[0]} - ${endDate!.toLocal().toString().split(' ')[0]}'
                                            : 'Select Date Range',
                                        style: TextStyle(
                                          color: startDate != null ? Colors.black : Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (startDate != null || endDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  startDate = null;
                                  endDate = null;
                                });
                                applyFilters();
                              },
                              tooltip: 'Clear Date Range',
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          Expanded(
            child: filteredAppointments.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No appointments found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try adjusting your filters or refresh the page',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filteredAppointments.length,
                    itemBuilder: (context, index) {
                      final appointment = filteredAppointments[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_month,
                                      color: Color(0xFF1E88E5),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Appointment #${appointment['id']}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E88E5),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(appointment['apt_status'] ?? 'pending').withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: getStatusColor(appointment['apt_status'] ?? 'pending').withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          appointment['apt_status'] == 'Scheduled' ? Icons.schedule :
                                          appointment['apt_status'] == 'Completed' ? Icons.check_circle :
                                          appointment['apt_status'] == 'Cancelled' ? Icons.cancel :
                                          appointment['apt_status'] == 'Overdue' ? Icons.warning :
                                          Icons.help_outline,
                                          color: getStatusColor(appointment['apt_status'] ?? 'pending'),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (appointment['apt_status'] ?? 'pending').toString().toUpperCase(),
                                          style: TextStyle(
                                            color: getStatusColor(appointment['apt_status'] ?? 'pending'),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _buildInfoRow(Icons.person, 'Student', '${appointment['student_name']} (${appointment['student_number']})'),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(Icons.person_outline, 'Counselor', appointment['counselor_name']),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(Icons.date_range, 'Date', appointment['appointment_date']),
                                    const SizedBox(height: 8),
                                    _buildInfoRow(Icons.description, 'Purpose', appointment['purpose']),
                                    if (appointment['course'] != null && appointment['course'].isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoRow(Icons.school, 'Course', appointment['course']),
                                    ],
                                    if (appointment['notes'] != null && appointment['notes'].isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      _buildInfoRow(Icons.note, 'Notes', appointment['notes']),
                                    ],
                                    const SizedBox(height: 8),
                                    _buildInfoRow(Icons.school, 'Grade & Section', 'Grade ${appointment['grade_level']} | Section ${appointment['section']}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
          ],),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
