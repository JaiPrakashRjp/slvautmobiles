import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';

/// In-app document preview. Renders images (png/jpg/jpeg/heic) with pinch-zoom
/// and PDFs with a scrollable viewer. The bytes are loaded from the backend via
/// [loader] (so nothing is written to disk / opened externally).
class DocumentPreviewScreen extends StatelessWidget {
  const DocumentPreviewScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.loader,
  });

  final String title;
  final String fileName;
  final Future<Uint8List> Function() loader;

  bool get _isPdf => fileName.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<Uint8List>(
        future: loader(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null || snap.data!.isEmpty) {
            return _message(context, 'Could not load this document.');
          }
          final bytes = snap.data!;
          if (_isPdf) {
            return PdfPreview(
              build: (_) => bytes,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: fileName,
            );
          }
          // Images (png / jpg / jpeg / heic). HEIC may not decode on every
          // platform — fall back to a clear message if it can't.
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 5,
            child: Center(
              child: Image.memory(
                bytes,
                errorBuilder: (_, __, ___) => _message(
                  context,
                  "This image format can't be previewed on this device.",
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _message(BuildContext context, String text) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, size: 48, color: c.textSub),
            const SizedBox(height: AppSpacing.md),
            Text(text,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: c.textSub)),
          ],
        ),
      ),
    );
  }
}
