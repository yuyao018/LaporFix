import 'package:flutter/foundation.dart';
import '../models/announcement.dart';
import '../services/announcement_repository.dart';

/// ViewModel for the Announcement page.
/// Handles filtering, searching, and user profile state.
class AnnouncementViewModel extends ChangeNotifier {
  final AnnouncementRepository _repository;

  AnnouncementViewModel({AnnouncementRepository? repository})
      : _repository = repository ?? AnnouncementRepository();

  // State
  UserProfile? _userProfile;
  String _searchQuery = '';
  bool _isLoadingProfile = true;

  // Getters
  UserProfile? get userProfile => _userProfile;
  String get searchQuery => _searchQuery;
  bool get isLoadingProfile => _isLoadingProfile;
  bool get isAdmin => _userProfile?.isAdmin ?? false;

  /// Initialize by fetching user profile
  Future<void> initialize() async {
    _isLoadingProfile = true;
    notifyListeners();

    _userProfile = await _repository.getCurrentUserProfile();

    _isLoadingProfile = false;
    notifyListeners();
  }

  /// Update search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Stream of announcements
  Stream<List<Announcement>> watchAnnouncements() {
    return _repository.watchAnnouncements();
  }

  /// Filter announcements based on user location and search query
  List<Announcement> filterAnnouncements(List<Announcement> announcements) {
    return announcements.where((announcement) {
      // If searching, filter by search query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final title = announcement.title.toLowerCase();
        final caption = announcement.caption.toLowerCase();
        final location = announcement.target.location;
        final locationStr =
            '${location.area} ${location.city} ${location.state} ${location.full}'
                .toLowerCase();

        return title.contains(query) ||
            caption.contains(query) ||
            locationStr.contains(query);
      }

      // Default: filter by user's location
      if (_userProfile == null) return true;

      final userArea = _userProfile!.area.toLowerCase();
      final userState = _userProfile!.state.toLowerCase();

      if (userArea.isEmpty && userState.isEmpty) return true;

      final announcementArea = announcement.target.location.area.toLowerCase();
      final announcementState =
          announcement.target.location.state.toLowerCase();
      final announcementFull = announcement.target.location.full.toLowerCase();

      // Match by area
      if (userArea.isNotEmpty) {
        if (announcementArea == userArea) return true;
        if (announcementFull.contains(userArea)) return true;
      }

      // Match by state as fallback
      if (userState.isNotEmpty && announcementState == userState) return true;

      return false;
    }).toList();
  }

  /// Split announcements into upcoming and past
  Map<String, List<Announcement>> splitByDate(List<Announcement> announcements) {
    final upcoming = <Announcement>[];
    final past = <Announcement>[];

    for (final announcement in announcements) {
      if (announcement.isUpcoming) {
        upcoming.add(announcement);
      } else {
        past.add(announcement);
      }
    }

    return {
      'upcoming': upcoming,
      'past': past,
    };
  }

  /// Get display location based on search or user profile
  String getDisplayLocation(List<Announcement> filteredAnnouncements) {
    // If searching and has results, show location from first result
    if (_searchQuery.isNotEmpty && filteredAnnouncements.isNotEmpty) {
      return filteredAnnouncements.first.target.location.shortDisplay;
    }

    // Default: show user's location
    return _userProfile?.locationDisplay ?? 'All Locations';
  }

  /// Delete an announcement (admin only)
  Future<String?> deleteAnnouncement(String announcementId) async {
    if (!isAdmin) {
      return 'Only admins can delete announcements';
    }

    try {
      await _repository.deleteAnnouncement(announcementId);
      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }
}
