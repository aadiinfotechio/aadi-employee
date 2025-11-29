import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';

// Task names for WorkManager
const String locationCheckTask = "locationCheckTask";
const String periodicLocationTask = "periodicLocationTask";

// Distance threshold for auto-checkout (3km = 3000 meters)
const double autoCheckoutDistance = 3000.0;

class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final ApiService _apiService = ApiService();
  bool _isInitialized = false;

  // Initialize the background location service
  Future<void> initialize({
    required String employeeId,
    required double? siteLatitude,
    required double? siteLongitude,
    required bool isCheckedIn,
  }) async {
    // Save data to SharedPreferences for background task access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('employeeId', employeeId);
    await prefs.setBool('isCheckedIn', isCheckedIn);

    if (siteLatitude != null) {
      await prefs.setDouble('siteLatitude', siteLatitude);
    }
    if (siteLongitude != null) {
      await prefs.setDouble('siteLongitude', siteLongitude);
    }

    if (!_isInitialized) {
      // Initialize WorkManager
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      _isInitialized = true;
    }

    // Start or stop tracking based on check-in status
    if (isCheckedIn && siteLatitude != null && siteLongitude != null) {
      await startTracking();
    } else {
      await stopTracking();
    }
  }

  // Start periodic background location tracking
  Future<void> startTracking() async {
    debugPrint('[BackgroundLocation] Starting periodic tracking...');

    // Cancel any existing tasks first
    await Workmanager().cancelByTag('location_tracking');

    // Register periodic task - runs every 15 minutes (minimum on Android)
    await Workmanager().registerPeriodicTask(
      periodicLocationTask,
      periodicLocationTask,
      frequency: const Duration(minutes: 15),
      tag: 'location_tracking',
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );

    // Also run an immediate check
    await Workmanager().registerOneOffTask(
      '${locationCheckTask}_immediate',
      locationCheckTask,
      tag: 'location_tracking',
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  // Stop background location tracking
  Future<void> stopTracking() async {
    debugPrint('[BackgroundLocation] Stopping tracking...');
    await Workmanager().cancelByTag('location_tracking');
  }

  // Update check-in state
  Future<void> updateCheckInState({
    required bool isCheckedIn,
    double? siteLatitude,
    double? siteLongitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCheckedIn', isCheckedIn);

    if (siteLatitude != null) {
      await prefs.setDouble('siteLatitude', siteLatitude);
    }
    if (siteLongitude != null) {
      await prefs.setDouble('siteLongitude', siteLongitude);
    }

    if (isCheckedIn && siteLatitude != null && siteLongitude != null) {
      await startTracking();
    } else {
      await stopTracking();
    }
  }

  // Perform location check (can be called directly or from background)
  Future<void> checkLocationAndAutoCheckout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCheckedIn = prefs.getBool('isCheckedIn') ?? false;
      final employeeId = prefs.getString('employeeId');
      final siteLatitude = prefs.getDouble('siteLatitude');
      final siteLongitude = prefs.getDouble('siteLongitude');

      if (!isCheckedIn || employeeId == null || siteLatitude == null || siteLongitude == null) {
        debugPrint('[BackgroundLocation] Not checked in or missing data, skipping check');
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      // Calculate distance
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        siteLatitude,
        siteLongitude,
      );

      debugPrint('[BackgroundLocation] Distance from site: ${distance.toStringAsFixed(0)}m');

      // Check if outside 3km radius
      if (distance > autoCheckoutDistance) {
        debugPrint('[BackgroundLocation] Outside 3km - triggering auto-checkout');

        final result = await _apiService.autoCheckout(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (result['success'] == true && result['skipped'] != true) {
          // Auto-checkout successful, update local state
          await prefs.setBool('isCheckedIn', false);
          await stopTracking();
          debugPrint('[BackgroundLocation] Auto-checkout completed');
        } else if (result['skipped'] == true) {
          debugPrint('[BackgroundLocation] Auto-checkout skipped - away for equipment');
        }
      }
    } catch (e) {
      debugPrint('[BackgroundLocation] Error during location check: $e');
    }
  }
}

// WorkManager callback dispatcher - must be top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('[WorkManager] Executing task: $task');

    try {
      final prefs = await SharedPreferences.getInstance();
      final isCheckedIn = prefs.getBool('isCheckedIn') ?? false;
      final employeeId = prefs.getString('employeeId');
      final siteLatitude = prefs.getDouble('siteLatitude');
      final siteLongitude = prefs.getDouble('siteLongitude');

      if (!isCheckedIn || employeeId == null || siteLatitude == null || siteLongitude == null) {
        debugPrint('[WorkManager] Not checked in or missing data');
        return true;
      }

      // Check location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('[WorkManager] Location permission denied');
        return true;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      // Calculate distance using Haversine formula
      final distance = _calculateDistance(
        position.latitude,
        position.longitude,
        siteLatitude,
        siteLongitude,
      );

      debugPrint('[WorkManager] Distance from site: ${distance.toStringAsFixed(0)}m');

      // Check if outside 3km radius
      if (distance > autoCheckoutDistance) {
        debugPrint('[WorkManager] Outside 3km - triggering auto-checkout');

        final apiService = ApiService();
        final result = await apiService.autoCheckout(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (result['success'] == true && result['skipped'] != true) {
          await prefs.setBool('isCheckedIn', false);
          debugPrint('[WorkManager] Auto-checkout completed');
        }
      }

      return true;
    } catch (e) {
      debugPrint('[WorkManager] Error: $e');
      return true; // Return true to not retry
    }
  });
}

// Haversine formula for distance calculation
double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371000; // meters

  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);

  final a = sin(dLat / 2) * sin(dLat / 2) +
            cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadius * c;
}

double _toRadians(double degrees) => degrees * pi / 180;
