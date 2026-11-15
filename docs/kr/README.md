# iterm2-tools — iTerm2 우클릭 메뉴·클릭 버튼 확장

[English](../../README.md) | **한국어**

문서: 이 사용 설명서 · [영어 사용 설명서 (English manual)](../../README.md) · [문서 작성·관리 규칙](DOCS_GUIDE.md) · [Documentation rules](../en/DOCS_GUIDE.md)

iTerm2 + zsh 에 아래 세 가지를 추가한다. 필요한 것만 골라 설치할 수 있다.

| 기능 | 무엇을 하나 | 바로 사용 | 필요 조건 |
|---|---|---|---|
| **A. 경로 우클릭** | 터미널에 출력된 파일·폴더 경로 위에서 우클릭 → `VS Code에서 열기` / `Finder에서 보기` (`파일:줄:열` 은 해당 줄로 이동) | 설치 즉시 | 없음 |
| **B. 어디서나 우클릭** | 터미널 아무 곳 우클릭 → `현재 폴더: VS Code에서 열기` / `현재 폴더: Finder에서 열기` / `현재 폴더: 정리(clean)…` | 설치 후 스크립트 1회 실행 | iTerm2 3.4.0+, Python 런타임, Python API 허용, (Apple Silicon) Rosetta 2 |
| **D. 폴더 정리(clean)** | 현재 폴더(하위 포함)의 캐시·빌드 산출물·의존성 폴더를 정리. **드라이런 결과를 먼저 보여 주고**(변경 없음) 사용자가 확인한 뒤 `yes` 면 그 결과대로 휴지통으로, Enter 면 그대로 종료. B 메뉴에서 새 탭으로 실행되며, 명령 `iterm-clean` 으로 어떤 터미널에서도 사용 | 설치 즉시(`~/bin/iterm-clean`) | 없음 (git 보호는 git 이 있을 때 동작) |
| **C. 클릭 버튼** | 터미널 출력 안에 아이콘 버튼을 그리고, 클릭하면 등록한 명령을 입력/실행 | iTerm2 3.7.0 이상이 **실행 중**일 때 | zsh, `~/.zshrc` 수정 |

---

## 0. 요구 사항 (다른 Mac 포함)

| 항목 | 조건 | 근거(실측) |
|---|---|---|
| macOS | **12 이상** (미만이면 설치 스크립트가 중단) | 설치에 쓰는 `plutil -extract … raw` 가 macOS 12 부터 (`man plutil` HISTORY). 최신 iTerm2 3.7.7 자체가 macOS 13 이상 요구 |
| CPU | Apple Silicon / Intel 모두 | 셸 스크립트·테스트를 x86_64(Rosetta) 모드에서도 실행해 PASS |
| iTerm2 | A: 3.4.0+ 권장 · **B: 3.4.0 이상** · **C: 3.7.0 이상** | B = API 프로토콜 1.7(3.4.0 부터), C = custom 버튼 코드(3.7.0 부터) — 릴리스 태그 소스 비교 |
| Rosetta 2 | **Apple Silicon 에서 B 사용 시 필요** | iTerm2 Python 런타임이 x86_64 전용으로 배포됨(공개 manifest·설치본 확인). 없으면 `softwareupdate --install-rosetta --agree-to-license` |
| Python API | B 첫 실행 때 `Enable Python API?` → **OK** | 새 iTerm2 의 기본값은 꺼짐(`EnableAPIServer=NO`) |
| 추가 설치 프로그램 | 없음 — macOS 기본 명령(`/bin`, `/usr/bin`)만 사용. Homebrew·Xcode 불필요 | 사용 명령 전수 확인 |
| VS Code | 선택. `/Applications`·`~/Applications`·Spotlight 순으로 찾고, CLI 가 없으면 앱으로만 연다(줄 이동 불가) | CLI 없는 경우 테스트 PASS |
| 권한 | 관리자·손쉬운 사용 권한 **불필요** | — |
| 사용자별 차이 | 홈 경로(공백 포함), 사용자 이름, 기본 프로필 이름, 바꾼 Scripts·DynamicProfiles 폴더, 기본 프로필의 사용자 지정 규칙을 **설치할 때 자동 반영** | 이식성 테스트 S1~S4 |

**메뉴 이름 언어:** iTerm2 메뉴는 macOS 언어에 따라 번역된다(한국어 번역은 없어 영어로 표시). 위치는 같다.

| 이 문서 | 일본어 | 독일어 |
|---|---|---|
| Scripts → Manage → Install Python Runtime | スクリプト → 管理 → Pythonランタイムをインストール | Skripte → Verwalten → Python-Laufzeitumgebung installieren |

### 다른 Mac 으로 옮기기

1. `iterm2-tools` 폴더를 통째로 받는다: `git clone https://github.com/yaioyaio/iterm2-tools.git ~/iterm2-tools`, 또는 복사(AirDrop·zip·USB).
2. 받은 Mac 에서 **`zsh install.sh …`** 형태로 실행한다 — 복사 중 실행 권한이 빠져도 동작하고, 설치한 파일의 격리 표시(quarantine)는 자동으로 지운다.
3. 먼저 `zsh install.sh status` 로 그 Mac 의 조건(macOS·iTerm2 버전·런타임·Rosetta·API)을 확인한다.

---

## 1. 패키지 구성

