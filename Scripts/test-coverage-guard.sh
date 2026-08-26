#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
guard="$project_dir/Scripts/CoverageGuard.swift"
fixture=$(mktemp -d "${TMPDIR:-/tmp}/coverage-guard-tests.XXXXXX")
trap 'rm -rf "$fixture"' EXIT

cd "$fixture"
git init --quiet
git config user.name "Coverage Guard Tests"
git config user.email "coverage@example.invalid"
mkdir Sources
printf 'let first = 1\nlet second = 2\n' > Sources/Policy.swift
git add Sources/Policy.swift
git commit --quiet -m "fixture baseline"

write_report() {
    local path="$1"
    local third_count="${2:-1}"
    printf 'TN:\nSF:%s/%s\nDA:1,1\nDA:2,1\nDA:3,%s\nend_of_record\n' \
        "$fixture" "$path" "$third_count" > coverage.lcov
}

printf 'TN:\nSF:%s/Sources/Policy.swift\nDA:1,1\nDA:2,1\nend_of_record\n' \
    "$fixture" > coverage.lcov
swift "$guard" coverage.lcov HEAD 100 100 >/dev/null

printf 'let first = 1\nlet second = 2\nlet third = 3\n' > Sources/Policy.swift
write_report Sources/Policy.swift
swift "$guard" coverage.lcov HEAD 100 100 >/dev/null

write_report Sources/Policy.swift 0
if swift "$guard" coverage.lcov HEAD 0 100 >/dev/null 2>&1; then
    print -u2 "Coverage guard accepted an uncovered added line."
    exit 1
fi

git restore Sources/Policy.swift
git mv Sources/Policy.swift Sources/RenamedPolicy.swift
printf 'let first = 1\nlet second = 2\nlet third = 3\n' > Sources/RenamedPolicy.swift
git diff --name-status HEAD | grep --quiet '^R'
write_report Sources/RenamedPolicy.swift 0
if swift "$guard" coverage.lcov HEAD 0 100 >/dev/null 2>&1; then
    print -u2 "Coverage guard ignored an uncovered line in a renamed file."
    exit 1
fi
write_report Sources/RenamedPolicy.swift
swift "$guard" coverage.lcov HEAD 100 100 >/dev/null

print "Coverage guard contract tests passed."