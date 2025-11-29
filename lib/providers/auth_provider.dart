import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/employee.dart';
import '../services/api_service.dart';
import '../services/background_location_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final BackgroundLocationService _backgroundLocationService = BackgroundLocationService();

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

        // Initialize background location service with employee data
        await _initializeBackgroundLocation();
      } else {
        _isAuthenticated = false;
      }
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;
    }
    notifyListeners();
  }

  // Initialize background location tracking
  Future<void> _initializeBackgroundLocation() async {
    if (_currentUser == null) return;

    try {
      // Get current check-in status
      final status = await _apiService.getEmployeeStatus(_currentUser!.id);
      final isCheckedIn = status['isCheckedIn'] ?? false;

      // Save employee data to SharedPreferences for headless task
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employeeId', _currentUser!.id);
      await prefs.setBool('isCheckedIn', isCheckedIn);

      if (_currentUser!.siteLatitude != null) {
        await prefs.setDouble('siteLatitude', _currentUser!.siteLatitude!);
      }
      if (_currentUser!.siteLongitude != null) {
        await prefs.setDouble('siteLongitude', _currentUser!.siteLongitude!);
      }

      // Initialize background location service
      await _backgroundLocationService.initialize(
        employeeId: _currentUser!.id,
        siteLatitude: _currentUser!.siteLatitude,
        siteLongitude: _currentUser!.siteLongitude,
        isCheckedIn: isCheckedIn,
      );
    } catch (e) {
      debugPrint('Error initializing background location: $e');
    }
  }

  // Update check-in state for background service
  Future<void> updateCheckInState(bool isCheckedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCheckedIn', isCheckedIn);

    await _backgroundLocationService.updateCheckInState(
      isCheckedIn: isCheckedIn,
      siteLatitude: _currentUser?.siteLatitude,
      siteLongitude: _currentUser?.siteLongitude,
    );
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
    // Stop background location tracking
    await _backgroundLocationService.stopTracking();

    // Clear stored data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('employeeId');
    await prefs.remove('isCheckedIn');
    await prefs.remove('siteLatitude');
    await prefs.remove('siteLongitude');

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
