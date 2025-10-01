import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../login_page.dart';
import '../settings.dart';
import 'counselor_dashboard.dart';
import 'counselor_appointments_page.dart';
import 'counselor_sessions_page.dart';

class CounselorStudentsPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const CounselorStudentsPage({super.key, this.userData});

  @override
  State<CounselorStudentsPage> createState() => _CounselorStudentsPageState();
}

class _CounselorStudentsPageState extends State<CounselorStudentsPage> {
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> guidanceSchedules = [];
  bool isLoading = true;
  bool isLoadingSchedules = true;
  String errorMessage = '';
  String searchQuery = '';
  int _selectedIndex = 1;
  String selectedTab = 'students'; // 'students' or 'guidance'

  static const String apiBaseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    fetchStudents();
    fetchGuidanceSchedules();
  }

  Future<void> fetchStudents() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final userId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/counselor/students?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          students = List<Map<String, dynamic>>.from(data['students'] ?? []);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load students';
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

  Future<void> fetchGuidanceSchedules() async {
    setState(() {
      isLoadingSchedules = true;
    });

    try {
      final userId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/counselor/guidance-schedules?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          guidanceSchedules = List<Map<String, dynamic>>.from(data['schedules'] ?? []);
          isLoadingSchedules = false;
        });
      } else {
        setState(() {
          isLoadingSchedules = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingSchedules = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredStudents {
    if (searchQuery.isEmpty) {
      return students;
    }
    return students.where((student) {
      final firstName = student['first_name'] ?? '';
      final lastName = student['last_name'] ?? '';
      final studentId = student['student_id']?.toString() ?? '';
      final name = '$firstName $lastName';
      return name.toLowerCase().contains(searchQuery.toLowerCase()) ||
             studentId.contains(searchQuery);
    }).toList();
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    (student['first_name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student['first_name']} ${student['last_name']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Student ID: ${student['student_id']}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () => _showStudentOptions(student),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Grade ${student['grade_level']}',
                    Icons.school,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoChip(
                    'Section ${student['section']}',
                    Icons.class_,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewStudentProfile(student),
                    icon: const Icon(Icons.person),
                    label: const Text('View Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _scheduleAppointment(student),
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Schedule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidanceScheduleCard(Map<String, dynamic> schedule) {
    final appointmentDate = DateTime.parse(schedule['appointment_date']);
    final status = schedule['status'];
    final purpose = schedule['purpose'];
    final course = schedule['course'] ?? 'N/A';
    final studentName = schedule['student_name'] ?? 'Unknown Student';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'scheduled':
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        statusText = 'Scheduled';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = 'Pending Approval';
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Approved';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = status;
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    (studentName.isNotEmpty ? studentName[0] : 'U').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${appointmentDate.month}/${appointmentDate.day}/${appointmentDate.year} at ${appointmentDate.hour}:${appointmentDate.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(statusIcon, color: statusColor, size: 28),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              purpose,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoChip(
                    'Course: $course',
                    Icons.book,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveGuidanceSchedule(schedule),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectGuidanceSchedule(schedule),
                      icon: const Icon(Icons.cancel),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentOptions(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${student['first_name']} ${student['last_name']}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Profile'),
              onTap: () {
                Navigator.pop(context);
                _viewStudentProfile(student);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Schedule Appointment'),
              onTap: () {
                Navigator.pop(context);
                _scheduleAppointment(student);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View Session History'),
              onTap: () {
                Navigator.pop(context);
                _viewSessionHistory(student);
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Send Message'),
              onTap: () {
                Navigator.pop(context);
                _sendMessage(student);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewStudentProfile(Map<String, dynamic> student) {
    // TODO: Navigate to student profile page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing profile for ${student['first_name']} ${student['last_name']}')),
    );
  }

  void _scheduleAppointment(Map<String, dynamic> student) {
    // TODO: Navigate to appointment scheduling page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scheduling appointment for ${student['first_name']} ${student['last_name']}')),
    );
  }

  void _viewSessionHistory(Map<String, dynamic> student) {
    // TODO: Navigate to session history page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing session history for ${student['first_name']} ${student['last_name']}')),
    );
  }

  void _sendMessage(Map<String, dynamic> student) {
    // TODO: Navigate to messaging page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sending message to ${student['first_name']} ${student['last_name']}')),
    );
  }

  Future<void> _approveGuidanceSchedule(Map<String, dynamic> schedule) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/counselor/guidance-schedules/${schedule['id']}/approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'counselor_id': widget.userData?['id']}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guidance schedule approved successfully')),
        );
        fetchGuidanceSchedules(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to approve guidance schedule')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _rejectGuidanceSchedule(Map<String, dynamic> schedule) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/counselor/guidance-schedules/${schedule['id']}/reject'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'counselor_id': widget.userData?['id']}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guidance schedule rejected')),
        );
        fetchGuidanceSchedules(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to reject guidance schedule')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }



  void _handleNavigation(int index) {
    switch (index) {
      case 0: // Dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CounselorDashboardPage(userData: widget.userData),
          ),
        );
        break;
      case 1: // Students
        setState(() => _selectedIndex = 1);
        break;
      case 2: // Appointments
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CounselorAppointmentsPage(userData: widget.userData),
          ),
        );
        break;
      case 3: // Sessions
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CounselorSessionsPage(userData: widget.userData),
          ),
        );
        break;
      case 4: // Settings
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SettingsPage(userData: widget.userData),
          ),
        );
        break;
      case 5: // Logout
        _handleLogout();
        break;
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                ),
                (route) => false,
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _buildDestinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people),
        label: Text('Students'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.calendar_today),
        label: Text('Appointments'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.event_note),
        label: Text('Sessions'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings),
        label: Text('Settings'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.logout),
        label: Text('Logout'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top header bar for this page
        Container(
          color: const Color.fromARGB(255, 30, 182, 88),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    "Student Management",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // Search bar
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (value) => setState(() => searchQuery = value),
                        decoration: InputDecoration(
                          hintText: selectedTab == 'students' ? 'Search students by name or ID...' : 'Search guidance schedules...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Tab buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => selectedTab = 'students'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTab == 'students' ? Colors.white : Colors.white.withOpacity(0.8),
                        foregroundColor: selectedTab == 'students' ? const Color.fromARGB(255, 30, 182, 88) : Colors.grey[700],
                      ),
                      child: const Text('Students'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => selectedTab = 'guidance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedTab == 'guidance' ? Colors.white : Colors.white.withOpacity(0.8),
                        foregroundColor: selectedTab == 'guidance' ? const Color.fromARGB(255, 30, 182, 88) : Colors.grey[700],
                      ),
                      child: const Text('Guidance Schedules'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              selectedTab == 'students'
                  ? (isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : errorMessage.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                                  const SizedBox(height: 16),
                                  Text(errorMessage, textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: fetchStudents,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: fetchStudents,
                              child: ListView.builder(
                                itemCount: filteredStudents.length,
                                itemBuilder: (context, index) => _buildStudentCard(filteredStudents[index]),
                              ),
                            ))
                  : (isLoadingSchedules
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: fetchGuidanceSchedules,
                          child: ListView.builder(
                            itemCount: guidanceSchedules.length,
                            itemBuilder: (context, index) => _buildGuidanceScheduleCard(guidanceSchedules[index]),
                          ),
                        )),
              if (selectedTab == 'students')
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: () {
                      // TODO: Add new student or bulk import
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Add student functionality coming soon')),
                      );
                    },
                    backgroundColor: const Color.fromARGB(255, 30, 182, 88),
                    child: const Icon(Icons.add),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
