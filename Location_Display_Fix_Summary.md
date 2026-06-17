# Location Display Fix - Community Posts

## Issue
The community feed was showing the **user's home address** instead of the **report location** where the issue was actually reported.

## Changes Made

### 1. **Community Issue Card** (`lib/features/upvoting/widgets/community_issue_card.dart`)

**Before:**
```dart
final String reporterArea; // User's home address from profile
// ...
Text(area.isNotEmpty ? area : 'Location unavailable') // Showing user's home
```

**After:**
```dart
// Removed reporterArea parameter
final reportLocation = issue.location.heading.trim(); // Report location
// ...
Text(reportLocation.isNotEmpty ? reportLocation : 'Location unavailable')
```

**Impact**: All community post cards now display where the issue was reported, not where the reporter lives.

---

### 2. **Upvoting Page** (`lib/features/upvoting/upvoting_page.dart`)

**Before:**
```dart
final reporterArea = profile?.area ?? '';

return CommunityIssueCard(
  // ...
  reporterArea: reporterArea, // Passing user's home address
  // ...
);
```

**After:**
```dart
// Removed reporterArea variable

return CommunityIssueCard(
  // ...
  // No longer passing reporterArea
  // Card uses issue.location.heading instead
);
```

**Impact**: Simplified data flow - location comes directly from issue data, not user profile.

---

### 3. **Post Details Page** (`lib/features/upvoting/post_details_page.dart`)

**Before:**
```dart
Widget _buildBody(
  AsyncSnapshot<CommunityIssue> snapshot,
  String reporterArea, // User's home address
) {
  // ...
  final displayArea = reporterArea.trim().isNotEmpty
      ? reporterArea.trim()
      : '';
  
  Text(displayArea.isNotEmpty ? displayArea : 'Location unavailable')
}
```

**After:**
```dart
Widget _buildBody(
  AsyncSnapshot<CommunityIssue> snapshot,
  // Removed reporterArea parameter
) {
  // Use report location instead of user's home address
  final reportLocation = issue.location.heading.trim();
  
  Text(reportLocation.isNotEmpty ? reportLocation : 'Location unavailable')
}
```

**Impact**: Post detail page now shows the actual report location.

---

## What Was NOT Changed (Intentionally)

### Comment Tiles - Still Show Commenter's Home Area
The comment tiles in the post details page **correctly** show the commenter's home area:

```dart
CommentTile(
  // ...
  overrideArea: profile?.area, // Commenter's home area - CORRECT
  // ...
)
```

**Why?** This shows where the person **making the comment** is from, which helps indicate community engagement from different areas. This is different from the issue location and should remain as the user's profile area.

---

## Data Structure

### Issue Location Data (from Firestore)
```dart
class CommunityIssueLocation {
  final String heading;    // Report location (e.g., "Jalan Sultan Azlan Shah")
  final String postcode;   // Report location postcode
}
```

This data is set when the user creates a report and selects the location on the map.

### User Profile Data (from Firestore)
```dart
class CommunityUserProfile {
  final String area;       // User's home address (e.g., "Bayan Lepas")
}
```

This data is from the user's registration/profile.

---

## User Experience Improvement

### Before Fix:
❌ User in **Bayan Lepas** reports pothole on **Jalan Sultan Azlan Shah**  
❌ Community feed shows: "📍 Bayan Lepas" (misleading - makes it look like issue is in Bayan Lepas)

### After Fix:
✅ User in **Bayan Lepas** reports pothole on **Jalan Sultan Azlan Shah**  
✅ Community feed shows: "📍 Jalan Sultan Azlan Shah" (correct - shows actual issue location)  
✅ Comments still show: "User from Bayan Lepas" (shows where supporters/commenters are from)

---

## Testing Checklist

- [x] Community feed cards display report location
- [x] Post detail page displays report location
- [x] Comment tiles still display commenter's home area
- [x] No compilation errors
- [x] "Location unavailable" fallback works when heading is empty

---

## Files Modified

1. `lib/features/upvoting/widgets/community_issue_card.dart`
2. `lib/features/upvoting/upvoting_page.dart`
3. `lib/features/upvoting/post_details_page.dart`

---

## Conclusion

The community feed now accurately reflects **where infrastructure issues are located** rather than where the reporters live, making it much more useful for:
- Users looking for issues in their area
- Understanding geographic distribution of problems
- Prioritizing issues by actual location
- Community engagement based on issue proximity
