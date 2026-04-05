const projectSiteRootUrl = 'https://777genius.github.io/dartdoc_modern';
const projectVitePressDocsUrl = '$projectSiteRootUrl/vitepress/';
const projectJasprDocsUrl = '$projectSiteRootUrl/jaspr/';

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

  if (path == '/api') {
    return _replaceRoutePath(routeUri, '/api/').toString();
  }

  final libraryMatch = RegExp(r'^/api/([^/]+)/library$').firstMatch(path);
  if (libraryMatch != null) {
    return _replaceRoutePath(
      routeUri,
      '/api/${libraryMatch.group(1)!}/',
    ).toString();
  }

  return _replaceRoutePath(routeUri, path).toString();
}

String _routeForJaspr(String currentRoute) {
  final routeUri = Uri.parse(currentRoute.isEmpty ? '/' : currentRoute);
  final path = _normalizeRoutePath(routeUri.path);

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
      '/api/${segments[1]}/library',
    ).toString();
  }

  return _replaceRoutePath(routeUri, path).toString();
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
