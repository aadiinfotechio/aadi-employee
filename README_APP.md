# Aadi Infotech Employee App

Flutter mobile application for employees and site engineers to manage tasks, attendance, and location tracking.

## Features

- **User Authentication** - Secure login with email and password
- **Dashboard** - Overview of daily stats and recent activities
- **Task Management** - View assigned tasks, update status, filter by status
- **Attendance** - Check-in/Check-out with GPS location tracking
- **Location Tracking** - Automatic location capture during attendance
- **Responsive UI** - Material Design 3 with company branding

## Quick Start

1. Install dependencies:
```bash
cd /Users/kinjaldas/aadi_employee_app
flutter pub get
```

2. Update API URL in `lib/config/api_config.dart` with your backend URL

3. Run the app:
```bash
flutter run
```

## Testing (Easiest Way!)

Flutter has HOT RELOAD - the easiest testing:

1. Run once: `flutter run`
2. Make changes to any file
3. Press `r` - changes apply instantly!
4. Press `R` for full restart

## Connect to Backend

Update `lib/config/api_config.dart`:
```dart
static const String baseUrl = 'http://YOUR_IP:8888/api';
```

Get your IP: `ipconfig getifaddr en0`

## Login Credentials

Use admin credentials from your backend:
- Email: admin@demo.com
- Password: admin123

## Build APK

```bash
flutter build apk --release
```

APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