| 파일 | 역할 | 설치 위치 |
|---|---|---|
| `install.sh` | 설치 / 상태 점검 / 테스트. 사용자별 값(홈 경로, 폴더 위치, 기본 규칙, 프로필 GUID)을 실행 시 계산 | — |
| `uninstall.sh` | 이 패키지가 설치한 파일만 삭제(설치 때와 같은 경로 계산) | — |
| `lib/common.zsh` | 설치·제거 공통: 그 Mac 의 iTerm2 설정에서 설치 경로 계산 | — |
| `bin/iterm-clean` | D 의 정리 도구(드라이런·확인·휴지통 이동, 판정 규칙 표 내장) | `~/bin/iterm-clean` |
| `bin/iterm-open` | A 의 실행기. 경로 해석(`~`, 상대경로, `file://`, `:줄:열`) 후 VS Code / Finder 실행 | `~/bin/iterm-open` |
| (생성) `dp-open-in.json` | A 의 Dynamic Profile. iTerm2 기본 Smart Selection 규칙 + 경로 규칙 1개 + 동작 2개 | `~/Library/Application Support/iTerm2/DynamicProfiles/` |
| `python/open_in_tools.py` | B 의 iTerm2 Python API 스크립트(우클릭 메뉴 제공자) | `~/Library/Application Support/iTerm2/Scripts/AutoLaunch/` |
| `zsh/iterm-buttons.zsh` | C 의 zsh 플러그인(`ib_add`, `ib_bar`) | `~/.zsh/iterm2-tools/` |
| `zsh/ib-selftest.zsh` | C 의 클릭 자가 테스트 | `~/.zsh/iterm2-tools/` |
| `tests/test_iterm_open.zsh` | A 회귀 테스트(동작당 실행 명령 1건·주입 차단) | — |
| `tests/test_open_in_tools.py` | B 회귀 테스트(메뉴 항목당 콜백·실행 1건) — iterm2 라이브러리 실제 디스패치 사용 | — |
| `tests/test_iterm_clean.zsh` | D 회귀 테스트: 임시 폴더에 12개 언어·도구 픽스처를 만들어 판정·드라이런·확인·휴지통·git 보호·거부·메뉴 모드 검증, 영어 화면 검사 포함(109건) | — |
| `tests/test_portability.zsh` | 이식성 테스트: 가짜 홈·가짜 iTerm2 설정으로 "다른 Mac" 조건 S1~S7 과 언어(S8: 영어 설치·`--lang` 저장/전환·선택 순서) 재현 | — |
| `tests/test_lang.zsh` | 언어 공통 검사: 모든 실행 파일의 언어 선택 코드 일치·선택 순서 12가지·영어 화면 한글 0자·번역 함수 밖 한글 없음(정적 검사) | — |
| (생성) `lang` | `install.sh --lang en\|kr` 로 저장한 화면 언어(`--lang` 을 쓸 때만 생김) | `~/.config/iterm2-tools/lang` |
| `tests/test_docs.zsh` | 문서 짝 검사: `README.md` ↔ `docs/kr/README.md`, `docs/en` ↔ `docs/kr` 파일 짝·언어 전환 링크·구조(제목 단계·번호, 표 행, 목록, 코드 블록의 명령) 일치 | — |
| `README.md` | 영어 사용 설명서(메인 문서) | — |
| `docs/kr/README.md`, `docs/{en,kr}/` | 한국어 사용 설명서(`README.md` 의 짝)와 그 밖의 문서(영어 / 한국어, 같은 이름의 파일이 짝). 작성·관리 규칙은 `DOCS_GUIDE.md` | — |

설치 위치의 `~/Library/Application Support/iTerm2/…` 는 기본값이다. 그 Mac 에서 Scripts 폴더(`UseCustomScriptsFolder`)나 DynamicProfiles 폴더(`dynamicProfilesPath`)를 바꿔 두었다면 설치 스크립트가 **바뀐 위치에 설치**한다.

`install.sh` 는 `~/.zshrc` 와 iTerm2 설정 파일(plist)을 **수정하지 않는다**.

---

## 2. 설치 순서

### 2-1. 준비 — 상태 점검 (아무것도 바꾸지 않음)

```sh
cd ~/iterm2-tools        # 패키지를 둔 폴더
zsh install.sh status
```

`설치본과 실행본이 다릅니다` 경고가 나오면 iTerm2 가 업데이트된 뒤 재시작되지 않은 상태다. A·B 는 그대로 설치해도 되지만, **작업을 마친 뒤 iTerm2 를 재시작**하는 것을 권장한다(아래 5. 문제 해결 참고).

### 2-2. A. 경로 우클릭

```sh
zsh install.sh path
```

1. iTerm2 메뉴 막대 **Profiles → `우클릭 도구`** 로 새 탭/창을 연다.
   (이 프로필은 기본 프로필의 모든 설정을 그대로 상속하고, 우클릭 동작만 추가된 것이다.)
2. 경로가 출력되게 한다. 예: `ls -d ~/bin/iterm-open`
3. 출력된 경로 위에서 **우클릭 → `VS Code에서 열기` / `Finder에서 보기`**.

> 재시작·Settings 조작이 필요 없다. iTerm2 가 DynamicProfiles 폴더를 감시하다가 바로 읽어 들인다.

### 2-3. B. 어디서나 우클릭

1. Python 런타임이 없다면: iTerm2 메뉴 **Scripts → Manage → Install Python Runtime**.
   - 별도 창 없이 **조용히 끝날 수 있다**. `zsh install.sh status` 에서 `Python 런타임 있음` 이 나오면 완료.
