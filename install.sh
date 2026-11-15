#!/bin/zsh
# iterm2-tools 설치 스크립트
#
#   zsh install.sh [--lang en|kr|auto] <명령>   # 출력 언어(영어/한국어) 지정·저장. auto = 저장값 지움(자동 판별)
#   zsh install.sh all          # A + B + C 모두
#   zsh install.sh path         # A. 경로 텍스트 우클릭 → VS Code / Finder
#   zsh install.sh anywhere     # B. 어디서나 우클릭 → 현재 폴더를 VS Code / Finder
#   zsh install.sh buttons      # C. 터미널 안 클릭 버튼 (zsh)
#   zsh install.sh status       # 설치 상태 점검만 (아무것도 바꾸지 않음)
#   zsh install.sh test         # 회귀 테스트 (실제로 앱을 열지 않음)
#
# 바꾸는 곳: 아래 경로의 이 패키지 파일만. ~/.zshrc · iTerm2 설정(plist)은 건드리지 않는다.

emulate -L zsh
setopt err_exit no_unset pipe_fail

ROOT=${0:A:h}
source "$ROOT/lib/common.zsh"            # 그 Mac 의 iTerm2 설정으로 설치 경로 계산
SUP=$IT2_SUP
BIN_DIR=$IT2_BIN_DIR
ZSH_DIR=$IT2_ZSH_DIR
DP_FILE=$IT2_DP_FILE
AL_FILE=$IT2_AL_FILE

say()  { print -r -- "  $*" }
ok()   { print -r -- "  ✅ $*" }
warn() { print -r -- "  ⚠️  $*" }
die()  { print -u2 -r -- "  ❌ $*"; exit 1 }

usage() { print -r -- "$(t '사용법' 'Usage'): zsh install.sh [--lang en|kr|auto] <all|path|anywhere|buttons|status|test>"; exit 2 }

# ── 언어 옵션: --lang en|kr 은 저장(다음 실행부터 유지), auto 는 저장값을 지운다 ──
LANG_FILE=$HOME/.config/iterm2-tools/lang
if [[ ${1:-} == --lang || ${1:-} == --lang=* ]]; then
  if [[ $1 == --lang=* ]]; then lv=${1#--lang=}; shift
  else lv=${2:-}; shift; (( $# )) && shift; fi
  case $lv in
    en|kr) mkdir -p "${LANG_FILE:h}"; print -r -- $lv > $LANG_FILE; /bin/chmod 0644 $LANG_FILE; IT2_L=$lv ;;
    auto)  /bin/rm -f -- $LANG_FILE; unset IT2_LANG; it2_lang; IT2_L=$REPLY ;;
    *)     print -u2 -r -- "  ❌ $(t "--lang 값이 올바르지 않습니다: '$lv' (en, kr, auto 중 하나)" "Invalid --lang value: '$lv' (use en, kr or auto)")"; usage ;;
  esac
fi
PROFILE_NAME=${IT_PROFILE_NAME:-"$(t '우클릭 도구' 'Right-click tools')"}

# ── 사전 점검 ──────────────────────────────────────────────
find_iterm_app() {
  local a
  for a in ${IT2_ITERM_APP:-} /Applications/iTerm.app "$HOME/Applications/iTerm.app" \
           ${(f)"$(/usr/bin/mdfind 'kMDItemCFBundleIdentifier == "com.googlecode.iterm2"' 2>/dev/null)"}; do
    [[ -f "$a/Contents/Info.plist" ]] && { print -r -- "$a"; return 0 }
  done
  return 1
}

[[ $OSTYPE == darwin* ]] || die "$(t 'macOS 전용입니다.' 'macOS only.')"
MACOS_VER=${IT2_TEST_MACOS_VER:-$(/usr/bin/sw_vers -productVersion)}      # IT2_TEST_*: 테스트용 버전 흉내
# plutil 의 raw 형식(-extract … raw)이 macOS 12 부터 지원된다(man plutil HISTORY)
is-at-least 12 "$MACOS_VER" || die "$(t "macOS 12 이상이 필요합니다 (현재 $MACOS_VER)." "macOS 12 or later is required (current: $MACOS_VER).")"
ITERM_APP=$(find_iterm_app) || die "$(t 'iTerm2 를 찾지 못했습니다. https://iterm2.com 에서 설치하세요.' 'iTerm2 not found. Install it from https://iterm2.com.')"
INSTALLED_VER=${IT2_TEST_ITERM_VER:-$(/usr/bin/defaults read "$ITERM_APP/Contents/Info" CFBundleShortVersionString 2>/dev/null || print '0')}
RUNNING_VER=""
[[ ${TERM_PROGRAM:-} == iTerm.app ]] && RUNNING_VER=${TERM_PROGRAM_VERSION:-}

