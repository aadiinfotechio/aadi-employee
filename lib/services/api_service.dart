import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/employee.dart';
import '../models/task.dart';
import '../models/attendance.dart';

class ApiService {
  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptor for auth token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        print('API Error: ${error.response?.statusCode} - ${error.message}');
        return handler.next(error);
      },
    ));
  }

  // Auth Methods
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post(ApiConfig.login, data: {
        'email': email,
        'password': password,
      });

      if (response.data['success']) {
        final token = response.data['auth_token'];
        final userId = response.data['data']['employee'];
        await _storage.write(key: 'auth_token', value: token);
        await _storage.write(key: 'user_id', value: userId);
      }

      return response.data;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_id');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> getUserId() async {
    return await _storage.read(key: 'user_id');
  }

  Future<Map<String, dynamic>> changePassword({
    required String employeeId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(ApiConfig.changePassword, data: {
        'employeeId': employeeId,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      return response.data;
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  // Employee Methods
  Future<Employee> getEmployeeProfile(String id) async {
    try {
      final response = await _dio.get('${ApiConfig.employeeProfile}/$id');
      return Employee.fromJson(response.data['result']);
    } catch (e) {
      throw Exception('Failed to load employee profile: $e');
    }
  }

  // Task Methods
  Future<List<Task>> getTasks({String? employeeId}) async {
    try {
      final response = await _dio.get(ApiConfig.tasksList, queryParameters: {
        if (employeeId != null) 'assignedTo': employeeId,
      });

      final List<dynamic> tasksJson = response.data['result'] ?? [];
      return tasksJson.map((json) => Task.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load tasks: $e');
    }
  }

  Future<Task> updateTaskStatus(String taskId, String status) async {
    try {
      final response = await _dio.patch('${ApiConfig.taskUpdate}/$taskId', data: {
        'status': status,
      });

      return Task.fromJson(response.data['result']);
    } catch (e) {
      throw Exception('Failed to update task: $e');
    }
  }

  // Attendance Methods
  Future<Attendance> checkin({
    required String employeeId,
    required String logType,
    double? latitude,
    double? longitude,
    String? location,
  }) async {
    try {
      final response = await _dio.post(ApiConfig.checkin, data: {
        'employee': employeeId,
        'time': DateTime.now().toIso8601String(),
        'log_type': logType,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (location != null) 'location': location,
      });

      return Attendance.fromJson(response.data['result']);
    } catch (e) {
      throw Exception('Failed to check in/out: $e');
    }
  }

  Future<List<Attendance>> getAttendanceHistory(String employeeId) async {
    try {
      final response = await _dio.get('${ApiConfig.checkinHistory}/$employeeId');

      final List<dynamic> attendanceJson = response.data['result'] ?? [];
      return attendanceJson.map((json) => Attendance.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load attendance history: $e');
    }
  }

  Future<Attendance?> getLastCheckin(String employeeId) async {
    try {
      final response = await _dio.get('${ApiConfig.lastCheckin}/$employeeId');

      if (response.data['result'] != null) {
        return Attendance.fromJson(response.data['result']);
      }
      return null;
    } catch (e) {
      print('Failed to load last check-in: $e');
      return null;
    }
  }

  // Dashboard Methods
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final response = await _dio.get(ApiConfig.dashboardStats);
      return response.data['result'] ?? {};
    } catch (e) {
      throw Exception('Failed to load dashboard stats: $e');
    }
  }

  Future<List<Attendance>> getTodayActivities({String? employeeId}) async {
    try {
      final response = await _dio.get(ApiConfig.todayActivities, queryParameters: {
        if (employeeId != null) 'employeeId': employeeId,
      });

      final List<dynamic> activitiesJson = response.data['result'] ?? [];
      return activitiesJson.map((json) => Attendance.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load today\'s activities: $e');
    }
  }

  // Leave Methods
  Future<List> getLeaves({String? employeeId}) async {
    try {
      final response = await _dio.get(ApiConfig.leaveList, queryParameters: {
        if (employeeId != null) 'employeeId': employeeId,
      });

      final List<dynamic> leavesJson = response.data['result'] ?? [];
      return leavesJson;
    } catch (e) {
      throw Exception('Failed to load leaves: $e');
    }
  }

  Future<Map<String, dynamic>> applyLeave({
    required String employeeId,
    required String leaveType,
    required DateTime fromDate,
    required DateTime toDate,
    required bool halfDay,
    required String reason,
  }) async {
    try {
      final response = await _dio.post(ApiConfig.leaveApply, data: {
        'employeeId': employeeId,
        'leaveType': leaveType,
        'fromDate': fromDate.toIso8601String(),
        'toDate': toDate.toIso8601String(),
        'halfDay': halfDay,
        'reason': reason,
      });

      return response.data;
    } catch (e) {
      throw Exception('Failed to apply leave: $e');
    }
  }

  Future<Map<String, dynamic>> getAttendanceCalendar({
    required String employeeId,
    required int month,
    required int year,
  }) async {
    try {
      final response = await _dio.get(ApiConfig.attendanceCalendar, queryParameters: {
        'employeeId': employeeId,
        'month': month,
        'year': year,
      });

      return response.data;
    } catch (e) {
      throw Exception('Failed to load calendar data: $e');
    }
  }
}
