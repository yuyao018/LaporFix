import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/announcement.dart';
import '../services/announcement_repository.dart';

/// ViewModel for creating/editing announcements.
class CreateAnnouncementViewModel extends ChangeNotifier {
  final AnnouncementRepository _repository;

  CreateAnnouncementViewModel({AnnouncementRepository? repository})
      : _repository = repository ?? AnnouncementRepository();

  // State
  final List<AttachmentData> _attachments = [];
  String _selectedAudience = 'all';
  String _selectedLocation = '';
  String _selectedColour = 'green';
  bool _isSubmitting = false;

  // Getters
  List<AttachmentData> get attachments => List.unmodifiable(_attachments);
  String get selectedAudience => _selectedAudience;
  String get selectedLocation => _selectedLocation;
  String get selectedColour => _selectedColour;
  bool get isSubmitting => _isSubmitting;

  // Options
  final List<String> audienceOptions = ['Everyone', 'Admin', 'Residents'];
  final List<String> colourOptions = [
    'green',
    'blue',
    'red',
    'yellow',
    'purple',
    'orange'
  ];

  /// Add an attachment
  void addAttachment(File file, String name, AttachmentType type) {
    _attachments.add(AttachmentData(file: file, name: name, type: type));
    notifyListeners();
  }

  /// Remove an attachment by index
  void removeAttachment(int index) {
    if (index >= 0 && index < _attachments.length) {
      _attachments.removeAt(index);
      notifyListeners();
    }
  }

  /// Set selected audience
  void setAudience(String audience) {
    _selectedAudience = audience.toLowerCase();
    notifyListeners();
  }

  /// Set selected location
  void setLocation(String location) {
    _selectedLocation = location;
    notifyListeners();
  }

  /// Set selected colour
  void setColour(String colour) {
    _selectedColour = colour;
    notifyListeners();
  }

  /// Validate inputs
  String? validate(String title, String caption) {
    if (title.trim().isEmpty) {
      return 'Please enter a title.';
    }
    if (caption.trim().isEmpty) {
      return 'Please enter a caption.';
    }
    if (_selectedLocation.isEmpty) {
      return 'Please select a location.';
    }
    return null; // Valid
  }

  /// Submit announcement
  Future<String?> submitAnnouncement(String title, String caption) async {
    final error = validate(title, caption);
    if (error != null) return error;

    _isSubmitting = true;
    notifyListeners();

    try {
      // Parse location
      final locationParts = _selectedLocation.split(', ');
      final location = AnnouncementLocation(
        area: locationParts.isNotEmpty ? locationParts[0] : '',
        city: locationParts.length > 1 ? locationParts[1] : '',
        state: locationParts.length > 2 ? locationParts[2] : '',
        full: _selectedLocation,
      );

      // Get attachment files
      final attachmentFiles = _attachments.map((a) => a.file).toList();

      // Create announcement
      await _repository.createAnnouncement(
        title: title.trim(),
        caption: caption.trim(),
        colour: _selectedColour,
        audience: _selectedAudience,
        location: location,
        attachmentFiles: attachmentFiles,
      );

      return null; // Success
    } catch (e) {
      return e.toString();
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Reset form
  void reset() {
    _attachments.clear();
    _selectedAudience = 'all';
    _selectedLocation = '';
    _selectedColour = 'green';
    _isSubmitting = false;
    notifyListeners();
  }
}

/// Data class for attachment before upload
class AttachmentData {
  final File file;
  final String name;
  final AttachmentType type;

  AttachmentData({
    required this.file,
    required this.name,
    required this.type,
  });
}

/// Attachment type enum
enum AttachmentType { image, document, video }
