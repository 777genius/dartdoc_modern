import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'app.dart';
import 'docs_base.dart';
import 'main.server.options.dart';
import 'template_engine/docs_template_engine.dart';
import 'theme/docs_theme.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);
  const themeName = String.fromEnvironment('DOCS_THEME', defaultValue: 'ocean');
  final themePreset = DocsThemePresetX.parse(themeName);

  runApp(
    Document(
      base: hasDocsBasePath ? '$docsBasePath/' : '/',
      head: [
        link(
          href: withDocsBasePath('/generated/api_styles.css'),
          rel: 'stylesheet',
        ),
        link(
          href: withDocsBasePath('/favicon.svg'),
          rel: 'icon',
          attributes: {'type': 'image/svg+xml'},
        ),
      ],
      body: div(
        [
          buildDocsApp(
            packageName: '{{packageName}}',
            themePreset: themePreset,
            repositoryUrl: '{{repositoryUrl}}',
            templateEngine: DocsTemplateEngine(),
          ),
        ],
      ),
    ),
  );
}
