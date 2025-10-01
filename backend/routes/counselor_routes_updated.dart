import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../connection.dart';

class CounselorRoutes {
  final DatabaseConnection _database;

  CounselorRoutes(this._database);

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

  Future<Response> getCounselorDashboard(Request request) async {
    try {
      final counselorId = int.parse(request.url.queryParameters['user_id'] ?? '0');
      if (!await _checkUserRole(counselorId, 'counselor')) {
        return Response.forbidden(jsonEncode({'error': 'Counselor access required'}));
      }

      // Get counselor's statistics
      final stats = await _database.query('''
        SELECT
          COUNT(DISTINCT student_id) as total_students,
          COUNT(*) as total_appointments,
          COUNT(CASE WHEN apt_status = 'scheduled' THEN 1 END) as scheduled,
          COUNT(CASE WHEN apt_status = 'completed' THEN 1 END) as completed
        FROM appointments
        WHERE counselor_id = @counselor_id
      ''', {'counselor_id': counselorId});

      // Get recent students
      final recentStudents = await _database.query('''
        SELECT DISTINCT
          s.id,
          s.first_name,
          s.last_name,
          s.status,
          s.program,
          MAX(a.appointment_date) as last_appointment_date
        FROM users s
        JOIN appointments a ON s.id = a.student_id
        WHERE a.counselor_id = @counselor_id
        GROUP BY s.id, s.first_name, s.last_name, s.status, s.program
        ORDER BY MAX(a.appointment_date) DESC
        LIMIT 5
      ''', {'counselor_id': counselorId});

      // Get upcoming appointments
      final upcomingAppointments = await _database.query('''
        SELECT
          a.id,
          a.student_id,
          a.appointment_date,
          a.purpose,
          a.course,
          a.apt_status,
          a.notes,
          CONCAT(s.first_name, ' ', s.last_name) as student_name,
          s.student_id as student_number,
          s.status,
          s.program
        FROM appointments a
        JOIN users s ON a.student_id = s.id
        WHERE a.counselor_id = @counselor_id AND a.appointment_date >= CURRENT_DATE
        ORDER BY a.appointment_date ASC
        LIMIT 10
      ''', {'counselor_id': counselorId});

      return Response.ok(jsonEncode({
        'statistics': stats.isNotEmpty ? {
          'total_students': stats.first[0],
          'counseling_sessions': stats.first[1],
          'pending_requests': stats.first[2],
          'completed_sessions': stats.first[3],
        } : null,
        'recent_students': recentStudents.map((row) => {
          'id': row[0],
          'first_name': row[1]?.toString() ?? '',
          'last_name': row[2]?.toString() ?? '',
          'status': row[3]?.toString() ?? '',
          'program': row[4]?.toString() ?? '',
          'last_appointment_date': row[5]?.toString(),
        }).toList(),
        'upcoming_appointments': upcomingAppointments.map((row) => {
          'id': row[0],
          'student_id': row[1],
          'appointment_date': row[2] is DateTime ? (row[2] as DateTime).toIso8601String() : row[2]?.toString(),
          'purpose': row[3]?.toString() ?? '',
          'course': row[4]?.toString() ?? '',
          'apt_status': row[5]?.toString() ?? 'scheduled',
          'notes': row[6]?.toString() ?? '',
          'student_name': row[7]?.toString() ?? 'Unknown Student',
          'student_number': row[8]?.toString(),
          'status': row[9]?.toString(),
          'program': row[10]?.toString(),
        }).toList(),
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch counselor dashboard: $e'}),
      );
    }
  }

  Future<Response> completeAppointment(Request request, String appointmentId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final counselorId = data['counselor_id'];

      if (counselorId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'counselor_id is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': counselorId},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      // Check if the appointment exists and belongs to this counselor
      final appointmentResult = await _database.query(
        'SELECT id, counselor_id, apt_status FROM appointments WHERE id = @id',
        {'id': int.parse(appointmentId)},
      );

      if (appointmentResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Appointment not found'}),
        );
      }

      final appointment = appointmentResult.first;
      if (appointment[1] != counselorId) {
        return Response.forbidden(
          jsonEncode({'error': 'You can only complete appointments assigned to you'}),
        );
      }

      if (appointment[2] == 'completed') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Appointment is already completed'}),
        );
      }

