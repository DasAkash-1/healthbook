import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../utils/app_colors.dart';
import '../utils/file_kind.dart';

// Shows a PDF or an image that a patient uploaded.
//
// TODO(backend): uploaded files will live in cloud storage. Until then only the path on
// the phone that picked the file is kept, so the file can only be opened on that phone.
// Once files are stored online, download the file (or open its link) here instead of
// reading [path].
class FileViewerScreen extends StatelessWidget {
  final String title;
  final String path;
  final String? subtitle;

  const FileViewerScreen({
    super.key,
    required this.title,
    required this.path,
    this.subtitle,
  });

  Widget _message(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _content() {
    if (path.isEmpty || !File(path).existsSync()) {
      return _message(
        'This file cannot be found on this phone. It may have been moved or '
        'deleted, or it was uploaded from another phone. Upload it again to view it.',
      );
    }

    switch (fileKindFor(path)) {
      case FileKind.pdf:
        return PdfViewer.file(path);
      case FileKind.image:
        return InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Center(
            child: Image.file(
              File(path),
              errorBuilder: (context, error, stackTrace) =>
                  _message('This image could not be opened.'),
            ),
          ),
        );
      case FileKind.other:
        return _message(
          'This file type cannot be shown in the app yet. '
          'Only PDFs and images (PNG, JPG) can be opened.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 14, color: kTextMuted),
                  ),
                ),
              ),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }
}