2. 설치(재설치·업데이트도 같은 명령):
   ```sh
   zsh install.sh anywhere
   ```
   이전 버전이 실행 중이면 자동으로 정지시킨다(이전 코드로 메뉴를 계속 처리하지 않도록).
3. 지금 바로 켜기: iTerm2 메뉴 **Scripts → AutoLaunch → open_in_tools.py**.
   (다음 iTerm2 실행부터는 자동으로 켜진다. 설치·업데이트 후에는 이 단계를 매번 한다.)
4. 터미널 **아무 곳이나 우클릭 → `현재 폴더: VS Code에서 열기` / `현재 폴더: Finder에서 열기` / `현재 폴더: 정리(clean)…`**.
   프로필과 관계없이 모든 창에 나온다.

### 2-4. C. 클릭 버튼 (iTerm2 3.7 이상 실행 중일 때)

1. 설치:
   ```sh
   zsh install.sh buttons
   ```
2. 자가 테스트 — 별 버튼을 클릭해 `✅ 성공` 이 나오는지 확인:
   ```sh
   zsh ~/.zsh/iterm2-tools/ib-selftest.zsh
   ```
   `❌` 이면 실행 중인 iTerm2 가 3.7 미만이다 → iTerm2 재시작 후 다시 시도.
3. `~/.zshrc` 에 **직접** 추가:
   ```zsh
   source ~/.zsh/iterm2-tools/iterm-buttons.zsh
   ib_add 1 hammer.fill 'make build'     # code(양의 정수)  SF Symbol 이름  명령
   ib_add 2 play.fill   'make run'
   # IB_MODE=run                         # 기본(insert) 대신 클릭 즉시 실행하려면
   ```
4. 새 셸에서 `ib_bar` → 버튼 줄이 출력된다.

### 2-5. 언어 (English / 한국어)

모든 실행 파일(설치기·`iterm-clean`·`iterm-open`·우클릭 메뉴·버튼)은 영어와 한국어 화면을 함께 갖고 있고, 실행할 때 아래 순서로 언어를 고른다.

| 순서 | 정하는 곳 | 예 |
|---|---|---|
| 1 | 환경변수 `IT2_LANG` (`en` / `kr`) | `IT2_LANG=en iterm-clean` |
| 2 | 저장된 설정 `~/.config/iterm2-tools/lang` | `zsh install.sh --lang en status` 로 저장 |
| 3 | macOS 언어(시스템 설정 → 일반 → 언어 및 지역의 첫 번째 언어) | 한국어면 한국어 |
| 4 | 그 밖 | 영어 |

```sh
zsh install.sh --lang en path       # 영어로 저장하고 A 설치(프로필·우클릭 항목 이름도 영어)
zsh install.sh --lang kr status     # 한국어로 저장
zsh install.sh --lang auto status   # 저장값을 지우고 macOS 언어를 따름
```

- 언어를 바꾼 뒤 `iterm-clean`·`iterm-open`·설치기는 다음 실행부터 바로 바뀐다.
- A 의 프로필·우클릭 항목 이름은 `zsh install.sh path` 를 다시 실행해야 바뀐다(프로필 GUID 는 유지). B 메뉴 이름은 **Scripts → AutoLaunch → open_in_tools.py** 를 다시 실행해야 바뀐다. 우클릭 메뉴와 그 정리 탭은 iTerm2 가 직접 실행하므로 `~/.zshrc` 에 넣은 `IT2_LANG` 이 닿지 않을 수 있다 — 이 둘의 언어는 `--lang` 으로 정한다.
- iTerm2 자체 메뉴(Scripts, Profiles 등)와 macOS·git·`trash` 가 내는 메시지는 이 패키지가 바꾸지 않는다.
- 판정 범주(`cache`/`build`/`deps`), 확인 입력 `yes`, 메뉴 번호 `1`/`2`/`3`/`q` 는 두 언어에서 같다.
- 이 문서는 한국어 화면 기준이다. 영어 화면의 문구는 영어 문서를 본다.

### 한 번에 설치

```sh
zsh install.sh all
```

---

## 3. 사용법 요약

### A. 경로 우클릭 — 인식되는 텍스트
| 출력된 텍스트 | 동작 |
|---|---|
| `src/main.py`, `./a/b.txt`, `~/dev/x.js`, `../x/y`, `/abs/dir` | 그 파일·폴더 |
| `main.py:12:3`, `app/x.ts:7` | VS Code 에서 해당 줄·열 |
| `README.md` (확장자 있는 파일명) | 그 파일 |
| `error: foo.c:3: bad` | 메시지 안의 `foo.c:3` |

- 상대경로는 **그 탭의 현재 폴더** 기준(셸 통합 불필요).
- 없는 경로면 아무것도 열지 않고 알림만 표시.
- 경로 위 **⌘클릭** = 첫 동작(VS Code 열기).
- 공백이 들어간 경로는 인식하지 않는다.

### B. 어디서나 우클릭
- 우클릭한 탭의 현재 폴더를 VS Code / Finder 로 연다.
- `정리(clean)…` 은 바로 지우지 않는다. 그 폴더에서 **새 탭**을 열어 아래 D 의 절차를 실행한다.

### D. 폴더 정리(clean)

