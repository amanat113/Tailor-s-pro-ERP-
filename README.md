# Tailor's ERP - Complete Real Flutter Android App

A real Firebase-backed Flutter Android app for professional tailoring and garment shop management.

## What is included

- Real Firebase Mobile OTP login (no demo OTP)
- Secure PIN setup/login after OTP
- Owner / Manager / Staff role selection
- Auto logout: Owner/Manager 20 minutes, Staff 24 hours
- Dashboard with compact metrics and Recent Orders
- Manual slip number order creation
- Dynamic measurements from Settings
- Duplicate slip number validation
- PDF digital slip generation and share
- Firebase Storage slip upload service
- WhatsApp notification deep links
- Native call confirmation
- Cutting/processing per-cloth tracking
- Last-item cutting/ready notification trigger
- Partial delivery with delivery ledger
- Staff setup with stitch type price/rate
- Daily staff work ledger and all-time summary
- Analytics reports for Today / Month / Year / All Time
- Shop settings, measurement setup, stitch types
- JSON backup in Firestore backups collection
- Owner-protected data reset with CONFIRM
- GitHub Actions APK build workflow

## Required Firebase setup

1. Firebase Android app package name must be:

```text
com.tailors.erp
```

2. Download your Firebase config and place it exactly here:

```text
android/app/google-services.json
```

3. Firebase Console setup:

- Authentication -> Sign-in method -> Phone -> Enable
- Firestore Database -> Create database
- Storage -> Get started

4. Firestore rules for testing/current production base:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /shops/{shopId}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

5. Storage rules:

```js
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /shops/{shopId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

## Build with GitHub Actions

1. Upload this project to your GitHub repository root.
2. Upload `google-services.json` to `android/app/google-services.json`.
3. Open GitHub -> Actions -> Build Tailor's ERP Android APK -> Run workflow.
4. Download artifact `tailors-erp-debug-apk`.
5. Install `app-debug.apk` on Android.

## Local build

```bash
flutter create --platforms=android --project-name tailors_erp --org com.tailors .
flutter pub get
flutter build apk --debug
```

APK path:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Important OTP note

If real OTP does not arrive, add the APK's SHA-1/SHA-256 fingerprints in Firebase Project Settings -> Android App. This is required by Firebase Phone Auth on many Android builds.
