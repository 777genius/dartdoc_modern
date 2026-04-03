import 'languages/common.dart';
import 'src/highlightv2.dart';
import 'src/html_renderer.dart' show scopeToCSSClass;
import 'src/language.dart';
import 'src/result.dart';

export 'src/node.dart';
export 'src/result.dart';

final docsHighlight = DocsHighlightEngine._();

class DocsHighlightEngine {
  DocsHighlightEngine._();

  static const _manualAliases = <String, String>{
    'console': 'shell',
    'shellsession': 'shell',
    'text': 'plaintext',
    'txt': 'plaintext',
    'yml': 'yaml',
    'zsh': 'bash',
  };

  final HighlightV2 _engine = HighlightV2();
  late final Map<String, String> _aliases = _buildAliases();

  String? canonicalize(String? languageId) {
    final normalized = languageId?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    return _aliases[normalized];
  }

  bool supports(String? languageId) => canonicalize(languageId) != null;

  Result highlight(String source, {required String languageId}) {
    final canonical = canonicalize(languageId);
    if (canonical == null) {
      return _engine.justTextHighlightResult(source);
    }
    return _engine.parse(source, languageId: canonical);
  }

  String scopeToCssClasses(String scope) => scopeToCSSClass(scope, 'hljs-');

  Map<String, String> _buildAliases() {
    final aliases = <String, String>{};

    void register(Language language) {
      aliases[language.id.toLowerCase()] = language.id;
      for (final alias in language.aliases) {
        aliases[alias.toLowerCase()] = language.id;
      }
    }

    for (final language in builtinLanguages.values) {
      register(language);
    }

    aliases.addAll(_manualAliases);
    return aliases;
  }
}
