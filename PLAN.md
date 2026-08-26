# Android-to-Mac SMS Sync — Implementation Plan

## Overview

A two-app system that syncs SMS messages from an Android phone to a native Mac app over local WiFi. The Android app is sideloaded (not on Play Store), giving full `READ_SMS` access. The Mac app is native Swift/SwiftUI with a menu bar + full window UI.

**Core flow**: Android advertises via mDNS → Mac discovers → PIN pairing → batch sync all historical SMS → real-time push of new messages via WebSocket.

---

## Architecture

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

---

## Project Structure

```
mac-android-sms-sync/
├── PLAN.md
├── STATUS.md
├── .gitignore
├── android/                          # Android project (Kotlin)
│   ├── app/
│   │   ├── build.gradle.kts
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── java/com/smsync/
│   │           ├── MainActivity.kt           # UI + permission handling
│   │           ├── SmsReader.kt              # ContentResolver queries
│   │           ├── LocalServer.kt            # Embedded HTTP server (NanoHTTPD)
│   │           ├── WebSocketHandler.kt       # Real-time push to Mac
│   │           ├── MdnsAdvertiser.kt         # NsdManager mDNS broadcast
│   │           ├── SmsContentObserver.kt     # Watches for new SMS
│   │           ├── AuthManager.kt            # PIN pairing + device auth
│   │           └── models/
│   │               └── SmsMessage.kt         # Data class for SMS JSON
│   ├── build.gradle.kts                      # Project-level build file
│   └── settings.gradle.kts
├── mac/                              # Xcode project (Swift)
│   ├── SMSync.xcodeproj
│   └── SMSync/
│       ├── SMSyncApp.swift                    # App entry point, menu bar setup
│       ├── Services/
│       │   ├── BonjourDiscovery.swift         # NetServiceBrowser for mDNS
│       │   ├── SMSSyncClient.swift            # HTTP client for initial sync
│       │   ├── WebSocketManager.swift         # WebSocket for real-time push
│       │   ├── ContactResolver.swift          # CNContactStore phone→name
│       │   └── PairingManager.swift           # PIN auth + device trust
│       ├── Models/
│       │   ├── SMSMessage.swift               # Core Data entity
│       │   ├── Conversation.swift             # Derived conversation model
│       │   ├── SyncState.swift                # Last sync timestamp, device info
│       │   └── SMSDatabase.swift              # Core Data stack + CRUD ops
│       ├── Views/
│       │   ├── MenuBarView.swift              # NSStatusItem popover
│       │   ├── MainWindowView.swift           # Full window with sidebar
│       │   ├── ConversationListView.swift     # Sidebar: all conversations
│       │   ├── MessageThreadView.swift        # Individual thread messages
│       │   ├── SettingsView.swift             # Connection, pairing, sync controls
│       │   └── ConnectionStatusView.swift     # Connected/disconnected indicator
│       └── Resources/
│           └── SMSync.xcdatamodeld           # Core Data model
```

---

## Phase 1: Android App — SMS Reader + HTTP Server

### Step 1.1: Project Setup
- Create Android project with Kotlin, min SDK 26, target SDK 34
- Add permissions to `AndroidManifest.xml`:
  - `android.permission.READ_SMS`
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_NETWORK_STATE`
  - `android.permission.ACCESS_WIFI_STATE`
- Add dependencies:
  - `org.nanohttpd:nanohttpd:2.3.1` (embedded HTTP server)

### Step 1.2: SMS Data Model
**File**: `models/SmsMessage.kt`
```kotlin
data class SmsMessage(
    val id: Long,
    val address: String,      // Phone number
    val body: String,         // Message text
    val date: Long,           // Timestamp in millis
    val type: Int,            // 1=inbox, 2=sent, 3=draft, etc.
    val read: Boolean
)
```

### Step 1.3: SMS Reader
**File**: `SmsReader.kt`
- Query `content://sms` via `ContentResolver`
- Return all messages sorted by date descending
- Support pagination: `?offset=0&limit=500` for batched transfer
- Support `?since=<timestamp>` for delta sync
- Columns: `_id`, `address`, `body`, `date`, `type`, `read`

