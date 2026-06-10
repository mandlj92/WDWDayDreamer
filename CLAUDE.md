# WDWDayDreamer - Project Overview

## Executive Summary
WDWDayDreamer is an iOS application that enables Disney fans to share and collaborate on themed story experiences. It features a partnership system where two users can take turns writing interconnected stories, real-time notifications, user authentication, and comprehensive safety features including content moderation and user blocking.

**Tech Stack:**
- **Frontend:** SwiftUI (iOS app)
- **Backend:** Firebase (Firestore + Cloud Functions + Authentication)
- **Infrastructure:** Google Cloud (Cloud Functions, Firestore, Remote Config)

---

## Core Features

### 1. Authentication & User Management
- **Google Sign-In** integration via Firebase Auth
- **User Profiles** with customizable preferences
- **Session Management** - tracks active sessions per device
- **Privacy Controls** - profile visibility settings (private, connections-only, everyone)
- **User Blocking** - ability to block other users

**Key Files:**
- `Services/AuthViewModel.swift` - handles login/signup flow
- `Models/UserProfile.swift` - user data structure and preferences
- `Services/SessionManager.swift` - device session tracking

### 2. Partnership System
- **Pal Connections** - invite other users to form writing partnerships
- **Invitation System** - 6-character alphanumeric codes with 7-day expiration
- **Rate Limiting** - max 5 invitations per hour
- **Partnership Stories** - partners take turns writing stories
- **Turn-Based System** - ensures only assigned author can write their turn

**Key Files:**
- `Models/PalConnection.swift` - partnership data structures
- `Services/PalsService.swift` - partnership management logic
- `firestore.rules` - security rules for partnership access control

### 3. Story Creation & Management
- **Story Editor** - rich text editor for writing stories
- **Story Drafts** - auto-save drafts locally
- **Story Cards** - beautiful UI for displaying stories
- **Favorites System** - users can favorite stories
- **Legacy Data** - sharedStories collection (migration in progress)

**Key Files:**
- `Services/ScenarioManager.swift` (36KB) - core story management logic
- `Services/StoryDraftManager.swift` - draft persistence
- `CommonUI/StoryCardView.swift` - story display UI
- `WDWDaydreams/DataModel.swift` - story data structures

### 4. Notifications
- **Firebase Cloud Messaging (FCM)** - push notification delivery
- **Notification Queue** - client writes to queue, Cloud Functions processes
- **Custom Notifications** - in-app notification handling
- **Haptic Feedback** - tactile response system

**Key Files:**
- `Services/FCMService.swift` - FCM token management and setup
- `Services/NotificationManager.swift` - notification lifecycle
- `Utilities/Helpers/HapticManager.swift` - haptic feedback

### 5. Safety & Moderation
- **Content Reporting** - users can report inappropriate content
- **Moderation Queue** - Cloud Functions process reports
- **Blocked Users** - prevent interactions with blocked users
- **Security Incidents** - logging suspicious activity
- **App Check** - Firebase security validation (AppAttest for iOS 14+, DeviceCheck fallback)

**Key Files:**
- `Services/ModerationService.swift` - moderation workflow
- `Models/ContentReport.swift` - report structure
- `firestore.rules` - rule-based access control
- `WDWDaydreamsApp.swift` - App Check initialization

### 6. Theme & Customization
- **Dynamic Theming** - light/dark mode support
- **Design System** - consistent UI patterns

**Key Files:**
- `Theme.swift` - theme definitions
- `ThemeManager.swift` - theme state management
- `DesignSystem.swift` - UI constants and styles

---

## Architecture

### Firebase Firestore Schema

```
/users/{userId}
  ├── /private/{document}        # Sensitive data (FCM tokens, etc.)
  ├── /sessions/{sessionId}      # Device session tracking
  └── /blockedUsers/{blockedUserId}

/partnerships/{partnershipId}
  └── /stories/{storyId}         # Stories written by partners

/palInvitations/{invitationId}   # Partnership invitations

/userStories/{userId}/{collection}/{storyId}  # Favorites & personal collections

/userSettings/{userId}           # User preferences

/notificationQueue/{queueId}     # Notifications (processed by Cloud Functions)

/contentReports/{reportId}       # User-submitted content reports

/moderationQueue/{queueId}       # Reports awaiting moderation (admin only)

/securityIncidents/{incidentId}  # Security event logs (admin only)

/sharedStories/{storyId}         # Legacy data (deprecated, read-only)

/connectionTest/{userId}         # Debug connection validation
```

### Firestore Security Rules
- **Authentication-based access control** - all operations require authenticated user
- **Ownership validation** - users can only modify their own data
- **Partnership verification** - partners verified before story access
- **Immutable fields** - key fields (authorship, codes) cannot be changed
- **Timestamp validation** - prevents client timestamp manipulation
- **Rate limiting** - invitation creation limited to 5/hour
- **Field validation** - required fields must be present and valid

### Cloud Functions (Firebase)
Located in `functions/index.js` - handles:
- Partnership creation workflows
- Notification processing and delivery
- Content moderation processing
- User data cleanup on deletion
- Security incident logging

**Stack:** Node.js 18, firebase-admin ^12.0.0, firebase-functions ^5.0.0

---

## Key Services

| Service | Purpose |
|---------|---------|
| `AuthViewModel` | Authentication state & login flow |
| `FirebaseDataService` | Firestore read/write operations (33KB) |
| `PalsService` | Partnership management |
| `FCMService` | Push notification setup & token management |
| `SessionManager` | Device session tracking |
| `UserService` | User profile operations |
| `ModerationService` | Content moderation workflow |
| `DataExportService` | User data export (GDPR) |
| `AnalyticsService` | Event tracking |
| `StoryDraftManager` | Local draft persistence |

