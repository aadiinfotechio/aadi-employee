class Leave {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final bool halfDay;
  final double totalDays;
  final String reason;
  final String status;
  final String? approvedBy;
  final DateTime? approvedDate;
  final String? rejectionReason;
  final DateTime appliedOn;

  Leave({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.halfDay,
    required this.totalDays,
    required this.reason,
    required this.status,
    this.approvedBy,
    this.approvedDate,
    this.rejectionReason,
    required this.appliedOn,
  });

  factory Leave.fromJson(Map<String, dynamic> json) {
    return Leave(
      id: json['_id'] ?? '',
      employeeId: json['employee']?['_id'] ?? json['employee'] ?? '',
      employeeName: json['employee']?['firstName'] != null
          ? '${json['employee']['firstName']} ${json['employee']['lastName'] ?? ''}'.trim()
          : null,
      leaveType: json['leaveType'] ?? 'casual',
      fromDate: DateTime.parse(json['fromDate']),
      toDate: DateTime.parse(json['toDate']),
      halfDay: json['halfDay'] ?? false,
      totalDays: (json['totalDays'] ?? 1).toDouble(),
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      approvedBy: json['approvedBy']?['name'],
      approvedDate: json['approvedDate'] != null ? DateTime.parse(json['approvedDate']) : null,
      rejectionReason: json['rejectionReason'],
      appliedOn: DateTime.parse(json['appliedOn'] ?? json['created'] ?? DateTime.now().toIso8601String()),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String get leaveTypeLabel {
    switch (leaveType) {
      case 'casual':
        return 'Casual Leave';
      case 'sick':
        return 'Sick Leave';
      case 'earned':
        return 'Earned Leave';
      case 'maternity':
        return 'Maternity Leave';
      case 'paternity':
        return 'Paternity Leave';
      case 'unpaid':
        return 'Unpaid Leave';
      case 'comp_off':
        return 'Comp Off';
      case 'other':
        return 'Other';
      default:
        return leaveType;
    }
  }
}
