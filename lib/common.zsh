# iterm2-tools: lib/common.zsh — install.sh / uninstall.sh 공통 (경로·버전 판정)
#
# 다른 Mac 에서도 같은 결과가 나오도록, 설치 위치를 "그 Mac 의 iTerm2 설정"에서 계산한다.
#   - DynamicProfiles 폴더 : 고급 설정 dynamicProfilesPath (비어 있으면 기본 폴더)
#   - Scripts 폴더        : UseCustomScriptsFolder + CustomScriptsFolder(실제로 존재할 때만, iTerm2 와 같은 규칙)
# 설정은 ~/Library/Preferences/com.googlecode.iterm2.plist 에서 필요한 키만 읽는다(출력하지 않음).

autoload -Uz is-at-least

# ── 언어 선택 (iterm2-tools 공통 — 모든 실행 파일에 같은 코드. tests/test_lang.zsh 가 일치를 확인) ──
#   IT2_LANG(en|kr) → ~/.config/iterm2-tools/lang (install.sh --lang 이 저장) → macOS 언어 → en
#   IT2_TEST_SYS_LANG: 테스트용 macOS 언어 흉내(설정돼 있으면 defaults 대신 사용, 빈 값 = 언어 정보 없음)
it2_lang() {
  local v=${IT2_LANG:-} f=$HOME/.config/iterm2-tools/lang
  [[ -z $v && -r $f ]] && v=$(<$f)
  [[ -z $v ]] && v=${IT2_TEST_SYS_LANG-$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null | /usr/bin/sed -n '2{s/[^A-Za-z_-]//g;p;}')}
  case ${v:l} in (kr|ko|ko[-_]*) REPLY=kr ;; (*) REPLY=en ;; esac
}
it2_lang; IT2_L=$REPLY
t() { if [[ $IT2_L == kr ]]; then print -r -- "$1"; else print -r -- "$2"; fi }   # t '한국어' 'English'

# 현재 언어가 어디서 정해졌는지: env | file | macos | default (위 블록과 같은 순서)
it2_lang_source() {
  local v=${IT2_LANG:-} f=$HOME/.config/iterm2-tools/lang
  [[ -n $v ]] && { REPLY=env; return 0 }
  [[ -r $f ]] && v=$(<$f)
  [[ -n $v ]] && { REPLY=file; return 0 }
  v=${IT2_TEST_SYS_LANG-$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null | /usr/bin/sed -n '2{s/[^A-Za-z_-]//g;p;}')}
  [[ -n $v ]] && REPLY=macos || REPLY=default
  return 0
}

# 이 패키지 파일 표식(소유 판별용 — 번역하지 않는다). 마지막 항목은 한글 표식의 바이트 표기(UTF-8)
IT2_OWN_RE=$'iterm2-tools|iterm-open —|iTerm2 \xec\x9a\xb0\xed\x81\xb4\xeb\xa6\xad'


IT2_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
IT2_SUP="$HOME/Library/Application Support/iTerm2"

# plist 의 단일 값(없으면 빈 문자열)
it2_pref() {
  [[ -f $IT2_PLIST ]] || return 0
  /usr/bin/plutil -extract "$1" raw -o - "$IT2_PLIST" 2>/dev/null || true
}

it2_expand() {  # ~ 확장
  local p=$1
  [[ $p == '~' || $p == '~/'* ]] && p=$HOME${p#\~}
  print -r -- "$p"
}

it2_dynamic_profiles_dir() {
  local custom=$(it2_pref dynamicProfilesPath)
  if [[ -n $custom ]]; then it2_expand "$custom"; else print -r -- "$IT2_SUP/DynamicProfiles"; fi
}

it2_scripts_dir() {
  local use=$(it2_pref UseCustomScriptsFolder) custom=$(it2_pref CustomScriptsFolder)
  if [[ $use == (1|true|YES) && -n $custom ]]; then
    custom=$(it2_expand "$custom")
    [[ -d $custom ]] && { print -r -- "$custom"; return }
  fi
  print -r -- "$IT2_SUP/Scripts"
}

# 기본 프로필에 사용자 지정 Smart Selection 규칙이 있으면 그 JSON 배열, 없으면 빈 문자열
it2_default_profile_rules_json() {
  [[ -f $IT2_PLIST ]] || return 0
  local guid=$(it2_pref 'Default Bookmark Guid') n i
  [[ -n $guid ]] || return 0
  n=$(it2_pref 'New Bookmarks'); [[ $n == <-> ]] || return 0
  for (( i = 0; i < n; i++ )); do
    if [[ $(it2_pref "New Bookmarks.$i.Guid") == $guid ]]; then
      /usr/bin/plutil -extract "New Bookmarks.$i.Smart Selection Rules" json -o - "$IT2_PLIST" 2>/dev/null || true
      return 0
    fi
  done
}

IT2_DP_FILE="$(it2_dynamic_profiles_dir)/dp-open-in.json"
IT2_AL_FILE="$(it2_scripts_dir)/AutoLaunch/open_in_tools.py"
IT2_BIN_DIR="$HOME/bin"
IT2_ZSH_DIR="$HOME/.zsh/iterm2-tools"
