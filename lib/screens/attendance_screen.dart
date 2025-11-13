import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/attendance.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  Attendance? _lastCheckin;
  List<Attendance> _attendanceHistory = [];
  bool _isLoading = true;
  bool _isCheckingIn = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> _loadAttendanceData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      if (employeeId != null) {
        final lastCheckin = await _apiService.getLastCheckin(employeeId);
        final history = await _apiService.getAttendanceHistory(employeeId);

        setState(() {
          _lastCheckin = lastCheckin;
          _attendanceHistory = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendance data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckInOut(String logType) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting location... Please try again'),
          backgroundColor: Colors.orange,
        ),
      );
      await _getCurrentLocation();
      return;
    }

    setState(() => _isCheckingIn = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      if (employeeId == null) {
        throw Exception('Employee ID not found');
      }

      await _apiService.checkin(
        employeeId: employeeId,
        logType: logType,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        location: await _locationService.getAddressFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$logType successful!'),
            backgroundColor: Colors.green,
          ),
        );

        _loadAttendanceData(); // Reload data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to $logType: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isCheckingIn = false);
    }
  }

  bool get _isCheckedIn {
    if (_lastCheckin == null) return false;
    return _lastCheckin!.isCheckIn;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _getCurrentLocation();
        await _loadAttendanceData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Check-in/out Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(
                      _isCheckedIn ? Icons.check_circle : Icons.access_time,
                      size: 64,
                      color: _isCheckedIn ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isCheckedIn ? 'Checked In' : 'Not Checked In',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isCheckedIn ? Colors.green : Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (_lastCheckin != null)
                      Text(
                        'Last ${_lastCheckin!.logType}: ${DateFormat('hh:mm a').format(_lastCheckin!.timestamp)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    const SizedBox(height: 24),

                    // Location Info
                    if (_currentPosition != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Check-in/out Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isCheckingIn
                            ? null
                            : () => _handleCheckInOut(_isCheckedIn ? 'OUT' : 'IN'),
                        icon: _isCheckingIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(_isCheckedIn ? Icons.logout : Icons.login),
                        label: Text(_isCheckedIn ? 'Check Out' : 'Check In'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: _isCheckedIn ? Colors.red : Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Attendance History
            Text(
              'Attendance History',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_attendanceHistory.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('No attendance records'),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attendanceHistory.length,
                itemBuilder: (context, index) {
                  final attendance = _attendanceHistory[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            attendance.isCheckIn ? Colors.green : Colors.red,
                        child: Icon(
                          attendance.isCheckIn ? Icons.login : Icons.logout,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        attendance.logType,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy - hh:mm a')
                                .format(attendance.timestamp),
                          ),
                          if (attendance.latitude != null &&
                              attendance.longitude != null)
                            Text(
                              'Location: ${attendance.latitude!.toStringAsFixed(4)}, ${attendance.longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.location_on,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
