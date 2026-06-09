// model for the nested location map
class IssueLocation {
  const IssueLocation({required this.postcodeName, required this.postcode, required this.coordinates});

  final String postcodeName;
  final String postcode;
  final List<String> coordinates;

  factory IssueLocation.fromMap(Map<String, dynamic>? map) {
    final rawCoordinates = map?['precise_location'];

    return IssueLocation(
      postcodeName: _readString(map?['postcodeName']),
      postcode: _readString(map?['postcode']),
      coordinates: _readCoordinates(rawCoordinates),
    );
  }

  String get displayName {
    if (postcodeName.isNotEmpty) return postcodeName;
    if (postcode.isNotEmpty) return postcode;
    if (coordinates.isNotEmpty) return coordinates.join(', ');
    return 'Location unavailable';
  }

  static String _readString(Object? value) => value?.toString().trim() ?? '';

  static List<String> _readCoordinates(Object? value) {
    if (value is Iterable) {
      return value.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList(growable: false);
    }

    final text = value?.toString().trim();
    return text == null || text.isEmpty ? const [] : [text];
  }
}
