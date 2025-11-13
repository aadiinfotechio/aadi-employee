import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  Employee? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  Employee? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Check if user is already logged in
  Future<void> checkAuth() async {
    try {
      final token = await _apiService.getToken();
      final userId = await _apiService.getUserId();

      if (token != null && userId != null) {
        _currentUser = await _apiService.getEmployeeProfile(userId);
        _isAuthenticated = true;
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;
    }
    notifyListeners();
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.login(email, password);

      if (response['success']) {
        // Create a simple Employee object from the login response
        _currentUser = Employee(
          id: response['data']['employee'],
          name: response['data']['name'] ?? 'Admin',
          email: response['data']['email'],
          phone: '', // Admin users don't have phone numbers
          position: response['data']['role'] ?? 'admin',
        );
        _isAuthenticated = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _apiService.logout();
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
