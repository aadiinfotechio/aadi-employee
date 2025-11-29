import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final ApiService _apiService = ApiService();

  // Distance threshold for auto-checkout (3km = 3000 meters)
  static const double autoCheckoutDistance = 3000.0;

  // Site coordinates (loaded from employee profile)
  double? _siteLatitude;
  double? _siteLongitude;
  String? _employeeId;
  bool _isCheckedIn = false;
  bool _isInitialized = false;

  // Initialize the background location service
  Future<void> initialize({
    required String employeeId,
    required double? siteLatitude,
    required double? siteLongitude,
    required bool isCheckedIn,
  }) async {
    _employeeId = employeeId;
    _siteLatitude = siteLatitude;
    _siteLongitude = siteLongitude;
    _isCheckedIn = isCheckedIn;

    if (_isInitialized) {
      // Just update state if already initialized
      await _updateTrackingState();
      return;
    }

    // Configure the plugin
    await bg.BackgroundGeolocation.ready(bg.Config(
      // Debug/Logging
      debug: kDebugMode,
      logLevel: kDebugMode ? bg.Config.LOG_LEVEL_VERBOSE : bg.Config.LOG_LEVEL_OFF,

      // Geolocation config
      desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
      distanceFilter: 100.0, // Update every 100 meters
      stopOnTerminate: false, // Continue tracking after app terminated
      startOnBoot: true, // Auto-start on device boot
      enableHeadless: true, // Enable headless mode for background execution

      // Activity Recognition
      stopTimeout: 5, // Minutes to wait before turning off GPS after vehicle stops

      // Application config
      foregroundService: true,
      notification: bg.Notification(
        title: 'AADI Employee App',
        text: 'Location tracking active',
        priority: bg.Config.NOTIFICATION_PRIORITY_LOW,
        sticky: true,
      ),

      // iOS specific
      locationAuthorizationRequest: 'Always',
      backgroundPermissionRationale: bg.PermissionRationale(
        title: 'Allow location access in background',
        message: 'This app needs to track your location in the background to automatically check you out when you leave the site.',
        positiveAction: 'Allow',
        negativeAction: 'Cancel',
      ),
    ));

    // Listen for location updates
    bg.BackgroundGeolocation.onLocation(_onLocation);

    // Listen for motion changes
    bg.BackgroundGeolocation.onMotionChange(_onMotionChange);

    // Listen for provider changes (GPS on/off)
    bg.BackgroundGeolocation.onProviderChange(_onProviderChange);

    _isInitialized = true;

    // Start or stop based on check-in state
    await _updateTrackingState();
  }

  // Handle location updates
  void _onLocation(bg.Location location) async {
    debugPrint('[BackgroundLocation] Location: ${location.coords.latitude}, ${location.coords.longitude}');

    if (!_isCheckedIn || _siteLatitude == null || _siteLongitude == null) {
      return;
    }

    // Calculate distance from site
    final distance = _calculateDistance(
      location.coords.latitude,
      location.coords.longitude,
      _siteLatitude!,
      _siteLongitude!,
    );

    debugPrint('[BackgroundLocation] Distance from site: ${distance.toStringAsFixed(0)}m');

    // Check if employee has moved more than 3km from site
    if (distance > autoCheckoutDistance) {
      debugPrint('[BackgroundLocation] Employee is ${(distance/1000).toStringAsFixed(2)}km from site - triggering auto-checkout');
      await _triggerAutoCheckout(location.coords.latitude, location.coords.longitude);
    }
  }

  // Handle motion state changes
  void _onMotionChange(bg.Location location) {
    debugPrint('[BackgroundLocation] Motion change: isMoving=${location.isMoving}');
  }

  // Handle GPS provider changes
  void _onProviderChange(bg.ProviderChangeEvent event) {
    debugPrint('[BackgroundLocation] Provider change: enabled=${event.enabled}, status=${event.status}');
  }

  // Trigger auto-checkout via API
  Future<void> _triggerAutoCheckout(double latitude, double longitude) async {
    if (_employeeId == null) return;

    try {
      final result = await _apiService.autoCheckout(
        employeeId: _employeeId!,
        latitude: latitude,
        longitude: longitude,
      );

      if (result['success'] == true) {
        if (result['skipped'] == true) {
          // Away for equipment flag is on - don't stop tracking
          debugPrint('[BackgroundLocation] Auto-checkout skipped - away for equipment');
        } else {
          // Successfully checked out - stop tracking
          debugPrint('[BackgroundLocation] Auto-checkout successful');
          _isCheckedIn = false;
          await stopTracking();

          // Save state
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isCheckedIn', false);
        }
      }
    } catch (e) {
      debugPrint('[BackgroundLocation] Auto-checkout error: $e');
    }
  }

  // Calculate distance between two coordinates using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = _sin(dLat / 2) * _sin(dLat / 2) +
              _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
              _sin(dLon / 2) * _sin(dLon / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
  double _sin(double x) => _sinApprox(x);
  double _cos(double x) => _sinApprox(x + 1.5707963267948966);
  double _sqrt(double x) => x > 0 ? _sqrtApprox(x) : 0;
  double _atan2(double y, double x) => _atan2Approx(y, x);

  // Math approximations (dart:math not available in isolate)
  double _sinApprox(double x) {
    x = x % (2 * 3.141592653589793);
    if (x < 0) x += 2 * 3.141592653589793;
    if (x > 3.141592653589793) x -= 2 * 3.141592653589793;
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _sqrtApprox(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2Approx(double y, double x) {
    if (x > 0) return _atanApprox(y / x);
    if (x < 0 && y >= 0) return _atanApprox(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atanApprox(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 1.5707963267948966;
    if (x == 0 && y < 0) return -1.5707963267948966;
    return 0;
  }

  double _atanApprox(double x) {
    if (x > 1) return 1.5707963267948966 - _atanApprox(1 / x);
    if (x < -1) return -1.5707963267948966 - _atanApprox(1 / x);
    double result = x;
    double term = x;
    for (int i = 1; i <= 15; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  // Update tracking state based on check-in status
  Future<void> _updateTrackingState() async {
    if (_isCheckedIn && _siteLatitude != null && _siteLongitude != null) {
      await startTracking();
    } else {
      await stopTracking();
    }
  }

  // Start background location tracking
  Future<void> startTracking() async {
    if (!_isInitialized) {
      debugPrint('[BackgroundLocation] Not initialized - cannot start tracking');
      return;
    }

    debugPrint('[BackgroundLocation] Starting background tracking...');
    await bg.BackgroundGeolocation.start();
  }

  // Stop background location tracking
  Future<void> stopTracking() async {
    debugPrint('[BackgroundLocation] Stopping background tracking...');
    await bg.BackgroundGeolocation.stop();
  }

  // Update check-in state (called when user checks in/out manually)
  Future<void> updateCheckInState({
    required bool isCheckedIn,
    double? siteLatitude,
    double? siteLongitude,
  }) async {
    _isCheckedIn = isCheckedIn;
    if (siteLatitude != null) _siteLatitude = siteLatitude;
    if (siteLongitude != null) _siteLongitude = siteLongitude;

    await _updateTrackingState();
  }

  // Get current location (one-time)
  Future<bg.Location?> getCurrentLocation() async {
    try {
      return await bg.BackgroundGeolocation.getCurrentPosition(
        timeout: 30,
        maximumAge: 5000,
        desiredAccuracy: 10,
        samples: 3,
      );
    } catch (e) {
      debugPrint('[BackgroundLocation] Error getting current location: $e');
      return null;
    }
  }

  // Check if tracking is currently active
  Future<bool> isTracking() async {
    final state = await bg.BackgroundGeolocation.state;
    return state.enabled;
  }

  // Dispose/cleanup
  Future<void> dispose() async {
    await stopTracking();
    bg.BackgroundGeolocation.removeListeners();
  }
}

// Headless task for background execution when app is terminated
@pragma('vm:entry-point')
void backgroundGeolocationHeadlessTask(bg.HeadlessEvent headlessEvent) async {
  debugPrint('[BackgroundGeolocation HeadlessTask]: ${headlessEvent.name}');

  switch (headlessEvent.name) {
    case bg.Event.LOCATION:
      bg.Location location = headlessEvent.event;
      debugPrint('[HeadlessTask] Location: ${location.coords.latitude}, ${location.coords.longitude}');

      // Load saved site coordinates and check distance
      final prefs = await SharedPreferences.getInstance();
      final siteLatitude = prefs.getDouble('siteLatitude');
      final siteLongitude = prefs.getDouble('siteLongitude');
      final employeeId = prefs.getString('employeeId');
      final isCheckedIn = prefs.getBool('isCheckedIn') ?? false;

      if (isCheckedIn && siteLatitude != null && siteLongitude != null && employeeId != null) {
        final service = BackgroundLocationService();
        final distance = service._calculateDistance(
          location.coords.latitude,
          location.coords.longitude,
          siteLatitude,
          siteLongitude,
        );

        if (distance > BackgroundLocationService.autoCheckoutDistance) {
          debugPrint('[HeadlessTask] Distance ${distance.toStringAsFixed(0)}m > 3km - triggering auto-checkout');
          await service._triggerAutoCheckout(location.coords.latitude, location.coords.longitude);
        }
      }
      break;
  }
}