**절차** — 우클릭 `현재 폴더: 정리(clean)…` (= `iterm-clean --menu`)
1. 범위 선택: `1` 캐시+빌드(기본, Enter) / `2` 캐시만 / `3` 전부(의존성 포함) / `q` 취소
2. **드라이런 결과** 표시 — 항목별 범주·크기·판정 근거(예: `rust/target/ (Cargo.toml)`), 합계, 건너뛴 항목과 이유. **아무것도 바꾸지 않는다.**
3. 결과를 확인한 뒤: **`yes`** = 이 드라이런 목록 **그대로** 휴지통으로 / **Enter**(또는 그 외 입력) = 정리하지 않고 끝
4. Enter 로 탭 닫기

드라이런만 보려면 3 에서 Enter, 바로 정리하려면 3 에서 `yes` — 메뉴는 하나로 둘 다 된다. `yes` 를 정확히 입력해야만 옮긴다. `no`·빈 줄·`y`·`YES`·입력 없음은 **취소(아무것도 바꾸지 않음)**. 보여 준 목록만 휴지통으로 옮기며(영구 삭제 아님) Finder 휴지통에서 복원할 수 있다.

**명령으로 쓰기** (iTerm2 가 아니어도 됨)
```sh
iterm-clean                    # 현재 폴더 드라이런 (기본 — 아무것도 바꾸지 않음). -n / --dry-run 과 같음
iterm-clean --menu             # 드라이런 결과 → 확인 후 yes 면 그 결과대로 정리, Enter 면 종료
iterm-clean -c all ~/work/app  # 의존성까지 포함해 드라이런
iterm-clean --trash            # 목록 → yes 확인 → 휴지통
iterm-clean --rules            # 판정 규칙 표
```

**범주와 판정 규칙** (전체 표: `iterm-clean --rules`)

| 범주 | 판정 | 예 |
|---|---|---|
| `cache` | 이름만으로 확실한 캐시·OS 찌꺼기 | `__pycache__` `.pytest_cache` `.mypy_cache` `.ruff_cache` `.tox` `*.egg-info` `*.pyc`(옆에 원본 `.py` 가 있을 때만) `.next` `.nuxt` `.svelte-kit` `.turbo` `.parcel-cache` `*.tsbuildinfo` `.kotlin` `cmake-build-*` `DerivedData` `.zig-cache` `.DS_Store` |
| `build` | **같은 폴더에 빌드 파일이 있을 때만** | `target`+`Cargo.toml`/`pom.xml`/`build.sbt` · `build`+`build.gradle(.kts)`/`CMakeLists.txt`/`pubspec.yaml`/`setup.py`/`pyproject.toml` · `dist`+`package.json`/`pyproject.toml` · `bin`·`obj`+`*.csproj` · `.build`+`Package.swift` · `.dart_tool`+`pubspec.yaml` · `_build`+`mix.exs` · `.gradle`·`.stack-work`·`dist-newstyle`·`zig-out`·`.angular`·`coverage` · `*.tsbuildinfo`(캐시·빌드 어느 쪽을 골라도 지움) |
| `deps` | 설치된 의존성(지우면 다시 설치) — 기본 제외 | `node_modules` `bower_components` `.pnpm-store` · `.venv`/`venv`/`env`(안에 `pyvenv.cfg`) · `vendor`+`composer.json` · `Pods`+`Podfile` · `deps`+`mix.exs` |

**원칙: clean 은 다시 만들 수 있는 것을 모두 지우되, 다시 빌드가 안 되는 반쪽 상태를 남기지 않는다.**

**TypeScript `*.tsbuildinfo` — 어떤 선택에서도 지우는 이유 (tsc 5.6.3 실측)**

| 지운 것 | 다시 `tsc` / `tsc -b` 했을 때 |
|---|---|
| tsbuildinfo 만 | 정상 — 전체를 다시 빌드(한 번 느려질 뿐) |
| dist 만 (tsbuildinfo 남김) | **결과 파일을 다시 만들지 않음** — "이미 빌드됨" 기록이 남아 있어서 |
| 둘 다 | 정상 |

그래서 tsbuildinfo 는 캐시·빌드 어느 쪽을 골라도 지운다(dist 를 지울 때 반드시 함께 지워짐). `tsconfig.json` 에 `tsBuildInfoFile` 로 위치를 바꾼 프로젝트는 그 파일을 찾을 수 없으므로 목록에 **경고**를 표시한다 — 그 파일도 직접 지우거나 `tsc -b --force` 로 빌드.

**그 밖에 반쪽 정리를 막는 규칙**
- `__pycache__` 밖의 `*.pyc` 는 옆에 같은 이름의 `.py` 가 있을 때만 지운다(`.py` 없는 `.pyc` 는 그 모듈의 유일한 사본일 수 있음).
- `CMakeFiles` 는 `build/`·`cmake-build-*` 안에 있을 때만(그 폴더째) 지운다. 소스 폴더에 직접 빌드한 경우는 `CMakeCache.txt`·`Makefile` 이 남는 반쪽 상태가 될 수 있는데, cmake 가 없어 실측하지 못했으므로 지우지 않는다.
- `*.egg-info` 는 Python 표준 정리 대상(`rm -rf build dist *.egg-info`)으로 지운다. 단, 옛 방식 editable 설치(`setup.py develop`)는 이 폴더를 참조하므로 정리 후 `pip install -e .` 를 다시 해야 할 수 있다 — setuptools 를 오프라인으로 준비할 수 없어 **미실측**.