### Step 1.4: Embedded HTTP Server
**File**: `LocalServer.kt`
- NanoHTTPD on port `8484`
- Endpoints:
  - `GET /api/sms` — All SMS (paginated via query params)
  - `GET /api/sms?since=<ts>` — SMS since timestamp
  - `GET /api/info` — Device info (name, SMS count, last message timestamp)
  - `GET /api/pair?pin=<pin>` — Pair with Mac (validates PIN)
  - `GET /api/pair/init` — Generate pairing PIN
- CORS headers for local access
- JSON responses using `org.json` (Android built-in)

### Step 1.5: mDNS Advertiser
**File**: `MdnsAdvertiser.kt`
- Use `android.net.nsd.NsdManager`
- Service type: `_smsync._tcp.`
- Service name: device model or user-configured name
- Register on app start, deregister on stop

### Step 1.6: Real-Time ContentObserver
**File**: `SmsContentObserver.kt`
- Register `ContentObserver` on `content://sms`
- On new SMS detected: serialize to JSON, push to all connected WebSocket clients
- Debounce: batch pushes if multiple SMS arrive rapidly (100ms window)

### Step 1.7: Auth Manager
**File**: `AuthManager.kt`
- Generate 6-digit PIN for pairing
- Store paired Mac device IDs in `SharedPreferences`
- Validate incoming connections against stored device list
- Auto-accept connections from already-paired devices

### Step 1.8: MainActivity
**File**: `MainActivity.kt`
- Request `READ_SMS` runtime permission
- Start HTTP server + mDNS on permission granted
- Show connection status (IP, paired devices, connected clients)
- Keep service running in foreground (notification required on Android 8+)

---

## Phase 2: Mac App — Discovery + Sync Client

### Step 2.1: Xcode Project Setup
- Create macOS app project, Swift, SwiftUI lifecycle
- Deployment target: macOS 13+
- Info.plist: `NSContactsUsageDescription` for contact resolution

### Step 2.2: Bonjour Discovery
**File**: `Services/BonjourDiscovery.swift`
- `NetServiceBrowser` searching for `_smsync._tcp.`
- Resolve service to IP + port
- Auto-reconnect on network changes (`NWPathMonitor`)
- Publish discovered devices as `@Published` for SwiftUI binding

### Step 2.3: HTTP Sync Client
**File**: `Services/SMSSyncClient.swift`
- `URLSession` based HTTP client
- Base URL from discovered mDNS service
- Methods:
  - `fetchAllSMS(offset: Int, limit: Int) async throws -> [SMSMessageJSON]`
  - `fetchSMSSince(timestamp: Int64) async throws -> [SMSMessageJSON]`
  - `fetchDeviceInfo() async throws -> DeviceInfo`
  - `initPairing(pin: String) async throws -> Bool`
- Retry logic with exponential backoff

### Step 2.4: WebSocket Manager
**File**: `Services/WebSocketManager.swift`
- `URLSessionWebSocketTask` for real-time connection
- Connect after successful pairing
- Receive new SMS JSON, insert into Core Data
- Auto-reconnect on disconnect
- Heartbeat ping every 30s

### Step 2.5: Pairing Manager
**File**: `Services/PairingManager.swift`
- Generate and display 6-digit PIN
- Send PIN to Android `/api/pair` endpoint
- Store paired device ID in Keychain
- Check pairing status on app launch

---

## Phase 3: Mac App — Data Layer

### Step 3.1: Core Data Model
**File**: `Resources/SMSync.xcdatamodeld`

**Entities**:

`SMSMessage`:
| Attribute | Type | Notes |
|-----------|------|-------|
| `id` | Integer 64 | Android SMS `_id` |
| `address` | String | Phone number |
| `body` | String | Message text |
| `date` | Date | Message timestamp |
| `type` | Integer 16 | 1=inbox, 2=sent |
| `read` | Boolean | Read status |
| `contactName` | String? | Resolved name (nullable) |
| `threadHash` | String | Hash of sorted addresses for grouping |

