#!/bin/zsh -f
# 이식성 테스트 — "다른 Mac" 조건을 가짜 홈(HOME) + 가짜 iTerm2 설정 파일로 흉내 내어
# install.sh all → 결과 확인 → uninstall.sh 를 시나리오마다 실행한다.
# 실제 홈·실제 iTerm2 설정·실행 중인 스크립트는 건드리지 않는다(가짜 홈 안에서만 동작).
emulate -L zsh
setopt no_unset
ROOT=${0:A:h:h}
BASE=$(/usr/bin/mktemp -d)
export IT2_LANG=kr        # 아래 기존 점검은 한국어 문구를 확인한다 — 환경(IT2_LANG·macOS 언어)과 무관하게 고정
fail=0
# 가짜 홈에는 iTerm2 가 없으므로, 실제 환경에서 찾은 iTerm.app 위치를 시나리오에 넘긴다
# (iTerm2 를 /Applications 가 아닌 곳에 둔 Mac 에서도 테스트가 성립하도록)
export IT2_ITERM_APP=$(/bin/zsh "$ROOT/install.sh" where-iterm 2>/dev/null)
[[ -n $IT2_ITERM_APP ]] || { print "  ❌ iTerm2 를 찾지 못해 이식성 테스트를 실행할 수 없음"; exit 1 }
print -r -- "  (iTerm2: ${IT2_ITERM_APP/#$HOME/~})"
pass() { print -r -- "    ✅ $*" }
bad()  { print -r -- "    ❌ $*"; fail=1 }

# 가짜 iTerm2 설정 파일 만들기: mkprefs <home> <json>
mkprefs() {
  mkdir -p "$1/Library/Preferences"
  print -r -- "$2" > "$1/prefs.json"
  /usr/bin/plutil -convert binary1 -o "$1/Library/Preferences/com.googlecode.iterm2.plist" "$1/prefs.json"
  rm -f "$1/prefs.json"
}

