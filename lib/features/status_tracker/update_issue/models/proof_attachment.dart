import 'dart:io';

// supported proof file types
enum ProofAttachmentType { image, video }

// file selected by the updater
class ProofAttachment {
  const ProofAttachment({
    required this.file,
    required this.name,
    required this.type,
  });

  final File file;
  final String name;
  final ProofAttachmentType type;

  // storage metadata used when uploading proof files
  String get contentType {
    return switch (type) {
      ProofAttachmentType.image => 'image/jpeg',
      ProofAttachmentType.video => 'video/mp4',
    };
  }
}
