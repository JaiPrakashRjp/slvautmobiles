import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../models/picked_doc.dart';
import '../widgets/doc_upload_tile.dart' show kAllowedDocExtensions;

/// Shared document pickers used by create / edit / detail screens. They capture
/// the file BYTES (not just the name) so uploads work on web, desktop, mobile.

Future<PickedDoc?> pickPhotoDoc() async {
  final img = await ImagePicker().pickImage(source: ImageSource.camera);
  if (img == null) return null;
  final bytes = await img.readAsBytes();
  return PickedDoc(name: img.name, bytes: bytes, mimeType: img.mimeType);
}

Future<PickedDoc?> pickFileDoc() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: kAllowedDocExtensions,
    withData: true,
  );
  final f = result?.files.singleOrNull;
  if (f?.bytes == null) return null;
  return PickedDoc(name: f!.name, bytes: f.bytes!);
}
