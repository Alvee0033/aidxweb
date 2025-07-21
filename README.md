# Aidx - Health Assistant App

This is a Flutter version of the Aidx health assistant app, a comprehensive health monitoring solution with wearable device integration.

## Features

- **User Authentication**: Email/password login and registration with Firebase Auth
- **Dashboard**: Overview of health metrics and feature cards
- **Health News**: Regional health news updates
- **Wearable Integration**: Connect to BLE devices for heart rate and SpO2 monitoring
- **Emergency SOS**: One-tap emergency alert with auto-dispatch based on abnormal vitals
- **User Profile**: Editable user information

## Project Structure

The Flutter project is organized as follows:

```
lib/
├── main.dart          # App entry point with routes
├── models/            # Data models
│   ├── news_model.dart
│   └── user_model.dart
├── screens/           # UI screens
│   ├── auth/          # Authentication screens
│   │   └── login_screen.dart
│   ├── dashboard_screen.dart
│   ├── profile_screen.dart
│   ├── wearable_screen.dart
│   ├── sos_screen.dart
│   └── splash_screen.dart
├── services/          # Business logic and services
│   ├── auth_service.dart
│   ├── bluetooth_service.dart
│   └── news_service.dart
├── utils/            # Utilities and helpers
│   ├── constants.dart
│   └── theme.dart
└── widgets/          # Reusable UI components
    ├── glass_container.dart
    ├── feature_card.dart
    └── news_card.dart
```

## Getting Started

### Prerequisites

- Flutter SDK (version 3.0.0 or higher)
- Dart SDK (version 2.17.0 or higher)
- Firebase account
- Android Studio / VS Code with Flutter extensions

### Installation

1. Clone the repository
```bash
git clone https://github.com/Alvee0033/aidx.git
cd aidx/flutter
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the app
```bash
flutter run
```

## Bluetooth Functionality

The app uses `flutter_blue_plus` to connect to BLE devices. For the ESP32-based blood oximeter, ensure your device advertises the following services:
- Heart Rate Service UUID: 0000180d-0000-1000-8000-00805f9b34fb
- SpO2 Service UUID: 00001822-0000-1000-8000-00805f9b34fb

## Firebase Configuration

The app uses Firebase for authentication and Firestore for data storage. Make sure to update the Firebase configuration in `main.dart` with your own Firebase project details.

## Implementation Notes

1. **Glass Effect UI**: The app uses a custom `GlassContainer` widget to create frosted glass effects consistent with the web app's design.

2. **Auto SOS Feature**: The Emergency SOS screen includes an automatic dispatch feature that monitors vital signs and triggers an emergency countdown when abnormal readings persist for 30 seconds.

3. **News Integration**: The app fetches regional health news using the News API, with support for country detection.

4. **Wearable Connection**: The Bluetooth service handles device scanning, connection, and real-time data streaming from wearable devices.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
