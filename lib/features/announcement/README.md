# Announcement Feature

## Overview
The Announcement feature allows admins to create location-based announcements for residents. Users can view announcements filtered by their home location and search for specific announcements.

## Architecture: MVVM Pattern

This feature follows the MVVM (Model-View-ViewModel) architecture pattern for clean separation of concerns.

### Folder Structure
```
announcement/
├── models/                          # Data models
│   └── announcement.dart
├── services/                        # Data layer
│   └── announcement_repository.dart
├── viewmodels/                      # Business logic
│   ├── announcement_view_model.dart
│   └── create_announcement_view_model.dart
├── announcement_page.dart           # Main listing view
├── create_announcement_page.dart    # Create announcement view
├── announcement_detail_page.dart    # Detail view (needs refactoring)
├── edit_announcement_page.dart      # Edit view (needs refactoring)
└── colours.dart                     # Color constants
```

## Quick Start

### Display Announcements

```dart
import 'package:flutter/material.dart';
import 'viewmodels/announcement_view_model.dart';

class AnnouncementPage extends StatefulWidget {
  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  late final AnnouncementViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AnnouncementViewModel();
    _viewModel.initialize(); // Load user profile
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) {
        return StreamBuilder<List<Announcement>>(
          stream: _viewModel.watchAnnouncements(),
          builder: (context, snapshot) {
            final announcements = snapshot.data ?? [];
            final filtered = _viewModel.filterAnnouncements(announcements);
            // Build UI...
          },
        );
      },
    );
  }
}
```

### Create Announcement

```dart
import 'viewmodels/create_announcement_view_model.dart';

class CreateAnnouncementPage extends StatefulWidget {
  @override
  State<CreateAnnouncementPage> createState() => _CreateAnnouncementPageState();
}

class _CreateAnnouncementPageState extends State<CreateAnnouncementPage> {
  late final CreateAnnouncementViewModel _viewModel;
  final _titleController = TextEditingController();
  final _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = CreateAnnouncementViewModel();
  }

  Future<void> _submit() async {
    final error = await _viewModel.submitAnnouncement(
      _titleController.text,
      _captionController.text,
    );
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    } else {
      Navigator.pop(context); // Success
    }
  }
}
```

## Key Components

### 1. Models

#### `Announcement`
Main data model for announcements.

**Properties**:
- `id`: Document ID
- `title`: Announcement title
- `caption`: Description
- `colour`: Card color ('green', 'blue', 'red', etc.)
- `announcerId`: Creator's user ID
- `createdAt`: Timestamp
- `isDeleted`: Soft delete flag
- `attachments`: List of files
- `target`: Audience and location targeting

**Methods**:
- `isUpcoming`: Check if announcement is today or future
- `isPast`: Check if announcement is past

#### `AnnouncementLocation`
Geographic location data.

**Properties**:
- `area`: Suburb/neighborhood
- `city`: City name
- `state`: State name
- `full`: Complete address string

**Methods**:
- `shortDisplay`: Formatted display "Area, State"

### 2. Repository

#### `AnnouncementRepository`
Handles all Firebase operations.

**Methods**:
```dart
// Read
Stream<List<Announcement>> watchAnnouncements()
Future<Announcement?> getAnnouncement(String id)
Future<UserProfile?> getUserProfile(String userId)

// Create/Update
Future<void> createAnnouncement({...})
Future<void> updateAnnouncement({...})

// Delete
Future<void> deleteAnnouncement(String id)
```

### 3. ViewModels

#### `AnnouncementViewModel`
Business logic for announcement listing.

**State**:
- `userProfile`: Current user data
- `searchQuery`: Search filter text
- `isLoadingProfile`: Loading indicator

**Methods**:
```dart
Future<void> initialize()
void setSearchQuery(String query)
List<Announcement> filterAnnouncements(List<Announcement> all)
Map<String, List<Announcement>> splitByDate(List<Announcement> filtered)
String getDisplayLocation(List<Announcement> filtered)
```

#### `CreateAnnouncementViewModel`
Business logic for creating announcements.

**State**:
- `attachments`: Selected files
- `selectedAudience`: Target audience
- `selectedLocation`: Geographic location
- `selectedColour`: Card color
- `isSubmitting`: Submission progress

**Methods**:
```dart
void addAttachment(File file, String name, AttachmentType type)
void removeAttachment(int index)
void setAudience(String audience)
void setLocation(String location)
void setColour(String colour)
String? validate(String title, String caption)
Future<String?> submitAnnouncement(String title, String caption)
```

## Features