**규칙 추가하기** — 모든 언어를 다 담은 것은 아니다(예: OCaml `_build`, Scala `.bloop`, Ruby `vendor/bundle`, Unity `Library`, IntelliJ `out` 미포함). `bin/iterm-clean` 의 `RULES` 에 한 줄을 넣고 `zsh install.sh path`(또는 `anywhere`)로 다시 설치한다.
```zsh
#  범주 | d=폴더 f=파일 | 이름(glob) | 증거(비우면 이름만, 쉼표=하나라도, in:X=폴더 안에 X)
  'build|d|_build|dune-project'          # 예: OCaml(dune)
  'deps|d|vendor|Gemfile'                # 예: Ruby — 주의: Rails 의 vendor/ 는 커밋 대상일 수 있음
```
흔한 이름은 반드시 증거 파일을 붙이고, 추가 후 `zsh tests/test_iterm_clean.zsh` 로 확인한다.

**안전장치**
- `build`·`dist`·`target`·`bin`·`vendor`·`env` 처럼 흔한 이름은 증거 파일이 없으면 대상이 아니다(소스 폴더 보호). Go 의 `vendor`(커밋 대상)는 대상이 아니다.
- git 저장소 안에서 **추적 중인 파일이 들어 있으면 건너뜀**. git(개발자 도구)이 없는 Mac 에서는 저장소 안 항목을 확인할 수 없으므로 **모두 건너뜀**.
- 안에 별도 `.git` 저장소가 있는 폴더는 건너뜀(의존성 제외).
- `.git`·`.hg`·`.svn`·`*.app`·`*.framework` 안으로 들어가지 않음. 심볼릭 링크는 따라가지도 지우지도 않음. 다른 디스크로 넘어가지 않음.
- 시작 폴더 거부: `/`, 홈 폴더 자체, `~/Library`, `~/.숨김폴더`, `/System`·`/Library`·`/Applications`·`/usr`·`/opt` 등.
- `.env*`·`.idea`·`.vscode`·잠금 파일(`package-lock.json` 등)은 어떤 규칙에도 해당하지 않으며, 파일 **내용은 읽지 않는다**(이름만 본다).
- 휴지통 이동: `/usr/bin/trash`(`man trash`: macOS 15.0 부터, 같은 이름 자동 처리). macOS 14 이하에서는 `~/.Trash` 로 직접 이동(같은 디스크만, 이름 충돌 시 `이름 2` …) — 이 대체 경로는 테스트 전용 폴더로만 검증했고 실제 macOS 14 이하에서는 미검증.
- 메뉴 모드에서 거부·오류가 나면 메시지를 보여 주고 Enter 를 기다린 뒤 탭을 닫는다.

### C. 클릭 버튼
| 모드 | 클릭 시 |
|---|---|
| `IB_MODE=insert` (기본) | 명령을 입력줄에 넣음(입력 중이던 내용은 교체). Enter 는 사용자가 |
| `IB_MODE=run` | 입력 중이던 내용은 보존하고 즉시 실행 |

- 다른 명령을 실행하면 기존 버튼은 **회색(비활성)** 이 된다 — 실행 중인 프로그램(vim 등)에 클릭 신호가 들어가지 않게 하는 의도된 동작. 다시 쓰려면 `ib_bar`.

---

## 4. 설치 확인 체크리스트

```sh
zsh install.sh status
```

| 확인 항목 | 기대 결과 |
|---|---|
| A | `설치됨 ~/bin/iterm-open`, `설치됨 …/dp-open-in.json`, `프로필 파일 형식 정상` |
| B | `설치됨 …/open_in_tools.py`, `Python 런타임 있음`, `open_in_tools.py 실행 중: 1개` |
| C | `설치됨 …/iterm-buttons.zsh`, `.zshrc 에 버튼 설정 있음` |

회귀 테스트(실제로 앱을 열지 않음) — 모두 `PASS` 여야 한다:
```sh
zsh install.sh test
```

A 실행기 단독 점검(실제로 열지 않고 명령만 출력):
```sh
IO_DRYRUN=1 ~/bin/iterm-open vscode "$PWD" README.md
```

---

## 5. 문제 해결

