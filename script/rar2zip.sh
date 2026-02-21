#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 archive.rar"
    exit 1
fi

RAR_FILE="$1"

if [[ ! -f "$RAR_FILE" ]]; then
    echo "Error: File not found: $RAR_FILE"
    exit 1
fi

BASE_NAME="$(basename "$RAR_FILE" .rar)"
WORKDIR="$(mktemp -d)"
RAR_DIR="$WORKDIR/rar_contents"
ZIP_DIR="$WORKDIR/zip_contents"
ZIP_FILE="${BASE_NAME}.zip"

mkdir -p "$RAR_DIR" "$ZIP_DIR"

echo "Extracting RAR..."
unrar x -idq "$RAR_FILE" "$RAR_DIR/"

echo "Creating ZIP..."
(
    cd "$RAR_DIR"
    zip -qr "$OLDPWD/$ZIP_FILE" .
)

echo "Extracting ZIP for verification..."
unzip -qq "$ZIP_FILE" -d "$ZIP_DIR"

echo "Comparing file lists..."

# Normalize file lists
(
    cd "$RAR_DIR"
    find . -type f | sort > "$WORKDIR/rar_files.txt"
)

(
    cd "$ZIP_DIR"
    find . -type f | sort > "$WORKDIR/zip_files.txt"
)

if ! diff -u "$WORKDIR/rar_files.txt" "$WORKDIR/zip_files.txt"; then
    echo "ERROR: File lists differ!"
    exit 1
fi

echo "Comparing file checksums..."

(
    cd "$RAR_DIR"
    find . -type f -print0 | sort -z | xargs -0 sha256sum > "$WORKDIR/rar_hashes.txt"
)

(
    cd "$ZIP_DIR"
    find . -type f -print0 | sort -z | xargs -0 sha256sum > "$WORKDIR/zip_hashes.txt"
)

if ! diff -u "$WORKDIR/rar_hashes.txt" "$WORKDIR/zip_hashes.txt"; then
    echo "ERROR: File contents differ!"
    exit 1
fi

echo "SUCCESS: ZIP matches RAR contents."

# Cleanup
rm -rf "$WORKDIR"