class Employee {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? employeeId;
  final String? department;
  final String? departmentCode;
  final String? site;
  final String? siteCode;
  final double? siteLatitude;
  final double? siteLongitude;
  final String? shift;
  final String? shiftStartTime;
  final String? shiftEndTime;
  final String? position;
  final String? photo;
  final bool enabled;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.employeeId,
    this.department,
    this.departmentCode,
    this.site,
    this.siteCode,
    this.siteLatitude,
    this.siteLongitude,
    this.shift,
    this.shiftStartTime,
    this.shiftEndTime,
    this.position,
    this.photo,
    this.enabled = true,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      employeeId: json['employeeId'],
      department: json['department']?['name'] ?? json['department'],
      departmentCode: json['department']?['code'],
      site: json['site']?['name'] ?? json['site'],
      siteCode: json['site']?['code'],
      siteLatitude: json['site']?['latitude']?.toDouble(),
      siteLongitude: json['site']?['longitude']?.toDouble(),
      shift: json['shift']?['name'] ?? json['shift'],
      shiftStartTime: json['shift']?['startTime'],
      shiftEndTime: json['shift']?['endTime'],
      position: json['role'] ?? json['position'] ?? json['designation'],
      photo: json['photo'],
      enabled: json['enabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'employeeId': employeeId,
      'department': department,
      'site': site,
      'shift': shift,
      'position': position,
      'photo': photo,
      'enabled': enabled,
    };
  }
}
