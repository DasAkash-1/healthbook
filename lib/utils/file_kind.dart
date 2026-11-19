// What kind of file is this, going by its name or path? Decides how the app shows it.
enum FileKind { pdf, image, other }

// Supported image file extensions (compared case-insensitively).
const Set<String> _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};

// Extracts the file extension after the final '.' and maps it to a [FileKind].
FileKind fileKindFor(String pathOrName) {
  final dot = pathOrName.lastIndexOf('.');
  if (dot < 0) return FileKind.other;

  final extension = pathOrName.substring(dot + 1).toLowerCase();
  if (extension == 'pdf') return FileKind.pdf;
  if (_imageExtensions.contains(extension)) return FileKind.image;
  return FileKind.other;
}
