import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/attendance.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  Map<String, dynamic>? _stats;
  List<Attendance> _recentActivities = [];
  bool _isLoading = true;
  bool _isCheckingIn = false;
  Attendance? _lastCheckin;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      final stats = await _apiService.getDashboardStats();

      // Get activities filtered by logged-in employee
      final activities = await _apiService.getTodayActivities(employeeId: employeeId);

      Attendance? lastCheckin;
      if (employeeId != null) {
        lastCheckin = await _apiService.getLastCheckin(employeeId);
      }

      setState(() {
        _stats = stats;
        _recentActivities = activities;
        _lastCheckin = lastCheckin;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckInOut(String logType) async {
    // Show confirmation dialog for check-out
    if (logType == 'OUT') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Check Out'),
          content: const Text('Are you sure you want to check out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Check Out'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return; // User cancelled
      }
    }

    // If location is null, try to get it first
    if (_currentPosition == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting location...'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
      await _getCurrentLocation();

      // If still null after trying, show error
      if (_currentPosition == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get location. Please enable location services.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isCheckingIn = true);

    try {
      if (!mounted) return;
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
            content: Text('Check ${logType.toLowerCase()} successful!'),
            backgroundColor: Colors.green,
          ),
        );

        _loadDashboardData(); // Reload data
      }
    } catch (e) {
      debugPrint('Check-in/out error: $e');
      if (mounted) {
        String errorMessage = e.toString();
        // Extract just the error message if it's wrapped
        if (errorMessage.contains('Exception:')) {
          errorMessage = errorMessage.replaceAll('Exception:', '').trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  bool get _isCheckedIn {
    if (_lastCheckin == null) return false;
    return _lastCheckin!.isCheckIn;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return RefreshIndicator(
      onRefresh: () async {
        await _getCurrentLocation();
        await _loadDashboardData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        user?.name.substring(0, 1).toUpperCase() ?? 'U',
                        style: const TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back,',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            user?.name ?? 'Employee',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            user?.position ?? user?.department ?? 'Employee',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Check-in/out Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isCheckedIn ? Icons.check_circle : Icons.access_time,
                          size: 48,
                          color: _isCheckedIn ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isCheckedIn ? 'Checked In' : 'Not Checked In',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _isCheckedIn ? Colors.green : Colors.grey,
                                    ),
                              ),
                              if (_lastCheckin != null)
                                Text(
                                  'Last ${_lastCheckin!.logType}: ${DateFormat('hh:mm a').format(_lastCheckin!.timestamp)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.grey,
                                      ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Location Info
                    if (_currentPosition != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),

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
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(_isCheckedIn ? Icons.logout : Icons.login),
                        label: Text(_isCheckedIn ? 'Check Out' : 'Check In'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

            // Stats Cards
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_stats != null) ...[
              Text(
                'Today\'s Overview',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Checked In',
                      value: '${_stats!['todayCheckins'] ?? 0}',
                      icon: Icons.login,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Total Staff',
                      value: '${_stats!['totalEmployees'] ?? 0}',
                      icon: Icons.people,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'My Tasks',
                      value: '${_stats!['activeTasks'] ?? 0}',
                      icon: Icons.task_alt,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      title: 'Projects',
                      value: '${_stats!['activeProjects'] ?? 0}',
                      icon: Icons.folder,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Recent Activities
            Text(
              'Recent Activities',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            if (_recentActivities.isEmpty && !_isLoading)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(
                    child: Text('No activities today'),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentActivities.length,
                itemBuilder: (context, index) {
                  final activity = _recentActivities[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: activity.isCheckIn ? Colors.green : Colors.red,
                        child: Icon(
                          activity.isCheckIn ? Icons.login : Icons.logout,
                          color: Colors.white,
                        ),
                      ),
                      title: Text('${activity.logType} - ${DateFormat('hh:mm a').format(activity.timestamp)}'),
                      subtitle: Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              activity.location ?? 'Location not available',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        DateFormat('MMM dd').format(activity.timestamp),
                        style: Theme.of(context).textTheme.bodySmall,
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
