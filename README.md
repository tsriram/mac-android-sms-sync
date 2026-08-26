# SMSync — Android-to-Mac SMS Sync

Sync SMS messages from your Android phone to your Mac over local WiFi.

## How It Works

```
┌──────────────────┐       WiFi (mDNS + HTTP/WS)        ┌──────────────────┐
│   Android App    │ ◄─────────────────────────────────► │    Mac App       │
│   (Kotlin)       │       JSON over HTTP/WebSocket      │   (Swift/SwiftUI)│
│                  │                                     │                  │
│ • READ_SMS       │  1. mDNS advertise (_smsync._tcp.)  │ • Bonjour discover│
│ • HTTP server    │  2. Mac connects + PIN auth          │ • CoreData store │
│ • ContentObserver│  3. Batch sync all SMS              │ • Contact lookup  │
│ • mDNS broadcast │  4. Push new SMS via WebSocket      │ • Menu bar + Win  │
└──────────────────┘                                     └──────────────────┘
```

## Requirements

- **Android**: API 26+ (Android 8.0+), sideloaded APK
- **Mac**: macOS 13+, Xcode 15+

## Project Structure

```
mac-android-sms-sync/
├── android/              # Android project (Kotlin)
│   ├── app/src/main/java/com/smsync/
│   │   ├── MainActivity.kt
│   │   ├── SmsReader.kt
│   │   ├── LocalServer.kt
│   │   ├── MdnsAdvertiser.kt
│   │   ├── AuthManager.kt
│   │   └── models/SmsMessage.kt
│   └── build.gradle.kts
├── mac/                  # Xcode project (Swift)
│   ├── SMSync/
│   │   ├── SMSyncApp.swift
│   │   ├── Services/
│   │   ├── Models/
│   │   └── Views/
│   └── Package.swift
├── PLAN.md               # Implementation plan
├── STATUS.md             # Progress tracker
└── README.md
```

## Setup

### Android App

1. Open the `android/` folder in Android Studio
2. Let Gradle sync
3. Connect your Android device via USB
4. Enable Developer Options → USB Debugging
5. Run the app
6. Grant SMS permission when prompted
7. The app will show your device IP and wait for Mac to connect

### Mac App

1. Open `mac/Package.swift` in Xcode
2. Select your Mac as the build destination
3. Press Cmd+R to build and run
4. The app will appear in the menu bar
5. Click the icon → "Pair Device"
6. Enter the PIN shown on your Android app

## Usage

- **Menu bar icon**: Quick access to connection status and recent messages
- **Full window**: Click "Open Full Window" for conversations sidebar + message threads
- **Settings**: Manage paired devices, trigger manual sync
- **Real-time**: New SMS are pushed automatically when both devices are on the same network

## Privacy

- All data stays on your local network
- No cloud services, no internet required
- End-to-end: Android ↔ Mac direct connection
- No analytics, no tracking

## License

Private — personal use only.