| 증상 | 원인 | 조치 |
|---|---|---|
| 경로 위에서만 메뉴가 보이고 빈 곳에서는 안 보임 | A 는 **설계상** 규칙에 맞는 텍스트 위에서만 동작 | 어디서나 쓰려면 B 설치 |
| B 에서 `VS Code에서 열기` 를 누르면 **Finder 도 같이 열림** | 이전 버전 결함: 두 메뉴가 같은 RPC 이름(`handler`)으로 등록되어, iterm2 라이브러리가 한 번의 클릭에 같은 이름의 콜백을 모두 실행 | `zsh install.sh anywhere` 로 업데이트 → **Scripts → AutoLaunch → open_in_tools.py** 재실행 → `zsh install.sh test` PASS 확인 |
| `실행 중인 스크립트가 설치 파일보다 오래됨` 경고 | 파일만 바뀌고 이전 버전이 계속 실행 중 | **Scripts → AutoLaunch → open_in_tools.py** 재실행 (또는 `zsh install.sh anywhere` 재실행) |
| (다른 Mac) B 항목이 안 보이고 `status` 에 `Rosetta 2 가 없습니다` | Apple Silicon 인데 Intel 전용 Python 런타임을 실행할 Rosetta 2 가 없음 | 터미널에서 `softwareupdate --install-rosetta --agree-to-license` 실행 후 **Scripts → AutoLaunch → open_in_tools.py** |
| (다른 Mac) B 항목이 안 보이고 `status` 에 `Python API 꺼짐` | 새 iTerm2 기본값. 첫 실행 때 뜬 `Enable Python API?` 에서 Cancel 했거나 창이 안 뜸 | **Scripts → AutoLaunch → open_in_tools.py** 를 다시 실행해 창에서 **OK**. 창이 다시 안 뜨면 iTerm2 Settings → General → Magic 탭 → *Enable Python API* 켜기 (3.6.9 설정 화면 정의 파일로 위치 확인) |
| (다른 Mac) `macOS 12 이상이 필요합니다` 로 설치 중단 | macOS 11 이하 | macOS 업데이트 필요 |
| (다른 Mac) `B 는 iTerm2 3.4.0 이상이 필요합니다` | 오래된 iTerm2 | iTerm2 업데이트 |
| (다른 Mac) `Permission denied` 로 `./install.sh` 실행 안 됨 | 복사 중 실행 권한이 빠짐 | `zsh install.sh …` 형태로 실행 |
| B 항목이 메뉴에 없음 | 스크립트 미실행 | `status` 에서 `실행 중: 0개` 면 **Scripts → AutoLaunch → open_in_tools.py**. 그래도 없으면 **Scripts → Script Console** 에서 오류 확인 |
| Install Python Runtime 을 눌러도 반응 없음 | 화면 표시 없이 설치가 끝남 | `zsh install.sh status` 로 `Python 런타임 있음` 확인 |
| Profiles 메뉴에 `우클릭 도구` 가 없음 | DynamicProfiles 폴더의 **다른 파일이 깨져 있으면** iTerm2 가 전체 변경을 무시 | 각 파일 점검: `plutil -convert xml1 -o /dev/null <파일>` |
| C 버튼이 안 보이거나 자가 테스트 `❌` | 실행 중인 iTerm2 가 3.7 미만(3.6.9 는 custom 버튼 미지원) | iTerm2 완전 종료 후 재시작 |
| `설치본과 실행본이 다릅니다` / Settings 가 안 열림 등 이상 동작 | iTerm2 가 실행 중에 업데이트되어 실행 파일과 디스크 파일이 불일치 | 작업을 정리한 뒤 iTerm2 재시작 |
| VS Code 에서 줄 이동이 안 됨 | VS Code CLI 를 찾지 못해 앱으로만 연 경우 | VS Code 가 `/Applications` 또는 `~/Applications` 에 있는지 확인 |
| 정리 탭에 `홈 폴더 전체는 정리할 수 없습니다` | 우클릭한 탭의 현재 폴더가 `~` | 프로젝트 폴더로 `cd` 한 뒤 다시 우클릭 |
| 정리 목록에 `git 저장소 안인데 git 이 없어 … 건너뜀` | 개발자 도구(git)가 없는 Mac | `xcode-select --install` 로 설치하거나 그대로 둔다(안전 쪽 동작) |
| 정리 목록에 원하는 폴더가 없음 | 증거 파일이 없거나(예: `build` 옆에 빌드 파일 없음) git 추적 중, 또는 `deps` 미선택 | `iterm-clean --rules` 로 규칙 확인, 의존성은 `-c all`(메뉴 `3`) |
| `정리(clean)…` 을 눌러도 탭이 안 열림 | `~/bin/iterm-clean` 미설치, 또는 폴더 이름에 `$$` · `\(` 가 있음(iTerm2 가 다시 해석하는 문자라 열지 않음) | `zsh install.sh anywhere` / 터미널에서 `iterm-clean --trash` 직접 실행 |
| 화면이 원하는 언어로 안 나옴 | 환경변수 `IT2_LANG` 이나 저장된 설정이 macOS 언어보다 먼저 적용됨 | `zsh install.sh status` 첫 줄에서 언어와 그 출처 확인 → `zsh install.sh --lang kr status` (또는 `en`, `auto`) |
| `iterm-open 이 이미 있고 이 패키지 파일이 아닙니다` | 같은 이름의 다른 파일 보호 | 내용을 확인한 뒤 직접 정리하고 다시 설치 |

---

## 6. 보안 설계

- A: iTerm2 는 매치된 텍스트를 셸 이스케이프해서 넘긴다. `iterm-open` 은 인자를 따옴표로만 다루고 `eval` 하지 않으며, 실행 대상은 VS Code CLI / `open` 으로 고정. (`$(…)` 주입 시도가 실행되지 않음을 시험함)
- B: 셸을 거치지 않는 `exec` 로 실행 — 경로의 특수문자가 명령으로 해석되지 않는다.
- D: 기본은 드라이런, 이동은 `yes` 정확 입력 후 **휴지통으로만**(영구 삭제 없음). 확인 후 다시 찾지 않고 보여 준 목록만 옮긴다. 경로는 항상 절대 경로로 넘긴다 — `/usr/bin/trash` 는 `--` 를 옵션 끝이 아니라 **파일 이름**으로 처리함을 실측해 쓰지 않는다. 우클릭 메뉴는 폴더를 명령 인자가 아니라 새 탭의 작업 폴더로 넘긴다.
- C: 버튼은 어떤 출력으로도 그려질 수 있으므로, 클릭에서 받는 값은 **숫자 code 뿐**이고 실행 내용은 `ib_add` 로 등록한 표에서만 찾는다.
- 권한: 손쉬운 사용·관리자 권한을 요구하지 않는다.

---

## 7. 제거

```sh
cd ~/iterm2-tools && zsh uninstall.sh
```
- 이 패키지가 설치한 파일만 지운다(다른 파일은 건너뜀). 저장된 언어 설정(`~/.config/iterm2-tools/lang`)도 지운다.
- `~/.zshrc` 에 넣은 C 설정 줄은 직접 지운다.
- B 메뉴 항목은 다음 iTerm2 재시작 때 사라진다.

