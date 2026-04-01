String get docsBasePath {
  const raw = String.fromEnvironment('DOCS_BASE_PATH', defaultValue: '');
  return _normalizeDocsBasePath(raw);
}

bool get hasDocsBasePath => docsBasePath.isNotEmpty;

String withDocsBasePath(String path) {
  if (path.isEmpty) return docsBasePath.isEmpty ? '/' : docsBasePath;
  if (_isExternalPath(path)) return path;
  if (path.startsWith('#')) return path;

  final basePath = docsBasePath;
  final normalizedPath = _normalizeRoutePath(path);
  if (basePath.isEmpty) return normalizedPath;
  if (normalizedPath == '/') return basePath;
  if (normalizedPath == basePath || normalizedPath.startsWith('$basePath/')) {
    return normalizedPath;
  }
  return '$basePath$normalizedPath';
}

String stripDocsBasePath(String path) {
  if (path.isEmpty) return '/';
  if (_isExternalPath(path)) return path;
  if (path.startsWith('#')) return path;

  final basePath = docsBasePath;
  final normalizedPath = _normalizeRoutePath(path);
  if (basePath.isEmpty || normalizedPath == '/') return normalizedPath;
  if (normalizedPath == basePath) return '/';
  if (normalizedPath.startsWith('$basePath/')) {
    return normalizedPath.substring(basePath.length);
  }
  return normalizedPath;
}

String _normalizeDocsBasePath(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '/') return '';

  var path = trimmed;
  if (!path.startsWith('/')) {
    path = '/$path';
  }
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

String _normalizeRoutePath(String value) {
  if (value.isEmpty) return '/';
  if (value == '/') return '/';

  var path = value;
  if (!path.startsWith('/')) {
    path = '/$path';
  }
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

bool _isExternalPath(String value) {
  return value.startsWith('http://') ||
      value.startsWith('https://') ||
      value.startsWith('mailto:') ||
      value.startsWith('tel:');
}
