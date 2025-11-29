import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/leave.dart';
import '../models/attendance.dart';

class AttendanceScreenEnhanced extends StatefulWidget {
  const AttendanceScreenEnhanced({super.key});

  @override
  State<AttendanceScreenEnhanced> createState() => _AttendanceScreenEnhancedState();
}

class _AttendanceScreenEnhancedState extends State<AttendanceScreenEnhanced> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, Map<String, dynamic>> _calendarData = {};
  bool _isLoadingCalendar = false;

  // Leave state
  List<Leave> _leaves = [];
  bool _isLoadingLeaves = false;

  // Check-in state
  Attendance? _lastCheckin;
  Position? _currentPosition;
  bool _isCheckingIn = false;
  bool _awayForEquipment = false;
  bool _isTogglingAwayFlag = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDay = _focusedDay;
    _loadCalendarData();
    _loadLeaves();
    _loadLastCheckin();
    _getCurrentLocation();
    _loadEmployeeStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendarData() async {
    setState(() => _isLoadingCalendar = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      if (employeeId == null) return;

      final response = await _apiService.getAttendanceCalendar(
        employeeId: employeeId,
        month: _focusedDay.month,
        year: _focusedDay.year,
      );

      final List<dynamic> calendarItems = response['result'] ?? [];
      final Map<String, Map<String, dynamic>> newData = {};

      for (var item in calendarItems) {
        newData[item['date']] = {
          'status': item['status'],
          'checkins': item['checkins'],
          'leave': item['leave'],
        };
      }

      setState(() {
        _calendarData = newData;
        _isLoadingCalendar = false;
      });
    } catch (e) {
      debugPrint('Error loading calendar: $e');
      setState(() => _isLoadingCalendar = false);
    }
  }

  Future<void> _loadLeaves() async {
    setState(() => _isLoadingLeaves = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      if (employeeId == null) return;

      final leavesJson = await _apiService.getLeaves(employeeId: employeeId);
      final List<Leave> loadedLeaves = leavesJson.map((json) => Leave.fromJson(json)).toList();

      setState(() {
        _leaves = loadedLeaves;
        _isLoadingLeaves = false;
      });
    } catch (e) {
      debugPrint('Error loading leaves: $e');
      setState(() => _isLoadingLeaves = false);
    }
  }

  Future<void> _loadLastCheckin() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      if (employeeId == null) return;

      final lastCheckin = await _apiService.getLastCheckin(employeeId);

      setState(() {
        _lastCheckin = lastCheckin;
      });
    } catch (e) {
      debugPrint('Error loading last check-in: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    setState(() {
      _currentPosition = position;
    });
  }

  Future<void> _loadEmployeeStatus() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      if (employeeId == null) return;

      final status = await _apiService.getEmployeeStatus(employeeId);

      setState(() {
        _awayForEquipment = status['awayForEquipment'] ?? false;
      });
    } catch (e) {
      debugPrint('Error loading employee status: $e');
    }
  }

  Future<void> _toggleAwayForEquipment(bool value) async {
    setState(() => _isTogglingAwayFlag = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      if (employeeId == null) {
        throw Exception('Employee ID not found');
      }

      final result = await _apiService.setAwayForEquipment(
        employeeId: employeeId,
        awayForEquipment: value,
      );

      if (result['success'] == true) {
        setState(() {
          _awayForEquipment = value;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value
                  ? 'Away for equipment enabled - Auto-checkout disabled'
                  : 'Away for equipment disabled - Auto-checkout enabled'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isTogglingAwayFlag = false);
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

      // Update background location tracking state
      await authProvider.updateCheckInState(logType == 'IN');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Check ${logType.toLowerCase()} successful!'),
            backgroundColor: Colors.green,
          ),
        );

        // Reload all data including calendar
        _loadLastCheckin();
        _loadCalendarData();
        _loadEmployeeStatus();
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

  Color _getMarkerColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'leave':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance & Leaves'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_month)),
            Tab(text: 'Leave Requests', icon: Icon(Icons.flight_takeoff)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(),
          _buildLeaveTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLeaveRequestDialog,
        icon: const Icon(Icons.add),
        label: const Text('Request Leave'),
      ),
    );
  }

  Widget _buildCalendarTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _getCurrentLocation();
        await _loadLastCheckin();
        await _loadCalendarData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // Check-in/out Card
            Container(
              margin: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isCheckedIn ? Icons.check_circle : Icons.access_time,
                            size: 40,
                            color: _isCheckedIn ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isCheckedIn ? 'Checked In' : 'Not Checked In',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(_isCheckedIn ? Icons.logout : Icons.login),
                          label: Text(_isCheckedIn ? 'Check Out' : 'Check In'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: _isCheckedIn ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),

                      // Away for Equipment Toggle (only show when checked in)
                      if (_isCheckedIn) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.build_circle_outlined, color: Colors.orange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Away for Equipment',
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    _awayForEquipment
                                        ? 'Auto-checkout disabled'
                                        : 'Enable if leaving site to fetch equipment',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            _isTogglingAwayFlag
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Switch(
                                    value: _awayForEquipment,
                                    onChanged: _toggleAwayForEquipment,
                                    activeColor: Colors.orange,
                                  ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_isLoadingCalendar)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2030),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: CalendarFormat.month,
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                  _loadCalendarData();
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, date, events) {
                    final dateKey = DateFormat('yyyy-MM-dd').format(date);
                    final dayData = _calendarData[dateKey];

                    if (dayData != null) {
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getMarkerColor(dayData['status']),
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
              ),
              const Divider(),
              _buildSelectedDayInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDayInfo() {
    if (_selectedDay == null) return const SizedBox.shrink();

    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final dayData = _calendarData[dateKey];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMM dd, yyyy').format(_selectedDay!),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (dayData == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('No attendance data for this day')),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          dayData['status'] == 'present' ? Icons.check_circle : Icons.event_busy,
                          color: _getMarkerColor(dayData['status']),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dayData['status'] == 'present' ? 'Present' : 'On Leave',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    if (dayData['checkins'] != null && (dayData['checkins'] as List).isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Check-ins:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...((dayData['checkins'] as List).map((checkin) {
                        final time = DateTime.parse(checkin['time']);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Icon(
                                checkin['type'] == 'IN' ? Icons.login : Icons.logout,
                                size: 16,
                                color: checkin['type'] == 'IN' ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 8),
                              Text('${checkin['type']}: ${DateFormat('hh:mm a').format(time)}'),
                            ],
                          ),
                        );
                      }).toList()),
                    ],
                    if (dayData['leave'] != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${dayData['leave']['type']} Leave',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (dayData['leave']['halfDay'] == true)
                              const Text('(Half Day)', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeaveTab() {
    return RefreshIndicator(
      onRefresh: _loadLeaves,
      child: _isLoadingLeaves
          ? const Center(child: CircularProgressIndicator())
          : _leaves.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flight_takeoff, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No leave requests',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _leaves.length,
                  itemBuilder: (context, index) {
                    final leave = _leaves[index];
                    return _LeaveCard(leave: leave);
                  },
                ),
    );
  }

  Future<void> _showLeaveRequestDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _LeaveRequestForm(
        onSubmit: () {
          _loadLeaves();
          _loadCalendarData();
        },
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final Leave leave;

  const _LeaveCard({required this.leave});

  Color _getStatusColor() {
    switch (leave.status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  leave.leaveTypeLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    leave.statusLabel.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${DateFormat('MMM dd').format(leave.fromDate)} - ${DateFormat('MMM dd, yyyy').format(leave.toDate)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(width: 16),
                Text(
                  '${leave.totalDays} ${leave.totalDays == 1 ? 'day' : 'days'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reason: ${leave.reason}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (leave.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Rejection Reason: ${leave.rejectionReason}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaveRequestForm extends StatefulWidget {
  final VoidCallback onSubmit;

  const _LeaveRequestForm({required this.onSubmit});

  @override
  State<_LeaveRequestForm> createState() => _LeaveRequestFormState();
}

class _LeaveRequestFormState extends State<_LeaveRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final ApiService _apiService = ApiService();

  String _leaveType = 'casual';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  bool _halfDay = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitLeaveRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.currentUser?.id;

      if (employeeId == null) {
        throw Exception('User not logged in');
      }

      await _apiService.applyLeave(
        employeeId: employeeId,
        leaveType: _leaveType,
        fromDate: _fromDate,
        toDate: _toDate,
        halfDay: _halfDay,
        reason: _reasonController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
        widget.onSubmit();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Request Leave',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                value: _leaveType,
                decoration: const InputDecoration(
                  labelText: 'Leave Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'casual', child: Text('Casual Leave')),
                  DropdownMenuItem(value: 'sick', child: Text('Sick Leave')),
                  DropdownMenuItem(value: 'earned', child: Text('Earned Leave')),
                  DropdownMenuItem(value: 'unpaid', child: Text('Unpaid Leave')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => setState(() => _leaveType = value!),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _fromDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _fromDate = date;
                            if (_toDate.isBefore(_fromDate)) {
                              _toDate = _fromDate;
                            }
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'From Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat('MMM dd, yyyy').format(_fromDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _toDate.isBefore(_fromDate) ? _fromDate : _toDate,
                          firstDate: _fromDate,
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => _toDate = date);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'To Date',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(DateFormat('MMM dd, yyyy').format(_toDate)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Half Day'),
                value: _halfDay,
                onChanged: (value) => setState(() => _halfDay = value!),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                  hintText: 'Enter reason for leave',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a reason';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitLeaveRequest,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit Request'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
