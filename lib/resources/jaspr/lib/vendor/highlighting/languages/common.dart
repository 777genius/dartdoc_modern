import '../src/language.dart';
import 'bash.dart';
import 'css.dart';
import 'dart.dart';
import 'diff.dart';
import 'dockerfile.dart';
import 'ini.dart';
import 'javascript.dart';
import 'json.dart';
import 'markdown.dart';
import 'plaintext.dart';
import 'shell.dart';
import 'sql.dart';
import 'typescript.dart';
import 'xml.dart';
import 'yaml.dart';

final builtinLanguages = <String, Language>{
  'bash': bash,
  'css': css,
  'dart': dart,
  'diff': diff,
  'dockerfile': dockerfile,
  'ini': ini,
  'javascript': javascript,
  'json': json,
  'markdown': markdown,
  'plaintext': plaintext,
  'shell': shell,
  'sql': sql,
  'typescript': typescript,
  'xml': xml,
  'yaml': yaml,
};
