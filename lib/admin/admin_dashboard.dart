import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../login_page.dart';
import 'admin_users_page.dart';
import 'admin_appointments_page.dart';
import 'admin_analytics_page.dart';
import 'admin_re_admission_page.dart';
import 'admin_discipline_page.dart';
import 'admin_exit_interviews_page.dart';
import 'admin_forms_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AdminDashboardPage({super.key, this.userData});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;
  String errorMessage = '';
  int _selectedIndex = 0;
  Map<String, dynamic>? _currentUser;
  List<dynamic> credentialChangeRequests = [];
  bool isLoadingRequests = false;

  static const String apiBaseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _currentUser = widget.userData;
    fetchDashboardData();
    fetchCredentialChangeRequests();
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

  List<NavigationRailDestination> _buildNavigationDestinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people),
        label: Text('Users'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.calendar_today),
        label: Text('Appointments'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.analytics),
        label: Text('Analytics'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.assignment_return),
        label: Text('Re-admission'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.gavel),
        label: Text('Discipline'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.exit_to_app),
        label: Text('Exit Interviews'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.assignment),
        label: Text('Forms & Records'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.logout),
        label: Text('Logout'),
      ),
    ];
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 0: // Dashboard
        setState(() => _selectedIndex = 0);
        break;
      case 1: // Users
        setState(() => _selectedIndex = 1);
        break;
      case 2: // Appointments
        setState(() => _selectedIndex = 2);
        break;
      case 3: // Analytics
        setState(() => _selectedIndex = 3);
        break;
      case 4: // Re-admission Cases
        setState(() => _selectedIndex = 4);
        break;
      case 5: // Discipline Cases
        setState(() => _selectedIndex = 5);
        break;
      case 6: // Exit Interviews
        setState(() => _selectedIndex = 6);
        break;
      case 7: // Forms & Records
        setState(() => _selectedIndex = 7);
        break;
      case 8: // Logout
        _handleLogout();
        break;
    }
  }

  Future<void> fetchDashboardData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final userId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/dashboard?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        setState(() {
          dashboardData = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load dashboard data';
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

  Future<void> fetchCredentialChangeRequests() async {
    setState(() {
      isLoadingRequests = true;
    });

    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/credential-change-requests?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          credentialChangeRequests = data['requests'] ?? [];
          isLoadingRequests = false;
        });
      } else {
        setState(() {
          isLoadingRequests = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoadingRequests = false;
      });
    }
  }

  Future<void> approveRequest(int requestId) async {
    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/admin/credential-change-requests/$requestId/approve?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        fetchCredentialChangeRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to approve request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> rejectRequest(int requestId, String reason) async {
    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.put(
        Uri.parse('$apiBaseUrl/api/admin/credential-change-requests/$requestId?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'rejected', 'admin_notes': reason}),
      );

      if (response.statusCode == 200) {
        fetchCredentialChangeRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to reject request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withOpacity(0.3), width: 1),
      ),
      child: Container(
        height: 300, // Added fixed height to make cards taller
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: color.withOpacity(0.05),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedMetricCard(String title, String value, IconData icon, List<Color> gradientColors, IconData trendIcon) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: gradientColors.first.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 0),
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 36, color: Colors.white),
                  const SizedBox(width: 8),
                  Icon(trendIcon, size: 20, color: Colors.white.withOpacity(0.8)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildActivityItem(
              'New user registered',
              'John Doe joined as student',
              '2 hours ago',
              Icons.person_add,
              Colors.green,
            ),
            _buildActivityItem(
              'Appointment scheduled',
              'Maria Santos booked counseling',
              '4 hours ago',
              Icons.calendar_today,
              Colors.blue,
            ),
            _buildActivityItem(
              'User updated',
              'Admin updated counselor profile',
              '1 day ago',
              Icons.edit,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialChangeRequestsSection() {
    if (isLoadingRequests) {
      return const Card(
        elevation: 4,
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (credentialChangeRequests.isEmpty) {
      return Card(
        elevation: 4,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No pending credential change requests',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Credential Change Requests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: fetchCredentialChangeRequests,
                  child: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...credentialChangeRequests.map((request) {
              final requestId = request['id'];
              final firstName = request['first_name'] ?? '';
              final lastName = request['last_name'] ?? '';
              final studentName = '$firstName $lastName'.trim().isEmpty ? 'Unknown' : '$firstName $lastName'.trim();
              final requestType = request['request_type'] ?? 'N/A';
              final currentValue = request['current_value'] ?? '';
              final newValue = request['new_value'] ?? '';
              final requestedChange = '$requestType: $currentValue → $newValue';
              final status = request['status'] ?? 'pending';
              final createdAt = request['created_at'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Request #$requestId',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Chip(
                            label: Text(status.toUpperCase()),
                            backgroundColor: status == 'pending' ? Colors.orange : Colors.grey,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Student: $studentName'),
                      Text('Change: $requestedChange'),
                      Text('Submitted: $createdAt'),
                      const SizedBox(height: 12),
                      if (status == 'pending')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final reasonController = TextEditingController();
                                final reason = await showDialog<String>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Reject Request'),
                                    content: TextField(
                                      controller: reasonController,
                                      decoration: const InputDecoration(
                                        hintText: 'Reason for rejection',
                                      ),
                                      maxLines: 3,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(context).pop(reasonController.text),
                                        child: const Text('Reject'),
                                      ),
                                    ],
                                  ),
                                );
                                if (reason != null && reason.isNotEmpty) {
                                  rejectRequest(requestId, reason);
                                }
                              },
                              child: const Text('Reject'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => approveRequest(requestId),
                              child: const Text('Approve'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading dashboard data...'),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(errorMessage, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Mock data for demonstration
    final userStats = dashboardData?['user_statistics'] ?? {'total_users': '156', 'new_users_today': '0'};
    final appointmentStats = dashboardData?['appointment_statistics'] ?? {'total_appointments': '89', 'scheduled': '45', 'completed': '32', 'cancelled': '12'};

    return Column(
      children: [
        // Title bar always above
        Container(
          color: Colors.lightBlue.shade100,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.fromARGB(255, 211, 224, 233), Color(0xFFFFFFFF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: RefreshIndicator(
              onRefresh: fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Metrics Row
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildAnimatedMetricCard(
                              'Total Users',
                              userStats['total_users']?.toString() ?? '156',
                              Icons.people_alt_rounded,
                              [Colors.blue.shade400, Colors.blue.shade600, Colors.blue.shade800],
                              Icons.group_add,
                            ),
                          ),
                          Expanded(
                            child: _buildAnimatedMetricCard(
                              'New Today',
                              userStats['new_users_today']?.toString() ?? '0',
                              Icons.trending_up,
                              [Colors.orange.shade400, Colors.orange.shade600, Colors.orange.shade800],
                              Icons.person_add,
                            ),
                          ),
                          Expanded(
                            child: _buildAnimatedMetricCard(
                              'Total Appointments',
                              appointmentStats['total_appointments']?.toString() ?? '89',
                              Icons.calendar_month_rounded,
                              [Colors.purple.shade400, Colors.purple.shade600, Colors.purple.shade800],
                              Icons.schedule,
                            ),
                          ),
                          Expanded(
                            child: _buildAnimatedMetricCard(
                              'Completed',
                              appointmentStats['completed']?.toString() ?? '32',
                              Icons.check_circle_rounded,
                              [Colors.green.shade400, Colors.green.shade600, Colors.green.shade800],
                              Icons.thumb_up,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Credential Change Requests
                    _buildCredentialChangeRequestsSection(),

                    // Recent Activity
                    _buildRecentActivity(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: const Color.fromARGB(255, 30, 182, 88),
      ),
      body: Container(
        color: const Color.fromARGB(255, 249, 250, 250),
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Always visible NavigationRail
            SizedBox(
              width: 220,
              child: ListView(
                children: [
                  for (int i = 0; i < _buildNavigationDestinations().length; i++)
                    ListTile(
                      leading: _buildNavigationDestinations()[i].icon,
                      title: _buildNavigationDestinations()[i].label,
                      selected: _selectedIndex == i,
                      onTap: () => _handleNavigation(i),
                    ),
                ],
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main content area
            Expanded(
              child: _selectedIndex == 0
                  ? _buildDashboardContent()
                  : _selectedIndex == 1
                      ? AdminUsersPage(userData: _currentUser)
                      : _selectedIndex == 2
                          ? AdminAppointmentsPage(userData: _currentUser)
                          : _selectedIndex == 3
                              ? AdminAnalyticsPage(userData: _currentUser)
                              : _selectedIndex == 4
                                  ? AdminReAdmissionPage(userData: _currentUser)
                                  : _selectedIndex == 5
                                      ? AdminDisciplinePage(userData: _currentUser)
                                      : _selectedIndex == 6
                                          ? AdminExitInterviewsPage(userData: _currentUser)
                                          : AdminFormsPage(userData: _currentUser),
            ),
          ],
        ),
      ),
    );
  }
}
