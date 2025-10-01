import 'dart:convert';
import 'package:shelf/shelf.dart';

class AdminRoutes {
  final dynamic _database;

  AdminRoutes(this._database);

  // Helper method for role-based authorization
  Future<bool> _checkUserRole(int userId, String requiredRole) async {
    final result = await _database.query(
      'SELECT role FROM users WHERE id = @id',
      {'id': userId},
    );

    if (result.isEmpty) return false;
    final userRole = result.first[0];

    // Admin has access to everything
    if (userRole == 'admin') return true;

    // Counselor has access to counselor and student functions
    if (requiredRole == 'counselor' && userRole == 'counselor') return true;
    if (requiredRole == 'student' && (userRole == 'counselor' || userRole == 'student')) return true;

    return userRole == requiredRole;
  }

  // ================= ADMIN ENDPOINTS =================

  Future<Response> getAdminDashboard(Request request) async {
    try {
      final userId = int.parse(request.url.queryParameters['user_id'] ?? '0');
      if (!await _checkUserRole(userId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      // Get user statistics
      final userStats = await _database.query('SELECT * FROM user_statistics');
      final appointmentStats = await _database.query('SELECT * FROM appointment_statistics');
      final counselorWorkload = await _database.query('SELECT * FROM counselor_workload');

      // Query to get new users today count
      final newUsersTodayResult = await _database.query('''
        SELECT COUNT(*) FROM users
        WHERE role = 'student' AND created_at >= CURRENT_DATE
      ''');

      final newUsersTodayCount = newUsersTodayResult.isNotEmpty ? newUsersTodayResult.first[0] : 0;

      return Response.ok(jsonEncode({
        'user_statistics': userStats.isNotEmpty ? {
          'total_users': userStats.first[0],
          'admin_count': userStats.first[1],
          'counselor_count': userStats.first[2],
          'student_count': userStats.first[3],
          'new_users_30_days': userStats.first[4],
          'new_users_7_days': userStats.first[5],
          'new_users_today': newUsersTodayCount,
        } : null,
        'appointment_statistics': appointmentStats.isNotEmpty ? {
          'total_appointments': appointmentStats.first[0],
          'scheduled_count': appointmentStats.first[1],
          'completed_count': appointmentStats.first[2],
          'cancelled_count': appointmentStats.first[3],
          'upcoming_count': appointmentStats.first[4],
          'overdue_count': appointmentStats.first[5],
          'avg_days_to_appointment': appointmentStats.first[6],
          'appointments_30_days': appointmentStats.first[7],
        } : null,
        'counselor_workload': counselorWorkload.map((row) => {
          'counselor_id': row[0],
          'counselor_name': row[1],
          'counselor_email': row[2],
          'total_appointments': row[3],
          'scheduled_appointments': row[4],
          'completed_appointments': row[5],
          'upcoming_appointments': row[6],
          'overdue_appointments': row[7],
        }).toList(),
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch admin dashboard: $e'}),
      );
    }
  }

  Future<Response> getAdminUsers(Request request) async {
    try {
      final userId = int.parse(request.url.queryParameters['user_id'] ?? '0');
      if (!await _checkUserRole(userId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final result = await _database.query('''
        SELECT id, username, email, role, created_at, student_id, first_name, last_name, grade_level, section
        FROM users
        ORDER BY role, created_at DESC
      ''');

      final users = result.map((row) => {
        'id': row[0],
        'username': row[1],
        'email': row[2],
        'role': row[3],
        'created_at': row[4]?.toIso8601String(),
        'student_id': row[5],
        'first_name': row[6],
        'last_name': row[7],
        'grade_level': row[8],
        'section': row[9],
      }).toList();

      return Response.ok(jsonEncode({'users': users}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch users: $e'}),
      );
    }
  }

  Future<Response> createAdminUser(Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final adminId = data['admin_id'];

      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final role = data['role'] ?? 'student';
      final userData = {
        'username': data['username'],
        'email': data['email'],
        'password': data['password'],
        'role': role,
      };

      if (role == 'student') {
        userData.addAll({
          'student_id': data['student_id'] ?? 'STU${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
          'first_name': data['first_name'] ?? data['username'],
          'last_name': data['last_name'] ?? '',
          'grade_level': data['grade_level'] ?? 'Unknown',
          'section': data['section'] ?? 'Unknown',
        });
      }

      final userResult = await _database.query('''
        INSERT INTO users (username, email, password, role, student_id, first_name, last_name, grade_level, section)
        VALUES (@username, @email, @password, @role, @student_id, @first_name, @last_name, @grade_level, @section)
        RETURNING id, username, email, role, created_at, student_id, first_name, last_name, grade_level, section
      ''', userData);

      final userRow = userResult.first;

      return Response.ok(jsonEncode({
        'id': userRow[0],
        'username': userRow[1],
        'email': userRow[2],
        'role': userRow[3],
        'created_at': userRow[4]?.toIso8601String(),
        'student_id': userRow[5],
        'first_name': userRow[6],
        'last_name': userRow[7],
        'grade_level': userRow[8],
        'section': userRow[9],
        'message': 'User created successfully by admin',
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to create user: $e'}),
      );
    }
  }

  Future<Response> updateAdminUser(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final adminId = data['admin_id'];

      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      // Build update query
      final updateFields = <String>[];
      final params = <String, dynamic>{'id': int.parse(id)};

      if (data['username'] != null) {
        updateFields.add('username = @username');
        params['username'] = data['username'];
      }
      if (data['email'] != null) {
        updateFields.add('email = @email');
        params['email'] = data['email'];
      }
      if (data['role'] != null) {
        updateFields.add('role = @role');
        params['role'] = data['role'];
      }
      if (data['student_id'] != null) {
        updateFields.add('student_id = @student_id');
        params['student_id'] = data['student_id'];
      }
      if (data['first_name'] != null) {
        updateFields.add('first_name = @first_name');
        params['first_name'] = data['first_name'];
      }
      if (data['last_name'] != null) {
        updateFields.add('last_name = @last_name');
        params['last_name'] = data['last_name'];
      }
      if (data['grade_level'] != null) {
        updateFields.add('grade_level = @grade_level');
        params['grade_level'] = data['grade_level'];
      }
      if (data['section'] != null) {
        updateFields.add('section = @section');
        params['section'] = data['section'];
      }

      if (updateFields.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'No fields to update'}));
      }

      final updateQuery = 'UPDATE users SET ${updateFields.join(', ')} WHERE id = @id';
      await _database.execute(updateQuery, params);

      return Response.ok(jsonEncode({'message': 'User updated successfully'}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update user: $e'}),
      );
    }
  }

  Future<Response> deleteAdminUser(Request request, String id) async {
    try {
      final adminId = int.parse(request.url.queryParameters['admin_id'] ?? '0');
      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      // Delete user
      await _database.execute('DELETE FROM users WHERE id = @id', {'id': int.parse(id)});

      return Response.ok(jsonEncode({'message': 'User deleted successfully'}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to delete user: $e'}),
      );
    }
  }

  Future<Response> getAdminAppointments(Request request) async {
    try {
      final adminId = int.parse(request.url.queryParameters['admin_id'] ?? '0');
      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final result = await _database.query('''
        SELECT
          a.id,
          a.student_id,
          a.counselor_id,
          a.appointment_date,
          a.purpose,
          a.course,
          a.status,
          a.notes,
          a.created_at,
          CONCAT(s.first_name, ' ', s.last_name) as student_name,
          u.username as counselor_name,
          s.student_id as student_number,
          s.first_name as student_first_name,
          s.last_name as student_last_name,
          s.grade_level,
          s.section,
          u.email as counselor_email
        FROM appointments a
        JOIN users s ON a.student_id = s.id
        JOIN users u ON a.counselor_id = u.id
        ORDER BY a.appointment_date DESC
      ''');

      final appointments = result.map((row) => {
        'id': row[0],
        'student_id': row[1],
        'counselor_id': row[2],
        'appointment_date': row[3] is DateTime ? (row[3] as DateTime).toIso8601String() : row[3].toString(),
        'purpose': row[4]?.toString() ?? '',
        'course': row[5]?.toString() ?? '',
        'status': row[6]?.toString() ?? 'scheduled',
        'notes': row[7]?.toString() ?? '',
        'created_at': row[8] is DateTime ? (row[8] as DateTime).toIso8601String() : row[8].toString(),
        'student_name': row[9]?.toString() ?? 'Unknown Student',
        'counselor_name': row[10]?.toString() ?? 'Unknown Counselor',
        'student_number': row[11]?.toString(),
        'student_first_name': row[12]?.toString(),
        'student_last_name': row[13]?.toString(),
        'grade_level': row[14]?.toString(),
        'section': row[15]?.toString(),
        'counselor_email': row[16]?.toString(),
      }).toList();

      return Response.ok(jsonEncode({
        'success': true,
        'count': appointments.length,
        'appointments': appointments
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch appointments: $e'}),
      );
    }
  }

  Future<Response> getAdminAnalytics(Request request) async {
    try {
      final adminId = int.parse(request.url.queryParameters['admin_id'] ?? '0');
      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final dailySummary = await _database.query('SELECT * FROM daily_appointment_summary');
      final monthlyRegistrations = await _database.query('SELECT * FROM monthly_user_registrations');
      final purposeDistribution = await _database.query('SELECT * FROM appointment_purpose_distribution');

      return Response.ok(jsonEncode({
        'daily_appointment_summary': dailySummary.map((row) => {
          'appointment_day': row[0]?.toString(),
          'total_appointments': row[1],
          'scheduled': row[2],
          'completed': row[3],
          'cancelled': row[4],
        }).toList(),
        'monthly_user_registrations': monthlyRegistrations.map((row) => {
          'registration_month': row[0]?.toString(),
          'total_registrations': row[1],
          'student_registrations': row[2],
          'counselor_registrations': row[3],
          'admin_registrations': row[4],
        }).toList(),
        'appointment_purpose_distribution': purposeDistribution.map((row) => {
          'purpose_category': row[0],
          'appointment_count': row[1],
          'percentage': row[2],
        }).toList(),
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch analytics: $e'}),
      );
    }
  }

  // ================= COUNSELOR ENDPOINTS =================

  Future<Response> getCounselorDashboard(Request request) async {
    try {
      final counselorId = int.parse(request.url.queryParameters['counselor_id'] ?? '0');
      if (!await _checkUserRole(counselorId, 'counselor')) {
        return Response.forbidden(jsonEncode({'error': 'Counselor access required'}));
      }

      // Get counselor's appointments
      final appointments = await _database.query('''
        SELECT
          a.id,
          a.student_id,
          a.appointment_date,
          a.purpose,
          a.course,
          a.status,
          a.notes,
          CONCAT(s.first_name, ' ', s.last_name) as student_name,
          s.student_id as student_number,
          s.grade_level,
          s.section
        FROM appointments a
        JOIN users s ON a.student_id = s.id
        WHERE a.counselor_id = @counselor_id
        ORDER BY a.appointment_date DESC
        LIMIT 10
      ''', {'counselor_id': counselorId});

      // Get counselor's statistics
      final stats = await _database.query('''
        SELECT
          COUNT(*) as total_appointments,
          COUNT(CASE WHEN status = 'scheduled' THEN 1 END) as scheduled,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
          COUNT(CASE WHEN appointment_date >= CURRENT_DATE THEN 1 END) as upcoming
        FROM appointments
        WHERE counselor_id = @counselor_id
      ''', {'counselor_id': counselorId});

      return Response.ok(jsonEncode({
        'appointments': appointments.map((row) => {
          'id': row[0],
          'student_id': row[1],
          'appointment_date': row[2] is DateTime ? (row[2] as DateTime).toIso8601String() : row[2].toString(),
          'purpose': row[3]?.toString() ?? '',
          'course': row[4]?.toString() ?? '',
          'status': row[5]?.toString() ?? 'scheduled',
          'notes': row[6]?.toString() ?? '',
          'student_name': row[7]?.toString() ?? 'Unknown Student',
          'student_number': row[8]?.toString(),
          'grade_level': row[9]?.toString(),
          'section': row[10]?.toString(),
        }).toList(),
        'statistics': stats.isNotEmpty ? {
          'total_appointments': stats.first[0],
          'scheduled': stats.first[1],
          'completed': stats.first[2],
          'upcoming': stats.first[3],
        } : null,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch counselor dashboard: $e'}),
      );
    }
  }

  Future<Response> getCounselorStudents(Request request) async {
    try {
      final counselorId = int.parse(request.url.queryParameters['counselor_id'] ?? '0');
      if (!await _checkUserRole(counselorId, 'counselor')) {
        return Response.forbidden(jsonEncode({'error': 'Counselor access required'}));
      }

      final result = await _database.query('''
        SELECT DISTINCT
          s.id,
          s.username,
          s.email,
          s.student_id,
          s.first_name,
          s.last_name,
          s.grade_level,
          s.section,
          COUNT(a.id) as total_appointments,
          MAX(a.appointment_date) as last_appointment
        FROM users s
        LEFT JOIN appointments a ON s.id = a.student_id AND a.counselor_id = @counselor_id
        WHERE s.role = 'student'
        GROUP BY s.id, s.username, s.email, s.student_id, s.first_name, s.last_name, s.grade_level, s.section
        ORDER BY s.last_name, s.first_name
      ''', {'counselor_id': counselorId});

      final students = result.map((row) => {
        'id': row[0],
        'username': row[1],
        'email': row[2],
        'student_id': row[3],
        'first_name': row[4],
        'last_name': row[5],
        'grade_level': row[6],
        'section': row[7],
        'total_appointments': row[8],
        'last_appointment': row[9]?.toString(),
      }).toList();

      return Response.ok(jsonEncode({'students': students}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch students: $e'}),
      );
    }
  }

  Future<Response> updateCounselorAppointment(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final counselorId = data['counselor_id'];

      if (!await _checkUserRole(counselorId, 'counselor')) {
        return Response.forbidden(jsonEncode({'error': 'Counselor access required'}));
      }

      // Verify counselor owns this appointment
      final appointmentCheck = await _database.query(
        'SELECT counselor_id FROM appointments WHERE id = @id',
        {'id': int.parse(id)},
      );

      if (appointmentCheck.isEmpty) {
        return Response(404, body: jsonEncode({'error': 'Appointment not found'}));
      }

      if (appointmentCheck.first[0] != counselorId) {
        return Response(403, body: jsonEncode({'error': 'You can only update your own appointments'}));
      }

      // Build update query
      final updateFields = <String>[];
      final params = <String, dynamic>{'id': int.parse(id)};

      if (data['appointment_date'] != null) {
        updateFields.add('appointment_date = @appointment_date');
        params['appointment_date'] = DateTime.parse(data['appointment_date']);
      }
      if (data['purpose'] != null) {
        updateFields.add('purpose = @purpose');
        params['purpose'] = data['purpose'];
      }
      if (data['course'] != null) {
        updateFields.add('course = @course');
        params['course'] = data['course'];
      }
      if (data['status'] != null) {
        updateFields.add('status = @status');
        params['status'] = data['status'];
      }
      if (data['notes'] != null) {
        updateFields.add('notes = @notes');
        params['notes'] = data['notes'];
      }

      if (updateFields.isEmpty) {
        return Response(400, body: jsonEncode({'error': 'No fields to update'}));
      }

      final updateQuery = 'UPDATE appointments SET ${updateFields.join(', ')} WHERE id = @id';
      await _database.execute(updateQuery, params);

      return Response.ok(jsonEncode({'message': 'Appointment updated successfully'}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update appointment: $e'}),

      );
    }
  }

  // ================= CASE MANAGEMENT ENDPOINTS =================

  // Re-admission Cases
  Future<Response> getReAdmissionCases(Request request) async {
    try {
      final adminId = int.parse(request.url.queryParameters['admin_id'] ?? '0');
      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final result = await _database.query('''
        SELECT
          rac.id,
          rac.student_id,
          rac.student_name,
          rac.student_number,
          rac.previous_program,
          rac.reason_for_leaving,
          rac.reason_for_return,
          rac.academic_standing,
          rac.gpa,
          rac.status,
          rac.admin_notes,
          rac.counselor_id,
          rac.created_at,
          rac.updated_at,
          rac.reviewed_at,
          rac.reviewed_by,
          u.username as counselor_name,
          ru.username as reviewed_by_name
        FROM re_admission_cases rac
        LEFT JOIN users u ON rac.counselor_id = u.id
        LEFT JOIN users ru ON rac.reviewed_by = ru.id
        ORDER BY rac.created_at DESC
      ''');

      final cases = result.map((row) => {
        'id': row[0],
        'student_id': row[1],
        'student_name': row[2],
        'student_number': row[3],
        'previous_program': row[4],
        'reason_for_leaving': row[5],
        'reason_for_return': row[6],
        'academic_standing': row[7],
        'gpa': row[8],
        'status': row[9],
        'admin_notes': row[10],
        'counselor_id': row[11],
        'created_at': row[12]?.toIso8601String(),
        'updated_at': row[13]?.toIso8601String(),
        'reviewed_at': row[14]?.toIso8601String(),
        'reviewed_by': row[15],
        'counselor_name': row[16],
        'reviewed_by_name': row[17],
      }).toList();

      return Response.ok(jsonEncode({'cases': cases}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch re-admission cases: $e'}),
      );
    }
  }

  Future<Response> updateReAdmissionCase(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final adminId = data['admin_id'];

      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final updateFields = <String>[];
      final params = <String, dynamic>{'id': int.parse(id)};

      if (data['status'] != null) {
        updateFields.add('status = @status');
        params['status'] = data['status'];
      }
      if (data['admin_notes'] != null) {
        updateFields.add('admin_notes = @admin_notes');
        params['admin_notes'] = data['admin_notes'];
      }
      if (data['counselor_id'] != null) {
        updateFields.add('counselor_id = @counselor_id');
        params['counselor_id'] = data['counselor_id'];
      }

      if (updateFields.isNotEmpty) {
        updateFields.add('reviewed_at = NOW()');
        updateFields.add('reviewed_by = @reviewed_by');
        params['reviewed_by'] = adminId;

        final updateQuery = 'UPDATE re_admission_cases SET ${updateFields.join(', ')} WHERE id = @id';
        await _database.execute(updateQuery, params);
      }

      return Response.ok(jsonEncode({'message': 'Re-admission case updated successfully'}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update re-admission case: $e'}),
      );
    }
  }

  // Discipline Cases
  Future<Response> getDisciplineCases(Request request) async {
    try {
      final adminId = int.parse(request.url.queryParameters['admin_id'] ?? '0');
      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final result = await _database.query('''
        SELECT
          dc.id,
          dc.student_id,
          dc.student_name,
          dc.student_number,
          dc.incident_date,
          dc.incident_description,
          dc.incident_location,
          dc.witnesses,
          dc.action_taken,
          dc.severity,
          dc.status,
          dc.admin_notes,
          dc.counselor_id,
          dc.created_at,
          dc.updated_at,
          dc.resolved_at,
          dc.resolved_by,
          u.username as counselor_name,
          ru.username as resolved_by_name
        FROM discipline_cases dc
        LEFT JOIN users u ON dc.counselor_id = u.id
        LEFT JOIN users ru ON dc.resolved_by = ru.id
        ORDER BY dc.created_at DESC
      ''');

      final cases = result.map((row) => {
        'id': row[0],
        'student_id': row[1],
        'student_name': row[2],
        'student_number': row[3],
        'incident_date': row[4]?.toIso8601String(),
        'incident_description': row[5],
        'incident_location': row[6],
        'witnesses': row[7],
        'action_taken': row[8],
        'severity': row[9],
        'status': row[10],
        'admin_notes': row[11],
        'counselor_id': row[12],
        'created_at': row[13]?.toIso8601String(),
        'updated_at': row[14]?.toIso8601String(),
        'resolved_at': row[15]?.toIso8601String(),
        'resolved_by': row[16],
        'counselor_name': row[17],
        'resolved_by_name': row[18],
      }).toList();

      return Response.ok(jsonEncode({'cases': cases}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch discipline cases: $e'}),
      );
    }
  }

  Future<Response> updateDisciplineCase(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final adminId = data['admin_id'];

      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final updateFields = <String>[];
      final params = <String, dynamic>{'id': int.parse(id)};

      if (data['status'] != null) {
        updateFields.add('status = @status');
        params['status'] = data['status'];
      }
      if (data['admin_notes'] != null) {
        updateFields.add('admin_notes = @admin_notes');
        params['admin_notes'] = data['admin_notes'];
      }
      if (data['action_taken'] != null) {
        updateFields.add('action_taken = @action_taken');
        params['action_taken'] = data['action_taken'];
      }
      if (data['counselor_id'] != null) {
        updateFields.add('counselor_id = @counselor_id');
        params['counselor_id'] = data['counselor_id'];
      }

      if (updateFields.isNotEmpty) {
        if (data['status'] == 'resolved' || data['status'] == 'closed') {
          updateFields.add('resolved_at = NOW()');
          updateFields.add('resolved_by = @resolved_by');
          params['resolved_by'] = adminId;
        }

        final updateQuery = 'UPDATE discipline_cases SET ${updateFields.join(', ')} WHERE id = @id';
        await _database.execute(updateQuery, params);
      }

      return Response.ok(jsonEncode({'message': 'Discipline case updated successfully'}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update discipline case: $e'}),
      );
    }
  }

  // Exit Interviews
  Future<Response> getExitInterviews(Request request) async {
    try {
      final adminId = int.parse(request.url.queryParameters['admin_id'] ?? '0');
      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final result = await _database.query('''
        SELECT
          ei.id,
          ei.student_id,
          ei.student_name,
          ei.student_number,
          ei.interview_type,
          ei.interview_date,
          ei.reason_for_leaving,
          ei.satisfaction_rating,
          ei.academic_experience,
          ei.support_services_experience,
          ei.facilities_experience,
          ei.overall_improvements,
          ei.future_plans,
          ei.contact_info,
          ei.status,
          ei.admin_notes,
          ei.counselor_id,
          ei.created_at,
          ei.updated_at,
          ei.completed_at,
          u.username as counselor_name
        FROM exit_interviews ei
        LEFT JOIN users u ON ei.counselor_id = u.id
        ORDER BY ei.created_at DESC
      ''');

      final interviews = result.map((row) => {
        'id': row[0],
        'student_id': row[1],
        'student_name': row[2],
        'student_number': row[3],
        'interview_type': row[4],
        'interview_date': row[5]?.toIso8601String(),
        'reason_for_leaving': row[6],
        'satisfaction_rating': row[7],
        'academic_experience': row[8],
        'support_services_experience': row[9],
        'facilities_experience': row[10],
        'overall_improvements': row[11],
        'future_plans': row[12],
        'contact_info': row[13],
        'status': row[14],
        'admin_notes': row[15],
        'counselor_id': row[16],
        'created_at': row[17]?.toIso8601String(),
        'updated_at': row[18]?.toIso8601String(),
        'completed_at': row[19]?.toIso8601String(),
        'counselor_name': row[20],
      }).toList();

      return Response.ok(jsonEncode({'interviews': interviews}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch exit interviews: $e'}),
      );
    }
  }

  Future<Response> updateExitInterview(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final adminId = data['admin_id'];

      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final updateFields = <String>[];
      final params = <String, dynamic>{'id': int.parse(id)};

      if (data['status'] != null) {
        updateFields.add('status = @status');
        params['status'] = data['status'];
      }
      if (data['admin_notes'] != null) {
        updateFields.add('admin_notes = @admin_notes');
        params['admin_notes'] = data['admin_notes'];
      }
      if (data['counselor_id'] != null) {
        updateFields.add('counselor_id = @counselor_id');
        params['counselor_id'] = data['counselor_id'];
      }

      if (updateFields.isNotEmpty) {
        if (data['status'] == 'completed') {
          updateFields.add('completed_at = NOW()');
        }

        final updateQuery = 'UPDATE exit_interviews SET ${updateFields.join(', ')} WHERE id = @id';
        await _database.execute(updateQuery, params);
      }

      return Response.ok(jsonEncode({'message': 'Exit interview updated successfully'}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update exit interview: $e'}),
      );
    }
  }

  // Get Case Summary for Dashboard
  Future<Response> getCaseSummary(Request request) async {
    try {
      final adminId = int.parse(request.url.queryParameters['admin_id'] ?? '0');
      if (!await _checkUserRole(adminId, 'admin')) {
        return Response.forbidden(jsonEncode({'error': 'Admin access required'}));
      }

      final result = await _database.query('SELECT * FROM admin_case_summary');

      final summary = result.map((row) => {
        'case_type': row[0],
        'total_cases': row[1],
        'pending_cases': row[2],
        'approved_cases': row[3],
        'rejected_cases': row[4],
        'recent_cases': row[5],
      }).toList();

      return Response.ok(jsonEncode({'case_summary': summary}));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch case summary: $e'}),
      );
    }
  }
}