---

## UI Components

| Component | Purpose |
|-----------|---------|
| `StoryCardView` | Displays individual story with metadata |
| `SkeletonViews` | Loading placeholders for smooth UX |
| `DesignSystem` | Centralized color/spacing constants |
| `UIFeedbackCenter` | Haptic feedback and toast notifications |

---

## Configuration & Setup

### Environment
- **Firebase Project:** wdwdaydreams-e4e4e
- **iOS Target Deployment:** iOS 14+ (AppAttest), fallback iOS 13 (DeviceCheck)
- **Firestore Cache:** 10MB (reduced from 50MB for security)
- **Remote Config:** Used for feature flags and A/B testing

### Files
- `.firebaserc` - Firebase project mapping
- `firebase.json` - Functions deployment config
- `firestore.rules` - Database security rules
- `firestore.indexes.json` - Custom Firestore indexes

---

## Security Features

1. **App Check** - Validates app is legitimate (anti-abuse)
2. **Rule-based Access Control** - Fine-grained Firestore security rules
3. **Authentication Required** - All user data protected
4. **Encrypted Cache** - Firestore cache protected via iOS Data Protection
5. **Content Moderation** - User reports + admin review
6. **User Blocking** - Prevent unwanted interactions
7. **Timestamp Validation** - Prevent client time manipulation
8. **Field Immutability** - Critical fields cannot be modified
9. **Security Incident Logging** - Track suspicious activity

---

## Testing

**Test Suites:**
- `WDWDaydreamsTests/` - Unit tests
- `WDWDaydreamsUITests/` - UI/integration tests

---

## Development Workflow

### Local Development (Emulator-first)
```bash
# Start the full Firebase Emulator Suite (Auth :9099, Firestore :8080, Functions :5001, UI :4000)
npx firebase-tools emulators:start

# Seed content packs into the emulator
npm --prefix scripts run seed

# Run the web app against the emulators (NEXT_PUBLIC_USE_EMULATORS=true in web/.env.local)
npm --prefix web run dev

# Test on other devices over LAN
npm --prefix web run dev:lan
```

### Web App (`web/`)
Next.js 15 + TypeScript + Tailwind v4 + Firebase Web SDK. Shares the same Firestore backend and security rules as iOS. Field names in `web/lib/types.ts` must stay identical to the iOS serialization in `FirebaseDataService.swift` (`date`, `authorId`, `authorName`, `items`, `text`). Copy `web/.env.local.example` to `web/.env.local`; emulator mode needs no real keys, production needs a web app registered in the Firebase console.

### Content Packs
Prompt content (parks, rides, food, etc.) lives in Firestore `/contentPacks/{packId}`, seeded from `scripts/content-packs/*.json` via `scripts/seed-content.mjs`. Clients are read-only. On iOS, `Services/RemoteContentService.swift` listens for the pack and falls back to the hardcoded `DataModel.swift` lists when offline/unavailable. **Note:** `RemoteContentService.swift` must be added to the Xcode target manually (created outside Xcode).

### Deployment
```bash
# Deploy Cloud Functions
npm --prefix functions run deploy
```

### View Logs
```bash
firebase functions:log
```

---

## Known Issues & TODOs

- **Migration in Progress:** Legacy `sharedStories` collection is deprecated. New code should use `partnerships/*/stories` instead.
- **Firestore Rules Limitations:** Direct query-based rate limiting not supported in rules; validation done client-side with timestamp validation.
- **Remote Config:** Currently uses empty defaults; can be enhanced for feature flags.

---

## Common Tasks

### Adding a New Feature
1. Define data model in `Models/`
2. Create service in `Services/` for business logic
3. Add Firestore rules to `firestore.rules`
4. Create UI component in `CommonUI/` or main app
5. Update `FirebaseDataService` if new Firestore collection

### Debugging Firestore
- Check `firestore.rules` for access denial
- Verify user authentication state in `AuthViewModel`
- Review Firestore logs in Firebase Console
- Use `connectionTest/{userId}` collection for diagnostics

### Adding New Moderation Rules
1. Update moderation logic in `Services/ModerationService.swift`
2. Add new report reasons in `Models/ContentReport.swift`
3. Update Cloud Function handlers in `functions/index.js`
4. Test with test data before production deployment

---

## Project Structure
```
WDWDayDreamer/
├── WDWDaydreams/              # Main app source
│   ├── CommonUI/              # Reusable UI components
│   ├── Models/                # Data structures
│   ├── Services/              # Business logic & API
│   ├── Utilities/             # Helpers & extensions
│   ├── WDWDaydreamsApp.swift  # App entry point
│   ├── Theme.swift            # Theme definitions
│   └── DataModel.swift        # App-wide data structures
├── WDWDaydreamsTests/         # Unit tests
├── WDWDaydreamsUITests/       # UI tests
├── functions/                 # Cloud Functions (Node.js)
│   ├── index.js               # All Cloud Functions
│   └── package.json
├── firestore.rules            # Security rules
├── firestore.indexes.json      # Firestore indexes
├── firebase.json              # Firebase config
└── .firebaserc                # Firebase project mapping
```

---

## Contact & Questions
For questions about the codebase architecture or specific features, refer to the file paths listed above or the commit history for implementation details.