`SyncState`:
| Attribute | Type | Notes |
|-----------|------|-------|
| `deviceID` | String | Paired Android device ID |
| `lastSyncTimestamp` | Date | Last successful sync time |
| `pairedAt` | Date | When pairing occurred |
| `totalSynced` | Integer 64 | Count of synced messages |

### Step 3.2: Database Manager
**File**: `Models/SMSDatabase.swift`
- Core Data stack with `NSPersistentContainer`
- CRUD operations:
  - `insertMessages(_ messages: [SMSMessageJSON])` — batch insert, dedup by `id`
  - `fetchConversations() -> [Conversation]` — grouped by thread
  - `fetchMessages(for thread: String) -> [SMSMessage]` — messages in thread
  - `updateContactNames()` — re-resolve all phone numbers
- Background context for sync, main context for UI

### Step 3.3: Conversation Model
**File**: `Models/Conversation.swift`
- Derived from grouping `SMSMessage` by `threadHash`
- `threadHash` = SHA256 of sorted phone numbers in conversation
- Properties: `id`, `contactName`, `lastMessage`, `lastMessageDate`, `unreadCount`, `messages`

---

## Phase 4: Mac App — Contact Resolution

### Step 4.1: Contact Resolver
**File**: `Services/ContactResolver.swift`
- Use `CNContactStore` to fetch all contacts with phone numbers
- Build lookup dictionary: `[String: String]` (phone number → name)
- Normalize phone numbers: strip `+`, ` `, `-`, `(`, `)` for matching
- Match by suffix (last 10 digits) to handle country code variations
- Run on background queue, update Core Data `contactName` field
- Re-run periodically or on contacts change notification

---

## Phase 5: Mac App — UI

### Step 5.1: App Entry Point
**File**: `SMSyncApp.swift`
- `@main` App with `MenuBarExtra` (menu bar) and `WindowGroup` (full window)
- Menu bar: icon + unread count badge
- Full window: conversations sidebar + message thread

### Step 5.2: Menu Bar View
**File**: `Views/MenuBarView.swift`
- `NSStatusItem` with SF Symbol icon (`message.fill`)
- Badge showing unread count
- Popover showing:
  - Connection status (green/red dot)
  - Last sync time
  - Recent messages (last 5)
  - "Open Full Window" button
  - "Sync Now" button
  - "Settings" link

### Step 5.3: Main Window View
**File**: `Views/MainWindowView.swift`
- `NavigationSplitView` with sidebar + detail
- Sidebar: `ConversationListView`
- Detail: `MessageThreadView` or placeholder

### Step 5.4: Conversation List
**File**: `Views/ConversationListView.swift`
- List of conversations sorted by last message date (newest first)
- Each row: contact name (or phone number), last message preview, timestamp
- Search bar to filter conversations
- Click to select → shows thread in detail

### Step 5.5: Message Thread
**File**: `Views/MessageThreadView.swift`
- Messages sorted by date ascending
- Each message: bubble (blue for sent, gray for received), text, timestamp
- Incoming messages aligned left, outgoing aligned right
- Scroll to bottom on load, lazy loading for large threads

### Step 5.6: Settings View
**File**: `Views/SettingsView.swift`
- Connection section:
  - Paired device name + status
  - "Pair New Device" flow (shows PIN, waiting for Android to connect)
  - "Unpair" button
- Sync section:
  - Last sync time
  - Total messages synced
  - "Sync Now" button
- About section:
  - Version, privacy note ("all data stays on local network")

---

## API Contract

### HTTP Endpoints (Android → Mac)

**`GET /api/info`**
```json
{
  "deviceName": "Pixel 7",
  "totalSMS": 12345,
  "lastMessageTimestamp": 1693000000000,
  "version": "1.0"
}
```

**`GET /api/pair/init`**
```json
{
  "pin": "482916",
  "expiresIn": 120
}
```

**`GET /api/pair?pin=482916`**
```json
{
  "paired": true,
  "deviceToken": "abc123..."
}
```

**`GET /api/sms?offset=0&limit=500`**
```json
{
  "messages": [
    {
      "id": 12345,
      "address": "+15551234567",
      "body": "Hello!",
      "date": 1693000000000,
      "type": 1,
      "read": true
    }
  ],
  "total": 12345,
  "hasMore": true
}
```

