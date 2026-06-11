// model for the nested location map
class IssueLocation {
  const IssueLocation({required this.postcodeName, required this.postcode});

  final String postcodeName;
  final String postcode;

  factory IssueLocation.fromMap(Map<String, dynamic>? map) {
    return IssueLocation(
      postcodeName: _readString(map?['postcodeName']),
      postcode: _readString(map?['postcode']),
    );
  }

  String get displayName {
    if (postcodeName.isNotEmpty) return postcodeName;
    if (postcode.isNotEmpty) return postcode;
    return 'Location unavailable';
  }

  static String _readString(Object? value) => value?.toString().trim() ?? '';
}