ver_ge() { is-at-least "$2" "$1" }   # $1 >= $2

# 기능별 최소 iTerm2 버전(릴리스 태그 소스로 확인):
#   B 우클릭 메뉴 제공자 = API 프로토콜 1.7 = iTerm2 3.4.0
#   C custom 버튼(OSC 1337 Button=type=custom) = iTerm2 3.7.0
MIN_VER_ANYWHERE=3.4.0
MIN_VER_BUTTONS=3.7.0

# 이 패키지가 설치한 파일인지(덮어써도 되는지) 확인
# 파일 설치 + 다운로드/AirDrop 으로 받은 경우 붙는 격리 표시(quarantine) 제거
put() {  # put <mode> <src> <dst>
  /usr/bin/install -m "$1" "$2" "$3"
  /usr/bin/xattr -d com.apple.quarantine "$3" 2>/dev/null || true
}

ours_or_absent() {
  [[ ! -e $1 ]] && return 0
  /usr/bin/grep -qE "$IT2_OWN_RE" "$1" 2>/dev/null
}

install_bin() {  # install_bin <이름> → ~/bin/<이름>
  ours_or_absent "$BIN_DIR/$1" || die "$(t "$BIN_DIR/$1 이 이미 있고 이 패키지 파일이 아닙니다. 확인 후 지우고 다시 실행하세요." "$BIN_DIR/$1 already exists and is not from this package. Check it, remove it, then run again.")"
  mkdir -p "$BIN_DIR"
  put 0755 "$ROOT/bin/$1" "$BIN_DIR/$1"
  ok "$(t '실행 스크립트' 'Launcher'): ${BIN_DIR/#$HOME/~}/$1"
}

