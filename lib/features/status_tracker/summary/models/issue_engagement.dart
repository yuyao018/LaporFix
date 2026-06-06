/// Counts the engagement data stored inside the nested `comment` map.
class IssueEngagement {
  const IssueEngagement({required this.commentCount, required this.likesCount});

  final int commentCount;
  final int likesCount;

  factory IssueEngagement.fromMap(Map<String, dynamic>? map) {
    return IssueEngagement(
      commentCount: _readList(map?['comments']).length,
      likesCount: _readList(map?['likes']).length,
    );
  }

  static List<Object?> _readList(Object? value) {
    if (value is Iterable) return value.toList(growable: false);
    return const [];
  }
}
