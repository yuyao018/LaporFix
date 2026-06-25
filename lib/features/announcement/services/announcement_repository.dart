import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/announcement.dart';

/// Repository for announcement data operations.
/// Handles all Firestore and Firebase Storage interactions.
class AnnouncementRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  AnnouncementRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Stream of all announcements ordered by creation date
  Stream<List<Announcement>> watchAnnouncements() {
    return _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Announcement.fromDoc(doc))
          .where((a) => !a.isDeleted) // Filter out deleted
          .toList();
    });
  }

  /// Get user profile data
  Future<UserProfile?> getUserProfile(String userId) async {
    // Retry a few times in case doc hasn't been written yet
    for (int i = 0; i < 3; i++) {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserProfile.fromDoc(doc);
      }
      if (i < 2) await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  /// Get current user profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    return getUserProfile(userId);
  }

  /// Create a new announcement
  Future<void> createAnnouncement({
    required String title,
    required String caption,
    required String colour,
    required String audience,
    required AnnouncementLocation location,
    required List<File> attachmentFiles,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Upload attachments if any
    final attachments = await _uploadAttachments(attachmentFiles);

    // Create announcement document
    await _firestore.collection('announcements').add({
      'title': title,
      'caption': caption,
      'colour': colour,
      'announcerID': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'fcmSent': false,
      'isDeleted': false,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'target': {
        'audience': audience,
        'location': location.toMap(),
      },
    });
  }

  /// Update an existing announcement
  Future<void> updateAnnouncement({
    required String announcementId,
    required String title,
    required String caption,
    required String colour,
    required String audience,
    required AnnouncementLocation location,
    List<AnnouncementAttachment>? existingAttachments,
    List<File>? newAttachmentFiles,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    // Upload new attachments if any
    List<AnnouncementAttachment> allAttachments = existingAttachments ?? [];
    if (newAttachmentFiles != null && newAttachmentFiles.isNotEmpty) {
      final newAttachments = await _uploadAttachments(newAttachmentFiles);
      allAttachments = [...allAttachments, ...newAttachments];
    }

    // Update announcement document
    await _firestore.collection('announcements').doc(announcementId).update({
      'title': title,
      'caption': caption,
      'colour': colour,
      'attachments': allAttachments.map((a) => a.toMap()).toList(),
      'target': {
        'audience': audience,
        'location': location.toMap(),
      },
    });
  }

  /// Soft delete an announcement
  Future<void> deleteAnnouncement(String announcementId) async {
    await _firestore.collection('announcements').doc(announcementId).update({
      'isDeleted': true,
    });
  }

  /// Get a single announcement by ID
  Future<Announcement?> getAnnouncement(String announcementId) async {
    final doc =
        await _firestore.collection('announcements').doc(announcementId).get();
    if (!doc.exists) return null;
    return Announcement.fromDoc(doc);
  }

  /// Upload attachment files to Firebase Storage
  Future<List<AnnouncementAttachment>> _uploadAttachments(
    List<File> files,
  ) async {
    final List<AnnouncementAttachment> attachments = [];

    for (final file in files) {
      final fileName = file.path.split('/').last;
      final ref = _storage.ref().child('announcements').child(
            '${DateTime.now().millisecondsSinceEpoch}_$fileName',
          );

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      // Determine type from file extension
      String type = 'document';
      final ext = fileName.split('.').last.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
        type = 'image';
      } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
        type = 'video';
      }

      attachments.add(AnnouncementAttachment(
        url: url,
        name: fileName,
        type: type,
      ));
    }

    return attachments;
  }

  /// Delete attachment from storage
  Future<void> deleteAttachment(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // Ignore if file doesn't exist
    }
  }
}
