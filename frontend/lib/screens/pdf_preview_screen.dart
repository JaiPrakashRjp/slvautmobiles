import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// In-app preview for a generated PDF (invoice / buyer invoice). Renders the
/// document and shows Share + Print actions in its toolbar, so the user can
/// send it (WhatsApp / email / Drive) straight from the preview — no separate
/// share button needed on the calling screen.
class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.builder,
    this.fileName,
  });

  final String title;

  /// Builds the PDF bytes (rebuilt on open, so any edit is reflected).
  final Future<Uint8List> Function() builder;

  /// Suggested name for the shared/saved file.
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (_) => builder(),
        allowSharing: true,
        allowPrinting: true,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: fileName,
      ),
    );
  }
}
