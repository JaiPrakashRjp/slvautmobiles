/// App configuration — the single place to point the app at a backend.
///
/// The backend base URL comes from a compile-time variable named
/// `API_BASE_URL`. In local development the default below (localhost) is used.
///
/// To run/build against a different backend (e.g. production), pass it on the
/// command line — no code change needed:
///
///   flutter run   --dart-define=API_BASE_URL=https://api.slvauto.com
///   flutter build --dart-define=API_BASE_URL=https://api.slvauto.com
///
/// NOTE on the localhost default:
///   • Web / Windows desktop / iOS simulator → http://127.0.0.1:8000 works.
///   • Android emulator → use http://10.0.2.2:8000 (the emulator's alias for
///     the host machine). Pass it with --dart-define when running on Android.
///   • Real phone → use your PC's LAN IP, e.g. http://192.168.1.5:8000.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
