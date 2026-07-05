# Tailor's ERP

Professional Flutter Android app base for a tailoring and garment management system.

## Phase 1 included

- Mobile OTP login flow with offline demo fallback
- Secure PIN setup and PIN login
- Owner / Manager / Staff role selection
- Owner and Manager inactivity auto-logout logic
- Staff 24-hour session policy
- Firebase-ready architecture
- Offline-first local storage fallback
- Professional dark mobile dashboard UI
- GitHub Actions APK build workflow
- Codemagic APK build workflow

## Demo login without Firebase

- Mobile: any valid 10 digit number
- OTP: `123456`
- PIN: any 4 to 8 digit PIN
- Role: Owner / Manager / Staff

## Build locally

```bash
flutter pub get
flutter build apk --release
```

The APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## GitHub Actions build

Open the repository in GitHub:

1. Go to **Actions**
2. Open **Build Tailor's ERP Android APK**
3. Tap **Run workflow**
4. Download artifact: `tailors-erp-release-apk`

## Firebase dart-define config later

The app runs without Firebase in offline demo mode. Later, pass Firebase values using `--dart-define` keys:

```bash
flutter build apk --release \
  --dart-define=FIREBASE_API_KEY=your_api_key \
  --dart-define=FIREBASE_APP_ID_ANDROID=your_android_app_id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your_sender_id \
  --dart-define=FIREBASE_PROJECT_ID=your_project_id \
  --dart-define=FIREBASE_STORAGE_BUCKET=your_storage_bucket
```
