# GEIMS Hospital - Developer Guide

## 🏗️ Architecture Overview

### Service Layer (Singleton Pattern via GetIt)
All services are registered as singletons and accessed via dependency injection:

```dart
import 'package:geims_hospital/core/service_locator.dart';

// Access services
final dbService = getIt<DatabaseService>();
final authService = getIt<AuthService>();
final connectivity = getIt<ConnectivityService>();
final offlineQueue = getIt<OfflineQueueService>();
final logger = getIt<Logger>();
```

### Core Utilities

#### 1. StreamManager
Prevents memory leaks by automatically managing stream subscriptions:

```dart
import 'package:geims_hospital/core/stream_manager.dart';

class MyWidget extends StatefulWidget {
  // ...
}

class _MyWidgetState extends State<MyWidget> {
  final StreamManager _streamManager = StreamManager();
  
  @override
  void initState() {
    super.initState();
    
    // Managed stream - auto cleanup
    _streamManager.listen(
      databaseService.getVitalsForPatient(patientId),
      (vitals) {
        setState(() => _vitals = vitals);
      },
    );
  }
  
  @override
  void dispose() {
    _streamManager.dispose(); // Cancels all streams
    super.dispose();
  }
}
```

#### 2. ManagedStreamWidget (Advanced)
Base class with built-in stream management:

```dart
import 'package:geims_hospital/core/managed_stream_widget.dart';

class MyWidget extends ManagedStreamWidget {
  const MyWidget({super.key});
  
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends ManagedStreamState<MyWidget> {
  @override
  void initState() {
    super.initState();
    
    // Automatic cleanup!
    listenToStream(myStream, (data) {
      setState(() {
        // Handle data
      });
    });
  }
  
  // No need to override dispose!
}
```

#### 3. Input Validation
Comprehensive validators for all input types:

```dart
import 'package:geims_hospital/core/validators.dart';

// In forms
TextFormField(
  validator: Validators.email,
  // or
  validator: (value) => Validators.heartRate(value),
  // or
  validator: (value) => Validators.required(value, 'Patient name'),
)

// Sanitize user input before saving
final safeName = Validators.sanitize(userInput);
```

Available validators:
- `Validators.email()`
- `Validators.password()`
- `Validators.required(value, fieldName)`
- `Validators.numeric(value, fieldName)`
- `Validators.numericRange(value, min, max, fieldName)`
- `Validators.heartRate(value)`
- `Validators.bloodPressureSystolic(value)`
- `Validators.bloodPressureDiastolic(value)`
- `Validators.oxygenSaturation(value)`
- `Validators.temperature(value)`
- `Validators.respiratoryRate(value)`
- `Validators.glucoseLevel(value)`
- `Validators.age(value)`
- `Validators.phone(value)`
- `Validators.sanitize(input)` - Prevents XSS

### Offline Support

#### Connectivity Monitoring
```dart
final connectivity = getIt<ConnectivityService>();

// Check current status
if (connectivity.isConnected) {
  // User is online
}

// Listen to changes
connectivity.connectionStatus.listen((isOnline) {
  if (isOnline) {
    print('Back online!');
  } else {
    print('Offline mode');
  }
});
```

#### Offline Queue
Failed operations are automatically queued and retried:

```dart
final queue = getIt<OfflineQueueService>();

// Check pending operations
final pending = await queue.getQueueSize();
print('$pending operations pending');

// Manual sync (usually automatic)
await queue.processPendingOperations();

// Clear queue (use with caution!)
await queue.clearQueue();
```

### Reusable Widgets

#### Vitals History List
```dart
import 'package:geims_hospital/widgets/vitals/vitals_history_list.dart';

VitalsHistoryList(
  vitals: vitalsList,
  hasMore: true,
  isLoading: false,
  onLoadMore: () {
    // Load more vitals
  },
)
```

