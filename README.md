# WDWDayDreamer

WDWDayDreamer is a SwiftUI and Firebase application for creating and sharing Disney-inspired daydream stories with a writing partner. The repository also contains a Next.js web client, Firebase Cloud Functions, Firestore rules, and content-seeding scripts.

## Repository structure

- `WDWDaydreams/` — iOS application
- `WDWDaydreamsTests/` — unit-test target
- `WDWDaydreamsUITests/` — UI-test target
- `functions/` — Firebase Cloud Functions
- `web/` — Next.js web application
- `scripts/` — content-pack seeding utilities
- `firestore.rules` — Firestore authorization and validation
- `firestore.indexes.json` — Firestore indexes

## Local development

### Firebase Emulator Suite

```bash
npx firebase-tools emulators:start
```

The configured local services are:

- Authentication: `9099`
- Firestore: `8080`
- Functions: `5001`
- Emulator UI: `4000`

### Seed prompt content

```bash
npm --prefix scripts install
npm --prefix scripts run seed
```

### Run the web application

```bash
cp web/.env.local.example web/.env.local
npm --prefix web install
npm --prefix web run dev
```

### Run the iOS application

1. Open `WDWDaydreams.xcodeproj` in Xcode.
2. Confirm `GoogleService-Info.plist` is present in the application target.
3. Select an iOS simulator or registered device.
4. Build and run.

Do not commit production service-account credentials, APNs private keys, `.env.local`, or other private secrets.

## Security model

Firestore rules are the primary authorization boundary for client access. Cloud Functions run with administrative privileges and must independently validate all user-controlled identifiers before performing privileged work.

Important constraints:

- Partnership membership fields are immutable after creation.
- Partnership documents use a deterministic ID generated from the two user IDs.
- Story authors must be partnership members and match the assigned next author.
- Notification destinations and notification copy must not be supplied directly by clients.
- FCM tokens are stored under `/users/{userId}/private/notifications`.
- Moderation, achievements, and security incident records should be treated as server-owned data.

Before deploying rule changes, test them against the Firebase Emulator Suite. Production deployment without authorization tests is not recommended.

## Current technical debt

- `ScenarioManager` and `FirebaseDataService` contain too many responsibilities and should be split into focused view models and repositories.
- The legacy `/sharedStories` collection remains read-only during migration.
- Automated moderation is heuristic and requires realistic false-positive tests.
- Security-rule tests and domain unit tests need broader coverage.
- Client-managed achievements should be migrated to server-authoritative logic.

## Recommended test coverage

1. Firestore rules using `@firebase/rules-unit-testing`
2. Partnership invitation acceptance and immutable membership
3. Turn enforcement and concurrent story submissions
4. Prompt-deck uniqueness and reshuffling
5. Notification authorization
6. Moderation false positives
7. Swift and TypeScript serialization parity

## Deployment

```bash
npm --prefix functions install
npm --prefix functions run deploy
```

Deploy Firestore rules separately through the Firebase CLI after emulator validation.
