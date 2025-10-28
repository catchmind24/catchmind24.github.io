#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(pwd)"
DEB_DIR="$REPO_ROOT/debs"

if [ ! -d "$DEB_DIR" ]; then
  echo "❌ debs 디렉토리를 찾을 수 없습니다: $DEB_DIR"
  exit 1
fi

echo "▶ dpkg-scanpackages 실행..."
dpkg-scanpackages -m "$DEB_DIR" /dev/null > "$REPO_ROOT/Packages"

echo "▶ Packages.gz 생성..."
gzip -9kf "$REPO_ROOT/Packages"

# Release에 체크섬 추가 (Packages, Packages.gz 기준)
{
  echo "MD5Sum:"
  for f in Packages Packages.gz; do
    [ -f "$f" ] || continue
    size=$(stat -c%s "$f")
    hash=$(md5sum "$f" | cut -d' ' -f1)
    echo " $hash $size $f"
  done

  echo "SHA1:"
  for f in Packages Packages.gz; do
    [ -f "$f" ] || continue
    size=$(stat -c%s "$f")
    hash=$(sha1sum "$f" | cut -d' ' -f1)
    echo " $hash $size $f"
  done

  echo "SHA256:"
  for f in Packages Packages.gz; do
    [ -f "$f" ] || continue
    size=$(stat -c%s "$f")
    hash=$(sha256sum "$f" | cut -d' ' -f1)
    echo " $hash $size $f"
  done

  echo "SHA512:"
  for f in Packages Packages.gz; do
    [ -f "$f" ] || continue
    size=$(stat -c%s "$f")
    hash=$(sha512sum "$f" | cut -d' ' -f1)
    echo " $hash $size $f"
  done
} >> "$REPO_ROOT/Release"

echo "✅ 완료: Packages / Packages.gz / Release"