### 🔍 Location-Based Filtering
Announcements are automatically filtered based on the user's home address (area/state). Users see announcements relevant to their location.

### 🔎 Search Functionality
Users can search announcements by title, caption, or location. Search overrides location filtering.

### 📅 Date Categorization
Announcements are split into:
- **Upcoming**: Today onwards
- **Past**: Before today (shown with reduced opacity)

### 🎨 Color Coding
Announcements support different colors for visual categorization:
- Green, Blue, Red, Yellow, Purple, Orange

### 📎 Attachments
Support for multiple attachment types:
- Images (.jpg, .png, .gif, etc.)
- Videos (.mp4, .mov, etc.)
- Documents (.pdf, .doc, etc.)

### 👥 Audience Targeting
Admins can target announcements to:
- **Everyone**: All users
- **Admin**: Admin users only
- **Residents**: Non-admin users

## Firestore Schema

```
announcements/{announcementId}
├── title: string
├── caption: string
├── colour: string ('green', 'blue', 'red', etc.)
├── announcerID: string
├── createdAt: timestamp
├── isDeleted: boolean
├── fcmSent: boolean
├── attachments: array
│   └── {
│       url: string,
│       name: string,
│       type: string ('image', 'document', 'video')
│   }
└── target: map
    ├── audience: string ('all', 'admin', 'residents')
    └── location: map
        ├── area: string
        ├── city: string
        ├── state: string
        └── full: string
```

## User Roles

### Admin Users (`role == 'admin'`)
- Create announcements
- Edit announcements
- Delete announcements (soft delete)
- View all announcements

### Regular Users (`role == 'user'`)
- View announcements filtered by their location
- Search announcements
- View announcement details
- No creation/editing capabilities

## Testing

### Unit Tests (ViewModels)
```dart
test('should filter announcements by user area', () {
  final mockRepo = MockAnnouncementRepository();
  final viewModel = AnnouncementViewModel(repository: mockRepo);
  
  // Setup mock data
  when(mockRepo.getCurrentUserProfile()).thenAnswer((_) async => UserProfile(
    uid: 'test',
    role: 'user',
    area: 'Penang',
    state: 'Pulau Pinang',
    homeAddress: 'Test Address',
  ));
  
  // Test filtering
  final announcements = [/* test data */];
  final filtered = viewModel.filterAnnouncements(announcements);
  
  expect(filtered.length, 1);
});
```

### Integration Tests (Repository)
```dart
testWidgets('should create announcement successfully', (tester) async {
  final repo = AnnouncementRepository();
  
  await repo.createAnnouncement(
    title: 'Test',
    caption: 'Test caption',
    colour: 'green',
    audience: 'all',
    location: AnnouncementLocation(
      area: 'Test Area',
      city: 'Test City',
      state: 'Test State',
      full: 'Test Area, Test City, Test State',
    ),
    attachmentFiles: [],
  );
  
  // Verify announcement exists in Firestore
});
```

## Best Practices

### ✅ DO
- Use ViewModel for all business logic
- Use Repository for all Firebase operations
- Keep Views (UI) pure and simple
- Use models for type safety
- Handle errors gracefully

### ❌ DON'T
- Put Firebase calls directly in Views
- Mix business logic with UI code
- Use raw Maps instead of Models
- Forget to dispose ViewModels
- Expose Repository methods to Views

## Common Issues

### Issue: Announcements not filtered by location
**Solution**: Ensure user profile has `area` and `state` fields populated.

### Issue: Attachments not uploading
**Solution**: Check Firebase Storage rules and ensure user is authenticated.

### Issue: ViewModel not updating UI
**Solution**: Ensure View is wrapped with `AnimatedBuilder` or `ListenableBuilder` listening to ViewModel.

## Future Improvements

- [ ] Add unit tests for ViewModels
- [ ] Add integration tests for Repository
- [ ] Refactor `announcement_detail_page.dart` to use ViewModel
- [ ] Refactor `edit_announcement_page.dart` to use ViewModel
- [ ] Add pagination for large announcement lists
- [ ] Add push notifications (FCM) integration
- [ ] Add announcement expiry date
- [ ] Add announcement priority levels

## Related Features

- **Auth**: User authentication and roles
- **Profile**: User home address for filtering
- **Issue Reporting**: Similar location-based filtering
- **Status Tracker**: Similar MVVM pattern

## Support

For questions or issues with the Announcement feature:
1. Check the `MVVM_REFACTORING.md` document
2. Review other MVVM features (ChatBot, IssueReporting)
3. Check Firebase Console for data issues
4. Review unit tests for expected behavior
