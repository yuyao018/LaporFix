import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:group2_urbanfix/features/status_tracker/summary/data/status_tracker_repository.dart';
import 'package:group2_urbanfix/services/app_settings_service.dart';
import 'package:latlong2/latlong.dart';
import '../models/issue_report_model.dart';
import '../services/image_service.dart';
import '../services/location_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart';

class IssueReportingViewModel extends ChangeNotifier {
  static const String _googleGeocodeApiKey = 'AIzaSyCUrgapzNwjVE0TovS1joxgMIMMlAJPXlY';

  // Model
  IssueReportModel report = IssueReportModel();

  // Services
  final ImageService _imageService = ImageService();
  final LocationService _locationService = LocationService();

  // Firebase Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controllers
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController addressDetailsController = TextEditingController();
  final TextEditingController additionalNotesController = TextEditingController();

  // State
  bool isLoadingLocation = true;
  bool isSubmittingReport = false;
  Timer? _draftSaveTimer;

  // MAP State (OpenStreetMap uses latlong2 LatLng)
  LatLng currentPosition = const LatLng(5.3630, 100.4667);

  // Category List
  final List<String> categories = ['Lighting', 'Drainage', 'Electricity', 'Garbage', 'Water', 'Roads', 'Waste', 'Other'];

  // Select an image from the device gallery
  Future<void> pickImage() async {
    File? image = await _imageService.pickFromGallery();

    if (image != null) {
      report.image = image;
      notifyListeners();
    }
  }

  // Retrieve the user's current location and update the map marker
  Future<void> getCurrentLocation() async {
    try {
      isLoadingLocation = true;
      notifyListeners();

      Position position = await _locationService.getCurrentLocation();

      await Future.delayed(const Duration(milliseconds: 300));

      String address = await _locationService.getAddress(position.latitude, position.longitude);

      // Save into model
      report.latitude = position.latitude;
      report.longitude = position.longitude;
      report.locationName = address;
      _scheduleDraftSave();

      // Update map marker (OpenStreetMap)
      currentPosition = LatLng(position.latitude, position.longitude);

      // Fill text field
      addressController.text = address;
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      isLoadingLocation = false;
      notifyListeners();
    }
  }

  // Update location when the user moves the map marker
  void updateMapLocation(LatLng position) {
    currentPosition = position;
    report.latitude = position.latitude;
    report.longitude = position.longitude;
    _scheduleDraftSave();
    notifyListeners();
  }

  // Manual address input
  void setAddress(String value) {
    report.locationName = value;
    _scheduleDraftSave();
  }

  // UPDATE FORM DATA
  void updateCategory(String? value) {
    report.category = value ?? '';
    if (!isOtherCategorySelected) {
      categoryController.clear();
    }
    _scheduleDraftSave();
    notifyListeners();
  }

  void updateCustomCategory(String value) {
    _scheduleDraftSave();
    notifyListeners();
  }

  void updateDescription(String value) {
    report.description = value;
    _scheduleDraftSave();
    notifyListeners();
  }

  void updateAddressDetails(String value) {
    report.addressDetails = value;
    _scheduleDraftSave();
  }

  void updateAdditionalNotes(String value) {
    report.additionalNotes = value;
    _scheduleDraftSave();
    notifyListeners();
  }

  // Validate image, category, and description fields
  bool validateStepOne() {
    return report.image != null && resolvedCategory.isNotEmpty && report.description.isNotEmpty;
  }

  // Validate location information
  bool validateStepTwo() {
    return addressController.text.isNotEmpty;
  }

  // Submit issue report to Firebase Storage and Firestore
  Future<void> submitReport(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final settings = AppSettingsService.instance;
    String postcode = '';
    String postcodeName = '';

    isSubmittingReport = true;
    notifyListeners();

    // Show loading indicator immediately (before any async work)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (report.latitude != null && report.longitude != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(report.latitude!, report.longitude!);

        if (placemarks.isNotEmpty) {
          postcode = placemarks.first.postalCode ?? '';
        }
      }

