import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../screens/file_viewer_screen.dart';
import '../utils/file_kind.dart';

const String _missingFileMessage =
    'This file cannot be found on this phone. It may have been moved or deleted, '
    'or it was uploaded from another phone. Upload it again to view it.';

// Opens a file the patient uploaded. Images open inside the app. PDFs (and anything
// else) open in the phone's own app for that file type, such as a PDF reader.
//
// TODO(backend): files will live in cloud storage. Download the file (or open its link)
// here instead of reading a path on this phone.
Future<void> openUploadedFile(
  BuildContext context, {
  required String title,
  required String path,
  String? subtitle,
}) async {
  // Take these before any waiting, so the context is not used after an await.
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  // Verify a non-empty local file path exists before attempting to open it.
  if (path.isEmpty || !File(path).existsSync()) {
    messenger.showSnackBar(const SnackBar(content: Text(_missingFileMessage)));
    return;
  }

  // Render image attachments directly in the in-app viewer.
  if (fileKindFor(path) == FileKind.image) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => FileViewerScreen(title: title, path: path, subtitle: subtitle),
      ),
    );
    return;
  }

  // Delegate PDFs and other documents to the OS handler and map failure cases cleanly.
  final result = await OpenFilex.open(path);
  if (result.type == ResultType.done) return;

  final message = switch (result.type) {
    ResultType.noAppToOpen =>
      'No app on this phone can open this file. Install a PDF reader, then try again.',
    ResultType.fileNotFound => _missingFileMessage,
    ResultType.permissionDenied => 'Healthbook is not allowed to open this file.',
    _ => 'The file could not be opened.',
  };
  messenger.showSnackBar(SnackBar(content: Text(message)));
}
