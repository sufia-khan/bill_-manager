# Firebase & Hive Setup Guide for BillManager

## Overview
Your app now has both Firebase (cloud sync) and Hive (local storage) fully integrated with automatic synchronization.

## Step 1: Install Dependencies

Run this command to install all packages:

```bash
flutter pub get
```

## Step 2: Generate Hive Adapters

The Hive model needs code generation. Run:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will generate `lib/models/bill_hive.g.dart` file.

## Step 3: Setup Firebase Project

### Option A: Using FlutterFire CLI (Recommended)

1. Install FlutterFire CLI:
```bash
dart pub global activate flutterfire_cli
```

2. Login to Firebase:
```bash
firebase login
```

3. Configure your project:
```bash
flutterfire configure
```

This will:
- Create a Firebase project (or select existing)
- Register your app for Android/iOS/Web
- Generate `lib/firebase_options.dart` with your credentials
- Update platform-specific files

### Option B: Manual Setup

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing
3. Add apps for each platform you need:

#### For Android:
- Click "Add app" → Android
- Package name: `com.example.bill_manager` (from `android/app/build.gradle.kts`)
- Download `google-services.json`
- Place it in `android/app/`
- Add to `android/build.gradle.kts`:
```kotlin
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```
- Add to `android/app/build.gradle.kts`:
```kotlin
plugins {
    id 'com.google.gms.google-services'
}
```

#### For iOS:
- Click "Add app" → iOS
- Bundle ID: `com.example.billManager`
- Download `GoogleService-Info.plist`
- Place it in `ios/Runner/`
- Open `ios/Runner.xcworkspace` in Xcode
- Drag the file into the Runner folder

#### For Web:
- Click "Add app" → Web
- Copy the configuration
- Update `lib/firebase_options.dart` with your credentials

## Step 4: Enable Firebase Services

In Firebase Console:

### Authentication:
1. Go to Authentication → Sign-in method
2. Enable "Email/Password"
3. (Optional) Enable other providers

### Firestore Database:
1. Go to Firestore Database
2. Click "Create database"
3. Start in **test mode** (for development)
4. Choose a location
5. For production, update rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/bills/{billId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Step 5: Test the Setup

Run your app:

```bash
flutter run
```

### What Should Work:

1. **Local Storage (Hive)**:
   - Bills are saved locally immediately
   - Works offline
   - Fast access

2. **Cloud Sync (Firebase)**:
   - Bills sync to Firestore when online
   - Automatic conflict resolution
   - Real-time updates across devices

3. **Authentication**:
   - Sign up with email/password
   - Sign in
   - Password reset

## Architecture

```
┌─────────────────┐
│   UI Layer      │
│  (Screens)      │
└────────┬────────┘
         │
┌────────▼────────┐
│  BillProvider   │  ← State Management
│   (Provider)    │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼──┐  ┌──▼────┐
│ Hive │  │Firebase│
│Local │  │ Cloud  │
└──────┘  └────────┘
```

### Data Flow:

1. **Add Bill**: UI → Provider → Hive (instant) → Firebase (background)
2. **Load Bills**: Hive (instant) → UI, then Firebase sync → Hive → UI
3. **Offline**: All operations work with Hive, sync when online
4. **Conflict**: Server timestamp wins

## Key Features Implemented

✅ **Offline-First**: App works without internet
✅ **Auto-Sync**: Syncs every 5 minutes when online
✅ **Conflict Resolution**: Server wins on conflicts
✅ **Real-time Updates**: Optional Firestore listeners
✅ **Soft Deletes**: Bills marked as deleted, not removed
✅ **Multi-Device**: Sync across devices
✅ **Fast**: Local-first for instant UI updates

## Common Commands

```bash
# Install dependencies
flutter pub get

# Generate Hive adapters
flutter pub run build_runner build --delete-conflicting-outputs

# Watch for changes (auto-rebuild)
flutter pub run build_runner watch

# Configure Firebase
flutterfire configure

# Run app
flutter run

# Build for release
flutter build apk  # Android
flutter build ios  # iOS
flutter build web  # Web
```

## Troubleshooting

### "Target of URI hasn't been generated"
Run: `flutter pub run build_runner build --delete-conflicting-outputs`

### Firebase not initializing
- Check `firebase_options.dart` has correct credentials
- Verify `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) is in place

### Sync not working
- Check internet connection
- Verify user is authenticated
- Check Firestore rules allow access

### Build errors
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## Next Steps

1. Run `flutter pub get`
2. Run `flutter pub run build_runner build --delete-conflicting-outputs`
3. Run `flutterfire configure` (or manual setup)
4. Enable Authentication and Firestore in Firebase Console
5. Test the app!

## Files Created

- `lib/services/hive_service.dart` - Local storage operations
- `lib/services/firebase_service.dart` - Cloud operations
- `lib/services/sync_service.dart` - Synchronization logic
- `lib/providers/bill_provider.dart` - State management
- `lib/firebase_options.dart` - Firebase configuration (template)
- `lib/models/bill_hive.dart` - Already existed, ready for generation

## Support

If you encounter issues:
1. Check the error message carefully
2. Verify all setup steps completed
3. Check Firebase Console for service status
4. Review Firestore security rules