#### Medications List
```dart
import 'package:geims_hospital/widgets/medications/medications_list.dart';

MedicationsList(
  medications: medsList,
  isNurse: true,
  onAdminister: (medId, nurseId, nurseName) {
    // Mark as administered
  },
  hasMore: true,
  onLoadMore: () {
    // Load more medications
  },
)
```

## 🔥 Firestore Best Practices

### Query Optimization
All queries should:
1. Use server-side ordering (`.orderBy()`)
2. Have limits (`.limit(50)`)
3. Have composite indexes defined

Example:
```dart
// ✅ Good
_firestore
  .collection('vitals')
  .where('patientId', isEqualTo: patientId)
  .orderBy('timestamp', descending: true)
  .limit(50)
  .snapshots();

// ❌ Bad
_firestore
  .collection('vitals')
  .where('patientId', isEqualTo: patientId)
  .snapshots(); // No limit, will fetch all!
```

### Composite Indexes
All indexes are defined in `firestore.indexes.json`. Deploy with:
```bash
firebase deploy --only firestore:indexes
```

## 🐛 Debugging

### Logger Usage
```dart
final logger = getIt<Logger>();

logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message');
logger.wtf('What a terrible failure');
```

### Stream Monitoring
Check active stream count:
```dart
final manager = StreamManager();
print('Active streams: ${manager.activeCount}');
```

## 📊 Performance Tips

1. **Use const constructors** where possible
2. **Extract widgets** into separate classes
3. **Implement proper keys** for list items
4. **Dispose controllers** in dispose()
5. **Limit StreamBuilder nesting**
6. **Use pagination** for large lists

## 🔒 Security Guidelines

1. **Always validate input** before Firestore writes
2. **Sanitize user input** with `Validators.sanitize()`
3. **Never trust client-side validation alone**
4. **Use Firebase Security Rules**
5. **Rate limit sensitive operations**

## 🧪 Testing Guidelines

### Unit Tests
```dart
test('Validators should validate email correctly', () {
  expect(Validators.email('test@example.com'), null);
  expect(Validators.email('invalid'), isNotNull);
});
```

### Widget Tests
```dart
testWidgets('VitalsCard displays correctly', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: VitalsCard(vital: mockVital),
    ),
  );
  
  expect(find.text('Heart Rate'), findsOneWidget);
});
```

## 📱 Platform-Specific Notes

### Android
- Min SDK: 21
- Target SDK: 34

### iOS
- Min iOS: 12.0
- Requires permissions for camera, microphone

### Web
- Firebase Hosting configured
- PWA support enabled

## 🚀 Deployment

### Build Commands
```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

### Firebase Deploy
```bash
# Deploy everything
firebase deploy

# Deploy only Firestore rules
firebase deploy --only firestore:rules

# Deploy only indexes
firebase deploy --only firestore:indexes

# Deploy only hosting
firebase deploy --only hosting
```

## 📝 Code Style

- Use trailing commas for better diffs
- Max line length: 80 characters
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Run `flutter analyze` before committing
- Format with `flutter format .`

## 🔄 State Management

Using Provider pattern:
```dart
// Access provider
final authProvider = Provider.of<AuthProvider>(context, listen: false);

// Or with Consumer
Consumer<AuthProvider>(
  builder: (context, auth, child) {
    return Text(auth.currentUser?.name ?? '');
  },
)
```

## 📚 Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [GetIt Documentation](https://pub.dev/packages/get_it)
- [Provider Documentation](https://pub.dev/packages/provider)

## 🆘 Common Issues

### Issue: "Service not found"
**Solution**: Make sure service locator is initialized in main.dart

### Issue: "Memory leak detected"
**Solution**: Use StreamManager or ManagedStreamWidget

### Issue: "Composite index required"
**Solution**: Check console error, add to firestore.indexes.json, deploy

### Issue: "Offline operations not syncing"
**Solution**: Check connectivity service, verify queue implementation

## 👥 Contributing

1. Create feature branch
2. Make changes
3. Run `flutter analyze`
4. Run `flutter test`
5. Create pull request

## 📄 License

Proprietary - Graphic Era Hospital
