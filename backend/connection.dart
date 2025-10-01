import 'dart:io';
import 'package:postgres/postgres.dart';

class DatabaseConnection {
  static final DatabaseConnection _instance = DatabaseConnection._internal();
  late final PostgreSQLConnection _connection;
  bool _isInitialized = false;

  factory DatabaseConnection() {
    return _instance;
  }

  DatabaseConnection._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Use environment variable or default to localhost
    final dbHost = Platform.environment['DB_HOST'] ?? 'localhost';

    _connection = PostgreSQLConnection(
      dbHost,
      5432,
      'guidance',
      username: 'admin',
      password: '1254',
    );

    try {
      await _connection.open();
      _isInitialized = true;
      print('Database connection initialized successfully.');
    } catch (e) {
      print('Error initializing database connection: $e');
      rethrow;
    }
  }

  Future<PostgreSQLResult> query(String sql, [Map<String, dynamic>? values]) async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _connection.query(sql, substitutionValues: values);
  }

  Future<int> execute(String sql, [Map<String, dynamic>? values]) async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _connection.execute(sql, substitutionValues: values);
  }

  // Transaction wrapper for atomic operations - KEY FIX FOR LAG
  Future<T> transaction<T>(Future<T> Function(PostgreSQLExecutionContext) operation) async {
    if (!_isInitialized) {
      await initialize();
    }
    return await _connection.transaction(operation);
  }

  Future<void> close() async {
    if (_isInitialized) {
      await _connection.close();
      _isInitialized = false;
    }
  }

  bool get isConnected => _isInitialized && !_connection.isClosed;
}