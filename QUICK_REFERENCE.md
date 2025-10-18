# 🚀 Quick Reference Card

## Essential Commands

```bash
# Run app
flutter run

# Clean build
flutter clean && flutter pub get && flutter run

# Generate Hive adapters
flutter pub run build_runner build --delete-conflicting-outputs

# Check for errors
flutter analyze

# Build release
flutter build apk  # Android
flutter build ios  # iOS
```

## Firebase Console Links

**Project**: bill-manager-3cdaf

- **Dashboard**: https://console.firebase.google.com/project/bill-manager-3cdaf
- **Authentication**: https://console.firebase.google.com/project/bill-manager-3cdaf/authentication/users
- **Firestore**: https://console.firebase.google.com/project/bill-manager-3cdaf/firestore/data
- **Rules**: https://console.firebase.google.com/project/bill-manager-3cdaf/firestore/rules

## Setup Checklist

### ✅ Completed
- [x] Firebase project created
- [x] Email/Password auth enabled
- [x] google-services.json added
- [x] Firebase plugins configured
- [x] Hive setup complete
- [x] Providers configured
- [x] Login screen updated
- [x] Sync service ready

### 🔄 To Do Now
- [ ] Apply Firestore security rules
- [ ] Run the app
- [ ] Create test account
- [ ] Test offline mode

## Apply Security Rules

1. Open: https://console.firebase.google.com/project/bill-manager-3cdaf/firestore/rules
2. Copy content from `firestore.rules` file
3. Paste in Firebase Console
4. Click "Publish"

## Test Your App

```bash
# 1. Run app
flutter run

# 2. Create account
Email: test@example.com
Password: test123456

# 3. Add bills
Click orange "+" button

# 4. Test offline
Turn off WiFi → Add bill → Turn on WiFi
```

## Architecture

```
UI → Provider → Hive (instant) + Firebase (background)
```

## Key Files

```
lib/
├── main.dart                    # Entry point
├── firebase_options.dart        # Firebase config
├── providers/
│   ├── auth_provider.dart      # Auth state
│   └── bill_provider.dart      # Bills state
├── services/
│   ├── hive_service.dart       # Local storage
│   ├── firebase_service.dart   # Cloud sync
│   └── sync_service.dart       # Auto-sync
└── screens/
    └── login_screen.dart       # Login with Firebase

firestore.rules                  # Security rules
```

## Troubleshooting

### App won't start
```bash
flutter clean
flutter pub get
flutter run
```

### Firebase errors
- Check google-services.json location
- Verify services enabled in console
- Check internet connection

### Sync not working
- Apply security rules
- Check user is logged in
- Verify internet connection

## Features

✅ Offline-first (Hive)
✅ Cloud sync (Firebase)
✅ Auto-sync every 5 min
✅ Email/Password auth
✅ Multi-device support
✅ Conflict resolution

## Next Steps

1. **Apply security rules** (see firestore.rules)
2. **Run**: `flutter run`
3. **Test**: Create account & add bills
4. **Deploy**: Build release when ready

## Support Files

- `READY_TO_RUN.md` - Complete setup guide
- `FIREBASE_RULES_SETUP.md` - Security rules guide
- `QUICK_START.md` - Getting started
- `firestore.rules` - Copy to Firebase Console

---

**You're ready to go! Run `flutter run` now! 🎉**
