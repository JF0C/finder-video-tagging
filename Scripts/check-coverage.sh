#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
exclusions_file="$project_dir/Scripts/coverage-exclusions.txt"
overall_minimum="${COVERAGE_OVERALL_MINIMUM:-90}"
changed_minimum="${COVERAGE_CHANGED_MINIMUM:-95}"
base_ref="${COVERAGE_BASE_REF:-}"

cd "$project_dir"

if [[ -z "$base_ref" ]]; then
    if git rev-parse --verify --quiet origin/main >/dev/null; then
        base_ref="origin/main"
    elif git rev-parse --verify --quiet main >/dev/null; then
        base_ref="main"
    else
        base_ref="HEAD"
    fi
fi

exclusion_regex=$(awk 'NF && $1 !~ /^#/ { patterns[++count] = $0 } END {
    for (position = 1; position <= count; position++) {
        printf "%s%s", (position == 1 ? "" : "|"), patterns[position]
    }
}' "$exclusions_file")

swift test --enable-code-coverage --parallel

profile=$(find .build -type f -path '*/codecov/default.profdata' -print -quit)
test_binary=$(find .build -type f \
    -path '*PackageTests.xctest/Contents/MacOS/*PackageTests' -print -quit)

if [[ -z "$profile" || -z "$test_binary" ]]; then
    print -u2 "Could not locate SwiftPM coverage artifacts."
    exit 1
fi

report=$(mktemp "${TMPDIR:-/tmp}/video-tagging-coverage.XXXXXX")
trap 'rm -f "$report"' EXIT

xcrun llvm-cov export "$test_binary" \
    -instr-profile "$profile" \
    -format=lcov \
    -ignore-filename-regex="$exclusion_regex" > "$report"

swift "$project_dir/Scripts/CoverageGuard.swift" \
    "$report" "$base_ref" "$overall_minimum" "$changed_minimum"