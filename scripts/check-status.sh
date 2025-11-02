#!/usr/bin/env bash
# 실시간 Sileo 업데이트 진단

REPO_URL="https://catchmind24.github.io"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🔍 실시간 Sileo 업데이트 상태 확인"
echo "========================================"
echo ""

# 1. 로컬 Release 확인
echo "${BLUE}[1] 로컬 Release 파일 확인${NC}"
if [ -f Release ]; then
  LOCAL_VERSION=$(grep "^Version:" Release | cut -d' ' -f2)
  LOCAL_DATE=$(grep "^Date:" Release | cut -d' ' -f2-)
  echo "  Version: ${GREEN}${LOCAL_VERSION}${NC}"
  echo "  Date: ${LOCAL_DATE}"
  
  if [[ "$LOCAL_VERSION" == "1.0."* ]]; then
    echo "  ${GREEN}✅ 로컬은 새 버전 형식 사용 중${NC}"
  else
    echo "  ${RED}❌ 로컬이 여전히 고정 버전 (1.0)${NC}"
    echo "     → scripts/index.sh가 제대로 교체되지 않았을 수 있음"
  fi
else
  echo "  ${YELLOW}⚠️ 로컬에 Release 파일 없음${NC}"
fi
echo ""

# 2. GitHub (raw) 확인
echo "${BLUE}[2] GitHub 저장소 확인 (커밋됨?)${NC}"
GITHUB_VERSION=$(curl -s "https://github.com/catchmind24/catchmind24.github.io/raw/main/Release" 2>/dev/null | grep "^Version:" | cut -d' ' -f2)
if [ -n "$GITHUB_VERSION" ]; then
  echo "  Version: ${GREEN}${GITHUB_VERSION}${NC}"
  if [[ "$GITHUB_VERSION" == "1.0."* ]]; then
    echo "  ${GREEN}✅ GitHub에 새 버전이 커밋됨${NC}"
  else
    echo "  ${RED}❌ GitHub에 여전히 고정 버전 (${GITHUB_VERSION})${NC}"
    echo "     → Actions가 새 index.sh를 사용하지 않았거나 실행 안 됨"
  fi
else
  echo "  ${RED}❌ GitHub에서 Release 파일 못 가져옴${NC}"
fi
echo ""

# 3. GitHub Pages 확인
echo "${BLUE}[3] GitHub Pages 확인 (배포됨?)${NC}"
PAGES_VERSION=$(curl -s "${REPO_URL}/Release" 2>/dev/null | grep "^Version:" | cut -d' ' -f2)
PAGES_DATE=$(curl -s "${REPO_URL}/Release" 2>/dev/null | grep "^Date:" | cut -d' ' -f2-)

if [ -n "$PAGES_VERSION" ]; then
  echo "  Version: ${GREEN}${PAGES_VERSION}${NC}"
  echo "  Date: ${PAGES_DATE}"
  
  if [[ "$PAGES_VERSION" == "1.0."* ]]; then
    echo "  ${GREEN}✅ GitHub Pages에 새 버전 배포됨!${NC}"
  else
    echo "  ${YELLOW}⚠️ GitHub Pages에 여전히 고정 버전 (${PAGES_VERSION})${NC}"
    echo "     → CDN 캐시 때문일 수 있음 (5-10분 대기)"
  fi
else
  echo "  ${RED}❌ GitHub Pages에서 Release 못 가져옴 (404?)${NC}"
fi
echo ""

# 4. 버전 비교
echo "${BLUE}[4] 버전 동기화 상태${NC}"
if [ -n "$LOCAL_VERSION" ] && [ -n "$GITHUB_VERSION" ] && [ -n "$PAGES_VERSION" ]; then
  if [ "$LOCAL_VERSION" = "$GITHUB_VERSION" ] && [ "$GITHUB_VERSION" = "$PAGES_VERSION" ]; then
    echo "  ${GREEN}✅ 모든 버전이 동기화됨: ${LOCAL_VERSION}${NC}"
  else
    echo "  ${YELLOW}⚠️ 버전 불일치:${NC}"
    echo "     로컬:  ${LOCAL_VERSION}"
    echo "     GitHub: ${GITHUB_VERSION}"
    echo "     Pages:  ${PAGES_VERSION}"
  fi
fi
echo ""

# 5. HTTP 캐시 헤더 확인
echo "${BLUE}[5] GitHub Pages 캐시 정책 확인${NC}"
CACHE_CONTROL=$(curl -sI "${REPO_URL}/Release" 2>/dev/null | grep -i "cache-control:" | cut -d' ' -f2-)
ETAG=$(curl -sI "${REPO_URL}/Release" 2>/dev/null | grep -i "etag:" | cut -d' ' -f2-)
LAST_MODIFIED=$(curl -sI "${REPO_URL}/Release" 2>/dev/null | grep -i "last-modified:" | cut -d' ' -f2-)

if [ -n "$CACHE_CONTROL" ]; then
  echo "  Cache-Control: ${CACHE_CONTROL}"
fi
if [ -n "$ETAG" ]; then
  echo "  ETag: ${ETAG}"
