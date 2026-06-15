// model for the nested location map
class IssueLocation {
  const IssueLocation({
    required this.postcodeName,
    required this.postcode,
    this.displayNameOverride,
    this.heading,
  });

  final String postcodeName;
  final String postcode;
  final String? displayNameOverride; // The actual address from search
  final String? heading; // Short location name

  factory IssueLocation.fromMap(Map<String, dynamic>? map) {
    return IssueLocation(
      postcodeName: _readString(map?['postcodeName']),
      postcode: _readString(map?['postcode']),
      displayNameOverride: _readString(map?['displayName']),
      heading: _readString(map?['heading']),
    );
  }

  String get displayName {
    // Priority: actual address > heading > postcodeName > postcode > fallback
    if (displayNameOverride != null && displayNameOverride!.isNotEmpty && displayNameOverride != 'Unknown') {
      return displayNameOverride!;
    }
    if (heading != null && heading!.isNotEmpty && heading != 'Unknown') {
      return heading!;
    }
    if (postcodeName.isNotEmpty && postcodeName != 'Unknown') {
      return postcodeName;
    }
    if (postcode.isNotEmpty && postcode != 'Unknown') {
      return postcode;
    }
    return 'Location unavailable';
  }

  static String _readString(Object? value) => value?.toString().trim() ?? '';
}
