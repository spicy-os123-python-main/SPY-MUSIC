/// Centralized application version definitions.
/// Keeps the application version synchronized and prevents stale version lookups.
class AppVersion {
  /// The compiled application version (matches pubspec.yaml)
  static const String current = "v1.12.90";
  static const int buildNumber = 3094;

  static String _loadedVersion = current;

  /// Current active version string, e.g. "v1.12.90"
  static String get value => _loadedVersion;

  /// Clean numeric version string, e.g. "1.12.90"
  static String get clean => cleanString(value);

  /// Full version with build number, e.g. "v1.12.90+3094"
  static String get full => "$current+$buildNumber";

  /// Strips 'v' and build numbers for comparison
  static String cleanString(String version) {
    return version.toLowerCase().replaceAll('v', '').split('+').first.trim();
  }

  /// Compares two semver strings (supports "v1.2.3" and "v1.2.3+456")
  /// Returns true if [remoteVersion] is strictly newer than [currentVersion]
  static bool isNewer(String remoteVersion, String currentVersion) {
    try {
      final remoteClean = cleanString(remoteVersion);
      final currentClean = cleanString(currentVersion);

      final rParts = remoteClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (rParts.length < 3) {
        rParts.add(0);
      }
      while (cParts.length < 3) {
        cParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (rParts[i] > cParts[i]) return true;
        if (rParts[i] < cParts[i]) return false;
      }

      // Check build numbers if base versions are equal
      final rBuild = _extractBuildNumber(remoteVersion);
      final cBuild = _extractBuildNumber(currentVersion);
      if (rBuild != null && cBuild != null) {
        return rBuild > cBuild;
      }
    } catch (_) {}
    return false;
  }

  static int? _extractBuildNumber(String version) {
    if (!version.contains('+')) return null;
    final parts = version.split('+');
    if (parts.length > 1) {
      return int.tryParse(parts[1].trim());
    }
    return null;
  }

  /// Updates the version when resolved asynchronously from [PackageInfo]
  static void updateFromPackageInfo(String version) {
    final v = version.trim();
    if (v.isNotEmpty) {
      _loadedVersion = v.startsWith('v') ? v : 'v$v';
    }
  }
}
