# Android-to-Mac SMS Sync — Progress Tracker

> This file tracks the current state of the project across sessions.
> Update it after each session to maintain continuity.

---

## Current Status

**Phase**: Scaffold Complete — Ready for Integration Testing
**Last Updated**: 2026-08-26
**Next Step**: Build Android project in Android Studio, verify compilation, create Xcode project from Package.swift

---

## Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Android distribution | Sideloaded APK | Bypasses Play Store SMS restrictions |
| SMS access method | `READ_SMS` permission | Full historical access, allowed since sideloaded |
| Communication | WiFi local network | Fast, reliable |
| Discovery | mDNS/Bonjour | Automatic, no manual IP entry |
| Pairing | 6-digit PIN | Simple, secure enough for local use |
| Mac UI | Menu bar + full window | Quick access + full browsing |
| Contact names | Resolve from Mac contacts | Better UX |
| Sync scope | All historical + real-time new messages | Complete coverage |
| Sending | Read-only (V1) | Simpler, can add later |
| Mac app | Native Swift/SwiftUI | Best macOS integration |
| Android HTTP server | NanoHTTPD | Lightweight (~30KB) |
| Android language | Kotlin | Modern, concise |
| Mac storage | Core Data | Native, good for this scale |

---

## Build Progress

### Phase 1: Android App
| Step | Task | Status |
|------|------|--------|
| 1.1 | Android project setup + permissions | ✅ Done |
| 1.2 | SMS data model (`SmsMessage.kt`) | ✅ Done |
| 1.3 | SMS Reader (`SmsReader.kt`) | ✅ Done |
| 1.4 | Embedded HTTP server (`LocalServer.kt`) | ✅ Done |
| 1.5 | mDNS advertiser (`MdnsAdvertiser.kt`) | ✅ Done |
| 1.6 | ContentObserver for real-time (`SmsContentObserver.kt`) | 🔲 Not started |
| 1.7 | Auth manager (`AuthManager.kt`) | ✅ Done |
| 1.8 | Main activity | ✅ Done |

### Phase 2: Mac App — Discovery + Sync
| Step | Task | Status |
|------|------|--------|
| 2.1 | Xcode project setup | ✅ Done (Package.swift) |
| 2.2 | Bonjour discovery | ✅ Done |
| 2.3 | HTTP sync client | ✅ Done |
| 2.4 | WebSocket manager | ✅ Done |
| 2.5 | Pairing manager | ✅ Done |

### Phase 3: Mac App — Data Layer
| Step | Task | Status |
|------|------|--------|
| 3.1 | Core Data model | ✅ Done |
| 3.2 | Database manager | ✅ Done |
| 3.3 | Conversation model | ✅ Done |

### Phase 4: Mac App — Contact Resolution
| Step | Task | Status |
|------|------|--------|
| 4.1 | Contact resolver | ✅ Done |

### Phase 5: Mac App — UI
| Step | Task | Status |
|------|------|--------|
| 5.1 | App entry point | ✅ Done |
| 5.2 | Menu bar view | ✅ Done |
| 5.3 | Main window view | ✅ Done |
| 5.4 | Conversation list | ✅ Done |
| 5.5 | Message thread | ✅ Done |
| 5.6 | Settings view | ✅ Done |

---

## Session Log

### Session 1 — 2026-08-26
- Discussed project feasibility
- Researched Android SMS restrictions (Android 13+ default handler requirement)
- Evaluated communication methods (WiFi, Bluetooth, mDNS)
- Reviewed existing solutions (Bounce Connect, Droid2Mac, DesktopSMS)
- Finalized architecture decisions with user
- Wrote detailed implementation plan (PLAN.md)
- Created progress tracker (STATUS.md)
- **Status**: Planning complete, ready to build

### Session 2 — 2026-08-26
- Initialized git repo with .gitignore
- Created full project scaffold (35+ files)
- Android: MainActivity, SmsReader, LocalServer, MdnsAdvertiser, AuthManager, SmsMessage model
- Mac: Package.swift, SMSyncApp, ContentView, all services (Bonjour, HTTP client, WebSocket, Pairing, Contact resolver)
- Mac: All views (MenuBar, MainWindow, ConversationList, MessageThread, Settings)
- Mac: Core Data model + database manager + entities
- Created README.md and setup script
- **Status**: Scaffold complete, needs compilation testing and integration

---

## Open Questions / Notes

- None yet — all decisions finalized during planning session
