#!/usr/bin/env bash
set -euo pipefail

# Each path below has been reviewed against the common ancestor and the pinned
# upstream commit. HEAD contains the reconciled implementation for these paths.
# Do not use a global -X ours/theirs strategy.
keep_head=(
  .github/workflows/publish.yaml
  .github/workflows/test.yaml
  CHANGELOG.md
  dartdoc_options.yaml
  lib/resources/docs.dart.js
  lib/resources/docs.dart.js.map
  lib/src/dartdoc_options.dart
  lib/src/element_type.dart
  lib/src/experiment_options.dart
  lib/src/generator/html_generator_backend.dart
  lib/src/generator/resource_loader.dart
  lib/src/markdown_processor.dart
  lib/src/model/canonicalization.dart
  lib/src/model/documentation_comment.dart
  lib/src/model/library.dart
  lib/src/model/model_element.dart
  lib/src/model/model_node.dart
  lib/src/model/package_builder.dart
  lib/src/model/package_graph.dart
  lib/src/model/prefix.dart
  lib/src/package_meta.dart
  lib/src/render/parameter_renderer.dart
  lib/src/runtime_stats.dart
  lib/src/version.dart
  lib/src/warnings.dart
  pubspec.yaml
  test/documentation_comment_test_base.dart
  test/end2end/model_special_cases_test.dart
  test/end2end/model_test.dart
  test/example_directive_test.dart
  test/html_generator_test.dart
  test/io_utils_test.dart
  test/packages_test.dart
  test/parameters_test.dart
  test/prefixes_test.dart
  test/src/utils.dart
  testing/test_package_sanitize_html/lib/test_package_sanitize_html.dart
  tool/generate_data.dart
  tool/task.dart
  web/sig.txt
)

for file in "${keep_head[@]}"; do
  if [[ -n "$(git ls-files -u -- "$file")" ]]; then
    git checkout --ours -- "$file"
    git add -- "$file"
    echo "Reviewed: retained reconciled HEAD for $file"
  fi
done

# Intentionally deleted in the fork; no longer needed with fork-specific checks.
git rm --force --ignore-unmatch -- .github/workflows/scorecards-analysis.yml

# Upstream's dart-lang ecosystem health workflow overlaps the fork's existing
# PR publish validation and is not configured for this fork.
git rm --force --ignore-unmatch -- .github/workflows/health.yaml

# Source files added by upstream still refer to the old package name. Normalize
# package URI prefixes in Dart source, leaving other identifiers intact.
python3 - <<'PY'
import pathlib, subprocess
paths = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"],
).split(b"\0")
updated = []
for raw in paths:
    if not raw:
        continue
    path = pathlib.Path(raw.decode())
    if path.suffix != ".dart" or not path.is_file():
        continue
    original = path.read_bytes()
    updated_bytes = original.replace(
        b"package:dartdoc/", b"package:dartdoc_modern/"
    )
    if updated_bytes != original:
        path.write_bytes(updated_bytes)
        updated.append(str(path))
if updated:
    subprocess.run(["git", "add", "--", *updated], check=True)
for path in updated:
    print("Normalized Dart package URI:", path)
PY

unmerged="$(git diff --name-only --diff-filter=U)"
if [[ -n "$unmerged" ]]; then
  echo "::error::Unresolved upstream paths remain:"
  printf '%s\n' "$unmerged"
  exit 1
fi

if git grep -n -I -E '^(<<<<<<< |=======|>>>>>>> )' -- lib/src test tool >/tmp/upstream-conflict-markers.txt; then
  cat /tmp/upstream-conflict-markers.txt
  echo "::error::Merge conflict markers found in source"
  exit 1
fi

git add -A
# The Co19 placement fixture deliberately contains trailing whitespace to
# test whether comment placement is handled correctly; preserve it unchanged.
git diff --cached --check -- . ':(exclude)test/co19/placement_enums_test.dart'
echo "Resolved merge; staged changes:"
git diff --cached --stat | tail -45
