// Shared no-op template adapter for Markdown backends.
// VitePress and Jaspr implement page rendering directly rather than using the
// legacy HTML template system required by GeneratorBackend.

import 'package:dartdoc_modern/src/generator/template_data.dart';
import 'package:dartdoc_modern/src/generator/templates.dart';
import 'package:dartdoc_modern/src/model/model.dart';

final class NoOpTemplates implements Templates {
  @override
  String renderCategory(CategoryTemplateData context) => '';

  @override
  String renderCategoryRedirect(CategoryTemplateData context) => '';

  @override
  String renderClass<T extends Class>(ClassTemplateData context) => '';

  @override
  String renderConstructor(ConstructorTemplateData context) => '';

  @override
  String renderEnum(EnumTemplateData context) => '';

  @override
  String renderError(PackageTemplateData context) => '';

  @override
  String renderExtension(ExtensionTemplateData context) => '';

  @override
  String renderExtensionType(ExtensionTypeTemplateData context) => '';

  @override
  String renderFunction(FunctionTemplateData context) => '';

  @override
  String renderIndex(PackageTemplateData context) => '';

  @override
  String renderLibrary(LibraryTemplateData context) => '';

  @override
  String renderLibraryRedirect(LibraryTemplateData context) => '';

  @override
  String renderMethod(MethodTemplateData context) => '';

  @override
  String renderMixin(MixinTemplateData context) => '';

  @override
  String renderProperty(PropertyTemplateData context) => '';

  @override
  String renderSearchPage(PackageTemplateData context) => '';

  @override
  String renderSidebarForContainer(
    TemplateDataWithContainer<Documentable> context,
  ) => '';

  @override
  String renderSidebarForLibrary(
    TemplateDataWithLibrary<Documentable> context,
  ) => '';

  @override
  String renderTopLevelProperty(TopLevelPropertyTemplateData context) => '';

  @override
  String renderTypedef(TypedefTemplateData context) => '';
}
