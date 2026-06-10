import 'package:path/path.dart' as p;

class EpubPathResolver {
  const EpubPathResolver._();

  static List<String> imagePathCandidates({
    required String chapterPath,
    required String opfDir,
    required String source,
  }) {
    final path = sourcePath(source);
    if (path == null || path.isEmpty) {
      return const [];
    }

    final candidates = <String>[
      if (!path.startsWith('/'))
        p.posix.join(p.posix.dirname(chapterPath), path),
      if (opfDir.isNotEmpty && opfDir != '.') p.posix.join(opfDir, path),
      path,
    ];

    return candidates
        .map(normalizeArchivePath)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String? sourcePath(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.scheme.isNotEmpty) {
      if (parsed.scheme == 'file') {
        return _decodePath(parsed.toFilePath(windows: false));
      }
      return null;
    }

    final withoutFragment = trimmed.split('#').first;
    final withoutQuery = withoutFragment.split('?').first;
    return _decodePath(withoutQuery);
  }

  static String outputRelativePath({
    required String archivePath,
    required String opfDir,
  }) {
    final normalizedArchivePath = normalizeArchivePath(archivePath);
    final normalizedOpfDir = normalizeArchivePath(opfDir);
    final relPath = normalizedOpfDir.isEmpty || normalizedOpfDir == '.'
        ? normalizedArchivePath
        : p.posix.isWithin(normalizedOpfDir, normalizedArchivePath) ||
                normalizedArchivePath.startsWith('$normalizedOpfDir/')
            ? p.posix.relative(normalizedArchivePath, from: normalizedOpfDir)
            : normalizedArchivePath;

    final safeSegments = p.posix
        .split(relPath)
        .where((segment) =>
            segment.isNotEmpty && segment != '.' && segment != '..')
        .map(_safeLocalSegment)
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    return safeSegments.isEmpty
        ? p.posix.basename(normalizedArchivePath)
        : p.joinAll(safeSegments);
  }

  static String normalizeArchivePath(String path) {
    var normalized = path.replaceAll(r'\', '/').trim();
    while (normalized.startsWith('./')) {
      normalized = normalized.substring(2);
    }
    normalized = p.posix.normalize(normalized).replaceAll(r'\', '/');
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    while (normalized.startsWith('../')) {
      normalized = normalized.substring(3);
    }
    return normalized == '.' ? '' : normalized;
  }

  static String _decodePath(String path) {
    try {
      return Uri.decodeFull(path);
    } on FormatException {
      return path;
    }
  }

  static String _safeLocalSegment(String segment) {
    return segment.replaceAll(RegExp(r'[<>:"\\|?*\x00-\x1F]'), '_');
  }
}
