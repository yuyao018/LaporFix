import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  /// Picks an image from the device's photo gallery.
  Future<File?> pickFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null) return null;

      return File(pickedFile.path);
    } catch (e) {
      print("Error picking image from gallery: $e");
      return null;
    }
  }
}
