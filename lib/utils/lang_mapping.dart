const Map<String, String> langMap = {
  "en": "English",
  "de": "Deutsch",
  "it": "Italiano",
  "es": "Español",
  "fr": "Français",
  "nl": "Nederlands",
};

/// Normalizes persisted or locale-derived language codes to one of the 6
/// supported languages (`en`, `de`, `it`, `es`, `fr`, `nl`), defaulting to `en`.
String normalizeSupportedLanguageCode(String? code) {
  if (code == null || code.trim().isEmpty) return "en";
  final normalized = code.trim().replaceAll('-', '_').toLowerCase();
  final base = normalized.split('_').first;
  if (langMap.containsKey(normalized)) return normalized;
  if (langMap.containsKey(base)) return base;
  return "en";
}
