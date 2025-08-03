# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Development
- `flutter pub get` - Install dependencies
- `flutter run` - Run the application in debug mode (launches on connected device/emulator)
- `flutter run -d chrome` - Run as web app in Chrome browser
- `flutter build apk` - Build Android APK for release
- `flutter build ios` - Build iOS app (requires macOS with Xcode)
- `flutter clean` - Clean build artifacts and cached files

### Code Quality & Testing
- `flutter analyze` - Run static analysis to check for code issues
- `flutter format .` - Format all Dart files according to Flutter style guide
- `flutter test` - Run unit tests (when tests are implemented)
- `flutter test test/specific_test.dart` - Run a specific test file

### Debugging
- `flutter doctor` - Check Flutter installation and development environment
- `flutter logs` - View device logs while app is running
- `flutter inspector` - Launch widget inspector for UI debugging

## Project Architecture

### Application Overview
**Super Pet Connect** - A Flutter mobile application that facilitates blood donation for pets by connecting hospitals, pet owners, and administrators. The app serves as a platform for coordinating emergency and routine blood donation requests.

### Core Architecture Patterns

**Role-Based Architecture**
- Three distinct user interfaces: Admin, Hospital, and User (Pet Owner)
- Authentication-based routing with role validation
- Separate dashboards and feature sets per role

**Model-View-Service Pattern**
- **Models** (`lib/models/`): Data structures for API communication
  - Post: Blood donation requests with time slots and urgency flags
  - Hospital: Hospital entities with contact and verification info
  - Pet: Pet profiles with blood type and medical information
  - TimeRange: Appointment scheduling slots
- **Views**: Role-specific screens organized by user type
- **Services** (`lib/services/`): Business logic and backend API integration

**State Management**
- StatefulWidget-based local state management
- SharedPreferences for persistent data (user tokens, preferences)
- No global state management solution (consider adding Provider/Riverpod for complex state)

### Key Directories

- `lib/admin/` - Administrative interface
  - User approval workflows
  - Hospital verification management
  - System-wide content moderation
- `lib/auth/` - Authentication flow
  - Welcome screen with donation board preview
  - Login/registration with role selection
  - FCM token management for notifications
- `lib/hospital/` - Hospital functionality
  - Blood donation post creation/management
  - Applicant review and approval
  - Time slot scheduling interface
- `lib/user/` - Pet owner features
  - Pet registration and profile management
  - Browse/apply for donation opportunities
  - Educational content (columns)
- `lib/models/` - Core data models
- `lib/services/` - API communication layer
- `lib/utils/` - Configuration and utilities
  - `config.dart`: Backend server URL configuration
  - `app_theme.dart`: Centralized theming (Toss-inspired design)
- `lib/widgets/` - Reusable UI components

### Key Configuration

**Backend Integration**
- Server URL configured in `lib/utils/config.dart`
- HTTP-based REST API communication
- JWT token authentication
- Error handling and response parsing

**Firebase Setup**
- Firebase Core initialization in `main.dart`
- FCM for push notifications with background message handling
- Local notifications with Android notification channels
- Requires `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

**Localization**
- Korean market focus with Asia/Seoul timezone
- KPostal integration for Korean address lookup
- Date/time formatting for Korean locale

### Authentication & Navigation Flow

1. **App Launch** → Welcome screen showing blood donation posts
2. **Authentication** → Login/Register with role selection
3. **Admin Approval** → New users require admin verification
4. **Role-Based Routing**:
   - Admin → `AdminDashboard`
   - Hospital → `HospitalDashboard`
   - User → `UserDashboard`
5. **Token Management** → JWT stored in SharedPreferences

### Critical Features

**Blood Donation Post System**
- Time slot scheduling with `interval_time_picker`
- Urgency flags for emergency requests
- Regional filtering for location-based matching
- Real-time status updates

**Notification System**
- FCM push notifications for urgent requests
- Local notifications for app engagement
- Background message processing
- Notification channel configuration for Android

**Pet Management**
- Pet profile creation with medical details
- Blood type tracking
- Donation history
- Health status monitoring

### Dependencies

**Core Packages**
- `http: ^1.4.0` - REST API communication
- `shared_preferences: ^2.2.2` - Local data persistence
- `intl: ^0.19.0` - Internationalization and date formatting

**Firebase Integration**
- `firebase_core: ^2.27.0` - Firebase initialization
- `firebase_messaging: ^14.7.10` - Push notifications
- `flutter_local_notifications: ^17.0.0` - System notifications
- `timezone: ^0.9.2` - Timezone configuration

**UI/UX Enhancements**
- `interval_time_picker: ^3.0.3+9` - Time slot selection
- `kpostal: 1.1.0` - Korean postal code lookup
- `cupertino_icons: ^1.0.8` - iOS-style icons

**Development Tools**
- `flutter_lints: ^5.0.0` - Code quality enforcement

### Design System

**Theme Configuration** (`lib/utils/app_theme.dart`)
- Toss-inspired minimalist design
- Consistent color palette with semantic naming
- Typography scale for hierarchy
- Spacing system for consistent layouts
- Custom widget styling (buttons, cards, inputs)

**UI Components** (`lib/widgets/`)
- CustomAppBar with role-based styling
- Reusable form inputs with validation
- Card components for content display
- Loading states and error handling

### API Integration Patterns

**Request Structure**
```dart
// Typical API call pattern
final response = await http.post(
  Uri.parse('${AppConfig.baseUrl}/endpoint'),
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  },
  body: jsonEncode(data),
);
```

**Error Handling**
- Network error detection
- HTTP status code validation
- User-friendly error messages
- Retry mechanisms for failed requests

### Development Considerations

**Platform-Specific Setup**
- Android: Minimum SDK 21, Target SDK 33+
- iOS: Minimum deployment target iOS 11.0
- Firebase configuration files required for both platforms

**Performance Optimization**
- Lazy loading for list views
- Image caching strategies
- Efficient state updates
- Proper disposal of resources

**Security Considerations**
- JWT token expiration handling
- Secure storage of sensitive data
- API endpoint protection
- Input validation and sanitization