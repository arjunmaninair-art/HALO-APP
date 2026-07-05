# HALO-APP 🚨

HALO-APP is a comprehensive real-time emergency safety system combining a **Flutter mobile application** (integrated with an ESP32 BLE hardware button) and a **Leaflet-based web tracking dashboard** hosted on Firebase. 

It enables wearers to trigger instant alerts, send automated emergency SMS messages to their contacts containing a live tracking link, stream their live path trail to Firebase, and manage their emergency contacts with names directly from their phone.

---

## 🚀 Key Features

### 📱 Mobile Application (Flutter)
*   **Onboarding Access**: Secure **Email & Password login/registration** flow (Spark plan compatible, requiring no credit card).
*   **BLE Hardware Link**: Automatic BLE scanning and connection to the `ESP32_SOS_Button` module with crash-safe Bluetooth error handling.
*   **Robust Location Fetching**: Obtains high-accuracy GPS coordinates, falling back to the device's last known location after an 8-second timeout.
*   **Fail-Safe Emergency Loop**: Firebase database updates and SMS transmissions are isolated in separate try-catch blocks. If Firebase is offline or blocked, **critical emergency SMS alerts are guaranteed to send successfully** to contacts.
*   **Structured Contacts Manager**: Save names alongside phone numbers locally (persisted in `SharedPreferences` with legacy migration). Includes an **Inline Edit Dialog** to modify or assign names to existing phone numbers, and synchronizes numbers to the ESP32.

### 🌐 Live Web Tracker (`map.html` via Firebase Hosting)
*   **Real-Time Map Synchronization**: Connects to the database and tracks location dynamically using Leaflet.js and CartoDB Dark Matter dark-themed tiles.
*   **Satellite Imagery Toggle**: Features a floating glassmorphic button to switch instantly between the dark cartographic map and high-resolution satellite imagery (Esri World Imagery) for clear physical terrain visuals.
*   **Breadcrumb Path Trail**: Plots chronological dot markers indicating the wearer's path (newer markers are more opaque) connected by a dashed red polyline route.
*   **Pulsing State Markers**: Shows a pulsing red marker during an active emergency, which turns into a pulsing green marker when the alert is stopped.
*   **Complete Privacy Mode**: Once the alert is deactivated, the map tiles, location markers, and overlay stats panel are immediately wiped from memory and hidden from the screen, displaying a full-screen **"Wearer is Safe"** banner.
*   **Zero-Caching**: Configured with Cache-Control headers on Firebase Hosting to bypass browser caching, ensuring updates go live instantly.

---

## 🛠️ Tech Stack

*   **Frontend Mobile Framework**: Flutter (Android/iOS)
*   **Bluetooth Communications**: `flutter_blue_plus`
*   **Emergency SMS Gateway**: `another_telephony`
*   **Backend Serverless Services**: Firebase Auth & Firebase Realtime Database
*   **Web Hosting**: Firebase Hosting
*   **Web Maps Integration**: Leaflet.js (CartoDB Dark Matter tiles & Esri World Imagery)

---

## 🔒 Firebase Realtime Database Security Rules
The database is configured to allow read/write access specifically for active incident devices. Add these rules to your Firebase console or deploy them via `database.rules.json`:
```json
{
  "rules": {
    "active_incidents": {
      "$device_id": {
        ".read": "true",
        ".write": "true"
      }
    }
  }
}
```

---

## ⚙️ Local Development & Deployment

### 1. Prerequisites
Ensure you have the Flutter SDK, Android SDK (for phone deployment), and Firebase CLI tools installed:
```powershell
flutter upgrade
npm install -g firebase-tools
firebase login
```

### 2. Run the Mobile App
Plug in your Android device and execute the following in your root folder:
```powershell
flutter run
```

### 3. Deploy the Web Tracker
To deploy the tracking map webpage to Firebase Hosting, run:
```powershell
firebase deploy --only hosting --project halo-safety
```
*(The hosting configuration is defined in [firebase.json](file:///c:/Users/Arjun/halo_app/firebase.json) and deploys files located in the `public/` directory).*
