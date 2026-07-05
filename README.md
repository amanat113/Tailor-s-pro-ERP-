# Tailor's ERP

Professional Flutter Android app base for a real tailoring and garment management system.

## Phase 2A included

- Real Firebase Mobile OTP only; demo OTP is disabled
- Secure PIN setup and PIN login after OTP
- Owner / Manager / Staff role selection
- Owner and Manager inactivity auto-logout logic
- Staff 24-hour session policy
- Professional light premium UI rebuild
- Compact dashboard metrics
- Sidebar drawer with three-line menu
- Floating island bottom navigation
- Recent Orders section from real Cloud Firestore data
- Real new order creation to Firestore
- Duplicate slip number validation
- Real edit order bottom sheet
- Real call confirmation using Android phone dialer
- GitHub Actions APK build workflow

## Required Firebase setup

This app does not use fake/demo login. To login, configure Firebase Auth phone provider and Firestore.

Build with dart-define values:

```bash
flutter build apk --debug \
  --dart-define=FIREBASE_API_KEY=your_api_key \
  --dart-define=FIREBASE_APP_ID_ANDROID=your_android_app_id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your_sender_id \
  --dart-define=FIREBASE_PROJECT_ID=your_project_id \
  --dart-define=FIREBASE_STORAGE_BUCKET=your_storage_bucket
```

## Firestore path used

```text
shops/default_shop/orders
shops/default_shop/users
shops/default_shop/auditLogs
```

## Build locally

```bash
flutter pub get
flutter build apk --debug
```

APK path:

```text
build/app/outputs/flutter-apk/app-debug.apk
```