# run <이름> <home> <기대 DP 폴더> <기대 Scripts 폴더> <기대 규칙 수> [<규칙에 있어야 할 문자열>]
run() {
  local name=$1 H=$2 dp=$3/dp-open-in.json al=$4/AutoLaunch/open_in_tools.py nrules=$5 must=${6:-}
  print -r -- "  [$name]"
  local out; out=$(HOME="$H" TERM_PROGRAM= /bin/zsh "$ROOT/install.sh" all 2>&1) || { bad "설치 실패: $out"; return }
  [[ -f $dp ]] && pass "프로필 위치: ${dp/#$H/~}" || bad "프로필 없음: ${dp/#$H/~}"
  [[ -f $al ]] && pass "B 스크립트 위치: ${al/#$H/~}" || bad "B 스크립트 없음: ${al/#$H/~}"
  [[ -x $H/bin/iterm-open ]] && pass "실행기: ~/bin/iterm-open" || bad "실행기 없음"
  if [[ -f $dp ]]; then
    /usr/bin/plutil -convert xml1 -o /dev/null "$dp" && pass "프로필 형식 정상" || bad "프로필 형식 오류"
    local n=$(/usr/bin/plutil -extract 'Profiles.0.Smart Selection Rules' raw -o - "$dp")
    [[ $n == $nrules ]] && pass "규칙 수 $n" || bad "규칙 수 $n (기대 $nrules)"
    local p=$(/usr/bin/plutil -extract 'Profiles.0.Smart Selection Rules.0.actions.0.parameter' raw -o - "$dp")
    [[ $p == "'$H/bin/iterm-open' vscode "* ]] && pass "동작 명령이 이 홈의 실행기를 가리킴" || bad "동작 명령 경로 이상: $p"
    [[ -z $must ]] || { /usr/bin/grep -q -- "$must" "$dp" && pass "기본 프로필 규칙 이어받음($must)" || bad "기본 프로필 규칙 누락($must)" }
  fi
  HOME="$H" /bin/zsh "$ROOT/uninstall.sh" >/dev/null 2>&1
  local left=( "$dp" "$al" "$H/bin/iterm-open" "$H/.zsh/iterm2-tools"/*(N) )
  left=( ${^left}(N) )
  (( ${#left} == 0 )) && pass "제거 후 잔여 0" || bad "제거 후 잔여: ${left}"
}

H=$BASE/"S1 new mac"; mkdir -p "$H"
run "S1 새 Mac(설정 파일 없음)" "$H" "$H/Library/Application Support/iTerm2/DynamicProfiles" "$H/Library/Application Support/iTerm2/Scripts" 12

H=$BASE/"S2 custom dirs"; mkdir -p "$H/my scripts"
mkprefs "$H" '{"dynamicProfilesPath":"~/dp custom","UseCustomScriptsFolder":true,"CustomScriptsFolder":"~/my scripts"}'
run "S2 폴더 위치를 바꾼 Mac" "$H" "$H/dp custom" "$H/my scripts" 12

H=$BASE/"S3 missing custom"; mkdir -p "$H"
mkprefs "$H" '{"UseCustomScriptsFolder":true,"CustomScriptsFolder":"~/없는폴더"}'
run "S3 지정한 Scripts 폴더가 없는 Mac(iTerm2 처럼 기본 폴더로)" "$H" "$H/Library/Application Support/iTerm2/DynamicProfiles" "$H/Library/Application Support/iTerm2/Scripts" 12

H=$BASE/"S4 custom rules"; mkdir -p "$H"
mkprefs "$H" '{"Default Bookmark Guid":"G-2","New Bookmarks":[{"Guid":"G-1","Name":"Other"},{"Guid":"G-2","Name":"Default","Smart Selection Rules":[{"notes":"user-custom-rule","precision":"high","regex":"TICKET-[0-9]+"}]}]}'
run "S4 기본 프로필에 사용자 지정 규칙이 있는 Mac" "$H" "$H/Library/Application Support/iTerm2/DynamicProfiles" "$H/Library/Application Support/iTerm2/Scripts" 2 user-custom-rule

print -r -- "  [S5 Python API 꺼짐/켜짐 표시]"
for v in false true; do
  H=$BASE/"S5 api $v"; mkdir -p "$H"; mkprefs "$H" "{\"EnableAPIServer\":$v}"
  s=$(HOME="$H" TERM_PROGRAM= /bin/zsh "$ROOT/install.sh" status 2>&1)
  if [[ $v == false ]]; then [[ $s == *"Python API 꺼짐"* ]] && pass "꺼짐 → 안내 표시" || bad "꺼짐 미표시"
  else [[ $s == *"Python API 켜짐"* ]] && pass "켜짐 표시" || bad "켜짐 미표시"; fi
done

print -r -- "  [S6 버전 조건 (오래된 macOS / iTerm2 흉내)]"
H=$BASE/"S6 versions"; mkdir -p "$H"
o=$(HOME="$H" IT2_TEST_MACOS_VER=11.7 /bin/zsh "$ROOT/install.sh" status 2>&1); rc=$?
(( rc != 0 )) && [[ $o == *"macOS 12 이상이 필요"* ]] && pass "macOS 11.7 → 설치 중단(명확한 메시지)" || bad "macOS 11.7 차단 실패: $o"
o=$(HOME="$H" IT2_TEST_MACOS_VER=12.0 /bin/zsh "$ROOT/install.sh" status 2>&1); rc=$?
(( rc == 0 )) && pass "macOS 12.0 → 진행" || bad "macOS 12.0 진행 실패"
o=$(HOME="$H" IT2_TEST_ITERM_VER=3.3.12 /bin/zsh "$ROOT/install.sh" anywhere 2>&1); rc=$?
(( rc != 0 )) && [[ $o == *"3.4.0 이상이 필요"* ]] && pass "iTerm2 3.3.12 → B 설치 중단" || bad "B 버전 차단 실패: $o"
o=$(HOME="$H" IT2_TEST_ITERM_VER=3.4.0 /bin/zsh "$ROOT/install.sh" anywhere 2>&1); rc=$?
(( rc == 0 )) && pass "iTerm2 3.4.0 → B 설치 진행" || bad "B 3.4.0 진행 실패"
o=$(HOME="$H" IT2_TEST_ITERM_VER=3.6.11 TERM_PROGRAM= /bin/zsh "$ROOT/install.sh" buttons 2>&1)
[[ $o == *"3.7.0 이상이 필요"* ]] && pass "iTerm2 3.6.11 → C 업데이트 필요 경고" || bad "C 경고 없음"
o=$(HOME="$H" IT2_TEST_ITERM_VER=3.7.7 TERM_PROGRAM=iTerm.app TERM_PROGRAM_VERSION=3.6.9 /bin/zsh "$ROOT/install.sh" buttons 2>&1)
[[ $o == *"실행 중인 iTerm2 가 3.6.9"* ]] && pass "설치 3.7.7 / 실행 3.6.9 → C 재시작 필요 경고" || bad "C 재시작 경고 없음"
o=$(HOME="$H" IT2_TEST_ITERM_VER=3.7.7 TERM_PROGRAM=iTerm.app TERM_PROGRAM_VERSION=3.7.7 /bin/zsh "$ROOT/install.sh" buttons 2>&1)
[[ $o != *"3.7.0 이상"* ]] && pass "3.7.7 실행 중 → C 경고 없음" || bad "3.7.7 에서 불필요한 경고"
HOME="$H" /bin/zsh "$ROOT/uninstall.sh" >/dev/null 2>&1

print -r -- "  [S7 Apple Silicon + Intel 전용 Python 런타임 + Rosetta 유무]"
pys=( "$HOME/Library/Application Support/iTerm2/iterm2env/versions"/*/bin/python3(Nn) ); REAL_PY=${pys[-1]:-}
if [[ $(/usr/bin/uname -m) != arm64 || -z $REAL_PY ]]; then
  print -r -- "    - 건너뜀 (Apple Silicon 이 아니거나 실제 런타임 없음)"
else
  H=$BASE/"S7 rosetta"; R="$H/Library/Application Support/iTerm2/iterm2env/versions/9.9/bin"; mkdir -p "$R"
  ln -s "$REAL_PY" "$R/python3"                       # 실제 런타임 바이너리(아키텍처 판정용)
  o=$(HOME="$H" IT2_TEST_NO_ROSETTA=1 /bin/zsh "$ROOT/install.sh" status 2>&1)
  [[ $o == *"Rosetta 2 가 없습니다"* && $o == *"softwareupdate --install-rosetta"* ]] && pass "Rosetta 없음 → 경고 + 설치 명령 안내" || bad "Rosetta 없음 경고 실패"
  o=$(HOME="$H" IT2_TEST_ROSETTA_OK=1 /bin/zsh "$ROOT/install.sh" status 2>&1)
  [[ $o == *"Rosetta 2 있음"* ]] && pass "Rosetta 있음(흉내) → 정상 표시" || bad "Rosetta 있음 표시 실패"
  # 이 Mac 의 실제 Rosetta 상태를 제품이 맞게 판정하는지
  o=$(HOME="$H" /bin/zsh "$ROOT/install.sh" status 2>&1)
  if /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
    [[ $o == *"Rosetta 2 있음"* ]] && pass "실제 상태(Rosetta 있음) 정확히 판정" || bad "실제 상태(있음) 오판"
  else
    [[ $o == *"Rosetta 2 가 없습니다"* ]] && pass "실제 상태(Rosetta 없음) 정확히 판정" || bad "실제 상태(없음) 오판"
  fi
fi

# ── S8. 언어(영어/한국어) ─────────────────────────────────
# 한글 음절(UTF-8 선행 바이트 EA..ED)이 한 글자라도 있으면 참 (로케일 무관 바이트 검사)
has_hangul() { print -r -- "$1" | LC_ALL=C /usr/bin/grep -q $'[\xea-\xed][\x80-\xbf][\x80-\xbf]' }
has_hangul "가나다" && pass "한글 검출기 자체 점검" || bad "한글 검출기가 한글을 못 찾음"
LF=.config/iterm2-tools/lang
L() { local H=$1; shift; HOME="$H" TERM_PROGRAM= IT2_LANG= IT2_TEST_SYS_LANG= /bin/zsh "$ROOT/install.sh" "$@" 2>&1 }   # IT2_LANG 비움 = 미지정

print -r -- "  [S8a 영어: 설치·상태·제거 출력에 한글 0, 프로필 이름·동작 제목 영어]"
H=$BASE/"S8a english"; mkdir -p "$H"
[[ $H != *[가-힣]* ]] && pass "가짜 홈 경로에 한글 없음" || bad "가짜 홈 경로에 한글 있음"
oi=$(HOME="$H" TERM_PROGRAM= IT2_LANG=en /bin/zsh "$ROOT/install.sh" all 2>&1); rci=$?
(( rci == 0 )) && pass "영어 설치 성공" || bad "영어 설치 실패: $oi"
has_hangul "$oi" && bad "영어 설치 출력에 한글 있음" || pass "영어 설치 출력에 한글 없음"
[[ $oi == *"Launcher:"* && $oi == *"Profile: 'Right-click tools'"* ]] && pass "영어 설치 문구 확인" || bad "영어 설치 문구 이상"
DPF="$H/Library/Application Support/iTerm2/DynamicProfiles/dp-open-in.json"
nm=$(/usr/bin/plutil -extract Profiles.0.Name raw -o - "$DPF")
t0=$(/usr/bin/plutil -extract 'Profiles.0.Smart Selection Rules.0.actions.0.title' raw -o - "$DPF")
t1=$(/usr/bin/plutil -extract 'Profiles.0.Smart Selection Rules.0.actions.1.title' raw -o - "$DPF")
[[ $nm == "Right-click tools" && $t0 == "Open in VS Code" && $t1 == "Show in Finder" ]] && pass "프로필 이름·동작 제목 영어" || bad "프로필 영어 이상: $nm / $t0 / $t1"
os=$(HOME="$H" TERM_PROGRAM= IT2_LANG=en /bin/zsh "$ROOT/install.sh" status 2>&1)
has_hangul "$os" && bad "영어 status 에 한글 있음" || pass "영어 status 에 한글 없음"
[[ $os == *"Language: English (IT2_LANG environment variable)"* ]] && pass "status 언어 줄(환경변수)" || bad "status 언어 줄 이상"
ou=$(HOME="$H" IT2_LANG=en /bin/zsh "$ROOT/uninstall.sh" 2>&1)
has_hangul "$ou" && bad "영어 제거 출력에 한글 있음" || pass "영어 제거 출력에 한글 없음"
[[ $ou == *"Remaining steps"* ]] && pass "영어 제거 안내문" || bad "영어 제거 안내문 이상"
left=( "$DPF" "$H/bin/iterm-open" "$H/.zsh/iterm2-tools"/*(N) "$H/.config/iterm2-tools"(N) )
left=( ${^left}(N) ); (( ${#left} == 0 )) && pass "영어 제거 후 잔여 0" || bad "영어 제거 후 잔여: ${left}"
# 영어 오류 메시지도 영어
o=$(HOME="$H" IT2_LANG=en IT2_TEST_MACOS_VER=11.7 /bin/zsh "$ROOT/install.sh" status 2>&1)
[[ $o == *"macOS 12 or later is required"* ]] && ! has_hangul "$o" && pass "영어 버전 오류 메시지" || bad "영어 버전 오류 메시지 이상: $o"

print -r -- "  [S8b --lang 저장·전환·삭제, GUID 유지]"
H=$BASE/"S8b lang"; mkdir -p "$H"
o=$(L "$H" --lang kr path); rc=$?
(( rc == 0 )) && [[ -f $H/$LF && $(<$H/$LF) == kr && $(/usr/bin/stat -f %Lp "$H/$LF") == 644 ]] && pass "--lang kr → 설정 파일 kr (0644)" || bad "--lang kr 저장 실패 rc=$rc"
DPF="$H/Library/Application Support/iTerm2/DynamicProfiles/dp-open-in.json"
nm=$(/usr/bin/plutil -extract Profiles.0.Name raw -o - "$DPF"); g1=$(/usr/bin/plutil -extract Profiles.0.Guid raw -o - "$DPF")
[[ $nm == "우클릭 도구" && $(/usr/bin/plutil -extract 'Profiles.0.Smart Selection Rules.0.actions.0.title' raw -o - "$DPF") == "VS Code에서 열기" ]] && pass "한국어 프로필 이름·제목" || bad "한국어 프로필 이상: $nm"
o=$(L "$H" status); [[ $o == *"언어: 한국어 (저장된 설정 ~/.config/iterm2-tools/lang)"* ]] && pass "status 언어 줄(저장된 설정, 한국어)" || bad "status 언어 줄 이상: $o"
o=$(L "$H" --lang en path); rc=$?
g2=$(/usr/bin/plutil -extract Profiles.0.Guid raw -o - "$DPF"); nm=$(/usr/bin/plutil -extract Profiles.0.Name raw -o - "$DPF")
[[ $(<$H/$LF) == en && $nm == "Right-click tools" ]] && pass "--lang en → 파일 en, 프로필 이름 영어로 전환" || bad "--lang en 전환 실패: $nm"
[[ -n $g1 && $g1 == $g2 ]] && pass "언어를 바꿔 재설치해도 GUID 유지" || bad "GUID 달라짐: $g1 → $g2"
has_hangul "$o" && bad "--lang en 설치 출력에 한글 있음" || pass "--lang en 설치 출력에 한글 없음"
o=$(L "$H" status); [[ $o == *"Language: English (saved setting ~/.config/iterm2-tools/lang)"* ]] && ! has_hangul "$o" && pass "다음 실행에도 저장값 유지(영어 status)" || bad "저장값 유지 실패: $o"
o=$(L "$H" --lang=kr status); [[ $(<$H/$LF) == kr && $o == *"언어: 한국어"* ]] && pass "--lang=kr 형식" || bad "--lang=kr 실패"
o=$(L "$H" --lang fr status); rc=$?
(( rc == 2 )) && [[ $o == *"Invalid --lang value: 'fr'"* || $o == *"올바르지 않습니다"* ]] && [[ $(<$H/$LF) == kr ]] && pass "--lang fr → 종료 2, 저장값 그대로" || bad "--lang fr 처리 이상 rc=$rc"
o=$(L "$H" --lang auto status); [[ ! -e $H/$LF ]] && pass "--lang auto → 설정 파일 삭제" || bad "--lang auto 후에도 파일 있음"
HOME="$H" IT2_LANG=en /bin/zsh "$ROOT/install.sh" --lang kr buttons >/dev/null 2>&1
ou=$(HOME="$H" IT2_LANG= /bin/zsh "$ROOT/uninstall.sh" 2>&1)
left=( "$DPF" "$H/bin/iterm-open" "$H/.zsh/iterm2-tools"/*(N) "$H/.config/iterm2-tools"(N) ); left=( ${^left}(N) )
(( ${#left} == 0 )) && [[ $ou == *"~/.config/iterm2-tools/lang"* ]] && pass "제거 시 언어 설정 파일·폴더까지 정리(잔여 0)" || bad "제거 후 잔여: ${left}"
[[ -d $H/.config ]] && pass "~/.config 자체는 남김" || bad "~/.config 가 지워짐"

print -r -- "  [S8c 언어 결정 순서: IT2_LANG → 저장 파일 → macOS 언어 → en]"
H=$BASE/"S8c order"; mkdir -p "$H"
sl() { HOME="$H" TERM_PROGRAM= IT2_LANG=${1} IT2_TEST_SYS_LANG=${2} /bin/zsh "$ROOT/install.sh" status 2>&1 }
o=$(sl "" ko-KR); [[ $o == *"언어: 한국어 (macOS 언어)"* ]] && pass "macOS ko-KR → 한국어" || bad "ko-KR 판정 이상"
o=$(sl "" en-US); [[ $o == *"Language: English (macOS language)"* ]] && pass "macOS en-US → 영어" || bad "en-US 판정 이상"
o=$(sl "" ""); [[ $o == *"Language: English (default)"* ]] && pass "언어 정보 없음 → 영어(기본값)" || bad "빈 값 판정 이상"
o=$(sl "" ja-JP); [[ $o == *"Language: English (macOS language)"* ]] && pass "macOS ja-JP(미지원) → 영어" || bad "ja-JP 판정 이상"
mkdir -p "$H/.config/iterm2-tools"; print -r -- kr > "$H/$LF"
o=$(sl "" en-US); [[ $o == *"언어: 한국어 (저장된 설정"* ]] && pass "저장 파일 > macOS 언어" || bad "저장 파일 우선순위 이상"
o=$(sl en en-US); [[ $o == *"Language: English (IT2_LANG environment variable)"* ]] && pass "IT2_LANG > 저장 파일" || bad "환경변수 우선순위 이상"
o=$(sl ko ""); [[ $o == *"언어: 한국어 (IT2_LANG 환경변수)"* ]] && pass "IT2_LANG=ko 도 한국어" || bad "IT2_LANG=ko 이상"
rm -rf "$H/.config"

rm -rf "$BASE"
print "결과: $( ((fail)) && print FAIL || print PASS)"
exit $fail
