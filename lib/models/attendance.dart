class Attendance {
  final String? id;
  final String employeeId;
  final String? employeeName;
  final DateTime timestamp;
  final String logType; // 'IN' or 'OUT'
  final double? latitude;
  final double? longitude;
  final String? location;
  final String? device;

  Attendance({
    this.id,
    required this.employeeId,
    this.employeeName,
    required this.timestamp,
    required this.logType,
    this.latitude,
    this.longitude,
    this.location,
    this.device,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['_id'],
      employeeId: json['employee']?['_id'] ?? json['employee'] ?? '',
      employeeName: json['employee']?['name'],
      timestamp: DateTime.parse(json['time'] ?? json['timestamp'] ?? DateTime.now().toIso8601String()).toLocal(),
      logType: json['log_type'] ?? json['logType'] ?? 'IN',
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      location: json['location'],
      device: json['device_id'] ?? json['device'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'employee': employeeId,
      'time': timestamp.toIso8601String(),
      'log_type': logType,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (location != null) 'location': location,
      if (device != null) 'device_id': device,
    };
  }

  bool get isCheckIn => logType.toUpperCase() == 'IN';
  bool get isCheckOut => logType.toUpperCase() == 'OUT';
}
