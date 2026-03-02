#!/usr/bin/env bash
# Simple script to sort logs to directories from the first line, not from mtime etc.

SOURCE="."
TARGET="."

find "$SOURCE" -type f -print0 |
while IFS= read -r -d '' file; do
  # Read first line only
  IFS= read -r first_line < "$file" || continue

  # Accept optional BOM + optional leading spaces, then:
  # L <space> MM/DD/YYYY <space> -
  if [[ $first_line =~ ^$'\xEF\xBB\xBF'?[[:space:]]*L[[:space:]]([0-9]{2})/([0-9]{2})/([0-9]{4})[[:space:]]- ]]; then
    year="${BASH_REMATCH[3]}"
    mkdir -p "$TARGET/$year/"

    # Only copy if year dir exists (as you requested)
    if [[ -d "$TARGET/$year" ]]; then
            mv -vi "$file" "$TARGET/$year/"
    fi
  fi
done