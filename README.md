# Tailor's ERP PWA Logic Fixed R3

This is a clean PWA build. Upload these root files to GitHub Pages:

- index.html
- styles.css
- app.js
- manifest.json
- sw.js

Main fixes:
- Delivery is blocked until items are marked Ready in Processing.
- New Order fields are blank/select-only. No fake default quantity or bill.
- Measurements come only from Settings.
- Staff name is saved separately.
- Staff cloth type/rate setup is in Settings.
- Staff daily work auto-calculates based on type rate × quantity.
- PDF slip is generated as a real PDF Blob and shared via Web Share API where supported; otherwise it downloads.
- Search boxes have clear buttons and state is separated by screen.
- Daily login uses Firebase session + PIN; OTP is only for first login/new device/logout.
