# Announcement Feature - MVVM Refactoring

## Overview
The Announcement feature has been refactored from a monolithic architecture with direct Firebase calls in the UI to a proper MVVM (Model-View-ViewModel) architecture.

## Architecture Structure

```
announcement/
├── models/
│   └── announcement.dart           # Data models
├── services/
│   └── announcement_repository.dart # Data layer (Firebase operations)
├── viewmodels/
│   ├── announcement_view_model.dart         # Business logic for listing
│   └── create_announcement_view_model.dart  # Business logic for creation
├── announcement_page.dart          # View (UI)
├── create_announcement_page.dart   # View (UI)
├── announcement_detail_page.dart   # View (UI)
├── edit_announcement_page.dart     # View (UI)
└── colours.dart                    # UI constants
```

## What Changed?

### Before (Anti-pattern ❌)
```dart
class _AnnouncementPageState extends State<AnnouncementPage> {
  String _userRole = 'user';
  String _userArea = '';
  
  Future<void> _fetchUserData() async {
    // Direct Firebase call in UI ❌
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    setState(() {
      _userRole = doc.data()?['role'] ?? 'user';
    });
  }
  
  List<QueryDocumentSnapshot> _filterDocs(List<QueryDocumentSnapshot> docs) {
    // Business logic mixed with UI ❌
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      // Complex filtering logic...
    }).toList();
  }
}
```

### After (MVVM Pattern ✅)
```dart
// ViewModel - Business Logic
class AnnouncementViewModel extends ChangeNotifier {
  final AnnouncementRepository _repository;
  UserProfile? _userProfile;
  
  Future<void> initialize() async {
    _userProfile = await _repository.getCurrentUserProfile();
    notifyListeners();
  }
  
  List<Announcement> filterAnnouncements(List<Announcement> announcements) {
    // Clean business logic
  }
}

// View - UI Only
class _AnnouncementPageState extends State<AnnouncementPage> {
  late final AnnouncementViewModel _viewModel;
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        // Pure UI code ✅
      },
    );
  }
}
```

## Key Components

### 1. Models (`models/announcement.dart`)

**Purpose**: Define data structures

- `Announcement` - Main announcement model
- `AnnouncementAttachment` - File attachments
- `AnnouncementTarget` - Audience and location targeting
- `AnnouncementLocation` - Geographic location data
- `UserProfile` - User data for filtering

**Benefits**:
- Type safety
- Reusable across features
- Easy to test
- Clear data contracts

### 2. Repository (`services/announcement_repository.dart`)

**Purpose**: Handle all Firebase operations

**Methods**:
- `watchAnnouncements()` - Stream of announcements
- `getUserProfile()` - Fetch user data
- `createAnnouncement()` - Create new announcement
- `updateAnnouncement()` - Update existing
- `deleteAnnouncement()` - Soft delete
- `_uploadAttachments()` - Upload files to Storage

**Benefits**:
- Single source of truth for data access
- Testable with mock implementations
- Hides Firebase complexity from ViewModels
- Reusable across multiple ViewModels

### 3. ViewModels

#### `AnnouncementViewModel` (for listing page)

**Responsibilities**:
- Load user profile
- Filter announcements by location/search
- Split announcements by date (upcoming/past)
- Manage search query state

**State**:
- `userProfile` - Current user data
- `searchQuery` - Search filter
- `isLoadingProfile` - Loading indicator

**Methods**:
- `initialize()` - Load initial data
- `setSearchQuery()` - Update search
- `filterAnnouncements()` - Apply filters
- `splitByDate()` - Categorize by date
- `getDisplayLocation()` - Format location display

#### `CreateAnnouncementViewModel` (for creation page)

**Responsibilities**:
- Manage form state
- Handle attachments
- Validate inputs
- Submit to repository

**State**:
- `attachments` - Selected files
- `selectedAudience` - Target audience
- `selectedLocation` - Target location
- `selectedColour` - Card color
- `isSubmitting` - Submission state

### 4. Views (UI Pages)

**Changes**:
- No direct Firebase imports
- No business logic
- Pure UI rendering
- Listen to ViewModel via `AnimatedBuilder` or `ListenableBuilder`

## Benefits of MVVM Refactoring

### ✅ Separation of Concerns
- **View**: Only renders UI
- **ViewModel**: Contains business logic
- **Repository**: Handles data operations
- **Model**: Defines data structures

### ✅ Testability
```dart
// Easy to test ViewModel in isolation
test('should filter announcements by user area', () {
  final mockRepo = MockAnnouncementRepository();
  final viewModel = AnnouncementViewModel(repository: mockRepo);
  // Test filtering logic without Firebase
});
```

### ✅ Maintainability
- Changes to Firebase don't affect ViewModel
- Changes to business logic don't affect View
- Each layer has a single responsibility

### ✅ Reusability
- ViewModels can be reused across different Views
- Repository can be shared across features
- Models are consistent throughout app

### ✅ State Management
- Centralized state in ViewModel
- Reactive UI updates via `ChangeNotifier`
- No scattered `setState()` calls

## Migration Guide

### For `announcement_detail_page.dart` and `edit_announcement_page.dart`

These pages still need refactoring. Follow this pattern:

1. **Create ViewModel**:
```dart
class AnnouncementDetailViewModel extends ChangeNotifier {
  final AnnouncementRepository _repository;
  Announcement? _announcement;
  
  Future<void> loadAnnouncement(String id) async {
    _announcement = await _repository.getAnnouncement(id);
    notifyListeners();
  }
}
```

2. **Update View**:
```dart
class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  late final AnnouncementDetailViewModel _viewModel;
  
  @override
  void initState() {
    super.initState();
    _viewModel = AnnouncementDetailViewModel();
    _viewModel.loadAnnouncement(widget.docId);
  }
}
```

## Testing Strategy

### Unit Tests
- Test ViewModels in isolation
- Mock Repository
- Verify state changes
- Test business logic

### Integration Tests
- Test Repository with Firebase emulator
- Verify CRUD operations
- Test error handling

### Widget Tests
- Test Views with mock ViewModels
- Verify UI rendering
- Test user interactions

## Next Steps

1. ✅ Refactor `announcement_page.dart` - **DONE**
2. ⏳ Refactor `announcement_detail_page.dart` - TODO
3. ⏳ Refactor `edit_announcement_page.dart` - TODO
4. ⏳ Refactor `create_announcement_page.dart` to use ViewModel - TODO
5. ⏳ Add unit tests for ViewModels
6. ⏳ Add integration tests for Repository

## Comparison with Other Features

### Features Already Using MVVM ✅
- **AI Chatbot**: `ChatViewModel`
- **Issue Reporting**: `IssueReportingViewModel`
- **Upvoting**: `CommunityViewModel`, `PostDetailsViewModel`
- **Status Tracker**: `StatusTrackerViewModel`, `InsightsViewModel`

### Features Needing Refactoring ❌
- **Auth**: Login/Signup pages
- **Profile**: Profile and Settings pages
- **Announcement**: Detail and Edit pages (partially done)

## Conclusion

The Announcement feature now follows the same MVVM pattern as other major features in LaporFix. This makes the codebase more consistent, maintainable, and testable. The separation of concerns allows for easier debugging and feature additions without breaking existing functionality.
