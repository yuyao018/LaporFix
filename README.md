# LaporFix

A Flutter-based civic app for Malaysian residents to report, track, and engage with urban infrastructure issues — potholes, water/power disruptions, drainage problems, and more. Backed by Firebase and a local RAG AI assistant named **LAPI**.

---

## Features

### Authentication
- Email and password sign-in and sign-up
- Home address picker (required at registration) using OpenStreetMap Nominatim, Malaysia only
- Role-based access: `user` (resident) and `admin` — stored in Firestore

### Home — Announcements
- Real-time feed of announcements from Firestore, filtered by the user's registered area
- Splits into **Upcoming** and **Past Announcements** sections
- Search across title, caption, and location
- Admin users can create announcements with title, caption, attachments (image, document, video), audience target (Everyone / Admin / Residents), location, and colour theme
- Push notification sent automatically via Cloud Function when a new announcement is created

### Issue Tab — Status Tracker
- Lists all issues submitted by the logged-in user with search and status filter
- Full issue detail view with status history
- Floating action button to create a new report (two-step flow):
  1. Upload photo, select category, add description
  2. OpenStreetMap interactive map with draggable crosshair, Nominatim geocoding search, optional address details and notes
- Admin users can update issue status and upload proof
- Insights page for admin analytics

### Community Tab — Upvoting
- Public feed of all reported issues (real-time)
- Sort by Newest or Most Supported (like count)
- Search and filter
- Like / unlike posts
- Comment on issues
- Reporter visibility: anonymous or named (per user setting)
- Admin users see a Vote Insights page

### Profile
- Avatar (tappable to change, uploads to Firebase Storage)
- Stats: posts submitted, likes given
- Change password (re-authentication required)
- Change home address (Nominatim picker)
- Log out

### App Settings
- **Urgent alerts** — toggle FCM notifications for area announcements
- **Issue status updates** — toggle FCM notifications when your report changes status
- **Community profile** — show/hide display name on public activity
- **Low data mode** — reduces media loading; auto-activates on mobile data
- **Submit feedback or complaint** — form to report app issues, dissatisfaction with report resolutions, or suggestions; saved to Firestore `feedback` collection
- Settings sync in real-time to Firestore via `AppSettingsService`

### LAPI — AI Chatbot
- Accessible from all tabs via a floating action button
- Powered by a local RAG backend (FastAPI + Ollama + ChromaDB)
- Suggestion shortcuts:
  - **How to report an issue?** — guided answer with a "Report Issue" button
  - **Track my existing ticket** — fetches open issues from Firestore and renders ticket progress cards
  - **Check for water/power cut** — queries Firestore announcements for disruption keywords in user's area and renders disruption notice cards
- Image upload — Gemini Vision extracts content, then answered by RAG
- Document upload (PDF, DOC, DOCX, TXT) — Docling extracts text, then answered by RAG
- `/clear` command deletes all chat history
- Chat history panel — loads past sessions from backend
- Conversation history persisted to Firestore `chat_sessions`

### Push Notifications (FCM)
Two Cloud Functions in `functions/index.js` (region: `asia-southeast1`):
- **`sendAnnouncementNotification`** — fires on new announcement, targets admins and residents whose area/state matches the announcement's target location
- **`sendIssueStatusUpdateNotification`** — fires when an issue's status field changes, notifies the reporter
- Tapping a notification navigates directly to the relevant announcement or issue detail page
- Invalid FCM tokens are cleaned up automatically

---

## Project Structure

```
LaporFix/
├── lib/
│   ├── main.dart                     # App entry point, Firebase init, auth routing
│   ├── firebase_options.dart         # Firebase config
│   ├── theme/app_theme.dart          # Colours, gradients, text theme
│   ├── features/
│   │   ├── auth/                     # Login, signup, auth wrapper
│   │   ├── announcement/             # Announcements feed, detail, create, edit
│   │   ├── status_tracker/           # Issue list, detail, update, insights (MVVM)
│   │   ├── issue_reporting/          # Two-step report flow + OSM map
│   │   ├── upvoting/                 # Community feed, post detail, vote insights
│   │   ├── Profile/                  # Profile page, app settings, feedback form
│   │   └── AI_chatbot/               # LAPI chatbot UI, view model, services, models
│   ├── services/
│   │   ├── fcm_service.dart          # FCM token management + notification routing
│   │   └── app_settings_service.dart # Settings singleton with Firestore sync
│   └── widgets/                      # Shared UI components
├── backend/                          # Python FastAPI RAG backend (see backend/README.md)
├── functions/                        # Firebase Cloud Functions (Node.js)
│   └── index.js                      # FCM trigger functions
└── assets/icons/                     # App icons and chatbot mascot image
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile framework | Flutter (Dart SDK ^3.9.0) |
| State management | Provider (ChangeNotifier + MVVM) |
| Database | Cloud Firestore |
| Authentication | Firebase Auth (email/password) |
| File storage | Firebase Storage |
| Push notifications | Firebase Cloud Messaging + Cloud Functions |
| Maps | flutter_map (OpenStreetMap tiles) |
| Geocoding | OpenStreetMap Nominatim API |
| Location | geolocator |
| AI chatbot | FastAPI + LangChain + Ollama (qwen2.5:3b) + ChromaDB |
| Image understanding | Gemini Vision (gemini-2.0-flash) |
| Document parsing | Docling |
| Backend persistence | Firestore (via firebase-admin Python SDK) |

---

## Getting Started

### Prerequisites
- Flutter SDK (Dart ^3.9.0)
- Android Studio or VS Code with Flutter extension
- Firebase project with Firestore, Auth, Storage, Messaging, and Cloud Functions enabled
- `google-services.json` placed in `android/app/`

### Flutter setup

```bash
# Install dependencies
flutter pub get

# Run on Android emulator or physical device
flutter run
```

> The AI chatbot requires the backend server to be running separately. See [backend/README.md](backend/README.md).

### Firebase Cloud Functions setup

```bash
cd functions
npm install
firebase deploy --only functions
```

---

## Firestore Data Model

| Collection | Key fields |
|---|---|
| `users/{uid}` | username, email, homeAddress, area, state, role, photoURL, fcmTokens, appSettings |
| `issue/{id}` | title, category, description, status, reporterID, reportImages, location `{heading, postcode, precise_location}`, community `{likes, comments}`, isDeleted |
| `announcements/{id}` | title, caption, colour, target `{audience, location}`, attachments, fcmSent, isDeleted |
| `chat_sessions/{session_id}` | user_id, created_at, updated_at, preview |
| `chat_sessions/{id}/messages/{msg_id}` | role, content, timestamp, image_url, disruption_notice, ticket |
| `feedback/{id}` | userId, userEmail, type, subject, details, createdAt, status |

---

## Physical Device Testing

To use the chatbot on a physical Android device, update `_baseUrl` in `lib/features/AI_chatbot/services/chatbot_service.dart` to your machine's local IP:

```dart
static const String _baseUrl = 'http://192.168.x.x:8000';
```
