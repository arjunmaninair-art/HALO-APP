# HALO-APP 🚨

HALO-APP is a comprehensive Flutter-based safety application featuring a real-time web tracking dashboard, location history breadcrumbs, and instant SOS signaling managed via Firebase.

---

## 🚀 Key Features

* **Real-Time SOS Dashboard:** Monitor location metrics dynamically via a clean web interface.
* **Location Breadcrumbs:** Visualizes chronological tracking data for enhanced search-and-rescue utility.
* **Cross-Platform Core:** Built using Flutter for consistent cross-device performance.
* **Secure Infrastructure Pipeline:** Decoupled environmental configurations to protect backend service integrations.

---

## 🛠️ Tech Stack

* **Frontend Framework:** Flutter (Web/Mobile)
* **Backend Services:** Firebase Realtime Database & Firebase Hosting
* **Web Rendering Engine:** Native HTML5/JavaScript & Leaflet.js / Google Maps API

---

## 🔒 Security & Architecture Setup

This repository uses an **Environment Variable Injection System** during the build phase. This prevents sensitive Firebase API keys from being exposed in the public Git history while keeping the deployed web client functional.

### Project Directory Layout
```text
halo_app/
│
├── .env                  # LOCAL ONLY (Contains raw credentials - Git Ignored)
├── .gitignore            # Explicitly blocks .env tracking
├── web/
│   └── map.html          # Source file containing secure tracking placeholders
└── build/web/
    └── map.html          # Compiled production file containing active injected keys


⚙️ Local Development & Deployment
1. Prerequisites
Ensure you have the Flutter SDK and Firebase CLI tools installed locally:

flutter upgrade
npm install -g firebase-tools
firebase login

2. Configure Local Environment
Create a .env file in the root directory (halo_app/.env) and add your Firebase credentials:

Code snippet
FIREBASE_API_KEY=YOUR_SECRET_KEY
FIREBASE_MESSAGING_SENDER_ID=YOUR_SENDER_ID
FIREBASE_APP_ID=YOUR_APP_ID

3. Build & Deploy Script
Do not deploy using standard firebase deploy. Use the matching automated script block below to compile the code and dynamically inject the .env variables into the production tracking map.

Windows (PowerShell):
flutter build web; $envFile = Resolve-Path .env; $envData = Get-Content $envFile -Raw | ConvertFrom-StringData; (Get-Content build/web/map.html) -replace '__FIREBASE_API_KEY__', $envData.FIREBASE_API_KEY -replace '__FIREBASE_MESSAGING_SENDER_ID__', $envData.FIREBASE_MESSAGING_SENDER_ID -replace '__FIREBASE_APP_ID__', $envData.FIREBASE_APP_ID | Set-Content build/web/map.html; firebase deploy


macOS / Linux (Bash):
flutter build web && export $(cat .env | xargs) && sed -i '' "s/__FIREBASE_API_KEY__/$FIREBASE_API_KEY/g" build/web/map.html && sed -i '' "s/__FIREBASE_MESSAGING_SENDER_ID__/$FIREBASE_MESSAGING_SENDER_ID/g" build/web/map.html && sed -i '' "s/__FIREBASE_APP_ID__/$FIREBASE_APP_ID/g" build/web/map.html && firebase deploy