      postcodeName = await _fetchPostcodeName(postcode);
    } catch (e) {
      debugPrint('Postcode fetch failed: $e');
    }
    try {
      // STEP A: Upload image to Firebase Storage
      String imageUrl = '';
      if (report.image != null) {
        final storageRef = FirebaseStorage.instance.ref().child('issue_images/${DateTime.now().millisecondsSinceEpoch}.jpg');

        UploadTask uploadTask = storageRef.putFile(report.image!);
        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      // STEP B: Save report data to Firestore 'issue' collection
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
      final issueCategory = resolvedCategory;
      if (issueCategory.isEmpty) {
        throw StateError('Enter a category before submitting the report.');
      }

      // Save report into the required 'issue' collection！
      await _firestore.collection('issue').add({
        // Basic report information
        'title': issueCategory,
        'category': issueCategory,
        'description': report.description.isEmpty ? descriptionController.text : report.description,
        'reporterID': currentUserId,
        'reporterVisibility': settings.anonymousReportMode ? 'anonymous' : 'public',
        'publicReporterName': settings.anonymousReportMode ? 'Anonymous' : null,
        // Initial report status
        'status': 'submitted',

        // Location information
        'location': {
          'displayName': addressController.text.trim().isNotEmpty ? addressController.text.trim() : 'No address provided',
          'heading': addressController.text.trim().isNotEmpty ? addressController.text.split(',').first.trim() : 'Selected Location',
          'postcode': postcode.isNotEmpty ? postcode : 'Unknown',
          'postcodeName': postcodeName.isNotEmpty ? postcodeName : 'Unknown',
          'latitude': report.latitude ?? 0.0, // Fallback value if location is unavailable
          'longitude': report.longitude ?? 0.0, // Fallback value if location is unavailable
        },

        // Uploaded image URLs
        'reportImg': imageUrl.isNotEmpty ? [imageUrl] : [],

        // Metadata and timestamp information
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'estimatedResolutionAt': null,
        'statusChangedAt': [DateTime.now(), null, null], // Avoid Firebase array server timestamp conflicts
        // Initial engagement statistics
        'community': {'likes': [], 'comments': []},

        // Completion proof (not available during submission)
        'proofOfCompletion': null,

        // Custom fields
        'addressDetails': addressDetailsController.text.trim(),
        'additionalNotes': additionalNotesController.text.trim(),
        'isUnderReview': true,
      });

      // Close loading indicator after successful submission
      if (!context.mounted) return;
      navigator.pop();

      // Display success dialog
      await showDialog(
        context: navigator.context, // ignore: use_build_context_synchronously
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.3),
        builder: (_) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.0),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle, color: Color(0xFF00C853), size: 50),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Report Successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87, letterSpacing: 0.2),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Submitted',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black87, letterSpacing: 0.2),
                  ),
                  InkWell(
                    onTap: () => navigator.pop(),
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(4),
                      child: Text('Tap anywhere to close', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ).then((_) {
        unawaited(clearDraft());
        resetForm();
        // Return to the home page
        navigator.popUntil((route) => route.isFirst);
      });
    } catch (e) {
      if (isSubmittingReport) {
        navigator.pop(); // Ensure loading dialog is closed on error
      }

      // ignore: use_build_context_synchronously
      showDialog(
        context: navigator.context, // ignore: use_build_context_synchronously
        builder: (_) {
          return AlertDialog(title: const Text('Error'), content: Text('Failed to save database: ${e.toString()}'));
        },
      );
      rethrow;
    } finally {
      isSubmittingReport = false;
      notifyListeners();
    }
  }

  // Reset
  void resetForm() {
    _draftSaveTimer?.cancel();
    report = IssueReportModel();
    categoryController.clear();
    descriptionController.clear();
    addressController.clear();
    addressDetailsController.clear();
    additionalNotesController.clear();
    notifyListeners();
  }

  Future<void> loadDraftIfEnabled() async {
    // if (!AppSettingsService.instance.autoSaveReportDrafts) return;

    final ref = _draftRef();
    if (ref == null) return;

    final snapshot = await ref.get();
    final data = snapshot.data();
    if (data == null) return;

    final savedCategory = data['category']?.toString().trim() ?? '';
    if (savedCategory.isNotEmpty && !categories.contains(savedCategory)) {
      report.category = 'Other';
      categoryController.text = savedCategory;
    } else {
      report.category = savedCategory;
      categoryController.clear();
    }
    report.description = data['description']?.toString() ?? '';
    report.locationName = data['locationName']?.toString() ?? '';
    report.addressDetails = data['addressDetails']?.toString() ?? '';
    report.additionalNotes = data['additionalNotes']?.toString() ?? '';
    report.latitude = _readDouble(data['latitude']);
    report.longitude = _readDouble(data['longitude']);

    if (report.latitude != null && report.longitude != null) {
      currentPosition = LatLng(report.latitude!, report.longitude!);
    }

    descriptionController.text = report.description;
    addressController.text = report.locationName;
    addressDetailsController.text = report.addressDetails;
    additionalNotesController.text = report.additionalNotes;

    notifyListeners();
  }

  Future<void> clearDraft() async {
    _draftSaveTimer?.cancel();
    final ref = _draftRef();
    if (ref == null) return;
    await ref.delete().catchError((_) {});
  }

  // Dispose
  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    categoryController.dispose();
    descriptionController.dispose();
    addressController.dispose();
    addressDetailsController.dispose();
    additionalNotesController.dispose();
    super.dispose();
  }

  void _scheduleDraftSave() {
    // if (!AppSettingsService.instance.autoSaveReportDrafts) return;

    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(_saveDraft());
    });
  }

  Future<void> _saveDraft() async {
    // if (!AppSettingsService.instance.autoSaveReportDrafts) return;

    final ref = _draftRef();
    if (ref == null || !_hasDraftContent) return;

    await ref.set({
      'category': resolvedCategory,
      'description': report.description.trim(),
      'locationName': addressController.text.trim().isNotEmpty ? addressController.text.trim() : report.locationName.trim(),
      'addressDetails': addressDetailsController.text.trim(),
      'additionalNotes': additionalNotesController.text.trim().isNotEmpty ? additionalNotesController.text.trim() : report.additionalNotes.trim(),
      'latitude': report.latitude,
      'longitude': report.longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  bool get _hasDraftContent {
    return resolvedCategory.isNotEmpty ||
        report.description.trim().isNotEmpty ||
        addressController.text.trim().isNotEmpty ||
        addressDetailsController.text.trim().isNotEmpty ||
        additionalNotesController.text.trim().isNotEmpty;
  }

  bool get isOtherCategorySelected => report.category.trim().toLowerCase() == 'other';

  String get resolvedCategory {
    if (isOtherCategorySelected) {
      return categoryController.text.trim();
    }

    return report.category.trim();
  }

  DocumentReference<Map<String, dynamic>>? _draftRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    return _firestore.collection('users').doc(user.uid).collection('reportDrafts').doc('current');
  }

  Future<String> _fetchPostcodeName(String postcode) async {
    final normalizedPostcode = postcode.trim();
    if (normalizedPostcode.isEmpty || normalizedPostcode.toLowerCase() == 'unknown') {
      return '';
    }

    try {
      final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'components': 'postal_code:$normalizedPostcode|country:MY',
        'key': _googleGeocodeApiKey,
      });

      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('Google postcode lookup failed: ${response.statusCode}');
        return '';
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) return '';

      final status = decoded['status']?.toString() ?? '';
      if (status != 'OK') {
        debugPrint('Google postcode lookup returned status: $status');
        return '';
      }

      final results = decoded['results'];
      if (results is! List || results.isEmpty) return '';

      final firstResult = results.first;
      if (firstResult is! Map) return '';

      return _extractPostcodeName(Map<String, dynamic>.from(firstResult), normalizedPostcode);
    } catch (e) {
      debugPrint('Google postcode lookup failed: $e');
      return '';
    }
  }

  String _extractPostcodeName(Map<String, dynamic> result, String postcode) {
    final components = result['address_components'];
    const preferredTypes = [
      'locality',
      'postal_town',
      'sublocality',
      'sublocality_level_1',
      'administrative_area_level_3',
      'administrative_area_level_2',
    ];

    if (components is List) {
      for (final preferredType in preferredTypes) {
        for (final component in components) {
          if (component is! Map) continue;

          final longName = component['long_name']?.toString().trim() ?? '';
          final types = component['types'];
          if (longName.isEmpty || longName == postcode || types is! List) {
            continue;
          }

          final hasPreferredType = types.any((type) => type.toString() == preferredType);
          if (hasPreferredType) return longName;
        }
      }
    }

    final formattedAddress = result['formatted_address']?.toString().trim();
    if (formattedAddress == null || formattedAddress.isEmpty) return '';

    return formattedAddress.split(',').first.trim().replaceFirst(RegExp('^${RegExp.escape(postcode)}\\s*'), '').trim();
  }

  double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // New State for Search Suggestions
  List<Map<String, dynamic>> searchSuggestions = [];
  bool isSearching = false;

  StatusTrackerRepository? get repository => null;

  /// Search locations using the OpenStreetMap Nominatim API
  Future<void> searchAddress(String query) async {
    if (query.isEmpty || query.length < 3) {
      searchSuggestions = [];
      notifyListeners();
      return;
    }

    isSearching = true;
    notifyListeners();

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1');

      final response = await http.get(url, headers: {'User-Agent': 'com.group2.urbanfix'});

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        searchSuggestions = data.map((item) {
          return {'display_name': item['display_name'], 'lat': double.parse(item['lat']), 'lon': double.parse(item['lon'])};
        }).toList();
      }
    } catch (e) {
      debugPrint('Search error: ${e.toString()}');
    } finally {
      isSearching = false;
      notifyListeners();
    }
  }

  // Clear Suggestions
  void clearSuggestions() {
    searchSuggestions = [];
    notifyListeners();
  }
}
