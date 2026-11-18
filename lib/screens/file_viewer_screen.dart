import 'dart:io';

import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

// Shows an image that a patient uploaded, with pinch to zoom.
// PDFs are opened in the phone's own PDF reader instead (see openUploadedFile).
//
// TODO(backend): uploaded files will live in cloud storage. Until then only the path on
// the phone that picked the file is kept, so the file can only be opened on that phone.
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
            Expanded(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5,
                child: Center(
                  child: Image.file(
                    File(path),
                    errorBuilder: (context, error, stackTrace) =>
                        _message('This image could not be opened.'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
