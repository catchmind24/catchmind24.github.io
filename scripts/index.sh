#!/usr/bin/env bash
set -euo pipefail

# Git 저장소 루트로 이동
if git rev-parse --show-toplevel &>/dev/null; then
  cd "$(git rev-parse --show-toplevel)"
  echo "📂 작업 디렉토리: $(pwd)"
else
  echo "⚠️ Git 저장소가 아니거나 shallow clone입니다. 현재 디렉토리에서 작업합니다."
fi

DEB_DIR="debs"

# debs 디렉토리 확인
if [ ! -d "$DEB_DIR" ]; then
  echo "❌ $DEB_DIR 디렉토리가 없습니다"
  exit 1
fi

# deb 파일 개수 확인
DEB_COUNT=$(find "$DEB_DIR" -name "*.deb" | wc -l)
echo "📦 발견된 .deb 파일: $DEB_COUNT개"

if [ "$DEB_COUNT" -eq 0 ]; then
  echo "⚠️ 경고: deb 파일이 없습니다"
fi

# Packages 파일 생성
echo "▶ dpkg-scanpackages 실행..."
if ! dpkg-scanpackages -m "$DEB_DIR" /dev/null > "Packages"; then
  echo "❌ dpkg-scanpackages 실패"
  exit 1
fi

# 생성된 패키지 수 확인
PACKAGE_COUNT=$(grep -c "^Package:" Packages || echo "0")
echo "  ✓ 인덱싱된 패키지: $PACKAGE_COUNT개"

# Packages.gz 생성
echo "▶ Packages.gz 생성..."
if ! gzip -9kf "Packages"; then
  echo "❌ Packages.gz 생성 실패"
  exit 1
fi
echo "  ✓ 압축 완료: $(stat -c%s Packages.gz 2>/dev/null || stat -f%z Packages.gz) bytes"

# Release 파일 생성
echo "▶ Release 파일 생성..."

# 🔥 핵심: 타임스탬프 기반 버전 생성 (Sileo 캐시 무효화)
TIMESTAMP=$(date -u +%s)
VERSION="1.0.${TIMESTAMP}"
CURRENT_DATE=$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S %Z")

# 🔥 Date를 Release 파일 **안에** 포함 (해시 계산 전)
cat > "Release" <<EOF
Origin: catchmind
Label: catchmind repo
Suite: stable
Version: ${VERSION}
Codename: ios
Architectures: iphoneos-arm iphoneos-arm64 iphoneos-arm64e
Components: main
Description: catchmind Cydia/Sileo Repository
Date: ${CURRENT_DATE}
EOF

# 해시값 계산 및 추가
{
  echo "MD5Sum:"
  for f in Packages Packages.gz; do
    [ -f "$f" ] || continue
    # Linux와 macOS 호환성
    if stat -c%s "$f" &>/dev/null; then
      size=$(stat -c%s "$f")
    else
      size=$(stat -f%z "$f")
    fi
    hash=$(md5sum "$f" 2>/dev/null | cut -d' ' -f1 || md5 -q "$f")
    echo " $hash $size $f"
  done

  echo "SHA1:"
  for f in Packages Packages.gz; do
    [ -f "$f" ] || continue
    if stat -c%s "$f" &>/dev/null; then
      size=$(stat -c%s "$f")
    else
      size=$(stat -f%z "$f")
    fi
    hash=$(sha1sum "$f" 2>/dev/null | cut -d' ' -f1 || shasum -a 1 "$f" | cut -d' ' -f1)
    echo " $hash $size $f"
  done

  echo "SHA256:"
  for f in Packages Packages.gz; do
    [ -f "$f" ] || continue
    if stat -c%s "$f" &>/dev/null; then
      size=$(stat -c%s "$f")
    else
      size=$(stat -f%z "$f")
    fi
    hash=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 "$f" | cut -d' ' -f1)
    echo " $hash $size $f"
  done

  echo "SHA512:"
  for f in Packages Packages.gz; do
    [ -f "$f" ] || continue
    if stat -c%s "$f" &>/dev/null; then
      size=$(stat -c%s "$f")
    else
      size=$(stat -f%z "$f")
    fi
    hash=$(sha512sum "$f" 2>/dev/null | cut -d' ' -f1 || shasum -a 512 "$f" | cut -d' ' -f1)
    echo " $hash $size $f"
  done
} >> "Release"

# 최종 확인
echo ""
echo "✅ 인덱스 생성 완료"
echo "   - Version: ${VERSION}"
echo "   - Date: ${CURRENT_DATE}"
echo "   - Packages: $(wc -l < Packages) 줄"
echo "   - Packages.gz: $(stat -c%s Packages.gz 2>/dev/null || stat -f%z Packages.gz) bytes"
echo "   - Release: $(wc -l < Release) 줄"
echo ""
echo "💡 Sileo는 Version과 Date 변경을 감지하여 캐시를 갱신합니다"
