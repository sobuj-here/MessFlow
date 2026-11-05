<div align="center">

# 🏢 MessFlow

**The Ultimate Smart Mess & Hostel Management Ecosystem for Students and Bachelors**

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Version](https://img.shields.io/badge/Release-v2.1.2-brightgreen?style=for-the-badge)](https://github.com/sobuj-here/MessFlow/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

*Track daily meals, manage bazaar schedules, automate meal rates, calculate room rent, handle extra utilities, and archive fiscal months with single-click 24-hour restore.*

---

</div>

## 🌟 Key Highlights & Features

### 🍽️ 1. Daily Meal Tracker & Live Meal Rate
- **Automated Calculations:** Instant calculation of daily individual counts (Breakfast, Lunch, Dinner) and total mess meals.
- **Dynamic Meal Rate Engine:** Live meal rate recalculated continuously: `(Total Approved Bazaar Cost) ÷ (Total Meals)`.
- **Full Month Matrix:** Complete Day 1 to 31 meal chart breakdown for every member.

### 🛒 2. Bazaar Management & Duties
- **Duty Scheduling:** Manager can assign daily shopping duties to members with estimated budgets and custom item checklists.
- **Refund / Surplus Adjustment:** Support for negative amounts (`-৳500`) when shopping money is saved or returned.
- **Edit Audit & Alerts:** Any modified bazaar entry displays an `[EDITED]` badge and notifies all members automatically.

### 🏠 3. Room Rent & Utility Bills Sheet
- **Permanent Rent Persistence:** Fixed room rent per member is saved permanently across months—no need to re-enter monthly.
- **Dynamic Status Badges:** Visual badges showing **Paid (Green)**, **Partial Due (Yellow)**, or **Unpaid (Red)**.
- **Shared Utility Bills Breakdown:** Itemized utility records for House Rent, Maid, Gas, WiFi, and Electricity.

### 💳 4. Payments, Funds & Anti-Duplicate Protection
- **Multi-Method Support:** Built-in support for bKash, Nagad, Rocket, Upay, Bank Transfer, and Cash in Hand.
- **Double-Click Prevention:** Anti-spam debouncing and database-level guards prevent accidental double deductions.
- **Manager Balance Tracker:** Real-time visibility into the current meal fund balance and cash reserve.

### 🔒 5. Professional Month-End Fiscal Close (with 24h Undo)
- **Executive 2x2 Overview:** Clean metrics cards for Bazaar, Total Meals, Meal Rate, and Utility Bills before finalizing.
- **Session Chooser:** Choice cards to cleanly archive either the Previous Month or Current Month.
- **24-Hour Safety Grace:** Any closed month can be restored back to active state within 24 hours with a single click.

### 🌐 6. Native Multi-Language Localization
- Seamlessly localized with `easy_localization` across **5 languages**:
  - 🇺🇸 **English**
  - 🇧🇩 **বাংলা (Bangla)**
  - 🇮🇳 **हिन्दी (Hindi)**
  - 🇸🇦 **العربية (Arabic)**
  - 🇪🇸 **Español (Spanish)**
- Switch languages on-the-fly inside Settings with instantaneous full-widget re-rendering.

### 💬 7. Group Chat & System Push Notifications
- Integrated group chat for roommates with image and document sharing.
- Android system notifications categorized by specific notification channels (Bazaar, Meals, Payments, Rent, Notices).
- Duplicate notification suppression ensures no spam notifications.

---

## 🏗️ Architecture & Tech Stack

```
lib/
├── controllers/          # Application state controllers (Theme, Language)
├── screens/              # UI screens (Home, Meals, Bazaar, Rent, Chat, History)
│   ├── home_screen.dart
│   ├── meal_screen.dart
│   ├── add_bazaar_screen.dart
│   ├── room_rent_sheet_screen.dart
│   ├── payment_screen.dart
│   ├── history_screen.dart
│   ├── settings_screen.dart
│   └── group_chat_screen.dart
├── services/             # Core business logic & external APIs
│   ├── auth_service.dart
│   ├── auto_notification_service.dart
│   └── permission_service.dart
└── main.dart             # Entrypoint & localization initialization
```

- **Framework:** Flutter 3.24+ (Dart 3.5+)
- **State Management:** Reactive ValueNotifiers & ListenableBuilder
- **Backend / Database:** Cloud Firestore (Offline Persistence Enabled)
- **Authentication:** Firebase Auth (Email/Password & Google Sign-In)
- **Local Storage:** SharedPreferences
- **Localization:** EasyLocalization (JSON-based)
- **Media Uploads:** Cloudinary API

---

## 🚀 Getting Started

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.24 or higher)
- [Android Studio](https://developer.android.com/studio) or VS Code
- Java 17 LTS

### 2. Clone the Repository
```bash
git clone https://github.com/sobuj-here/MessFlow.git
cd MessFlow
```

### 3. Setup Firebase
> [!IMPORTANT]
> For security reasons, production Firebase credentials (`google-services.json`) are excluded from this repository.

1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project.
2. Enable **Authentication** (Email/Password & Google), **Cloud Firestore**, and **Cloud Storage**.
3. Register your Android app with package name: `com.example.messmate` (or your chosen ID).
4. Download your `google-services.json` file.
5. Place it inside the `android/app/` directory:
   ```bash
   cp path/to/your/google-services.json android/app/google-services.json
   ```
   *(See `android/app/google-services.json.example` for the required structure)*

### 4. Install Dependencies
```bash
flutter pub get
```

### 5. Run the Application
```bash
# Debug Mode
flutter run

# Release Build
flutter build apk --release --no-tree-shake-icons --android-skip-build-dependency-validation
```

The compiled APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📱 Releases & APK Download

You can download the pre-compiled, production-ready APK directly from the GitHub Releases page:
👉 **[Download Latest APK (v2.1.2)](https://github.com/sobuj-here/MessFlow/releases)**

---

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are always welcome!
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.

---

<div align="center">
  <sub>Developed with ❤️ for bachelor and student messes worldwide.</sub>
</div>
