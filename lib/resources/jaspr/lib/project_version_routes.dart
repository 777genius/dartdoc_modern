const projectSiteRootUrl = 'https://777genius.github.io/dartdoc_modern';
const projectVitePressDocsUrl = '$projectSiteRootUrl/vitepress/';
const projectJasprDocsUrl = '$projectSiteRootUrl/jaspr/';
const _sharedApiLibraryDirs = {'dartdoc', 'options'};

String projectVitePressUrlForRoute(String currentRoute) {
  return _buildProjectDocsVersionUrl(
    baseUrl: projectVitePressDocsUrl,
    route: _routeForVitePress(currentRoute),
  );
}

String projectJasprUrlForRoute(String currentRoute) {
  return _buildProjectDocsVersionUrl(
    baseUrl: projectJasprDocsUrl,
    route: _routeForJaspr(currentRoute),
  );
}

String _buildProjectDocsVersionUrl({
  required String baseUrl,
  required String route,
}) {
  final baseUri = Uri.parse(baseUrl);
  final routeUri = Uri.parse(route.isEmpty ? '/' : route);
  final path = _joinBasePath(
    baseUri.path,
    _normalizeRoutePath(
      routeUri.path,
      preserveTrailingSlash:
          routeUri.path.length > 1 && routeUri.path.endsWith('/'),
    ),
  );

  return baseUri
      .replace(
        path: path,
        query: routeUri.hasQuery ? routeUri.query : null,
        fragment: routeUri.hasFragment ? routeUri.fragment : null,
      )
      .toString();
}

String _routeForVitePress(String currentRoute) {
  final routeUri = Uri.parse(currentRoute.isEmpty ? '/' : currentRoute);
  final path = _normalizeRoutePath(routeUri.path);
  final sharedLibraryDir = _sharedApiLibraryDir(path);

  if (path == '/guide' || path == '/guide/' || path.startsWith('/guide/')) {
    return _replaceRoutePath(routeUri, _guideRouteForTarget(path, 'vitepress'))
        .toString();
  }

  if (path == '/api') {
    return _replaceRoutePath(routeUri, '/api/').toString();
  }

  final libraryMatch = RegExp(r'^/api/([^/]+)/library$').firstMatch(path);
  if (libraryMatch != null) {
    final libraryDir = libraryMatch.group(1)!;
    return _replaceRoutePath(
      routeUri,
      _sharedApiLibraryDirs.contains(libraryDir) ? '/api/$libraryDir/' : '/api/',
    ).toString();
  }

  if (path.startsWith('/api/') && sharedLibraryDir == null) {
    return _replaceRoutePath(routeUri, '/api/').toString();
  }

  return _replaceRoutePath(routeUri, path).toString();
}

String _routeForJaspr(String currentRoute) {
  final routeUri = Uri.parse(currentRoute.isEmpty ? '/' : currentRoute);
  final path = _normalizeRoutePath(routeUri.path);
  final sharedLibraryDir = _sharedApiLibraryDir(path);

  if (path == '/guide' || path == '/guide/' || path.startsWith('/guide/')) {
    return _replaceRoutePath(routeUri, _guideRouteForTarget(path, 'jaspr'))
        .toString();
  }

  if (path == '/api') {
    return _replaceRoutePath(routeUri, '/api').toString();
  }

  final segments = path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length == 2 && segments.first == 'api') {
    return _replaceRoutePath(
      routeUri,
      sharedLibraryDir == null ? '/api' : '/api/$sharedLibraryDir/library',
    ).toString();
  }

  if (path.startsWith('/api/') && sharedLibraryDir == null) {
    return _replaceRoutePath(routeUri, '/api').toString();
  }

  return _replaceRoutePath(
    routeUri,
    _apiRouteForJaspr(path, sharedLibraryDir),
  ).toString();
}

String? _sharedApiLibraryDir(String path) {
  final segments = _normalizeRoutePath(path)
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.length < 2 || segments.first != 'api') {
    return null;
  }

  final libraryDir = segments[1];
  return _sharedApiLibraryDirs.contains(libraryDir) ? libraryDir : null;
}

String _guideRouteForTarget(String path, String target) {
  final normalizedPath = _normalizeRoutePath(path);
  if (normalizedPath == '/guide' || normalizedPath == '/guide/') {
    return target == 'jaspr' ? '/guide' : '/guide/';
  }
  if (!normalizedPath.startsWith('/guide/')) {
    return normalizedPath;
  }
  if (target == 'jaspr' && !normalizedPath.endsWith('.html')) {
    return '$normalizedPath.html';
  }
  return normalizedPath;
}

String _apiRouteForJaspr(String path, String? sharedLibraryDir) {
  final normalizedPath = _normalizeRoutePath(path);
  if (!normalizedPath.startsWith('/api/') || sharedLibraryDir == null) {
    return normalizedPath;
  }

  if (normalizedPath.endsWith('.html')) {
    return normalizedPath.substring(0, normalizedPath.length - '.html'.length);
  }

  return normalizedPath;
}

Uri _replaceRoutePath(Uri uri, String path) {
  return uri.replace(path: path);
}

String _joinBasePath(String basePath, String routePath) {
  final normalizedBase = _trimTrailingSlash(basePath);
  if (routePath == '/') {
    return normalizedBase.isEmpty ? '/' : '$normalizedBase/';
  }
  if (normalizedBase.isEmpty) {
    return routePath;
  }
  return '$normalizedBase$routePath';
}

String _normalizeRoutePath(String value, {bool preserveTrailingSlash = false}) {
  if (value.isEmpty || value == '/') return '/';

  var path = value;
  if (!path.startsWith('/')) {
    path = '/$path';
  }
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (preserveTrailingSlash) {
    path = '$path/';
  }
  return path;
}

String _trimTrailingSlash(String value) {
  if (value.isEmpty || value == '/') return '';

  var path = value;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}
