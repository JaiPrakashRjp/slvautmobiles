import 'package:package_info_plus/package_info_plus.dart';

import 'api_client.dart';

/// Result of an update check.
class AppUpdateInfo {
  AppUpdateInfo({
    required this.updateAvailable,
    required this.latest,
    required this.current,
    required this.downloadUrl,
    required this.notes,
    required this.mandatory,
  });

  final bool updateAvailable;
  final String latest;
  final String current;
  final String downloadUrl; // absolute
  final String notes;
  final bool mandatory;
}

/// Checks the backend `/app-version` against the installed app's version and
/// tells the login screen whether to prompt for an update.
class AppVersionService {
  AppVersionService({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  Future<AppUpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;
      final data = await _api.get('/app-version') as Map<String, dynamic>;
      final latest = (data['latest_version'] as String?) ?? current;
      final path = (data['download_path'] as String?) ?? '';
      final downloadUrl =
          path.startsWith('http') ? path : _api.absoluteUrl(path);
      return AppUpdateInfo(
        updateAvailable: _isNewer(latest, current),
        latest: latest,
        current: current,
        downloadUrl: downloadUrl,
        notes: (data['notes'] as String?) ?? '',
        mandatory: (data['mandatory'] as bool?) ?? false,
      );
    } catch (_) {
      return null; // offline / not reachable → no prompt
    }
  }

  /// True if [latest] is a higher dotted version than [current] (e.g. 1.0.4 > 1.0.3).
  static bool _isNewer(String latest, String current) {
    final a = latest.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    final b =
        current.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();
    for (var i = 0; i < a.length || i < b.length; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
