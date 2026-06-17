import 'enums.dart';

/// A single KYC document attached to a customer (Aadhaar / DL / PAN / photo).
class KycDocument {
  KycDocument({required this.type, this.imagePath});

  final KycDocType type;

  /// Local file path (mock) or storage URL (Phase 7). Null = requested but not
  /// yet captured.
  String? imagePath;

  bool get isCaptured => imagePath != null && imagePath!.isNotEmpty;
}
