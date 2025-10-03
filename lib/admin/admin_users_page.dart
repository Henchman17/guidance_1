import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminUsersPage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AdminUsersPage({super.key, this.userData});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  bool isLoading = true;
  String errorMessage = '';
  String searchQuery = '';
  String selectedRoleFilter = 'All';

  static const String apiBaseUrl = 'http://localhost:8080';

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final userId = widget.userData?['id'] ?? 0;
      final response = await http.get(
        Uri.parse('$apiBaseUrl/api/admin/users?user_id=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          users = data['users'] ?? [];
          filteredUsers = users;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Failed to load users';
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

  void _filterUsers() {
    setState(() {
      filteredUsers = users.where((user) {
        final matchesSearch = searchQuery.isEmpty ||
            user['username'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            user['email'].toString().toLowerCase().contains(searchQuery.toLowerCase());

        final matchesRole = selectedRoleFilter == 'All' || user['role'] == selectedRoleFilter.toLowerCase();

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  Future<void> deleteUser(int userId) async {
    try {
      final adminId = widget.userData?['id'] ?? 0;
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/api/admin/users/$userId?admin_id=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete user'),
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

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'counselor':
        return Colors.blue;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildUserCard(dynamic user) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showUserDetailsDialog(user),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: _getRoleColor(user['role'] ?? 'unknown').withOpacity(0.2),
                child: Text(
                  user['username']?.substring(0, 1).toUpperCase() ?? 'U',
                  style: TextStyle(
                    color: _getRoleColor(user['role'] ?? 'unknown'),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user['username'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRoleColor(user['role'] ?? 'unknown').withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _getRoleColor(user['role'] ?? 'unknown').withOpacity(0.3)),
                          ),
                          child: Text(
                            (user['role'] ?? 'unknown').toUpperCase(),
                            style: TextStyle(
                              color: _getRoleColor(user['role'] ?? 'unknown'),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user['email'] ?? 'N/A',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    if (user['role'] == 'student') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Student ID: ${user['student_id'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditUserDialog(user);
                      break;
                    case 'delete':
                      _showDeleteConfirmationDialog(user);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Edit User'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete User'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserDetailsDialog(dynamic user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getRoleColor(user['role'] ?? 'unknown').withOpacity(0.2),
              child: Text(
                user['username']?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  color: _getRoleColor(user['role'] ?? 'unknown'),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(user['username'] ?? 'Unknown'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Username', user['username'] ?? 'N/A'),
              _buildDetailRow('Email', user['email'] ?? 'N/A'),
              _buildDetailRow('Role', (user['role'] ?? 'N/A').toUpperCase()),
              _buildDetailRow('Created', user['created_at'] ?? 'N/A'),
              if (user['role'] == 'student') ...[
                const Divider(),
                _buildDetailRow('Student ID', user['student_id'] ?? 'N/A'),
                _buildDetailRow('First Name', user['first_name'] ?? 'N/A'),
                _buildDetailRow('Last Name', user['last_name'] ?? 'N/A'),
                _buildDetailRow('Status', user['status'] ?? 'N/A'),
                _buildDetailRow('Program', user['program'] ?? 'N/A'),
              ],
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(dynamic user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['username']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              deleteUser(user['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditUserDialog(dynamic user) {
    // Implementation for edit user dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit user functionality coming soon')),
    );
  }

  Widget _buildRoleFilterChip(String label, Color color) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: selectedRoleFilter == label ? Colors.white : color)),
      selected: selectedRoleFilter == label,
      selectedColor: color,
      backgroundColor: color.withOpacity(0.15),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            selectedRoleFilter = label;
            _filterUsers();
          });
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  void showCreateUserDialog() {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final studentIdController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final statusController = TextEditingController();
    final programController = TextEditingController();
    String selectedRole = 'student';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New User'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: ['admin', 'counselor', 'student']
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => selectedRole = value!),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                TextFormField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                if (selectedRole == 'student') ...[
                  TextFormField(
                    controller: studentIdController,
                    decoration: const InputDecoration(labelText: 'Student ID'),
                  ),
                  TextFormField(
                    controller: firstNameController,
                    decoration: const InputDecoration(labelText: 'First Name'),
                  ),
                  TextFormField(
                    controller: lastNameController,
                    decoration: const InputDecoration(labelText: 'Last Name'),
                  ),
                  TextFormField(
                    controller: statusController,
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  TextFormField(
                    controller: programController,
                    decoration: const InputDecoration(labelText: 'Program'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final adminId = widget.userData?['id'] ?? 0;
                  final userData = {
                    'admin_id': adminId,
                    'username': usernameController.text,
                    'email': emailController.text,
                    'password': passwordController.text,
                    'role': selectedRole,
                  };

                  if (selectedRole == 'student') {
                    userData.addAll({
                      'student_id': studentIdController.text,
                      'first_name': firstNameController.text,
                      'last_name': lastNameController.text,
                      'status': statusController.text,
                      'program': programController.text,
                    });
                  }

                  final response = await http.post(
                    Uri.parse('$apiBaseUrl/api/admin/users'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode(userData),
                  );

                  if (response.statusCode == 200) {
                    Navigator.of(context).pop();
                    fetchUsers();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User created successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to create user'),
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
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          backgroundColor: const Color(0xFF1E88E5),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading users...'),
            ],
          ),
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Management'),
          backgroundColor: const Color(0xFF1E88E5),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: fetchUsers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'User Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchUsers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search users by username, email, or student ID...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Icon(Icons.search, color: Colors.blue.shade600),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade500),
                                onPressed: () {
                                  setState(() {
                                    searchQuery = '';
                                    _filterUsers();
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      onChanged: (value) {
                        searchQuery = value;
                        _filterUsers();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.filter_list, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Filter by Role',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildRoleFilterChip('All', Colors.grey.shade600),
                        const SizedBox(width: 8),
                        _buildRoleFilterChip('Admin', Colors.red.shade600),
                        const SizedBox(width: 8),
                        _buildRoleFilterChip('Counselor', Colors.blue.shade600),
                        const SizedBox(width: 8),
                        _buildRoleFilterChip('Student', Colors.green.shade600),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredUsers.length} users found',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                FloatingActionButton.extended(
                  onPressed: showCreateUserDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Add User'),
                  backgroundColor: const Color(0xFF1E88E5),
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: filteredUsers.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(filteredUsers[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