      // Update the appointment status to completed
      await _database.execute('''
        UPDATE appointments
        SET apt_status = 'completed'
        WHERE id = @id
      ''', {
        'id': int.parse(appointmentId),
      });

      return Response.ok(jsonEncode({
        'message': 'Appointment marked as completed successfully',
        'appointment_id': appointmentId,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to complete appointment: $e'}),
      );
    }
  }

  Future<Response> confirmAppointment(Request request, String appointmentId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final counselorId = data['counselor_id'];

      if (counselorId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'counselor_id is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': counselorId},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      // Check if the appointment exists and belongs to this counselor
      final appointmentResult = await _database.query(
        'SELECT id, counselor_id, apt_status FROM appointments WHERE id = @id',
        {'id': int.parse(appointmentId)},
      );

      if (appointmentResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Appointment not found'}),
        );
      }

      final appointment = appointmentResult.first;
      if (appointment[1] != counselorId) {
        return Response.forbidden(
          jsonEncode({'error': 'You can only confirm appointments assigned to you'}),
        );
      }

      if (appointment[2] == 'confirmed') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Appointment is already confirmed'}),
        );
      }

      // Update the appointment status to confirmed
      await _database.execute('''
        UPDATE appointments
        SET apt_status = 'confirmed'
        WHERE id = @id
      ''', {
        'id': int.parse(appointmentId),
      });

      return Response.ok(jsonEncode({
        'message': 'Appointment confirmed successfully',
        'appointment_id': appointmentId,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to confirm appointment: $e'}),
      );
    }
  }

  Future<Response> approveAppointment(Request request, String appointmentId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final counselorId = data['counselor_id'];

      if (counselorId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'counselor_id is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': counselorId},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      // Check if the appointment exists and belongs to this counselor
      final appointmentResult = await _database.query(
        'SELECT id, counselor_id, approval_status FROM appointments WHERE id = @id',
        {'id': int.parse(appointmentId)},
      );

      if (appointmentResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Appointment not found'}),
        );
      }

      final appointment = appointmentResult.first;
      if (appointment[1] != counselorId) {
        return Response.forbidden(
          jsonEncode({'error': 'You can only approve appointments assigned to you'}),
        );
      }

      if (appointment[2] == 'approved') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Appointment is already approved'}),
        );
      }

      // Update the appointment approval status
      await _database.execute('''
        UPDATE appointments
        SET approval_status = 'approved',
            approved_by = @counselor_id,
            approved_at = NOW(),
            rejection_reason = NULL,
            apt_status = 'scheduled'
        WHERE id = @id
      ''', {
        'counselor_id': counselorId,
        'id': int.parse(appointmentId),
      });

      return Response.ok(jsonEncode({
        'message': 'Appointment approved successfully',
        'appointment_id': appointmentId,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to approve appointment: $e'}),
      );
    }
  }

  Future<Response> rejectAppointment(Request request, String appointmentId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final counselorId = data['counselor_id'];
      final rejectionReason = data['rejection_reason'] ?? '';

      if (counselorId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'counselor_id is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': counselorId},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      // Check if the appointment exists and belongs to this counselor
      final appointmentResult = await _database.query(
        'SELECT id, counselor_id, approval_status FROM appointments WHERE id = @id',
        {'id': int.parse(appointmentId)},
      );

      if (appointmentResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Appointment not found'}),
        );
      }

      final appointment = appointmentResult.first;
      if (appointment[1] != counselorId) {
        return Response.forbidden(
          jsonEncode({'error': 'You can only reject appointments assigned to you'}),
        );
      }

      if (appointment[2] == 'rejected') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Appointment is already rejected'}),
        );
      }

      // Update the appointment approval status
      await _database.execute('''
        UPDATE appointments
        SET approval_status = 'rejected',
            approved_by = @counselor_id,
            approved_at = NOW(),
            rejection_reason = @rejection_reason,
            apt_status = 'cancelled'
        WHERE id = @id
      ''', {
        'counselor_id': counselorId,
        'rejection_reason': rejectionReason,
        'id': int.parse(appointmentId),
      });

      return Response.ok(jsonEncode({
        'message': 'Appointment rejected successfully',
        'appointment_id': appointmentId,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to reject appointment: $e'}),
      );
    }
  }

  Future<Response> cancelAppointment(Request request, String appointmentId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final counselorId = data['counselor_id'];
      final cancellationReason = data['cancellation_reason'] ?? '';

      if (counselorId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'counselor_id is required'}),
        );
      }

      if (cancellationReason.trim().isEmpty) {
        return Response.badRequest(
          body: jsonEncode({'error': 'cancellation_reason is required and cannot be empty'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': counselorId},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      // Check if the appointment exists and belongs to this counselor
      final appointmentResult = await _database.query(
        'SELECT id, counselor_id, status FROM appointments WHERE id = @id',
        {'id': int.parse(appointmentId)},
      );

      if (appointmentResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Appointment not found'}),
        );
      }

      final appointment = appointmentResult.first;
      if (appointment[1] != counselorId) {
        return Response.forbidden(
          jsonEncode({'error': 'You can only cancel appointments assigned to you'}),
        );
      }

      if (appointment[2] == 'cancelled') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Appointment is already cancelled'}),
        );
      }

      if (appointment[2] == 'completed') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Cannot cancel a completed appointment'}),
        );
      }

      // Update the appointment status to cancelled with reason
      await _database.execute('''
        UPDATE appointments
        SET apt_status = 'cancelled',
            cancellation_reason = @cancellation_reason,
            cancelled_by = @counselor_id,
            cancelled_at = NOW()
        WHERE id = @id
      ''', {
        'cancellation_reason': cancellationReason,
        'counselor_id': counselorId,
        'id': int.parse(appointmentId),
      });

      return Response.ok(jsonEncode({
        'message': 'Appointment cancelled successfully',
        'appointment_id': appointmentId,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to cancel appointment: $e'}),
      );
    }
  }

  Future<Response> deleteAppointment(Request request, String appointmentId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final counselorId = data['counselor_id'];

      if (counselorId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'counselor_id is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': counselorId},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      // Check if the appointment exists, belongs to this counselor, and is cancelled
      final appointmentResult = await _database.query(
        'SELECT id, counselor_id, status FROM appointments WHERE id = @id',
        {'id': int.parse(appointmentId)},
      );

      if (appointmentResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Appointment not found'}),
        );
      }

      final appointment = appointmentResult.first;
      if (appointment[1] != counselorId) {
        return Response.forbidden(
          jsonEncode({'error': 'You can only delete appointments assigned to you'}),
        );
      }

      if (appointment[2] != 'cancelled') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Can only delete cancelled appointments'}),
        );
      }

      // Delete the appointment
      await _database.execute('''
        DELETE FROM appointments
        WHERE id = @id
      ''', {
        'id': int.parse(appointmentId),
      });

      return Response.ok(jsonEncode({
        'message': 'Appointment deleted successfully',
        'appointment_id': appointmentId,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to delete appointment: $e'}),
      );
    }
  }

  Future<Response> getCounselorStudents(Request request) async {
    try {
      final userId = int.parse(request.url.queryParameters['user_id'] ?? '0');
      if (!await _checkUserRole(userId, 'counselor')) {
        return Response.forbidden(jsonEncode({'error': 'Counselor access required'}));
      }

      final result = await _database.query('''
        SELECT id, username, email, role, created_at,
               student_id, first_name, last_name, status, program
        FROM users
        WHERE role = 'student'
        ORDER BY last_name, first_name
      ''');

      final students = result.map((row) => {
        'id': row[0],
        'username': row[1],
        'email': row[2],
        'role': row[3],
        'created_at': row[4]?.toIso8601String(),
        'student_id': row[5],
        'first_name': row[6],
        'last_name': row[7],
        'status': row[8],
        'program': row[9],
      }).toList();

      return Response.ok(jsonEncode({
        'success': true,
        'count': students.length,
        'students': students
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch students: $e'}),
      );
    }
  }

  Future<Response> getStudentProfile(Request request, String studentId) async {
    try {
      final counselorId = int.parse(request.url.queryParameters['counselor_id'] ?? '0');
      if (!await _checkUserRole(counselorId, 'counselor')) {
        return Response.forbidden(jsonEncode({'error': 'Counselor access required'}));
      }

      // Get basic student information
      final studentResult = await _database.query('''
        SELECT id, username, email, role, created_at,
               student_id, first_name, last_name, status, program
        FROM users
        WHERE id = @student_id AND role = 'student'
      ''', {'student_id': int.parse(studentId)});

      if (studentResult.isEmpty) {
        return Response.notFound(jsonEncode({'error': 'Student not found'}));
      }

      final student = studentResult.first;
      final studentData = {
        'id': student[0],
        'username': student[1],
        'email': student[2],
        'role': student[3],
        'created_at': student[4] is DateTime ? (student[4] as DateTime).toIso8601String() : student[4]?.toString(),
        'student_id': student[5],
        'first_name': student[6],
        'last_name': student[7],
        'status': student[8],
        'program': student[9],
      };

      // Get SCRF record if exists
      Map<String, dynamic>? scrfData;
      try {
        final scrfResult = await _database.query('SELECT * FROM get_scrf_record(@user_id)', {
          'user_id': int.parse(studentId),
        });

        if (scrfResult.isNotEmpty) {
          final row = scrfResult.first;
          scrfData = {
            'id': row[0],
            'user_id': row[1],
            'student_id': row[2],
            'username': row[3],
            'student_number': row[4],
            'first_name': row[5],
            'last_name': row[6],
            'program_enrolled': row[7],
            'sex': row[8],
            'full_name': row[9],
            'address': row[10],
            'zipcode': row[11],
            'age': row[12],
            'civil_status': row[13],
            'date_of_birth': row[14]?.toIso8601String(),
            'place_of_birth': row[15],
            'lrn': row[16],
            'cellphone': row[17],
            'email_address': row[18],
            'father_name': row[19],
            'father_age': row[20],
            'father_occupation': row[21],
            'mother_name': row[22],
            'mother_age': row[23],
            'mother_occupation': row[24],
            'living_with_parents': row[25],
            'guardian_name': row[26],
            'guardian_relationship': row[27],
            'siblings': row[28],
            'educational_background': row[29],
            'awards_received': row[30],
            'transferee_college_name': row[31],
            'transferee_program': row[32],
            'physical_defect': row[33],
            'allergies_food': row[34],
            'allergies_medicine': row[35],
            'exam_taken': row[36],
            'exam_date': row[37]?.toIso8601String(),
            'raw_score': row[38],
            'percentile': row[39],
            'adjectival_rating': row[40],
            'created_at': row[41]?.toIso8601String(),
            'updated_at': row[42]?.toIso8601String(),
          };
        }
      } catch (e) {
        // SCRF record doesn't exist, continue without it
        scrfData = null;
      }

      // Get routine interview record if exists
      Map<String, dynamic>? routineInterviewData;
      try {
        final routineResult = await _database.query('''
          SELECT
            ri.id,
            ri.name,
            ri.date,
            ri.grade_course_year_section,
            ri.nickname,
            ri.ordinal_position,
            ri.student_description,
            ri.familial_description,
            ri.strengths,
            ri.weaknesses,
            ri.achievements,
            ri.best_work_person,
            ri.first_choice,
            ri.goals,
            ri.contribution,
            ri.talents_skills,
            ri.home_problems,
            ri.school_problems,
            ri.applicant_signature,
            ri.signature_date,
            ri.created_at,
            u.student_id,
            u.first_name,
            u.last_name,
            u.status,
            u.program
          FROM routine_interviews ri
          JOIN users u ON ri.student_id = u.id
          WHERE u.id = @user_id
          ORDER BY ri.created_at DESC
          LIMIT 1
        ''', {'user_id': int.parse(studentId)});

        if (routineResult.isNotEmpty) {
          final row = routineResult.first;
          routineInterviewData = {
            'id': row[0],
            'name': row[1],
            'date': row[2] is DateTime ? (row[2] as DateTime).toIso8601String() : row[2]?.toString(),
            'grade_course_year_section': row[3],
            'nickname': row[4],
            'ordinal_position': row[5],
            'student_description': row[6],
            'familial_description': row[7],
            'strengths': row[8],
            'weaknesses': row[9],
            'achievements': row[10],
            'best_work_person': row[11],
            'first_choice': row[12],
            'goals': row[13],
            'contribution': row[14],
            'talents_skills': row[15],
            'home_problems': row[16],
            'school_problems': row[17],
            'applicant_signature': row[18],
            'signature_date': row[19] is DateTime ? (row[19] as DateTime).toIso8601String() : row[19]?.toString(),
            'created_at': row[20] is DateTime ? (row[20] as DateTime).toIso8601String() : row[20]?.toString(),
            'student_id': row[21],
            'first_name': row[22],
            'last_name': row[23],
            'status': row[24],
            'program': row[25],
          };
        }
      } catch (e) {
        // Routine interview doesn't exist, continue without it
        routineInterviewData = null;
      }

      // Flatten the response to match frontend expectations
      final responseData = {
        ...studentData,
        'scrf_data': scrfData,
        'routine_interview': routineInterviewData,
      };

      return Response.ok(jsonEncode(responseData));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch student profile: $e'}),
      );
    }
  }

  Future<Response> getCounselorAppointments(Request request) async {
    try {
      final userId = request.url.queryParameters['user_id'];
      if (userId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'user_id parameter is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': int.parse(userId)},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      final result = await _database.query('''
        SELECT
          a.id,
          a.student_id,
          a.counselor_id,
          a.appointment_date,
          a.purpose,
          a.course,
          a.apt_status,
          a.notes,
          a.created_at,
          CONCAT(s.first_name, ' ', s.last_name) as student_name,
          s.student_id as student_number,
          s.first_name as student_first_name,
          s.last_name as student_last_name,
          s.status,
          s.program
        FROM appointments a
        JOIN users s ON a.student_id = s.id
        WHERE a.counselor_id = @counselor_id
        ORDER BY a.appointment_date DESC
      ''', {'counselor_id': int.parse(userId)});

      final appointments = result.map((row) => {
        'id': row[0],
        'student_id': row[1],
        'counselor_id': row[2],
        'appointment_date': row[3] is DateTime ? (row[3] as DateTime).toIso8601String() : row[3].toString(),
        'purpose': row[4]?.toString() ?? '',
        'course': row[5]?.toString() ?? '',
        'apt_status': row[6]?.toString() ?? 'scheduled',
        'notes': row[7]?.toString() ?? '',
        'created_at': row[8] is DateTime ? (row[8] as DateTime).toIso8601String() : row[8].toString(),
        'student_name': row[9]?.toString() ?? 'Unknown Student',
        'student_number': row[10]?.toString(),
        'student_first_name': row[11]?.toString(),
        'student_last_name': row[12]?.toString(),
        'status': row[13]?.toString(),
        'program': row[14]?.toString(),
        'date': row[3] is DateTime ? (row[3] as DateTime).toString().split(' ')[0] : row[3].toString().split(' ')[0],
        'time': row[3] is DateTime ? (row[3] as DateTime).toString().split(' ')[1].substring(0, 5) : '00:00',
        'type': row[4]?.toString() ?? 'General Counseling',
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

  Future<Response> getCounselorSessions(Request request) async {
    try {
      final userId = request.url.queryParameters['user_id'];
      if (userId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'user_id parameter is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': int.parse(userId)},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      // For now, we'll simulate sessions using completed appointments
      // In a real implementation, you'd have a separate sessions table
      final result = await _database.query('''
        SELECT
          a.id,
          a.student_id,
          a.counselor_id,
          a.appointment_date,
          a.purpose,
          a.course,
          a.apt_status,
          a.notes,
          a.created_at,
          CONCAT(s.first_name, ' ', s.last_name) as student_name,
          s.student_id as student_number,
          s.first_name as student_first_name,
          s.last_name as student_last_name,
          s.status,
          s.program
        FROM appointments a
        JOIN users s ON a.student_id = s.id
        WHERE a.counselor_id = @counselor_id AND a.status IN ('completed', 'in_progress')
        ORDER BY a.appointment_date DESC
      ''', {'counselor_id': int.parse(userId)});

      final sessions = result.map((row) => {
        'id': row[0],
        'student_id': row[1],
        'counselor_id': row[2],
        'date': row[3] is DateTime ? (row[3] as DateTime).toString().split(' ')[0] : row[3].toString().split(' ')[0],
        'start_time': row[3] is DateTime ? (row[3] as DateTime).toString().split(' ')[1].substring(0, 5) : '09:00',
        'end_time': row[3] is DateTime ? (row[3] as DateTime).add(const Duration(hours: 1)).toString().split(' ')[1].substring(0, 5) : '10:00',
        'type': row[4]?.toString() ?? 'General Counseling',
        'apt_status': row[6]?.toString() == 'completed' ? 'completed' : 'in_progress',
        'notes': row[7]?.toString() ?? 'Session completed successfully',
        'student_name': row[9]?.toString() ?? 'Unknown Student',
        'student_number': row[10]?.toString(),
        'student_first_name': row[11]?.toString(),
        'student_last_name': row[12]?.toString(),
        'status': row[13]?.toString(),
        'program': row[14]?.toString(),
      }).toList();

      return Response.ok(jsonEncode({
        'success': true,
        'count': sessions.length,
        'sessions': sessions
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch sessions: $e'}),
      );
    }
  }

  Future<Response> getCounselorGuidanceSchedules(Request request) async {
    try {
      final userId = request.url.queryParameters['user_id'];
      if (userId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'user_id parameter is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': int.parse(userId)},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      final result = await _database.query('''
        SELECT
          a.id,
          a.student_id,
          a.counselor_id,
          a.appointment_date,
          a.purpose,
          a.course,
          a.apt_status,
          a.approval_status,
          a.approved_by,
          a.approved_at,
          a.rejection_reason,
          a.notes,
          a.created_at,
          CONCAT(s.first_name, ' ', s.last_name) as student_name,
          s.student_id as student_number,
          s.first_name as student_first_name,
          s.last_name as student_last_name,
          s.status,
          s.program
        FROM appointments a
        JOIN users s ON a.student_id = s.id
        WHERE a.counselor_id = @counselor_id
        ORDER BY a.created_at DESC
      ''', {'counselor_id': int.parse(userId)});

      final schedules = result.map((row) => {
        'id': row[0],
        'student_id': row[1],
        'counselor_id': row[2],
        'appointment_date': row[3] is DateTime ? (row[3] as DateTime).toIso8601String() : row[3].toString(),
        'purpose': row[4]?.toString() ?? '',
        'course': row[5]?.toString() ?? '',
        'apt_status': row[6]?.toString() ?? 'scheduled',
        'approval_status': row[7]?.toString() ?? 'pending',
        'approved_by': row[8],
        'approved_at': row[9] is DateTime ? (row[9] as DateTime).toIso8601String() : row[9]?.toString(),
        'rejection_reason': row[10]?.toString() ?? '',
        'notes': row[11]?.toString() ?? '',
        'created_at': row[12] is DateTime ? (row[12] as DateTime).toIso8601String() : row[12].toString(),
        'student_name': row[13]?.toString() ?? 'Unknown Student',
        'student_number': row[14]?.toString(),
        'student_first_name': row[15]?.toString(),
        'student_last_name': row[16]?.toString(),
        'status': row[17]?.toString(),
        'program': row[18]?.toString(),
      }).toList();

      return Response.ok(jsonEncode({
        'success': true,
        'count': schedules.length,
        'schedules': schedules
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to fetch guidance schedules: $e'}),
      );
    }
  }

  Future<Response> approveGuidanceSchedule(Request request, String scheduleId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final counselorId = data['counselor_id'];

      if (counselorId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'counselor_id is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': counselorId},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      // Check if the schedule exists and belongs to this counselor
      final scheduleResult = await _database.query(
        'SELECT id, counselor_id, approval_status FROM appointments WHERE id = @id',
        {'id': int.parse(scheduleId)},
      );

      if (scheduleResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Guidance schedule not found'}),
        );
      }

      final schedule = scheduleResult.first;
      if (schedule[1] != counselorId) {
        return Response.forbidden(
          jsonEncode({'error': 'You can only approve schedules assigned to you'}),
        );
      }

      if (schedule[2] == 'approved') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Schedule is already approved'}),
        );
      }

      // Update the schedule with approval
      await _database.execute('''
        UPDATE appointments
        SET approval_status = 'approved',
            approved_by = @counselor_id,
            approved_at = NOW(),
            rejection_reason = NULL,
            status = 'scheduled'
        WHERE id = @id
      ''', {
        'counselor_id': counselorId,
        'id': int.parse(scheduleId),
      });

      return Response.ok(jsonEncode({
        'message': 'Guidance schedule approved successfully',
        'schedule_id': scheduleId,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to approve guidance schedule: $e'}),
      );
    }
  }

  Future<Response> rejectGuidanceSchedule(Request request, String scheduleId) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final counselorId = data['counselor_id'];
      final rejectionReason = data['rejection_reason'] ?? '';

      if (counselorId == null) {
        return Response.badRequest(
          body: jsonEncode({'error': 'counselor_id is required'}),
        );
      }

      // Verify user is a counselor
      final userResult = await _database.query(
        'SELECT role FROM users WHERE id = @id',
        {'id': counselorId},
      );

      if (userResult.isEmpty || userResult.first[0] != 'counselor') {
        return Response.forbidden(
          jsonEncode({'error': 'Access denied. Counselor role required.'}),
        );
      }

      // Check if the schedule exists and belongs to this counselor
      final scheduleResult = await _database.query(
        'SELECT id, counselor_id, approval_status FROM appointments WHERE id = @id',
        {'id': int.parse(scheduleId)},
      );

      if (scheduleResult.isEmpty) {
        return Response.notFound(
          jsonEncode({'error': 'Guidance schedule not found'}),
        );
      }

      final schedule = scheduleResult.first;
      if (schedule[1] != counselorId) {
        return Response.forbidden(
          jsonEncode({'error': 'You can only reject schedules assigned to you'}),
        );
      }

      if (schedule[2] == 'rejected') {
        return Response.badRequest(
          body: jsonEncode({'error': 'Schedule is already rejected'}),
        );
      }

      // Update the schedule with rejection
      await _database.execute('''
        UPDATE appointments
        SET approval_status = 'rejected',
            approved_by = @counselor_id,
            approved_at = NOW(),
            rejection_reason = @rejection_reason,
            status = 'cancelled'
        WHERE id = @id
      ''', {
        'counselor_id': counselorId,
        'rejection_reason': rejectionReason,
        'id': int.parse(scheduleId),
      });

      return Response.ok(jsonEncode({
        'message': 'Guidance schedule rejected successfully',
        'schedule_id': scheduleId,
      }));
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Failed to reject guidance schedule: $e'}),
      );
    }
  }
}
