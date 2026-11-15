# iterm2-tools: iterm-buttons.zsh
# iTerm2 인라인 custom 버튼 ↔ zsh 위젯 연결
#
# 요구: iTerm2 3.7 이상이 "실행 중"일 것 (3.6.9 는 type=custom 버튼을 무시함 — 실측)
#
# 사용:  ib_add 1 hammer.fill 'make build'     # code, SF Symbol 이름, 명령
#        ib_add 2 play.fill   'make run'
#        ib_bar                                 # 등록된 버튼을 한 줄로 출력
#
# 클릭 동작: IB_MODE=insert (기본) → 명령을 입력줄에 넣기만 함(Enter 는 사용자가)
#            IB_MODE=run            → 입력 중이던 내용은 보존하고 즉시 실행
#
# 보안: 버튼은 어떤 출력(cat 한 파일 포함)으로도 그려질 수 있다.
#       클릭 시 받는 값은 숫자 code 뿐이며, 실행 내용은 ib_add 로 등록한 표에서만 찾는다.

[[ $TERM_PROGRAM == iTerm.app ]] || return 0

typeset -gA _IB_CMD _IB_ICON
typeset -ga _IB_ORDER
: ${IB_MODE:=insert}

# 언어별 문구 — 셸 시작 시에는 외부 명령을 실행하지 않고, 첫 메시지를 낼 때 한 번만 언어를 정한다.
# 규칙은 iterm2-tools 공통 it2_lang 과 같다(tests/test_lang.zsh 가 같은 결과인지 확인):
#   IT2_LANG(en|kr) → ~/.config/iterm2-tools/lang → macOS 언어(IT2_TEST_SYS_LANG = 테스트용 흉내) → en
_ib_t() {  # _ib_t '한국어' 'English'
  if [[ -z ${_IB_L:-} ]]; then
    local v=${IT2_LANG:-} f=$HOME/.config/iterm2-tools/lang
    [[ -z $v && -r $f ]] && v=$(<$f)
    [[ -z $v ]] && v=${IT2_TEST_SYS_LANG-$(/usr/bin/defaults read -g AppleLanguages 2>/dev/null | /usr/bin/sed -n '2{s/[^A-Za-z_-]//g;p;}')}
    case ${v:l} in (kr|ko|ko[-_]*) typeset -g _IB_L=kr ;; (*) typeset -g _IB_L=en ;; esac
  fi
  if [[ $_IB_L == kr ]]; then print -r -- "$1"; else print -r -- "$2"; fi
}

ib_add() {
  [[ $1 == <1-> && -n ${2:-} && -n ${3:-} ]] || { print -u2 -r -- "$(_ib_t 'usage: ib_add <code(양의 정수)> <sf-symbol> <명령>' 'usage: ib_add <code(positive integer)> <sf-symbol> <command>')"; return 1 }
  (( ${+_IB_CMD[$1]} )) || _IB_ORDER+=($1)
  _IB_CMD[$1]=$3; _IB_ICON[$1]=$2
}

ib_bar() {
  local c
  for c in $_IB_ORDER; do
    printf '\e]1337;Button=type=custom;code=%d;icon=%s\a' $c ${_IB_ICON[$c]}
  done
  print
}

_ib_on_click() {
  local cmd=${_IB_CMD[$1]:-}
  if [[ -z $cmd ]]; then
    zle -M "iterm-buttons: $(_ib_t "등록되지 않은 code=$1 (무시)" "unregistered code=$1 (ignored)")"
    return
  fi
  if [[ $IB_MODE == run ]]; then
    [[ -n $BUFFER ]] && zle push-line     # 입력 중이던 내용은 실행 후 되돌아옴
    BUFFER=$cmd
    zle accept-line
  else
    BUFFER=$cmd
    CURSOR=${#BUFFER}
  fi
}

# '\e[?1337;' 접두어만 바인딩하고 숫자를 '~' 까지 직접 읽는다
# (코드마다 바인딩하면 미등록 코드의 잔여 바이트가 입력줄로 샌다 — 실측)
_ib_dispatch() {
  local ch code=""
  while read -k1 ch; do
    [[ $ch == '~' ]] && break
    [[ $ch == [0-9] ]] || return
    code+=$ch
  done
  [[ -n $code ]] && _ib_on_click $code
}
zle -N _ib_dispatch
bindkey -M emacs '\e[?1337;' _ib_dispatch
bindkey -M viins '\e[?1337;' _ib_dispatch

# 명령 실행 직전 모든 custom 버튼을 무효(회색) 처리 —
# 실행 중인 프로그램(vim 등)에 클릭 바이트가 들어가는 것을 막는다.
_ib_preexec() { printf '\e]1337;Button=type=custom\a' }
autoload -Uz add-zsh-hook
add-zsh-hook preexec _ib_preexec
