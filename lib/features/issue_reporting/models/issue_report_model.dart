import 'dart:io';

class IssueReportModel {
  File? image;
  String category;
  String description;
  double? latitude;
  double? longitude;
  String locationName;
  String addressDetails;
  String additionalNotes;

  IssueReportModel({
    this.image,
    this.category = '',
    this.description = '',
    this.latitude,
    this.longitude,
    this.locationName = '',
    this.addressDetails = '',
    this.additionalNotes = '',
  });
}
