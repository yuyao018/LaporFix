String communityNameForDisplay(
  String? rawName, {
  required bool maskName,
  String fallback = 'Resident',
}) {
  final trimmedName = rawName?.trim() ?? '';
  final displayName = trimmedName.isNotEmpty ? trimmedName : fallback;

  if (!maskName) return displayName;
  if (displayName.isEmpty) return displayName;

  return '${String.fromCharCode(displayName.runes.first)}****';
}
