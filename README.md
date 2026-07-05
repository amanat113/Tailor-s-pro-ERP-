# Tailor's ERP — Complete Real Flutter App

This project is rebuilt from zero for a real Android Flutter app with Firebase OTP, Firestore cloud database, PIN login, orders, processing, partial delivery, staff ledger, PDF slip, WhatsApp notifications, analytics-ready data, settings, backup, data reset protection, and GitHub Actions APK build.

## Important

This app has no demo OTP. Real login needs:

1. Firebase Android app package name: `com.tailors.erp`
2. `google-services.json`
3. Firebase Authentication → Phone enabled
4. Firestore Database created
5. Firebase Storage created

## Upload to GitHub from Codespaces

Upload these two files to the Codespaces root:

- `tailors_erp_zero_real_complete.zip`
- `google-services (1).json` or `google-services.json`

Then run:

```bash
mkdir -p /tmp/tailors_zero_upload
mv -f tailors_erp_zero_real_complete.zip /tmp/tailors_zero_upload/app.zip
if [ -f "google-services (1).json" ]; then mv -f "google-services (1).json" /tmp/tailors_zero_upload/google-services.json; fi
if [ -f "google-services.json" ]; then mv -f "google-services.json" /tmp/tailors_zero_upload/google-services.json; fi
find . -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} +
unzip -o /tmp/tailors_zero_upload/app.zip
cp -f /tmp/tailors_zero_upload/google-services.json google-services.json
mkdir -p android/app
cp -f /tmp/tailors_zero_upload/google-services.json android/app/google-services.json
git add .
git commit -m "Rebuild complete real Tailor's ERP app from zero"
git push
```

## Build APK

GitHub → Actions → Build Tailor's ERP Android APK → Run workflow.

Download artifact: `tailors-erp-debug-apk` → install `app-debug.apk`.

## Firestore Rules for first real version

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

## Firebase Phone OTP note

If OTP does not arrive, add the Android debug SHA-1/SHA-256 fingerprint in Firebase Project Settings → Android app → SHA certificate fingerprints, then download a fresh `google-services.json` and rebuild.
