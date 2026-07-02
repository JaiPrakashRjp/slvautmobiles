import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_text_styles.dart';

/// In-app document preview + share. Renders images (png/jpg/jpeg/heic) with
/// pinch-zoom and PDFs with a scrollable viewer. Bytes are loaded from the
/// backend via [loader]; the Share button hands the file to the OS share sheet
/// (WhatsApp / email / Drive …).
class DocumentPreviewScreen extends StatefulWidget {
  const DocumentPreviewScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.loader,
  });

  final String title;
  final String fileName;
  final Future<Uint8List> Function() loader;

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  bool get _isPdf => widget.fileName.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await widget.loader();
      if (!mounted) return;
      setState(() {
        _bytes = b;
        _loading = false;
        _error = b.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  String _mime() {
    final f = widget.fileName.toLowerCase();
    if (f.endsWith('.pdf')) return 'application/pdf';
    if (f.endsWith('.png')) return 'image/png';
    if (f.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _share() async {
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) return;
    final name = widget.fileName.isEmpty ? 'document' : widget.fileName;
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: name, mimeType: _mime())],
      subject: widget.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ready = _bytes != null && !_error && _bytes!.isNotEmpty;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (ready)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: _share,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !ready
              ? _message(context, 'Could not load this document.')
              : _isPdf
                  ? PdfPreview(
                      build: (_) => _bytes!,
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                      pdfFileName: widget.fileName,
                    )
                  : InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Center(
                        child: Image.memory(
                          _bytes!,
                          errorBuilder: (_, __, ___) => _message(
                            context,
                            "This image format can't be previewed on this device.",
                          ),
                        ),
                      ),
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
