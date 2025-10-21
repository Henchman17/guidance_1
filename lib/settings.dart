import 'package:flutter/material.dart';
import 'package:guidance_1/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'counselor/counselor_dashboard.dart';
import 'counselor/counselor_students_page.dart';
import 'counselor/counselor_appointments_page.dart';
import 'counselor/counselor_sessions_page.dart';
import 'privacy_policy_page.dart';

class SettingsPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  
  const SettingsPage({super.key, this.userData});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  String _selectedRole = 'Student';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _studentData;
  bool _isLoading = false;
  int _selectedIndex = 4;
  List<Map<String, dynamic>> _credentialRequests = [];

  // Database API endpoints
  static const String _baseUrl = 'http://10.0.2.2:8080/api'; // Adjust port as needed - 10.0.2.2 for Android emulator

  @override
  void initState() {
    super.initState();
    _loadDarkMode();
    _currentUser = widget.userData;
    _loadSettings();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
    });
    _updateTheme();
  }

  void _updateTheme() {
    // Theme changes should be handled at the MaterialApp level using ThemeMode.
    // This function is left empty or can trigger a callback to a theme provider if implemented.
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all stored preferences
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all previous routes
    );
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    setState(() {
      _darkMode = value;
    });
    _updateTheme();
  }

  void _loadSettings() {
    // Always fetch fresh profile settings from users table API
    if (_currentUser != null && _currentUser!['id'] != null) {
      _loadUserProfile();
    } else if (widget.userData != null && widget.userData!['id'] != null) {
      // Use passed userData as fallback, but still fetch fresh data
      setState(() {
        _currentUser = widget.userData;
      });
      _loadUserProfile();
    }

    // Load other settings from SharedPreferences (non-user data)
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _emailNotifications = prefs.getBool('emailNotifications') ?? true;
      
      // Only use SharedPreferences for role if no user data is available
      if (widget.userData == null) {
        _selectedRole = prefs.getString('selectedRole') ?? 'Student';
        _nameController.text = prefs.getString('userName') ?? '';
        _emailController.text = prefs.getString('userEmail') ?? '';
        _phoneController.text = prefs.getString('userPhone') ?? '';
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('emailNotifications', _emailNotifications);
    await prefs.setString('selectedRole', _selectedRole);
    await prefs.setString('userName', _nameController.text);
    await prefs.setString('userEmail', _emailController.text);
    await prefs.setString('userPhone', _phoneController.text);
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Navigate to different pages based on the selected index
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CounselorDashboardPage(userData: _currentUser)),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CounselorStudentsPage(userData: _currentUser)),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CounselorAppointmentsPage(userData: _currentUser)),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CounselorSessionsPage(userData: _currentUser)),
        );
        break;
      case 4:
        // Already on Settings page
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profile Settings',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildProfileSection(),
            const SizedBox(height: 32),
            const Text(
              'Preferences',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPreferencesSection(),
            const SizedBox(height: 32),
            const Text(
              'Notifications',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildNotificationsSection(),
            const SizedBox(height: 32),
            const Text(
              'Credential Change Requests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildCredentialRequestsSection(),
            const SizedBox(height: 32),
            const Text(
              'Privacy & Security',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildPrivacySection(),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  await _saveSettings();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings saved successfully')),
                  );
                },
                child: const Text('Save Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
              ),
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 12),
            // Display username from users table
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_circle, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text(
                    'Username:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentUser?['username'] ?? 'N/A',
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Read-only role display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_circle, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text(
                    'User Role:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedRole,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
            // Additional student information for students
            if (_selectedRole == 'student' && _studentData != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Student ID:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _studentData!['student_id'] ?? 'N/A',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.grade, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _studentData!['status'] ?? 'N/A',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.class_, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Program:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _studentData!['program'] ?? 'N/A',
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: Text(_darkMode ? 'Dark theme enabled' : 'Light theme enabled'),
              value: _darkMode,
              onChanged: _toggleDarkMode,
              secondary: Icon(
                _darkMode ? Icons.dark_mode : Icons.light_mode,
                color: _darkMode ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive app notifications'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive email updates'),
              value: _emailNotifications,
              onChanged: (value) {
                setState(() {
                  _emailNotifications = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRequestsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Request Username Change'),
              subtitle: const Text('Submit a request to change your username'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCredentialChangeDialog('username'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Request Email Change'),
              subtitle: const Text('Submit a request to change your email address'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCredentialChangeDialog('email'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Request Password Change'),
              subtitle: const Text('Submit a request to change your password'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCredentialChangeDialog('password'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text('Request Student ID Change'),
              subtitle: const Text('Submit a request to change your student ID'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showCredentialChangeDialog('student_id'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View Pending Requests'),
              subtitle: const Text('Check status of your credential change requests'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showPendingRequestsDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacy Policy'),
              subtitle: const Text('View data protection and privacy information'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: _signOut,
            ),
          ],
        ),
      ),
    );
  }

  // Database access methods for users and students tables

  /// Fetch user data from users table
  Future<Map<String, dynamic>?> _fetchUserData(int userId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/users/$userId'));
      print('API Response Status: ${response.statusCode}'); // Debug log
      print('API Response Body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        print('Decoded API data: $decodedData'); // Debug log

        // Handle different response formats
        if (decodedData is Map<String, dynamic>) {
          return decodedData;
        } else if (decodedData is List && decodedData.isNotEmpty) {
          // If API returns a list, take the first item
          return decodedData.first as Map<String, dynamic>;
        } else {
          print('Unexpected API response format');
          return null;
        }
      } else {
        print('Failed to fetch user data: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  /// Fetch student data from users table (merged structure)
  Future<Map<String, dynamic>?> _fetchStudentData(int userId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/users/$userId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      }
      return null;
    } catch (e) {
      print('Error fetching student data: $e');
      return null;
    }
  }

  /// Update user data in users table
  Future<bool> _updateUserData(int userId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  /// Update student data in users table (merged structure)
  Future<bool> _updateStudentData(int userId, Map<String, dynamic> updates) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Error updating student data: $e');
      return false;
    }
  }

  /// Load complete user profile from users table (merged structure)
  Future<void> _loadUserProfile() async {
    if (_currentUser == null || _currentUser!['id'] == null) return;

    if (mounted) setState(() => _isLoading = true);

    try {
      final userId = _currentUser!['id'];

      // Fetch fresh user data from users table (now contains all student data)
      final userData = await _fetchUserData(userId);
      if (userData != null) {
        print('Fetched user data: $userData'); // Debug log
        if (mounted) setState(() {
          _currentUser = userData;
          _selectedRole = userData['role'] ?? 'student';

          // Populate email field
          _emailController.text = userData['email'] ?? '';

          // For students, populate full name from first_name and last_name
          if (_selectedRole == 'student') {
            final firstName = userData['first_name'] ?? '';
            final lastName = userData['last_name'] ?? '';
            if (firstName.isNotEmpty && lastName.isNotEmpty) {
              _nameController.text = '$firstName $lastName';
            } else {
              // Fallback to username if names not available
              _nameController.text = userData['username'] ?? '';
            }
          } else {
            // For non-students, use username as display name
            _nameController.text = userData['username'] ?? '';
          }

          // Store student data for later use
          _studentData = userData;
        });
        print('Updated UI fields - Name: ${_nameController.text}, Email: ${_emailController.text}'); // Debug log
      } else {
        print('No user data received from API'); // Debug log
      }
    } catch (e) {
      print('Error loading user profile: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Save user profile changes to database
  Future<void> _saveUserProfile() async {
    if (_currentUser == null || _currentUser!['id'] == null) return;

    setState(() => _isLoading = true);

    try {
      final userId = _currentUser!['id'];
      bool success = true;

      // Update user data in users table
      final userUpdates = {
        'username': _nameController.text,
        'email': _emailController.text,
        'role': _selectedRole,
      };

      success &= await _updateUserData(userId, userUpdates);

      // Update student data if user is a student
      if (_selectedRole == 'student' && _studentData != null) {
        final studentUpdates = {
          'first_name': _studentData!['first_name'],
          'last_name': _studentData!['last_name'],
          'status': _studentData!['status'],
          'program': _studentData!['program'],
        };

        success &= await _updateStudentData(userId, studentUpdates);
      }

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        // Reload profile to get fresh data
        await _loadUserProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    } catch (e) {
      print('Error saving user profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Get all users from users table (admin function)
  Future<List<Map<String, dynamic>>> _fetchAllUsers() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/users'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['users'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching all users: $e');
      return [];
    }
  }

  /// Get all students with user information (from users table)
  Future<List<Map<String, dynamic>>> _fetchAllStudentsWithUsers() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/users'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final allUsers = List<Map<String, dynamic>>.from(data['users'] ?? []);
        // Filter for students only
        return allUsers.where((user) => user['role'] == 'student').toList();
      }
      return [];
    } catch (e) {
      print('Error fetching students with users: $e');
      return [];
    }
  }

  /// Search users table (merged structure)
  Future<List<Map<String, dynamic>>> _searchUsersAndStudents(String query) async {
    try {
      // Search users table (now contains all student data)
      final usersResponse = await http.get(Uri.parse('$_baseUrl/users'));

      List<Map<String, dynamic>> results = [];

      if (usersResponse.statusCode == 200) {
        final usersData = jsonDecode(usersResponse.body);
        final users = List<Map<String, dynamic>>.from(usersData['users'] ?? []);
        results.addAll(users.where((user) =>
          user['username'].toString().toLowerCase().contains(query.toLowerCase()) ||
          user['email'].toString().toLowerCase().contains(query.toLowerCase()) ||
          user['first_name'].toString().toLowerCase().contains(query.toLowerCase()) ||
          user['last_name'].toString().toLowerCase().contains(query.toLowerCase()) ||
          user['student_id'].toString().toLowerCase().contains(query.toLowerCase())
        ));
      }

      return results;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  /// Delete user from users table (admin function)
  Future<bool> _deleteUser(int userId) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/users/$userId'));
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  /// Get database statistics
  Future<Map<String, dynamic>> _getDatabaseStats() async {
    try {
      final users = await _fetchAllUsers();
      final students = await _fetchAllStudentsWithUsers();

      return {
        'total_users': users.length,
        'total_students': students.length,
        'total_counselors': users.where((u) => u['role'] == 'counselor').length,
        'total_admins': users.where((u) => u['role'] == 'admin').length,
      };
    } catch (e) {
      print('Error getting database stats: $e');
      return {};
    }
  }

  /// Show dialog for credential change request
  void _showCredentialChangeDialog(String credentialType) {
    final TextEditingController controller = TextEditingController();
    String title = '';
    String label = '';
    String hint = '';

    switch (credentialType) {
      case 'username':
        title = 'Request Username Change';
        label = 'New Username';
        hint = 'Enter your desired username';
        break;
      case 'email':
        title = 'Request Email Change';
        label = 'New Email Address';
        hint = 'Enter your new email address';
        break;
      case 'password':
        title = 'Request Password Change';
        label = 'New Password';
        hint = 'Enter your new password';
        break;
      case 'student_id':
        title = 'Request Student ID Change';
        label = 'New Student ID';
        hint = 'Enter your new student ID';
        break;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                ),
                obscureText: credentialType == 'password',
                keyboardType: credentialType == 'email' ? TextInputType.emailAddress : TextInputType.text,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your request will be reviewed by an administrator. You will be notified once it is processed.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await _submitCredentialChangeRequest(credentialType, controller.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Submit Request'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog for pending credential change requests
  void _showPendingRequestsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pending Credential Change Requests'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchCredentialRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Text('Error loading requests');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('No pending requests');
                } else {
                  final requests = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return ListTile(
                        title: Text('${request['request_type']} Change'),
                        subtitle: Text('Status: ${request['status']}'),
                        trailing: Text(request['created_at'] ?? ''),
                      );
                    },
                  );
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Submit credential change request to API
  Future<void> _submitCredentialChangeRequest(String credentialType, String newValue) async {
    if (_currentUser == null || _currentUser!['id'] == null) return;

    try {
      // Get current value based on credential type
      String currentValue = '';
      switch (credentialType) {
        case 'username':
          currentValue = _currentUser!['username'] ?? '';
          break;
        case 'email':
          currentValue = _currentUser!['email'] ?? '';
          break;
        case 'student_id':
          currentValue = _currentUser!['student_id'] ?? '';
          break;
        case 'password':
          // For password changes, we don't send the current password for security
          currentValue = '';
          break;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/credential-change-requests'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _currentUser!['id'],
          'request_type': credentialType,
          'current_value': currentValue,
          'new_value': newValue,
          'reason': 'User requested change via app',
          'status': 'pending',
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credential change request submitted successfully')),
        );
      } else {
        print('Failed to submit request. Status: ${response.statusCode}, Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit request. Please try again.')),
        );
      }
    } catch (e) {
      print('Error submitting credential change request: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error submitting request. Please check your connection.')),
      );
    }
  }

  /// Fetch credential change requests for current user
  Future<List<Map<String, dynamic>>> _fetchCredentialRequests() async {
    if (_currentUser == null || _currentUser!['id'] == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/credential-change-requests/user/${_currentUser!['id']}'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['requests'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error fetching credential requests: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
