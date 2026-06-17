import 'dart:typed_data';

/// A file the user picked (camera capture or file upload) held in memory,
/// ready to be uploaded to the backend. We keep the raw [bytes] (not just a
/// path) so uploads work the same on web, desktop and mobile.
class PickedDoc {
  const PickedDoc({required this.name, required this.bytes, this.mimeType});

  final String name;
  final Uint8List bytes;
  final String? mimeType;

  /// Best-effort MIME type from a file name's extension, used when the picker
  /// doesn't supply one. Covers the allowed upload types
  /// (see `kAllowedDocExtensions`).
  static String mimeFor(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'heic' => 'image/heic',
      _ => 'application/octet-stream',
    };
  }
}
