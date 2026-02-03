# Graphic Era Hospital Management System

A comprehensive, role-based mobile application designed for hospital management, streamlining communication and workflows between Nurses, Doctors, and Administrators.

## 📋 Overview

The **Graphic Era Hospital** app facilitates efficient patient management and hospital operations. It features distinct dashboards for different user roles, ensuring that each staff member has access to the tools and information relevant to their responsibilities.

## 🚀 Key Features

### 🔐 Authentication & Security
- **Secure Login/Signup**: Email and password-based authentication via Firebase Auth.
- **Role-Based Access Control (RBAC)**: Distinct login flows and permissions for:
  - **Nurses**: Ward assignment and patient care tasks.
  - **Doctors**: Specialization-based views and patient rounds.
  - **Admins**: System oversight and management.
- **Persistent Session**: Keeps users logged in with offline capability.

### 🖥️ Dashboards
#### 👩‍⚕️ Nurse Dashboard
- **Patient Details**: View and manage patient information.
- **Clinical Data**: Record vitals, ongoing treatments, and observations.
- **Task Management**: Track daily nursing tasks and reminders.
- **Communication Hub**: Message doctors and other staff.

#### 👨‍⚕️ Doctor Dashboard
- **Patient Detail View**: Comprehensive view of patient history and current status.
- **Rounds & Reviews**: Manage patient rounds and update treatment plans.

#### 🛠️ Admin Dashboard
- **System Overview**: Monitor hospital statistics.
- **Staff Management**: probable features for managing user accounts and assignments.

### ⚙️ Technical Capabilities
- **Offline Support**: Firestore persistence enabled for accessing data without an internet connection.
- **Real-time Updates**: Instant synchronization of data across devices using Cloud Firestore.
- **Multimedia Support**: Integration for recording audio and handling images.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (SDK ^3.10.1)
- **Language**: Dart
- **Backend & Database**: 
  - [Firebase Core](https://firebase.google.com/docs/flutter/setup)
  - [Firebase Auth](https://firebase.google.com/docs/auth) (Authentication)
  - [Cloud Firestore](https://firebase.google.com/docs/firestore) (Database)
  - [Firebase Storage](https://firebase.google.com/docs/storage) (Media Storage)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Storage**: `sqflite`, `shared_preferences`
- **UI Components**:
  - `flutter_animate` for animations.
  - `fl_chart` for data visualization.
  - `google_fonts` for typography.

## 📱 Application Flow

1. **Splash Screen**: Initial load and initialization.
2. **Login/Signup Screen**:
   - Users can Sign Up by entering details and selecting their role (Nurse/Doctor).
   - Sign In uses Email/Password.
   - **Role Selection**: Determines which dashboard is shown post-login.
   - **Form Validation**: Ensures robust data entry (Email format, Password length).
3. **Dashboards**:
   - **Admin** -> `/admin-dashboard`
   - **Nurse** -> `/nurse-dashboard`
   - **Doctor** -> `/doctor-dashboard`

## 📂 Project Structure

```
lib/
├── config/             # App configuration (routes, themes, constants)
├── models/             # Data models (Patient, User, Message, etc.)
├── providers/          # State management (AuthProvider, PatientProvider, etc.)
├── screens/            # UI Screens
│   ├── admin/          # Admin specific screens
│   ├── doctor/         # Doctor specific screens
│   ├── nurse/          # Nurse specific screens
│   ├── login_screen.dart
│   ├── splash_screen.dart
│   └── settings_screen.dart
├── services/           # Backend services (Firebase wrappers)
├── widgets/            # Reusable UI components
└── main.dart           # Entry point and initialization
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed.
- Setup a Firebase Project and configure `google-services.json` (Android) / `GoogleService-Info.plist` (iOS).

### Installation
1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   ```
2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the App**:
   ```bash
   flutter run
   ```

## 🤝 Contributing
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request
