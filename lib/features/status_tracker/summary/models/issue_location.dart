// model for the nested location map
class IssueLocation {
  const IssueLocation({
    required this.heading,
    required this.postcode,
    required this.coordinates,
  });

  final String heading;
  final String postcode;
  final List<String> coordinates;

  factory IssueLocation.fromMap(Map<String, dynamic>? map) {
    final rawCoordinates = map?['precise_location'];

    return IssueLocation(
      heading: _readString(map?['heading']),
      postcode: _readString(map?['postcode']),
      coordinates: _readCoordinates(rawCoordinates),
    );
  }

  String get displayName {
    if (heading.isNotEmpty) return heading;
    if (postcode.isNotEmpty) return postcode;
    if (coordinates.isNotEmpty) return coordinates.join(', ');
    return 'Location unavailable';
  }

  static String _readString(Object? value) => value?.toString().trim() ?? '';

  static List<String> _readCoordinates(Object? value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    final text = value?.toString().trim();
    return text == null || text.isEmpty ? const [] : [text];
  }
}
