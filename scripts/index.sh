#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

[ -d "debs" ] || { echo "❌ debs 디렉토리가 없습니다"; exit 1; }

echo "▶ dpkg-scanpackages 실행..."
dpkg-scanpackages -m "debs" /dev/null > "Packages"

echo "▶ Packages.gz 생성..."
gzip -9kf "Packages"

echo "▶ Release 생성..."
cat > "$REPO_ROOT/Release" <<'EOF'
Origin: catchmind repo
Label: catchmind repo
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm iphoneos-arm64 iphoneos-arm64e
Components: main
Description: lol
EOF

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
