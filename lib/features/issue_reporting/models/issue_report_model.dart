import 'dart:io';

enum ReportAttachmentType { image, video }

class ReportAttachment {
  const ReportAttachment({
    required this.file,
    required this.name,
    required this.type,
  });

  final File file;
  final String name;
  final ReportAttachmentType type;

  String get contentType {
    return switch (type) {
      ReportAttachmentType.image => 'image/jpeg',
      ReportAttachmentType.video => 'video/mp4',
    };
  }
}

class IssueReportModel {
  List<ReportAttachment> attachments;
  String category;
  String description;
  double? latitude;
  double? longitude;
  String locationName;
  String addressDetails;
  String additionalNotes;

  IssueReportModel({
    this.attachments = const [],
    this.category = '',
    this.description = '',
    this.latitude,
    this.longitude,
    this.locationName = '',
    this.addressDetails = '',
    this.additionalNotes = '',
  });
}