---

## 8. 검증 내역

| 항목 | 방법 | 결과 |
|---|---|---|
| 설치·재설치·제거 | 공백이 든 가짜 홈 폴더에서 `install.sh all` → `path` 재실행 → `uninstall.sh` | 통과, 재설치 시 프로필 GUID 유지, 제거 후 잔여 파일 없음 |
| A 경로 규칙 | iTerm2 와 같은 ICU 정규식 엔진으로 10개 사례 | 통과 |
| A 실행 경로 | iTerm2 와 같은 이스케이프 + `/bin/sh -c` 로 실행(드라이런) | 통과, 주입 미실행 |
| A 실제 우클릭 | iTerm2 3.6.9 에서 사용자 확인 | 메뉴 표시·동작 확인 |
| B 스크립트 | iTerm2 런타임 Python 3.7/3.8/3.10/3.14 문법 검사 | 통과 |
| B 메뉴 클릭 → 실행 도구 | `tests/test_open_in_tools.py`: iterm2 라이브러리의 실제 등록·디스패치 코드로 각 메뉴 클릭을 재현(Python 3.10·3.14) | 이전 버전 FAIL(클릭 1번에 VS Code+Finder 2건) 재현 → 수정 후 PASS(항목당 1건) |
| A 동작 → 실행 명령 | `tests/test_iterm_open.zsh` (7개 사례, 공백 포함 경로) | PASS (동작당 1건, 주입 미실행) |
| B 실제 우클릭 | iTerm2 3.6.9 에서 사용자 확인 | 어디서나 메뉴 표시 확인. 수정 후 `VS Code에서 열기` → VS Code 만, `Finder에서 열기` → Finder 만 실행 확인 |
| C 플러그인 | pty 에서 클릭 바이트 주입(insert/run 모드, 미등록 코드) | 통과 |
| C 실제 클릭 | — | **미검증**. 3.6.9 는 버튼 미지원, 3.7 이상 재시작 후 `ib-selftest.zsh` 로 확인 |
| 이식성 S1 새 Mac | 설정 파일 없는 가짜 홈 | PASS (기본 위치 설치, 규칙 12, 제거 후 잔여 0) |
| 이식성 S2 폴더 위치 변경 | `dynamicProfilesPath`·`CustomScriptsFolder`(공백 포함) 지정 | PASS (바뀐 위치에 설치·제거) |
| 이식성 S3 지정 폴더 없음 | `CustomScriptsFolder` 가 없는 경로 | PASS (iTerm2 와 같이 기본 위치 사용) |
| 이식성 S4 사용자 지정 규칙 | 기본 프로필에 자기 규칙 1개 | PASS (그 규칙 이어받음, 규칙 2) |
| 이식성 S5 Python API | 꺼짐/켜짐 | PASS (꺼짐이면 안내 표시) |
| 이식성 S6 버전 조건 | macOS 11.7/12.0, iTerm2 3.3.12/3.4.0/3.6.11/3.7.7 흉내 | PASS (중단·진행·경고 기준 정확) |
| 이식성 S7 Rosetta | Apple Silicon + Intel 전용 런타임, Rosetta 유/무 | PASS (없으면 경고 + 설치 명령) |
| Intel(x86_64) 실행 | A·이식성 테스트를 `arch -x86_64` 로 실행 | PASS |
| VS Code CLI 없는 Mac | A·B 테스트에서 CLI 없음 흉내 | PASS (`open -b com.microsoft.VSCode` 로 1건 실행) |
| 옮긴 패키지 | 격리 표시 + 실행 권한 제거 상태에서 `zsh install.sh` | PASS (설치·실행 정상) |
| **실제 다른 macOS (Parallels VM)** | macOS 26.6.2 / Apple Silicon / Xcode·CLT·Homebrew·Rosetta·VS Code 없음 / iTerm2 를 `~/Applications` 에 둠. 일반 사용자 권한·임시 HOME 으로 `zsh install.sh test` → `all` → `status` → `uninstall.sh` | 실행한 테스트 모두 PASS. B 단위 테스트는 Rosetta 없음으로 **건너뜀**(그 Mac 에서는 B 자체가 실행 불가 — 설치 스크립트가 감지해 설치 명령 안내). 설치 위치·프로필 형식(규칙 12)·VS Code 없음 대체 경로·제거 후 잔여 0 확인 |
| VM 에서 발견해 고친 테스트 결함 | — | ① VS Code 있다고 가정한 A 기대값 ② iTerm2 를 `/Applications` 에서만 찾던 이식성 테스트 ③ Rosetta 없는 Mac 에서 Intel 전용 Python 실행·런타임을 문자열 순으로 고르던 문제 ④ S7 이 Rosetta 있다고 가정. 제품 코드 결함은 없었음 |
| D 판정(언어별) | `tests/test_iterm_clean.zsh` [1]: Python·Rust·Maven·Gradle·Node·.NET·Swift·Flutter·Elixir·PHP·iOS·CMake 픽스처 + 증거 없는 `bin/build/target/dist/vendor/env/venv/Pods`·`.env`·앱 번들 | PASS — 범주별 후보 목록이 기대와 정확히 일치, 음성 사례 0건 |
| D 드라이런·확인 | [2][3]: 전후 트리(이름·크기·수정시각·권한) 비교, `no`·빈 줄·`y`·`YES`·EOF 입력 | PASS — 변화 없음 |
| D 휴지통 이동 | [4]: `yes` → 후보 27개 이동, 같은 이름 `__pycache__` 4개 충돌 없이 보관, 공백·한글·`-`시작·줄바꿈 이름, 심볼릭 링크·`.env`·소스 보존 / [8]: 실제 `/usr/bin/trash` 1건 | PASS |
| D git 보호 | [5]: 추적 중 `dist/` 건너뜀, 내부 `.git` 있는 `build/` 건너뜀, git 없는 Mac 흉내 | PASS |
| D TypeScript | tsc 5.6.3 으로 incremental·composite(`-b`) 프로젝트에서 tsbuildinfo 만 / dist 만 / 둘 다 지운 뒤 재빌드 · `iterm-clean -c build` 로 정리 후 재빌드 | dist 만 지우면 재출력 안 됨(결함 확인) → 같은 범주로 수정 후 dist·tsbuildinfo 함께 이동, 재빌드로 `dist/a.js` 재생성 |
| D 정리 메뉴(드라이런 단계) | [7-2]: 드라이런 후 Enter·`no`·EOF → 변화 없음, 결과와 '변경 없음' 안내 표시, `yes` → 드라이런에서 본 27개 그대로 이동·목록 밖 보존, `--trash`+`--dry-run` 거부 | PASS |
| D 거부·메뉴 | [6][7]: `/`·`~`·`~/Library`·`/usr`·`/Applications` 거부, 메뉴 `q`/`no`/`2+yes`, 홈에서 메뉴 거부 | PASS |
| D 속도 | 합성 프로젝트 10만 파일(`target` 4만·`node_modules` 4만·`.venv` 2만, `__pycache__` 300개) 드라이런 | 1.6초, 후보 303개 정확 |
| D 테스트 자체 검증 | 일부러 결함을 넣은 사본 4종(증거 규칙 제거·확인 무시·git 보호 제거·링크 따라가기)으로 실행 | 4종 모두 FAIL 로 잡힘(링크는 이중 방어라 둘 다 제거했을 때) |
| B 정리 메뉴 | `tests/test_open_in_tools.py`: 정리 항목 1개만 등록 확인, 클릭 → 실행 0건·새 탭 1개(명령 `iterm-clean --menu`, 작업 폴더 = 우클릭한 폴더), 그 명령을 실제 실행해 시작 확인, `$$`·`\(` 폴더는 탭 안 열림 — iterm2 2.11·2.30 | PASS |
| 문서 짝 | `tests/test_docs.zsh`: 영어·한국어 문서의 구조 비교, 일부러 한쪽만 고친 사본(절 삭제·명령 변경·표 행 추가·짝 파일 없음·링크 누락)으로 실행 | PASS — 고친 사본은 모두 FAIL 로 잡힘 |
| 언어 선택 | `tests/test_lang.zsh` [1][2] + `tests/test_open_in_tools.py`: 공통 언어 선택 코드가 zsh 실행 파일 4개에서 글자 그대로 같음, 선택 순서 12가지(IT2_LANG > 저장된 설정 > macOS 언어 > 영어)를 zsh 4개·버튼 플러그인·Python 메뉴에서 각각 실행(가짜 HOME) | PASS |
| 영어 화면 | `IT2_LANG=en` 으로 각 경로 실행: D [9] 51건(도움말·규칙·드라이런·건너뜀 이유·확인 `no`/빈 줄/`YES`/`y`/EOF 취소·`yes` 이동·실패·거부), 설치·상태·제거(S8a), B 메뉴 이름, `iterm-open`·`ib-selftest`·`ib_add` | PASS — 영어 출력에 한글 0자(한글 픽스처 이름 제외), 프로필 이름·우클릭 항목도 영어 |
| 언어와 무관한 동작 | 같은 폴더를 한국어·영어로 실행해 비교 | PASS — `--print0` 목록 바이트 단위 같음, 종료 코드 같음, 두 언어 모두 `yes` 만 진행, RPC 이름·고유 ID 같음, 언어를 바꿔 재설치해도 프로필 GUID 유지 |
| 번역 누락 정적 검사 | `tests/test_lang.zsh` [4]: 제품 코드에서 주석이 아닌 한글이 번역 함수(`t`·`_ib_t`)나 언어별 표 밖에 있는지 | PASS — 0곳 |
| 언어 테스트 자체 검증 | 일부러 결함을 넣은 사본: 영어 문구를 한국어로(iterm-clean 2종·설치기·iterm-open·ib-selftest), 영어에서 `y` 도 진행, 공통 블록 변경, 플러그인 언어 판정 고장 | 모두 FAIL 로 잡힘 |
| 전체 테스트 · 언어 환경 3가지 | `zsh install.sh test` 를 기본(이 Mac: 한국어), `IT2_LANG=en`, macOS 영어 흉내로 각각 실행 · B 는 iterm2 2.11·2.30, Python 3.7·3.10·3.14 | 모두 PASS (기존 검사는 한국어로 고정해 환경과 무관) |
| 미검증 | — | D 의 실제 iTerm2 우클릭 → 새 탭 동작은 사용자 확인 필요(설치 후 iTerm2 에서). 실제 iTerm2 GUI 에서의 우클릭·버튼 클릭은 VM 에서 하지 않음(이 Mac 에서 A·B 는 사용자 확인 완료). 영어 메뉴·프로필 이름이 실제 iTerm2 화면에 보이는 것은 미확인(테스트로만 확인) |
