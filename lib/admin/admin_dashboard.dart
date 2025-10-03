import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../login_page.dart';
import '../settings.dart';
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

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? dashboardData;
  bool isLoading = true;
  String errorMessage = '';
  int _selectedIndex = 0;
  Map<String, dynamic>? _currentUser;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _sidebarCollapsed = false;

  static const String apiBaseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    _currentUser = widget.userData;
    fetchDashboardData();
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
        icon: Icon(Icons.settings),
        label: Text('Settings'),
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
      case 8: // Settings
        setState(() => _selectedIndex = 8);
        break;
      case 9: // Logout
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
        Padding(
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
                colors: [Color(0xFFE3F2FD), Color(0xFFFFFFFF)],
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
                            child: _buildMetricCard(
                              'Total Users',
                              userStats['total_users']?.toString() ?? '156',
                              Icons.people,
                              Colors.blue,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricCard(
                              'New Today',
                              userStats['new_users_today']?.toString() ?? '0',
                              Icons.trending_up,
                              Colors.orange,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricCard(
                              'Total Appointments',
                              appointmentStats['total_appointments']?.toString() ?? '89',
                              Icons.calendar_today,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),



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
      body: Column(
        children: [
          // Top navigation bar with user avatar
          Container(
            color: const Color.fromARGB(255, 30, 182, 88),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/s_logo.jpg',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "PLSP Guidance Admin",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Notification icon
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No new notifications')),
                    );
                  },
                  tooltip: 'Notifications',
                ),
                const SizedBox(width: 10),
                // User Avatar with profile info
                if (_currentUser != null)
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('User Profile'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.green,
                                  child: Text(
                                    _currentUser!['username']?.substring(0, 1).toUpperCase() ?? 'A',
                                    style: const TextStyle(fontSize: 32, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Username: ${_currentUser!['username']}'),
                              Text('Email: ${_currentUser!['email'] ?? 'N/A'}'),
                              Text('Role: ${_currentUser!['role'] ?? 'Admin'}'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Text(
                            _currentUser!['username']?.substring(0, 1).toUpperCase() ?? 'A',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 30, 182, 88),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentUser!['username'] ?? 'Admin',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _currentUser!['role'] ?? 'Admin',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
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
                                              : _selectedIndex == 7
                                                  ? AdminFormsPage(userData: _currentUser)
                                                  : SettingsPage(userData: _currentUser),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
