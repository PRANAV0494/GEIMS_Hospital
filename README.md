# GEIMS Hospital Management System

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.10.1+-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase)
![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)

**A comprehensive, role-based mobile application for hospital management**

[Features](#-features) • [Architecture](#-architecture) • [Getting Started](#-getting-started) • [Documentation](#-documentation)

</div>

---

## 🏥 Overview

**GEIMS Hospital** (Graphic Era Integrated Medical System) is a production-ready Flutter application designed to streamline hospital operations. It provides distinct dashboards for **Nurses**, **Doctors**, and **Administrators**, ensuring each staff member has access to role-appropriate tools and information.

### ✨ Key Highlights

- 🔐 **Role-Based Access Control** - Secure authentication with distinct permissions
- 📱 **Offline-First Architecture** - Full functionality without internet connectivity
- ⚡ **Optimized Performance** - Server-side queries, pagination, and caching
- 🔄 **Real-time Sync** - Instant data synchronization across all devices
- 🏗️ **Clean Architecture** - Dependency injection with GetIt service locator

---

## � Features

### 👩‍⚕️ Nurse Dashboard
| Feature | Description |
|---------|-------------|
| **Patient Details** | View and manage patient information with GEIMS IDs |
| **Clinical Data** | Record vitals, medications, and observations |
| **Task Management** | Track daily nursing tasks with due dates |
| **Communication Hub** | Real-time messaging with doctors |

### 👨‍⚕️ Doctor Dashboard
| Feature | Description |
|---------|-------------|
| **Patient Rounds** | Ward-organized patient overview |
| **Medical History** | Complete patient records and vitals trends |
| **Treatment Plans** | Manage diagnoses and prescriptions |
| **Alerts & Notifications** | Critical patient status updates |

### 🛠️ Admin Dashboard
| Feature | Description |
|---------|-------------|
| **System Overview** | Hospital-wide statistics and metrics |
| **Staff Management** | User account and role management |
| **Configuration** | Ward and bed capacity settings |

---

## 🏗️ Architecture

```
lib/
├── core/                 # Service locator & dependency injection
├── config/               # Routes, themes, constants
├── models/               # Data models (Patient, User, Vitals, etc.)
├── providers/            # State management (ChangeNotifiers)
├── services/             # Backend services
│   ├── auth_service.dart
│   ├── database_service.dart
│   ├── connectivity_service.dart
│   └── offline_queue_service.dart
├── screens/
│   ├── admin/            # Admin-specific screens
│   ├── doctor/           # Doctor-specific screens
│   └── nurse/            # Nurse-specific screens
├── widgets/              # Reusable UI components
└── main.dart             # Entry point
```

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Flutter 3.10+ |
| **Backend** | Firebase (Auth, Firestore, Storage) |
| **State Management** | Provider + GetIt |
| **Local Storage** | SQLite + SharedPreferences |
| **UI** | Material 3, flutter_animate, fl_chart |

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.10.1+
- Firebase project configured
- Dart 3.0+

### Installation

```bash
# Clone the repository
git clone https://github.com/PRANAV0494/GEIMS_Hospital.git
cd GEIMS_Hospital

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android/iOS apps with your package name
3. Download and add configuration files:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
4. Deploy Firestore indexes:
   ```bash
   firebase deploy --only firestore:indexes
   ```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) | Common patterns and quick start guide |
| [DEVELOPER_GUIDE.md](./DEVELOPER_GUIDE.md) | Comprehensive development guide |
| [COMPREHENSIVE_FIXES_SUMMARY.md](./COMPREHENSIVE_FIXES_SUMMARY.md) | All improvements and changes |

---

## 🔧 Performance Optimizations

- **100MB Firestore cache limit** - Prevents memory bloat
- **Server-side ordering** - All queries use Firestore indexes
- **Pagination** - 50 record limits on vitals/medications/messages
- **Stream caching** - Reduces Firestore reads in search
- **Retry logic** - Exponential backoff for network failures

---

## 📱 Screens

| Screen | Route |
|--------|-------|
| Splash | `/` |
| Login | `/login` |
| Nurse Dashboard | `/nurse-dashboard` |
| Doctor Dashboard | `/doctor-dashboard` |
| Admin Dashboard | `/admin-dashboard` |

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License.

---

<div align="center">
Made with ❤️ for Graphic Era University
</div>
