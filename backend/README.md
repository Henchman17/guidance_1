# Guidance System Database API

This is a RESTful API server for your guidance system database built with Dart and Shelf.

## Features

- **Database Connection**: PostgreSQL with connection pooling
- **RESTful API**: Standard HTTP endpoints for CRUD operations
- **CORS Support**: Ready for Flutter integration
- **Error Handling**: Proper HTTP status codes and error responses
- **Guidance System Specific**: Endpoints for students, appointments, and counselors

## API Endpoints

### Health Check
- `GET /health` - Database connection health check

### Users
- `GET /api/users` - Get all users
- `GET /api/users/:id` - Get specific user
- `POST /api/users` - Create new user
- `PUT /api/users/:id` - Update user
- `DELETE /api/users/:id` - Delete user

### Students
- `GET /api/students` - Get all students
- `GET /api/students/:id` - Get specific student

### Appointments
- `GET /api/appointments` - Get all appointments
- `POST /api/appointments` - Create new appointment

## Setup Instructions

1. **Install Dependencies**:
   ```bash
   dart pub get
   ```

2. **Database Setup**:
   - Ensure PostgreSQL is running on localhost:5432
   - Database name: `guidance`
   - Update credentials in `backend/connection.dart` if needed

3. **Create Database Tables**:
   ```sql
   -- Users table
   CREATE TABLE users (
     id SERIAL PRIMARY KEY,
     username VARCHAR(50) UNIQUE NOT NULL,
     email VARCHAR(100) UNIQUE NOT NULL,
     password VARCHAR(255) NOT NULL,
     role VARCHAR(20) DEFAULT 'student',
     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );

   -- Students table
   CREATE TABLE students (
     id SERIAL PRIMARY KEY,
     user_id INTEGER REFERENCES users(id),
     student_id VARCHAR(20) UNIQUE NOT NULL,
     first_name VARCHAR(50) NOT NULL,
     last_name VARCHAR(50) NOT NULL,
     grade_level INTEGER,
     section VARCHAR(10),
     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );

   -- Appointments table
   CREATE TABLE appointments (
     id SERIAL PRIMARY KEY,
     student_id INTEGER REFERENCES students(id),
     counselor_id INTEGER REFERENCES users(id),
     appointment_date TIMESTAMP NOT NULL,
     purpose TEXT,
     status VARCHAR(20) DEFAULT 'scheduled',
     notes TEXT,
     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```

4. **Run the Server**:
   ```bash
   dart run backend/server.dart
   ```

5. **Test the API**:
   - Server will start on `http://localhost:8080`
   - Health check: `GET http://localhost:8080/health`

## Flutter Integration

The API is configured with CORS enabled for Flutter integration. Use the following base URL in your Flutter app:

```dart
const String apiBaseUrl = 'http://localhost:8080';
```

## Development

To add new endpoints:
1. Add the route in `backend/server.dart`
2. Create the handler method in `backend/routes/api_routes.dart`
3. Update the database queries as needed

## Production Deployment

For production:
1. Update database credentials in `backend/connection.dart`
2. Set environment variables for port and database connection
3. Use a reverse proxy like nginx for SSL termination
4. Consider using connection pooling for better performance
