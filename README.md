# catchmind repo

Sileo / Zebra / Cydia 저장소 — **https://catchmind24.github.io/**

| 패키지 관리자 | 추가 링크 |
| --- | --- |
| Sileo | `sileo://source/https://catchmind24.github.io` |
| Zebra | `zbra://sources/https://catchmind24.github.io` |
| Cydia | 소스 추가에서 `https://catchmind24.github.io` 입력 |

## 폴더 구조

```
debs/            현재 배포 중인 .deb (패키지별 최신 버전만, arm / arm64 / arm64e)
depictions/      Sileo 네이티브 depiction JSON (패키지별 1개)
archive/debs/    이전 버전 .deb 보관
archive/         그 외 지난 depiction·이미지 보관
assets/          사이트용 이미지
assets/featured/ Sileo 추천 배너 이미지 (789×444). 지금은 대표 트윅 SOOP++ 한 장
                     배너를 바꿀 때는 파일 이름도 바꾼다 (이름-해시.png). Sileo 는 같은 주소의 이미지를 오래 저장해 두어서 새 그림이 안 보인다
sileo-featured.json  Sileo 저장소 첫 화면 추천 배너 목록 (배너 추가·순서 변경은 여기서)
scripts/index.sh Packages / Packages.gz / Release 생성 스크립트
.githooks/       커밋할 때 debs/ 가 바뀌었으면 인덱스를 같은 커밋에 다시 만드는 훅
index.html       저장소 웹페이지 (트윅 목록은 Packages 를 읽어 자동으로 채움)
CydiaIcon.png    저장소 아이콘
```

`Packages`, `Packages.gz`, `Release`는 **직접 수정하지 않습니다.** `main`에 push하면
GitHub Actions(`.github/workflows/build-packages.yml`)가 다시 생성해서 커밋합니다.

## 카테고리 (control 의 Section)

Sileo 가 전용 아이콘을 가진 표준 이름만 씁니다.

| Section | 트윅 |
| --- | --- |
| `Tweaks` | 앱 하나를 고치는 트윅 (광고 제거, 기능 추가, 프리미엄 기능) |
| `Utilities` | 여러 앱에 공통으로 쓰는 트윅 (RevenueCat++) |

## 새 버전 배포 절차

1. 이전 버전 `.deb` 3개(arm / arm64 / arm64e)를 `debs/` → `archive/debs/`로 옮깁니다.
2. 새 `.deb` 3개를 `debs/`에 넣습니다.
3. `depictions/<패키지>.json`의 Changelog 탭 맨 위에 새 버전 항목을 추가합니다.
   Details 탭의 Information 표(Compatibility 등)는 Makefile 의 `TARGET` 최소 iOS 가 바뀔 때만 고칩니다.
4. 커밋 후 `main`에 push합니다. 훅이 켜져 있으면 커밋할 때 `Packages`/`Release`가 같이 갱신됩니다.

훅은 clone 마다 한 번 켭니다 (WSL `Ubuntu-24.04` 의 `dpkg-scanpackages` 를 씁니다).

```sh
git config core.hooksPath .githooks
```

훅 없이 push 하면 CI 가 인덱스를 고칠 때까지 1분쯤 옛 `Packages` 가 이미 옮긴 deb 를 가리켜 설치가 404 로 실패합니다.

CI는 다음을 확인한 뒤 인덱스를 커밋합니다.

- `depictions/*.json` JSON 문법
- `Packages`의 모든 SileoDepiction 링크가 `depictions/`에 실제로 있는지
- `Packages` / `Packages.gz` / `Release`가 비어 있지 않은지

## 로컬에서 인덱스 만들기 (선택)

`dpkg-dev`가 필요합니다 (Linux / macOS / WSL).

```sh
./scripts/index.sh
```
