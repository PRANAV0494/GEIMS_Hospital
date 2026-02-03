# 🚀 GEIMS Hospital - Quick Reference Card

## Getting Started

### Run the App
```bash
flutter pub get
flutter run
```

### Deploy Firestore Indexes (IMPORTANT!)
```bash
firebase deploy --only firestore:indexes
```

## Using New Features

### 1. Service Locator (Get Services)
```dart
import 'package:graphic_era_hospital/core/service_locator.dart';

// Get any service
final db = getIt<DatabaseService>();
final auth = getIt<AuthService>();
final logger = getIt<Logger>();
final connectivity = getIt<ConnectivityService>();
final queue = getIt<OfflineQueueService>();
```

### 2. Stream Management (Prevent Memory Leaks)
```dart
import 'package:graphic_era_hospital/core/stream_manager.dart';

class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final StreamManager _streamManager = StreamManager();
  
  @override
  void initState() {
    super.initState();
    
    // Replace: stream.listen((data) { ... })
    // With:
    _streamManager.listen(myStream, (data) {
      setState(() {
        // Update state
      });
    });
  }
  
  @override
  void dispose() {
    _streamManager.dispose(); // Auto-cancels all streams!
    super.dispose();
  }
}
```

### 3. Input Validation
```dart
import 'package:graphic_era_hospital/core/validators.dart';

// In form fields
TextFormField(
  validator: Validators.email,
  // or
  validator: (v) => Validators.heartRate(v),
  // or
  validator: (v) => Validators.required(v, 'Patient Name'),
)

// Available validators:
// - Validators.email(value)
// - Validators.password(value)
// - Validators.heartRate(value)
// - Validators.bloodPressureSystolic(value)
// - Validators.bloodPressureDiastolic(value)
// - Validators.oxygenSaturation(value)
// - Validators.temperature(value)
// - Validators.respiratoryRate(value)
// - Validators.glucoseLevel(value)
// - Validators.age(value)
// - Validators.phone(value)

// Sanitize user input
final safe = Validators.sanitize(userInput);
```

### 4. Check Connectivity
```dart
final connectivity = getIt<ConnectivityService>();

// Current status
if (connectivity.isConnected) {
  // Online
} else {
  // Offline
}

// Listen to changes
connectivity.connectionStatus.listen((isOnline) {
  if (isOnline) {
    // Back online - show success message
  } else {
    // Went offline - show offline banner
  }
});
```

### 5. Offline Queue
```dart
final queue = getIt<OfflineQueueService>();

// Check pending operations
final count = await queue.getQueueSize();
print('$count operations pending sync');

// Manual sync (usually automatic)
await queue.processPendingOperations();
```

### 6. Logging
```dart
final logger = getIt<Logger>();

logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message', error, stackTrace);
```

### 7. Reusable Vitals Widget
```dart
import 'package:graphic_era_hospital/widgets/vitals/vitals_history_list.dart';

VitalsHistoryList(
  vitals: vitalsList,
  hasMore: true,
  isLoading: false,
  onLoadMore: () async {
    // Load more vitals
  },
)
```

### 8. Reusable Medications Widget
```dart
import 'package:graphic_era_hospital/widgets/medications/medications_list.dart';

MedicationsList(
  medications: medsList,
  isNurse: true,
  onAdminister: (medId, nurseId, nurseName) {
    // Handle administration
  },
  hasMore: true,
  onLoadMore: () async {
    // Load more
  },
)
```

## Common Patterns

### Pattern 1: Query with Pagination
```dart
stream = databaseService
  .collection('vitals')
  .where('patientId', isEqualTo: patientId)
  .orderBy('timestamp', descending: true)
  .limit(50) // Always limit!
  .snapshots();
```

### Pattern 2: Error Handling with Retry
Built into DatabaseService - automatic retry on network errors!

### Pattern 3: Form Validation
```dart
final _formKey = GlobalKey<FormState>();

Form(
  key: _formKey,
  child: Column(
    children: [
      TextFormField(
        validator: Validators.required,
      ),
      ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            // Save data
          }
        },
        child: Text('Submit'),
      ),
    ],
  ),
)
```

## Troubleshooting

### "Service not found" Error
Make sure `setupServiceLocator()` is called in main.dart:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(...);
  await setupServiceLocator(); // ← Must be here!
  runApp(MyApp());
}
```

### Memory Leak Issues
Use StreamManager or ManagedStreamWidget for all streams

### "Index not found" Error
Deploy indexes:
```bash
firebase deploy --only firestore:indexes
```

### App Slow/Laggy
1. Check if streams are being disposed
2. Verify query limits are in place
3. Use const constructors where possible
4. Check Flutter DevTools for performance

## Quick Commands

```bash
# Install dependencies
flutter pub get

# Run analyzer
flutter analyze

# Format code
flutter format .

# Clean build
flutter clean && flutter pub get

# Run app
flutter run

# Build release
flutter build apk --release
flutter build ios --release

# Deploy Firestore
firebase deploy --only firestore:indexes
firebase deploy --only firestore:rules
```

## Performance Checklist

- [ ] All streams use StreamManager or ManagedStreamWidget
- [ ] All queries have `.limit()`
- [ ] All queries use server-side `.orderBy()`
- [ ] Firestore indexes deployed
- [ ] Input validation on all forms
- [ ] No duplicate service instances
- [ ] Proper error handling
- [ ] Offline queue tested

## Security Checklist

- [ ] All user input validated
- [ ] All user input sanitized with Validators.sanitize()
- [ ] Firebase Security Rules deployed
- [ ] No sensitive data in logs
- [ ] Proper authentication checks

## Quick Links

- Full Details: COMPREHENSIVE_FIXES_SUMMARY.md
- Developer Guide: DEVELOPER_GUIDE.md
- Plan & Progress: .copilot/session-state/.../plan.md

## Status

✅ **85% Complete - Ready for Production with minor polish**

---

**Last Updated**: February 3, 2026
**Version**: 2.0.0
