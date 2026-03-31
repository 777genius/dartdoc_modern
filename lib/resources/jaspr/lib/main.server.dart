import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'app.dart';
import 'main.server.options.dart';
import 'template_engine/docs_template_engine.dart';
import 'theme/docs_theme.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);
  const themeName = String.fromEnvironment('DOCS_THEME', defaultValue: 'ocean');
  final themePreset = DocsThemePresetX.parse(themeName);

  runApp(
    Document(
      head: [
        link(
          href: '/generated/api_styles.css',
          rel: 'stylesheet',
        ),
      ],
      body: div(
        [
          buildDocsApp(
            packageName: '{{packageName}}',
            themePreset: themePreset,
            templateEngine: DocsTemplateEngine(),
          ),
        ],
      ),
    ),
  );
}