# ── A. 경로 텍스트 우클릭 ─────────────────────────────────
install_path() {
  print "\n$(t '[A] 경로 텍스트 우클릭 → VS Code / Finder' '[A] Right-click on path text → VS Code / Finder')"
  local rules="$ITERM_APP/Contents/Resources/SmartSelectionRules.plist"
  [[ -f $rules ]] || die "$(t "기본 Smart Selection 규칙 파일이 없습니다: $rules" "Default Smart Selection rules file not found: $rules")"
  install_bin iterm-open
  install_bin iterm-clean

  local guid=""
  [[ -f $DP_FILE ]] && guid=$(/usr/bin/plutil -extract Profiles.0.Guid raw -o - "$DP_FILE" 2>/dev/null || true)
  [[ -n $guid ]] || guid=$(/usr/bin/uuidgen)

  local tmpd=$(/usr/bin/mktemp -d) ; local t="$tmpd/dp.json"
  local cmd=${(qq):-"$BIN_DIR/iterm-open"}         # 홈 경로에 공백이 있어도 안전하게 작은따옴표 처리
  local R='Profiles.0.Smart Selection Rules'
  print -n '{"Profiles":[{}]}' > $t
  /usr/bin/plutil -insert Profiles.0.Name -string "$PROFILE_NAME" $t
  /usr/bin/plutil -insert Profiles.0.Guid -string "$guid" $t
  # 기반 규칙: 기본 프로필에 사용자 지정 규칙이 있으면 그것(그 Mac 의 동작 유지), 없으면 iTerm2 기본 규칙
  local base=$(it2_default_profile_rules_json) base_from=$(t 'iTerm2 기본 규칙' 'iTerm2 default rules')
  if [[ -n $base && $base == \[* ]]; then base_from=$(t '기본 프로필의 사용자 지정 규칙' "your default profile's custom rules")
  else base=$(/usr/bin/plutil -extract Rules json -o - "$rules"); fi
  /usr/bin/plutil -insert "$R" -json "$base" $t
  /usr/bin/plutil -insert "$R.0" -json '{"precision":"very_high","actions":[]}' $t
  /usr/bin/plutil -insert "$R.0.notes" -string 'iterm2-tools: file/dir path (+ :line:col)' $t
  /usr/bin/plutil -insert "$R.0.regex" -string '(?:\~?\.{0,2}/?(?:[[:letter:][:number:]._-]+/+)+[[:letter:][:number:]._-]*|[[:letter:][:number:]_-][[:letter:][:number:]._-]*\.[[:letter:]]{1,10})(?::[0-9]+){0,2}' $t
  /usr/bin/plutil -insert "$R.0.actions.0" -json "{\"title\":\"$(t 'VS Code에서 열기' 'Open in VS Code')\",\"action\":2}" $t
  /usr/bin/plutil -insert "$R.0.actions.0.parameter" -string "$cmd vscode \\d \\0" $t
  /usr/bin/plutil -insert "$R.0.actions.1" -json "{\"title\":\"$(t 'Finder에서 보기' 'Show in Finder')\",\"action\":2}" $t
  /usr/bin/plutil -insert "$R.0.actions.1.parameter" -string "$cmd finder \\d \\0" $t

  # 깨진 파일이 하나라도 있으면 iTerm2 가 모든 Dynamic Profile 변경을 무시하므로 반드시 검증 후 반영
  /usr/bin/plutil -convert xml1 -o /dev/null $t || die "$(t '생성한 프로필 파일 형식 오류 (반영하지 않음)' 'Generated profile file is malformed (not applied)')"
  mkdir -p "${DP_FILE:h}"
  /bin/mv -f $t "$DP_FILE"; /bin/chmod 0644 "$DP_FILE"; /bin/rmdir $tmpd 2>/dev/null || true
  ok "$(t '프로필' 'Profile'): '${PROFILE_NAME}' → ${DP_FILE/#$HOME/~}"
  local nr=$(/usr/bin/plutil -extract "$R" raw -o - "$DP_FILE")
  say "$(t "   규칙 ${nr}개 = 경로 규칙 1 + ${base_from}. iTerm2 가 자동으로 다시 읽음" "   $nr rules = 1 path rule + ${base_from}. iTerm2 reloads it automatically")"
  say "$(t "사용: iTerm2 메뉴 Profiles → '${PROFILE_NAME}' 로 새 탭/창을 열고, 경로 텍스트 위에서 우클릭" "Use: open a new tab/window with the '${PROFILE_NAME}' profile (iTerm2 menu Profiles), then right-click on path text")"
}

# ── B. 어디서나 우클릭 ────────────────────────────────────
install_anywhere() {
  print "\n$(t '[B] 어디서나 우클릭 → 현재 폴더를 VS Code / Finder / 정리(clean)' '[B] Right-click anywhere → current folder in VS Code / Finder / clean')"
  ver_ge "$INSTALLED_VER" $MIN_VER_ANYWHERE || die "$(t "B 는 iTerm2 $MIN_VER_ANYWHERE 이상이 필요합니다 (설치본 $INSTALLED_VER)." "B requires iTerm2 $MIN_VER_ANYWHERE or later (installed: $INSTALLED_VER).")"
  ours_or_absent "$AL_FILE" || die "$(t "${AL_FILE/#$HOME/~} 이 이미 있고 이 패키지 파일이 아닙니다." "${AL_FILE/#$HOME/~} already exists and is not from this package.")"
  install_bin iterm-clean                      # '현재 폴더: 정리(clean)…' 항목이 새 탭에서 실행한다
  mkdir -p "${AL_FILE:h}"
  put 0644 "$ROOT/python/open_in_tools.py" "$AL_FILE"
  ok "$(t 'AutoLaunch 스크립트' 'AutoLaunch script'): ${AL_FILE/#$HOME/~}"
  # 이미 실행 중인 이전 버전은 이전 코드로 메뉴를 계속 처리하므로 정지시킨다(이 패키지 스크립트만)
  local pids=(${(f)"$(running_script_pids)"})
  if (( ${#pids} )); then
    /bin/kill -TERM $pids 2>/dev/null || true
    ok "$(t "실행 중이던 이전 버전 정지 (pid ${pids})" "Stopped the previously running version (pid ${pids})")"
    RESTART_NEEDED=1
  fi
  if [[ -d "$SUP/iterm2env" ]]; then
    ok "$(t 'Python 런타임: 설치되어 있음' 'Python runtime: installed')"
    check_rosetta || true
  else
    warn "$(t 'Python 런타임 없음 → iTerm2 메뉴 Scripts → Manage → Install Python Runtime 실행' 'Python runtime missing → run iTerm2 menu Scripts → Manage → Install Python Runtime')"
    say  "$(t "(설치는 별도 창 없이 조용히 끝날 수 있습니다. 'zsh install.sh status' 로 확인)" "(The install may finish quietly without a window. Check with 'zsh install.sh status')")"
  fi
  api_enabled || {
    warn "$(t 'Python API 가 꺼져 있습니다(새 iTerm2 의 기본값). 스크립트를 처음 실행하면' 'Python API is off (the default in new iTerm2). When the script first runs,')"
    say  "$(t "   'Enable Python API?' 창이 뜹니다 → OK 를 눌러야 B 가 동작합니다." "   an 'Enable Python API?' dialog appears → click OK for B to work.")"
  }
  say "$(t '적용: iTerm2 메뉴 Scripts → AutoLaunch → open_in_tools.py 를 선택해 지금 실행 (다음 iTerm2 실행부터는 자동)' 'Apply: run it now via iTerm2 menu Scripts → AutoLaunch → open_in_tools.py (automatic from the next iTerm2 launch)')"
}

api_enabled() { [[ $(it2_pref EnableAPIServer) == (1|true|YES) ]] }

# iTerm2 Python 런타임은 x86_64 로만 배포된다(공개 manifest·설치본 실측) →
# Apple Silicon 에서는 Rosetta 2 가 있어야 B 스크립트가 실행된다.
# 가장 높은 버전의 런타임 python3 (n = 숫자 순 정렬: 3.8 < 3.10 < 3.14)
runtime_python() { local p=( "$SUP"/iterm2env/versions/*/bin/python3(Nn) ); print -r -- ${p[-1]:-} }
rosetta_needed() {
  [[ $(/usr/bin/uname -m) == arm64 ]] || return 1
  local py=$(runtime_python); [[ -n $py ]] || return 1
  [[ $(/usr/bin/file -b "${py:A}") != *arm64* ]]
}
rosetta_ok() {    # IT2_TEST_NO_ROSETTA / IT2_TEST_ROSETTA_OK: 테스트용 흉내
  [[ -n ${IT2_TEST_NO_ROSETTA:-} ]] && return 1
  [[ -n ${IT2_TEST_ROSETTA_OK:-} ]] && return 0
  /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null
}
check_rosetta() {
  if rosetta_needed && ! rosetta_ok; then
    warn "$(t 'Python 런타임이 Intel(x86_64) 전용인데 Rosetta 2 가 없습니다 → B 가 실행되지 않습니다.' 'The Python runtime is Intel (x86_64) only and Rosetta 2 is missing → B will not run.')"
    say  "$(t '   설치(직접 실행)' '   Install (run it yourself)'): softwareupdate --install-rosetta --agree-to-license"
    return 1
  fi
  rosetta_needed && ok "$(t 'Rosetta 2 있음 (Intel 전용 Python 런타임 실행 가능)' 'Rosetta 2 present (can run the Intel-only Python runtime)')"
  return 0
}

# 이 설치 위치($AL_FILE)의 스크립트를 실행 중인 python 프로세스 pid (래퍼 셸 제외).
# 심볼릭 링크(~/.config/iterm2/AppSupport 등)를 풀어 실제 파일이 같은 것만 고른다 —
# 다른 위치(다른 사용자 설정·테스트용 가짜 홈)의 스크립트는 건드리지 않는다.
running_script_pids() {
  local pid cmd script want=${AL_FILE:A}
  /bin/ps -axo pid=,command= | while read -r pid cmd; do
    [[ $cmd == *python3' '*/AutoLaunch/open_in_tools.py && $cmd != *it2_api_wrapper* ]] || continue
    script=${cmd#*python3 }
    [[ ${script:A} == $want ]] && print -r -- $pid
  done
}

# ── 테스트 ───────────────────────────────────────────────
run_tests() {
  print "\n$(t '[테스트]' '[Tests]')"
  local rc=0 py=""
  /bin/zsh "$ROOT/tests/test_iterm_open.zsh" || rc=1
  print; /bin/zsh "$ROOT/tests/test_iterm_clean.zsh" || rc=1
  print; /bin/zsh "$ROOT/tests/test_portability.zsh" || rc=1
  print; /bin/zsh "$ROOT/tests/test_docs.zsh" || rc=1
  print; /bin/zsh "$ROOT/tests/test_lang.zsh" || rc=1
  py=$(runtime_python)
  print
  if [[ -z $py ]]; then
    warn "$(t 'B 테스트 건너뜀: Python 런타임 없음 (Scripts → Manage → Install Python Runtime 후 다시 실행)' 'B tests skipped: no Python runtime (run Scripts → Manage → Install Python Runtime, then try again)')"; SKIPPED=1
  elif rosetta_needed && ! rosetta_ok; then
    warn "$(t 'B 테스트 건너뜀: 이 Mac 은 Rosetta 2 가 없어 Intel 전용 Python 런타임을 실행할 수 없음' 'B tests skipped: this Mac has no Rosetta 2, so the Intel-only Python runtime cannot run')"
    say  "$(t "   (이 상태에서는 B 자체가 동작하지 않는다 — 'zsh install.sh status' 의 Rosetta 안내 참고)" "   (B itself does not work in this state — see the Rosetta note in 'zsh install.sh status')")"; SKIPPED=1
  else
    print "  $(t 'B 테스트 런타임' 'B test runtime'): ${${py:h:h}:t}"
    "$py" -I "$ROOT/tests/test_open_in_tools.py" || rc=1
    /bin/rm -rf "$ROOT/python/__pycache__" "$ROOT/tests/__pycache__"
  fi
  print
  if (( rc )); then warn "$(t '테스트 FAIL 있음' 'Some tests FAILED')"
  elif (( ${SKIPPED:-0} )); then ok "$(t '실행한 테스트 모두 PASS (건너뛴 항목은 위 사유 참고)' 'All executed tests PASS (see the reasons above for skipped items)')"
  else ok "$(t '전체 테스트 PASS' 'All tests PASS')"; fi
  return $rc
}

# ── C. 클릭 버튼 ─────────────────────────────────────────
install_buttons() {
  print "\n$(t '[C] 터미널 안 클릭 버튼 (zsh)' '[C] Clickable buttons inside the terminal (zsh)')"
  mkdir -p "$ZSH_DIR"
  put 0644 "$ROOT/zsh/iterm-buttons.zsh" "$ZSH_DIR/iterm-buttons.zsh"
  put 0755 "$ROOT/zsh/ib-selftest.zsh"   "$ZSH_DIR/ib-selftest.zsh"
  ok "$(t 'zsh 파일' 'zsh files'): ${ZSH_DIR/#$HOME/~}/"
  if ! ver_ge "$INSTALLED_VER" $MIN_VER_BUTTONS; then
    warn "$(t "설치된 iTerm2 가 $INSTALLED_VER 입니다. 버튼은 $MIN_VER_BUTTONS 이상이 필요합니다 → iTerm2 업데이트 후 사용" "Installed iTerm2 is $INSTALLED_VER. Buttons need $MIN_VER_BUTTONS or later → update iTerm2 first")"
  elif [[ -n $RUNNING_VER ]] && ! ver_ge "$RUNNING_VER" $MIN_VER_BUTTONS; then
    warn "$(t "실행 중인 iTerm2 가 $RUNNING_VER 입니다. 버튼은 $MIN_VER_BUTTONS 이상이 실행 중이어야 보입니다 → iTerm2 재시작 후 사용" "The running iTerm2 is $RUNNING_VER. Buttons only show when $MIN_VER_BUTTONS or later is running → restart iTerm2")"
  fi
  say "$(t "1) 자가 테스트:  zsh ${ZSH_DIR/#$HOME/~}/ib-selftest.zsh   (별 버튼 클릭 → ✅ 확인)" "1) Self-test:  zsh ${ZSH_DIR/#$HOME/~}/ib-selftest.zsh   (click the star button → check ✅)")"
  say "$(t '2) ~/.zshrc 에 직접 추가(이 스크립트는 .zshrc 를 수정하지 않음):' "2) Add this to ~/.zshrc yourself (this script does not modify .zshrc):")"
  say "     source ~/.zsh/iterm2-tools/iterm-buttons.zsh"
  say "     ib_add 1 hammer.fill 'make build'"
  say "$(t '3) 새 셸에서  ib_bar  → 버튼 줄 출력' '3) In a new shell run  ib_bar  → prints the button row')"
}

# ── 상태 점검 ────────────────────────────────────────────
show_status() {
  print "\n$(t '[상태]' '[Status]')"
  local lsrc; it2_lang_source; lsrc=$REPLY
  case $lsrc in
    env)   lsrc=$(t 'IT2_LANG 환경변수' 'IT2_LANG environment variable') ;;
    file)  lsrc=$(t '저장된 설정 ~/.config/iterm2-tools/lang' 'saved setting ~/.config/iterm2-tools/lang') ;;
    macos) lsrc=$(t 'macOS 언어' 'macOS language') ;;
    *)     lsrc=$(t '기본값' 'default') ;;
  esac
  say "$(t '언어' 'Language'): $(t '한국어' 'English') ($lsrc)"
  say "macOS: $MACOS_VER ($(/usr/bin/uname -m))"
  say "$(t 'iTerm2 설치본' 'iTerm2 installed'): $INSTALLED_VER (${ITERM_APP})"
  [[ $DP_FILE != "$SUP/DynamicProfiles/"* ]] && say "$(t 'DynamicProfiles 폴더(사용자 지정)' 'DynamicProfiles folder (custom)'): ${${DP_FILE:h}/#$HOME/~}"
  [[ $AL_FILE != "$SUP/Scripts/"* ]] && say "$(t 'Scripts 폴더(사용자 지정)' 'Scripts folder (custom)'): ${${AL_FILE:h:h}/#$HOME/~}"
  if [[ -n $RUNNING_VER ]]; then
    say "$(t '현재 세션의 iTerm2' 'iTerm2 in this session'): $RUNNING_VER"
    [[ $RUNNING_VER != $INSTALLED_VER ]] && warn "$(t '설치본과 실행본이 다릅니다 → 작업을 마친 뒤 iTerm2 재시작 권장' 'Installed and running versions differ → restart iTerm2 when you are done')"
  fi
  local f
  for f in "$BIN_DIR/iterm-open" "$BIN_DIR/iterm-clean" "$DP_FILE" "$AL_FILE" "$ZSH_DIR/iterm-buttons.zsh"; do
    [[ -e $f ]] && ok "$(t '설치됨 ' 'Installed    ') ${f/#$HOME/~}" || say "$(t '미설치 ' 'Not installed') ${f/#$HOME/~}"
  done
  [[ -f $DP_FILE ]] && { /usr/bin/plutil -convert xml1 -o /dev/null "$DP_FILE" && ok "$(t '프로필 파일 형식 정상' 'Profile file format OK')" || warn "$(t '프로필 파일 형식 오류' 'Profile file format error')"; }
  [[ -d "$SUP/iterm2env" ]] && { ok "$(t 'Python 런타임 있음' 'Python runtime present')"; check_rosetta || true; } || say "$(t 'Python 런타임 없음 (B 에 필요)' 'Python runtime missing (needed for B)')"
  api_enabled && ok "$(t 'Python API 켜짐' 'Python API on')" || say "$(t "Python API 꺼짐 (B 첫 실행 때 'Enable Python API?' → OK)" "Python API off (on B's first run: 'Enable Python API?' → OK)")"
  local pids=(${(f)"$(running_script_pids)"})
  say "$(t "open_in_tools.py 실행 중: ${#pids}개" "open_in_tools.py running: ${#pids}")"
  if (( ${#pids} )) && [[ -f $AL_FILE ]]; then
    local started=$(LC_ALL=C /bin/date -j -f '%a %b %d %T %Y' "$(LC_ALL=C /bin/ps -o lstart= -p ${pids[1]} | /usr/bin/xargs)" +%s 2>/dev/null || print 0)
    local modified=$(/usr/bin/stat -f %m "$AL_FILE")
    (( started && started < modified )) && warn "$(t '실행 중인 스크립트가 설치 파일보다 오래됨 → Scripts → AutoLaunch → open_in_tools.py 로 다시 실행' 'The running script is older than the installed file → rerun via Scripts → AutoLaunch → open_in_tools.py')"
  fi
  (( ${RESTART_NEEDED:-0} )) && warn "$(t 'B 를 켜려면: iTerm2 메뉴 Scripts → AutoLaunch → open_in_tools.py' 'To enable B: iTerm2 menu Scripts → AutoLaunch → open_in_tools.py')"
  /usr/bin/grep -q 'iterm2-tools/iterm-buttons.zsh' ~/.zshrc 2>/dev/null && ok "$(t '.zshrc 에 버튼 설정 있음' 'Button setup found in .zshrc')" || say "$(t '.zshrc 에 버튼 설정 없음 (C 를 쓸 때만 필요)' 'No button setup in .zshrc (only needed for C)')"
}

case ${1:-} in
  all)      install_path; install_anywhere; install_buttons; show_status ;;
  path)     install_path; show_status ;;
  anywhere) install_anywhere; show_status ;;
  buttons)  install_buttons; show_status ;;
  status)   show_status ;;
  test)     run_tests ;;
  where-iterm) print -r -- "$ITERM_APP" ;;     # 점검·테스트용: 찾은 iTerm.app 경로
  *) usage ;;
esac
