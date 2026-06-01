import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:group2_urbanfix/features/status_tracker/summary/data/status_tracker_repository.dart';
import 'package:latlong2/latlong.dart';
import '../models/issue_report_model.dart';
import '../services/image_service.dart';
import '../services/location_service.dart';
import '../issue_reporting_map.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geocoding/geocoding.dart';

class IssueReportingViewModel extends ChangeNotifier {
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
  final TextEditingController additionalNotesController =
      TextEditingController();

  // State
  bool isLoadingLocation = true;
  bool isSubmittingReport = false;

  // MAP State (OpenStreetMap uses latlong2 LatLng)
  LatLng currentPosition = const LatLng(5.3630, 100.4667);

  // Category List
  final List<String> categories = [
    'Pothole',
    'Broken Street Light',
    'Power Outage',
    'Water Leakage',
    'Road Damage',
    'Traffic Light Problem',
    'Garbage Overflow',
    'Other',
  ];

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

      String address = await _locationService.getAddress(
        position.latitude,
        position.longitude,
      );

      // Save into model
      report.latitude = position.latitude;
      report.longitude = position.longitude;
      report.locationName = address;

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
    notifyListeners();
  }

  // Manual address input
  void setAddress(String value) {
    report.locationName = value;
  }

  // UPDATE FORM DATA
  void updateCategory(String? value) {
    report.category = value ?? '';
    notifyListeners();
  }

  void updateDescription(String value) {
    report.description = value;
    notifyListeners();
  }

  void updateAdditionalNotes(String value) {
    report.additionalNotes = value;
    notifyListeners();
  }

  // Validate image, category, and description fields
  bool validateStepOne() {
    return report.image != null &&
        report.category.isNotEmpty &&
        report.description.isNotEmpty;
  }

  // Validate location information
  bool validateStepTwo() {
    return addressController.text.isNotEmpty;
  }

  // Submit issue report to Firebase Storage and Firestore
  Future<void> submitReport(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    String postcode = '';

    try {
      if (report.latitude != null && report.longitude != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          report.latitude!,
          report.longitude!,
        );

        if (placemarks.isNotEmpty) {
          postcode = placemarks.first.postalCode ?? '';
        }
      }
    } catch (e) {
      debugPrint('Postcode fetch failed: $e');
    }
    try {
      isSubmittingReport = true;
      notifyListeners();

      // Show loading indicator while submitting report
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // STEP A: Upload image to Firebase Storage
      String imageUrl = '';
      if (report.image != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
          'issue_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );

        UploadTask uploadTask = storageRef.putFile(report.image!);
        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      }

      // STEP B: Save report data to Firestore 'issue' collection
      final String currentUserId =
          FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
      String uniqueIssueId =
          'ID${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

      // Save report into the required 'issue' collection！
      await _firestore.collection('issue').add({
        // Basic report information
        'title': report.category.isEmpty
            ? categoryController.text
            : report.category,
        'category': report.category.isEmpty
            ? categoryController.text
            : report.category,
        'description': report.description.isEmpty
            ? descriptionController.text
            : report.description,
        'reporterID': currentUserId,
        // Initial report status
        'status': 'submitted',

        // Location information
        'location': {
          'displayName': addressController.text.trim().isNotEmpty
              ? addressController.text.trim()
              : 'No address provided',
          'heading': addressController.text.trim().isNotEmpty
              ? addressController.text.split(',').first.trim()
              : 'Selected Location',
          'postcode': postcode.isNotEmpty ? postcode : 'Unknown',
          'latitude':
              report.latitude ??
              0.0, // Fallback value if location is unavailable
          'longitude':
              report.longitude ??
              0.0, // Fallback value if location is unavailable
        },

        // Uploaded image URLs
        'reportImg': imageUrl.isNotEmpty ? [imageUrl] : [],

        // Metadata and timestamp information
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'estimatedResolutionAt': null,
        'statusChangedAt': [
          DateTime.now(),
          null,
          null,
        ], // Avoid Firebase array server timestamp conflicts
        // Initial engagement statistics
        'comment': {'likesCount': 0, 'commentCount': 0},

        // Completion proof (not available during submission)
        'proofOfCompletion': null,

        // Custom fields
        'additionalNotes': additionalNotesController.text,
        'isUnderReview': true,
      });

      // Close loading indicator after successful submission
      navigator.pop();

      // Display success dialog
      await showDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withOpacity(0.3),
        builder: (_) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 40),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black.withOpacity(0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF00C853),
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Report Successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Submitted',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                  InkWell(
                    onTap: () => navigator.pop(),
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        'Tap anywhere to close',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ).then((_) {
        resetForm();
        // Return to the home page
        navigator.popUntil((route) => route.isFirst);
      });
    } catch (e) {
      if (isSubmittingReport) {
        navigator.pop(); // Ensure loading dialog is closed on error
      }

      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to save database: ${e.toString()}'),
          );
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
    report = IssueReportModel();
    categoryController.clear();
    descriptionController.clear();
    addressController.clear();
    additionalNotesController.clear();
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    categoryController.dispose();
    descriptionController.dispose();
    addressController.dispose();
    additionalNotesController.dispose();
    super.dispose();
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
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.group2.urbanfix'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        searchSuggestions = data.map((item) {
          return {
            'display_name': item['display_name'],
            'lat': double.parse(item['lat']),
            'lon': double.parse(item['lon']),
          };
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
