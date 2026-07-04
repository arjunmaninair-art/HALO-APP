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