fi
if [ -n "$LAST_MODIFIED" ]; then
  echo "  Last-Modified: ${LAST_MODIFIED}"
fi
echo ""

# 6. Packages 파일 확인
echo "${BLUE}[6] Packages 파일 확인${NC}"
PACKAGES_COUNT=$(curl -s "${REPO_URL}/Packages" 2>/dev/null | grep -c "^Package:" || echo "0")
if [ "$PACKAGES_COUNT" -gt 0 ]; then
  echo "  ${GREEN}✅ Packages 파일 접근 가능 (${PACKAGES_COUNT}개 패키지)${NC}"
else
  echo "  ${RED}❌ Packages 파일 접근 불가${NC}"
fi
echo ""

# 진단 결과
echo "========================================"
echo "${BLUE}📊 진단 결과${NC}"
echo "========================================"
echo ""

if [[ "$PAGES_VERSION" == "1.0."* ]]; then
  echo "${GREEN}✅ GitHub Pages에 새 버전이 배포되어 있습니다!${NC}"
  echo ""
  echo "💡 Sileo가 아직 감지 못했다면:"
  echo ""
  echo "   ${YELLOW}원인: Sileo의 공격적인 캐싱${NC}"
  echo "   Sileo는 HTTP 캐시 헤더를 무시하고 자체 캐시를 사용합니다."
  echo "   Release 파일을 최대 24시간 동안 캐싱할 수 있습니다."
  echo ""
  echo "   ${GREEN}해결 방법:${NC}"
  echo ""
  echo "   1️⃣  ${BLUE}강제 새로고침 (추천)${NC}"
  echo "      - Sileo 열기"
  echo "      - Sources 탭"
  echo "      - catchmind repo를 길게 누르기"
  echo "      - 'Refresh' 또는 'Reload' 선택"
  echo "      - 여러 번 시도 (5-10번)"
  echo ""
  echo "   2️⃣  ${BLUE}시간 대기${NC}"
  echo "      - 보통 1-6시간 후 자동 갱신"
  echo "      - 최대 24시간까지 가능"
  echo ""
  echo "   3️⃣  ${BLUE}Sileo 캐시 클리어${NC}"
  echo "      - Sileo 앱 완전 종료"
  echo "      - Settings > Sileo > Reset (있다면)"
  echo "      - 기기 재부팅"
  echo ""
  echo "   4️⃣  ${BLUE}레포 재추가 (빠른 방법)${NC}"
  echo "      - 레포 삭제"
  echo "      - Sileo 종료"
  echo "      - Sileo 재실행"
  echo "      - 레포 재추가"
  echo ""
  echo "   ${YELLOW}참고: 새로운 Version 시스템이 적용되면${NC}"
  echo "   ${YELLOW}다음 업데이트부터는 자동으로 감지됩니다!${NC}"
  
elif [ "$PAGES_VERSION" = "1.0" ]; then
  echo "${YELLOW}⚠️ GitHub Pages에 아직 새 버전이 배포 안 됨${NC}"
  echo ""
  
  if [ "$GITHUB_VERSION" != "1.0" ] && [[ "$GITHUB_VERSION" == "1.0."* ]]; then
    echo "   ${GREEN}✅ GitHub에는 새 버전이 커밋됨${NC}"
    echo "   ${YELLOW}→ GitHub Pages CDN 캐시 때문${NC}"
    echo ""
    echo "   ${BLUE}대기 시간:${NC}"
    echo "   - 일반적: 5-10분"
    echo "   - 최대: 30분"
    echo ""
    echo "   ${BLUE}확인 방법:${NC}"
    echo "   watch -n 10 'curl -s ${REPO_URL}/Release | grep Version:'"
    echo ""
  else
    echo "   ${RED}❌ GitHub에도 새 버전이 없음${NC}"
    echo ""
    echo "   ${BLUE}해결 방법:${NC}"
    echo "   1. GitHub Actions가 실행되었는지 확인:"
    echo "      https://github.com/catchmind24/catchmind24.github.io/actions"
    echo ""
    echo "   2. 최신 커밋이 새 index.sh를 포함하는지 확인:"
    echo "      https://github.com/catchmind24/catchmind24.github.io/commits/main"
    echo ""
    echo "   3. 수동으로 트리거:"
    echo "      cd /path/to/repo"
    echo "      ./scripts/index.sh"
    echo "      git add Release Packages Packages.gz"
    echo "      git commit -m 'Force update with new version'"
    echo "      git push"
  fi
else
  echo "${RED}❌ 문제 발견!${NC}"
  echo ""
  echo "GitHub Pages에서 Release 파일을 가져올 수 없습니다."
  echo ""
  echo "${BLUE}해결 방법:${NC}"
  echo "1. GitHub Pages 설정 확인:"
  echo "   https://github.com/catchmind24/catchmind24.github.io/settings/pages"
  echo ""
  echo "2. Pages 빌드 상태 확인:"
  echo "   https://github.com/catchmind24/catchmind24.github.io/actions"
fi

echo ""
echo "🔄 이 스크립트를 주기적으로 실행하여 상태 확인:"
echo "   watch -n 30 ./check-status.sh"
echo ""