**`GET /api/sms?since=1693000000000`**
```json
{
  "messages": [...],
  "count": 3
}
```

### WebSocket Messages (Android → Mac)

**New SMS push**:
```json
{
  "event": "new_sms",
  "data": {
    "id": 12346,
    "address": "+15559876543",
    "body": "Meeting at 3pm",
    "date": 1693001000000,
    "type": 1,
    "read": false
  }
}
```

**Heartbeat**:
```json
{ "event": "ping" }
```

---

## Build Order

| Step | Component | Depends On | Testable Alone |
|------|-----------|------------|----------------|
| 1 | Android project setup + permissions | — | Yes (install on phone) |
| 2 | `SmsReader` — query all SMS | Step 1 | Yes (unit test) |
| 3 | `LocalServer` — HTTP endpoints | Step 2 | Yes (curl from Mac) |
| 4 | `MdnsAdvertiser` — mDNS broadcast | Step 1 | Yes (Bonjour browser) |
| 5 | `SmsContentObserver` — real-time watch | Step 2 | Yes (send SMS, check logs) |
| 6 | `WebSocketHandler` — push new SMS | Step 3, 5 | Yes (wscat client) |
| 7 | `AuthManager` — PIN pairing | Step 3 | Yes (manual PIN test) |
| 8 | Mac project setup | — | Yes (builds) |
| 9 | `BonjourDiscovery` — find Android | Step 4, 8 | Yes (shows discovered service) |
| 10 | `SMSSyncClient` — HTTP fetch | Step 3, 9 | Yes (fetches JSON) |
| 11 | Core Data model + `SMSDatabase` | Step 8 | Yes (unit test) |
| 12 | Historical sync flow | Step 10, 11 | Yes (full sync works) |
| 13 | `PairingManager` — PIN auth | Step 7, 9 | Yes (pairing flow works) |
| 14 | `WebSocketManager` — real-time | Step 6, 12 | Yes (new SMS appears) |
| 15 | `ContactResolver` — name lookup | Step 11 | Yes (names resolve) |
| 16 | `MenuBarView` — menu bar UI | Step 12 | Yes (shows in menu bar) |
| 17 | `ConversationListView` — sidebar | Step 11, 15 | Yes (shows conversations) |
| 18 | `MessageThreadView` — thread UI | Step 17 | Yes (shows messages) |
| 19 | `SettingsView` — settings UI | Step 13 | Yes (pairing flow in UI) |
| 20 | `MainWindowView` — full window | Step 16-19 | Yes (complete app) |

**Parallel track**: Steps 1-7 (Android) and Steps 8-11 (Mac core) can be built simultaneously.

---

## Dependencies

### Android
| Library | Purpose | Size |
|---------|---------|------|
| NanoHTTPD | Embedded HTTP server | ~30KB |
| AndroidX Core KTX | Kotlin extensions | Built-in |
| NsdManager | mDNS (Android built-in) | — |
| ContentObserver | SMS watcher (Android built-in) | — |
| org.json | JSON serialization (Android built-in) | — |

### Mac
| Framework | Purpose |
|-----------|---------|
| SwiftUI | UI framework |
| Combine | Reactive data flow |
| Network.framework | mDNS + NWConnection |
| CoreData | Local persistence |
| Contacts | Contact name resolution |
| CryptoKit | PIN/device token hashing |

No external dependencies required — everything uses Apple frameworks.

---

## Security Considerations

- **Local network only**: No cloud, no internet required
- **PIN pairing**: 6-digit PIN prevents unauthorized devices
- **Device fingerprinting**: Store paired device IDs to auto-accept future connections
- **No message content logging**: Avoid logging SMS body in production
- **Optional TLS**: Could add self-signed cert for encrypted WiFi traffic (phase 2 enhancement)

---

## Future Enhancements (Not in V1)

- Send SMS from Mac
- MMS/photo message support
- Notification mirroring (all Android notifications)
- Bluetooth fallback when not on same WiFi
- End-to-end encryption (TLS with certificate pinning)
- Multiple Android device support
- Message search across all conversations
- Export to macOS Messages.app
