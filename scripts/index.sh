#!/usr/bin/env bash
#
# Build a Sileo/Cydia APT repository index (Packages, Packages.gz, Release).
#
#  - Indexes only the LATEST version of each package (dpkg-scanpackages default).
#  - Deterministic output: re-running with the same .deb set produces byte-identical
#    files, so CI only commits when packages actually change.
#  - Architectures in Release are derived from the .deb files themselves.
#
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Config
# ──────────────────────────────────────────────────────────────────────────────
DEB_DIR="debs"
PACKAGES_FILE="Packages"
PACKAGES_GZ="Packages.gz"
RELEASE_FILE="Release"

REPO_ORIGIN="catchmind"
REPO_LABEL="catchmind repo"
REPO_SUITE="stable"
REPO_VERSION="1.0"
REPO_CODENAME="ios"
REPO_COMPONENTS="main"
REPO_DESCRIPTION="catchmind Cydia/Sileo Repository"
# Fallback used only when no .deb declares an architecture.
DEFAULT_ARCHS="iphoneos-arm iphoneos-arm64"

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────
log()  { printf '▶ %s\n' "$*"; }
ok()   { printf '  ✓ %s\n' "$*"; }
die()  { printf '❌ %s\n' "$*" >&2; exit 1; }

require() { command -v "$1" >/dev/null 2>&1 || die "필수 명령이 없습니다: $1"; }

# Portable file size (Linux/macOS).
filesize() {
  stat -c%s "$1" 2>/dev/null || stat -f%z "$1"
}

# Append "<algo>:\n <hash> <size> <file>" blocks to the Release file.
emit_hashes() {
  local label="$1" tool="$2"; shift 2
  echo "${label}:"
  local f size hash
  for f in "$@"; do
    [ -f "$f" ] || continue
    size=$(filesize "$f")
    hash=$("$tool" "$f" | cut -d' ' -f1)
    printf ' %s %s %s\n' "$hash" "$size" "$f"
  done
}

# ──────────────────────────────────────────────────────────────────────────────
# Pre-flight
# ──────────────────────────────────────────────────────────────────────────────
require dpkg-scanpackages
require gzip

# Work from the repo root when invoked inside a git checkout.
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  cd "$(git rev-parse --show-toplevel)"
fi
log "작업 디렉토리: $(pwd)"

[ -d "$DEB_DIR" ] || die "$DEB_DIR 디렉토리가 없습니다"

DEB_COUNT=$(find "$DEB_DIR" -type f -name '*.deb' | wc -l | tr -d ' ')
log ".deb 파일: ${DEB_COUNT}개 발견"
[ "$DEB_COUNT" -gt 0 ] || log "경고: .deb 파일이 없습니다 (빈 인덱스를 생성합니다)"

# ──────────────────────────────────────────────────────────────────────────────
# 1. Build Packages (latest version of each package only → no -m)
# ──────────────────────────────────────────────────────────────────────────────
TMP_PACKAGES="$(mktemp)"
trap 'rm -f "$TMP_PACKAGES"' EXIT

# Default (no --multiversion / no -m) keeps only the newest version of each package.
log "dpkg-scanpackages 실행 (최신 버전만 인덱싱)..."
dpkg-scanpackages -m "$DEB_DIR" /dev/null > "$TMP_PACKAGES"

PKG_COUNT=$(grep -c '^Package:' "$TMP_PACKAGES" || true)
ok "인덱싱된 패키지: ${PKG_COUNT}개"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Idempotency guard — skip regeneration when nothing changed
# ──────────────────────────────────────────────────────────────────────────────
if [ -f "$PACKAGES_FILE" ] && cmp -s "$TMP_PACKAGES" "$PACKAGES_FILE" \
   && [ -f "$PACKAGES_GZ" ] && [ -f "$RELEASE_FILE" ]; then
  ok "변경된 패키지가 없습니다. 인덱스를 그대로 유지합니다."
  exit 0
fi

mv "$TMP_PACKAGES" "$PACKAGES_FILE"
trap - EXIT

# ──────────────────────────────────────────────────────────────────────────────
# 3. Packages.gz  (-n = no timestamp/name → deterministic output)
# ──────────────────────────────────────────────────────────────────────────────
log "Packages.gz 생성..."
gzip -9nkf "$PACKAGES_FILE"
ok "압축 완료: $(filesize "$PACKAGES_GZ") bytes"

# ──────────────────────────────────────────────────────────────────────────────
# 4. Release  (architectures derived from the actual .debs)
# ──────────────────────────────────────────────────────────────────────────────
ARCHS=$(awk '/^Architecture:/ {print $2}' "$PACKAGES_FILE" | sort -u | paste -sd' ' -)
[ -n "$ARCHS" ] || ARCHS="$DEFAULT_ARCHS"
log "아키텍처: $ARCHS"

{
  cat <<EOF
Origin: ${REPO_ORIGIN}
Label: ${REPO_LABEL}
Suite: ${REPO_SUITE}
Version: ${REPO_VERSION}
Codename: ${REPO_CODENAME}
Architectures: ${ARCHS}
Components: ${REPO_COMPONENTS}
Description: ${REPO_DESCRIPTION}
EOF
  emit_hashes "MD5Sum" md5sum    "$PACKAGES_FILE" "$PACKAGES_GZ"
  emit_hashes "SHA1"   sha1sum   "$PACKAGES_FILE" "$PACKAGES_GZ"
  emit_hashes "SHA256" sha256sum "$PACKAGES_FILE" "$PACKAGES_GZ"
  emit_hashes "SHA512" sha512sum "$PACKAGES_FILE" "$PACKAGES_GZ"
  echo "Date: $(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S UTC')"
} > "$RELEASE_FILE"

# ──────────────────────────────────────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────────────────────────────────────
echo
ok "인덱스 생성 완료"
printf '   - %-12s %s 줄\n'  "$PACKAGES_FILE"  "$(wc -l < "$PACKAGES_FILE")"
printf '   - %-12s %s bytes\n' "$PACKAGES_GZ" "$(filesize "$PACKAGES_GZ")"
printf '   - %-12s %s 줄\n'  "$RELEASE_FILE"   "$(wc -l < "$RELEASE_FILE")"
