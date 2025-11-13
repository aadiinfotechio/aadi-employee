class ApiConfig {
  // Production backend URL
  static const String baseUrl = 'https://aadi-erp.onrender.com/api';

  // Auth endpoints
  static const String login = '/mobile/auth/login';
  static const String changePassword = '/mobile/change-password';

  // Employee endpoints
  static const String employeeProfile = '/employee/read';

  // Task endpoints
  static const String tasksList = '/mobile/task/list';
  static const String taskUpdate = '/mobile/task/update';

  // Attendance endpoints
  static const String checkin = '/mobile/checkin';
  static const String checkinHistory = '/mobile/checkin/history';
  static const String lastCheckin = '/mobile/checkin/last';
  static const String attendanceCalendar = '/mobile/attendance/calendar';

  // Leave endpoints
  static const String leaveList = '/mobile/leave/list';
  static const String leaveApply = '/mobile/leave/apply';

  // Project endpoints
  static const String projectsList = '/project/list';
  static const String projectRead = '/project/read';

  // Dashboard endpoints
  static const String dashboardStats = '/mobile/dashboard/stats';
  static const String todayActivities = '/mobile/dashboard/activities';
}
