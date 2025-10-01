import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../connection.dart';

class ScrfRoutes {
  final DatabaseConnection _database;

  ScrfRoutes(this._database);

  Router get router {
    final router = Router();

    // Insert SCRF record
    router.post('/api/scrf', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);

        // Validate required fields
        if (data['user_id'] == null || data['student_id'] == null) {
          return Response.badRequest(
            body: jsonEncode({'error': 'user_id and student_id are required'}),
          );
        }

        final result = await _database.execute('''
          CALL insert_scrf_record(
            @user_id, @student_id, @program_enrolled, @sex, @full_name, @address, @zipcode, @age,
            @civil_status, @date_of_birth, @place_of_birth, @lrn, @cellphone, @email_address,
            @father_name, @father_age, @father_occupation, @mother_name, @mother_age, @mother_occupation,
            @living_with_parents, @guardian_name, @guardian_relationship, @siblings,
            @educational_background, @awards_received, @transferee_college_name, @transferee_program,
            @physical_defect, @allergies_food, @allergies_medicine, @exam_taken, @exam_date,
            @raw_score, @percentile, @adjectival_rating, @created_by
          )
        ''', {
          'user_id': data['user_id'],
          'student_id': data['student_id'],
          'program_enrolled': data['program_enrolled'],
          'sex': data['sex'],
          'full_name': data['full_name'],
          'address': data['address'],
          'zipcode': data['zipcode'],
          'age': data['age'],
          'civil_status': data['civil_status'],
          'date_of_birth': data['date_of_birth'],
          'place_of_birth': data['place_of_birth'],
          'lrn': data['lrn'],
          'cellphone': data['cellphone'],
          'email_address': data['email_address'],
          'father_name': data['father_name'],
          'father_age': data['father_age'],
          'father_occupation': data['father_occupation'],
          'mother_name': data['mother_name'],
          'mother_age': data['mother_age'],
          'mother_occupation': data['mother_occupation'],
          'living_with_parents': data['living_with_parents'],
          'guardian_name': data['guardian_name'],
          'guardian_relationship': data['guardian_relationship'],
          'siblings': jsonEncode(data['siblings']),
          'educational_background': jsonEncode(data['educational_background']),
          'awards_received': data['awards_received'],
          'transferee_college_name': data['transferee_college_name'],
          'transferee_program': data['transferee_program'],
          'physical_defect': data['physical_defect'],
          'allergies_food': data['allergies_food'],
          'allergies_medicine': data['allergies_medicine'],
          'exam_taken': data['exam_taken'],
          'exam_date': data['exam_date'],
          'raw_score': data['raw_score'],
          'percentile': data['percentile'],
          'adjectival_rating': data['adjectival_rating'],
          'created_by': data['user_id'],
        });

        return Response.ok(jsonEncode({'message': 'SCRF record inserted successfully'}));
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to insert SCRF record: $e'}),
        );
      }
    });

    // Get SCRF record by user_id
    router.get('/api/scrf/<user_id>', (Request request, String userId) async {
      try {
        final result = await _database.query('SELECT * FROM get_scrf_record(@user_id)', {
          'user_id': int.parse(userId),
        });

        if (result.isEmpty) {
          return Response.notFound(jsonEncode({'error': 'SCRF record not found'}));
        }

        final row = result.first;
        // Map the row to a JSON object (adjust indices as per your function)
        final scrfRecord = {
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

        return Response.ok(jsonEncode(scrfRecord));
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to fetch SCRF record: $e'}),
        );
      }
    });

    // Update SCRF record
    router.put('/api/scrf/<user_id>', (Request request, String userId) async {
      try {
        final body = await request.readAsString();
        final data = jsonDecode(body);

        final result = await _database.execute('''
          CALL update_scrf_record(
            @user_id, @program_enrolled, @sex, @full_name, @address, @zipcode, @age,
            @civil_status, @date_of_birth, @place_of_birth, @lrn, @cellphone, @email_address,
            @father_name, @father_age, @father_occupation, @mother_name, @mother_age, @mother_occupation,
            @living_with_parents, @guardian_name, @guardian_relationship, @siblings,
            @educational_background, @awards_received, @transferee_college_name, @transferee_program,
            @physical_defect, @allergies_food, @allergies_medicine, @exam_taken, @exam_date,
            @raw_score, @percentile, @adjectival_rating, @updated_by
          )
        ''', {
          'user_id': int.parse(userId),
          'program_enrolled': data['program_enrolled'],
          'sex': data['sex'],
          'full_name': data['full_name'],
          'address': data['address'],
          'zipcode': data['zipcode'],
          'age': data['age'],
          'civil_status': data['civil_status'],
          'date_of_birth': data['date_of_birth'],
          'place_of_birth': data['place_of_birth'],
          'lrn': data['lrn'],
          'cellphone': data['cellphone'],
          'email_address': data['email_address'],
          'father_name': data['father_name'],
          'father_age': data['father_age'],
          'father_occupation': data['father_occupation'],
          'mother_name': data['mother_name'],
          'mother_age': data['mother_age'],
          'mother_occupation': data['mother_occupation'],
          'living_with_parents': data['living_with_parents'],
          'guardian_name': data['guardian_name'],
          'guardian_relationship': data['guardian_relationship'],
          'siblings': jsonEncode(data['siblings']),
          'educational_background': jsonEncode(data['educational_background']),
          'awards_received': data['awards_received'],
          'transferee_college_name': data['transferee_college_name'],
          'transferee_program': data['transferee_program'],
          'physical_defect': data['physical_defect'],
          'allergies_food': data['allergies_food'],
          'allergies_medicine': data['allergies_medicine'],
          'exam_taken': data['exam_taken'],
          'exam_date': data['exam_date'],
          'raw_score': data['raw_score'],
          'percentile': data['percentile'],
          'adjectival_rating': data['adjectival_rating'],
          'updated_by': data['user_id'],
        });

        return Response.ok(jsonEncode({'message': 'SCRF record updated successfully'}));
      } catch (e) {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Failed to update SCRF record: $e'}),
        );
      }
    });

    return router;
  }
}
