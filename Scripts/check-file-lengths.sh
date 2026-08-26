#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
violations=()

while IFS= read -r file; do
    line_count=$(awk 'END { print NR }' "$file")
    if (( line_count > 200 )); then
        violations+=("${file#$project_dir/}: $line_count lines")
    fi
done < <(find "$project_dir/Sources" "$project_dir/Tests" "$project_dir/Scripts" \
    -type f -name '*.swift' | sort)

if (( ${#violations[@]} > 0 )); then
    print -u2 "Swift files must not exceed 200 lines:"
    printf '  %s\n' "${violations[@]}" >&2
    exit 1
fi

print "All Swift source and test files are within the 200-line limit."