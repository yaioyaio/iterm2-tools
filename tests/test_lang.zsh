#!/bin/zsh -f
# 언어(영어/한국어) 공통 검사 — 모든 실행 파일이 같은 규칙으로 언어를 고르고, 영어 화면에 한국어가 새지 않는지 확인한다.
#   1) 공통 언어 선택 코드(it2_lang + t)가 모든 zsh 실행 파일에 글자 그대로 같다
#   2) 언어 선택 순서: IT2_LANG → ~/.config/iterm2-tools/lang → macOS 언어 → en (가짜 HOME, 실제 설정 안 건드림)
#   3) 영어 실행 시 한글 0자: iterm-open · ib-selftest · 버튼 플러그인 (iterm-clean·설치기·메뉴는 각자 테스트에서)
#   4) 정적 검사: 제품 코드에서 주석이 아닌 한글은 번역 함수(t / _ib_t) 또는 언어별 표 안에만 있다
# 사용: zsh tests/test_lang.zsh [패키지 폴더]
emulate -L zsh
setopt no_unset pipe_fail extended_glob
ROOT=${1:-${0:A:h:h}}; ROOT=${ROOT:A}
pass=0 fail=0
ok() { print -r -- "  ✅ $1"; (( ++pass )); return 0 }
ng() { print -r -- "  ❌ $1"; (( ++fail )); return 0 }
TMP=$(/usr/bin/mktemp -d); trap '/bin/rm -rf $TMP' EXIT
has_hangul() { print -r -- "$1" | LC_ALL=en_US.UTF-8 /usr/bin/grep -q '[가-힣]' }

# 공통 블록: "# ── 언어 선택" 줄부터 "t() {" 줄까지
block() { /usr/bin/awk '/^# ── 언어 선택/{p=1} p{print} p&&/^t\(\) \{/{exit}' "$1" }
SHARED=(bin/iterm-open bin/iterm-clean lib/common.zsh zsh/ib-selftest.zsh)

print -r -- "[1] 공통 언어 선택 코드"
REF=$(block $ROOT/bin/iterm-open)
[[ -n $REF && $REF == *'it2_lang()'* && $REF == *'t() {'* ]] && ok "기준: bin/iterm-open ($(print -r -- $REF | wc -l | tr -d ' ')줄)" || ng "bin/iterm-open 에 공통 블록 없음"
for f in ${SHARED:1}; do
  [[ $(block $ROOT/$f) == $REF ]] && ok "$f: 같음" || ng "$f: 공통 블록이 다르거나 없음"
done

print -r -- "[2] 언어 선택 순서"
# IT2_LANG | 저장된 설정(-=없음) | macOS 언어 흉내 | 기대 — tests/test_open_in_tools.py 의 LANG_CASES 와 같은 표
CASES=(
  '||ko-KR|kr' '||ko|kr' '||en-US|en' '|||en' '||ja-JP|en' '|kr|en-US|kr' '|en|ko-KR|en'
  'kr|en|en-US|kr' 'en|kr|ko-KR|en' 'ko_KR||-|kr' 'KO|||kr' 'fr||ko-KR|en'
)
H=$TMP/home; /bin/mkdir -p $H/.config/iterm2-tools
resolve() {  # <구현> <IT2_LANG> <설정> <macOS> → 고른 언어
  local impl=$1 el=$2 fl=$3 sl=$4
  [[ $sl == - ]] && sl=""
  if [[ -n $fl ]]; then print -r -- $fl > $H/.config/iterm2-tools/lang; else /bin/rm -f $H/.config/iterm2-tools/lang; fi
  if [[ $impl == plugin ]]; then
    HOME=$H IT2_LANG=$el IT2_TEST_SYS_LANG=$sl TERM_PROGRAM=iTerm.app /bin/zsh -f -c \
      'source "$1" 2>/dev/null; _ib_t kr en' _ $ROOT/zsh/iterm-buttons.zsh
  else
    HOME=$H IT2_LANG=$el IT2_TEST_SYS_LANG=$sl /bin/zsh -f -c 'eval "$1"; print -r -- $IT2_L' _ "$(block $ROOT/$impl)"
  fi
}
for impl in $SHARED plugin; do
  bad=()
  for c in $CASES; do
    r=$c; el=${r%%|*}; r=${r#*|}; fl=${r%%|*}; r=${r#*|}; sl=${r%%|*}; want=${r#*|}
    got=$(resolve $impl "$el" "$fl" "$sl")
    [[ $got == $want ]] || bad+="[$c → $got]"
  done
  label=$impl; [[ $impl == plugin ]] && label="zsh/iterm-buttons.zsh (_ib_t)"
  (( $#bad )) && ng "$label: ${(j: :)bad}" || ok "$label: ${#CASES}가지 경우"
done
# 실제 macOS 언어 읽기(defaults)가 동작하는지 — 값은 이 Mac 에 따라 다르므로 en/kr 중 하나면 통과
real=$(HOME=$H /bin/zsh -f -c 'unset IT2_LANG IT2_TEST_SYS_LANG; eval "$1"; print -r -- $IT2_L' _ "$REF")
[[ $real == (en|kr) ]] && ok "실제 macOS 언어 → $real" || ng "실제 macOS 언어 판정 실패: $real"
/bin/rm -f $H/.config/iterm2-tools/lang

print -r -- "[3] 영어 화면에 한글 없음"
out_en() { HOME=$H IT2_LANG=en IT2_TEST_SYS_LANG=ko-KR "$@" 2>&1 </dev/null }
out_kr() { HOME=$H IT2_LANG=kr IT2_TEST_SYS_LANG=en-US "$@" 2>&1 </dev/null }
check_pair() {  # <이름> <영어에 있어야 할 문구> <한국어에 있어야 할 문구> <명령…>
  local name=$1 want_en=$2 want_kr=$3; shift 3
  local e=$(out_en "$@") k=$(out_kr "$@")
  if has_hangul "$e"; then ng "$name (en): 한글 섞임 → $(print -r -- $e | LC_ALL=en_US.UTF-8 grep '[가-힣]' | head -1)"
  elif [[ $e != *$want_en* ]]; then ng "$name (en): '$want_en' 없음 → ${e[1,120]}"
  else ok "$name (en): 한글 0자, '$want_en'"; fi
  [[ $k == *$want_kr* ]] && ok "$name (kr): '$want_kr'" || ng "$name (kr): '$want_kr' 없음 → ${k[1,120]}"
}
check_pair "iterm-open 없는 경로" "path not found" "경로 없음" /bin/zsh -f $ROOT/bin/iterm-open vscode $TMP no-such-file
check_pair "iterm-open 사용법" "usage: iterm-open" "usage: iterm-open" /bin/zsh -f $ROOT/bin/iterm-open bogus $TMP $TMP
check_pair "ib-selftest" "Click the star button below" "아래 별 버튼을 클릭하세요" /bin/zsh $ROOT/zsh/ib-selftest.zsh
check_pair "버튼 ib_add 사용법" "usage: ib_add <code(positive integer)>" "양의 정수" \
  env TERM_PROGRAM=iTerm.app /bin/zsh -f -c 'source "$1" 2>/dev/null; ib_add x' _ $ROOT/zsh/iterm-buttons.zsh

print -r -- "[4] 정적 검사: 번역 함수 밖의 한글"
PRODUCT=( $ROOT/bin/*(.N) $ROOT/lib/common.zsh(.N) $ROOT/install.sh(.N) $ROOT/uninstall.sh(.N) $ROOT/zsh/*.zsh(.N) $ROOT/python/*.py(.N) )
PRODUCT=( ${PRODUCT#$ROOT/} )                       # 패키지 폴더 기준(현재 폴더와 무관)
must=(bin/iterm-open bin/iterm-clean lib/common.zsh install.sh uninstall.sh zsh/iterm-buttons.zsh zsh/ib-selftest.zsh python/open_in_tools.py)
missing=( ${must:|PRODUCT} )
(( $#missing )) && ng "정적 검사 대상 누락: ${(j:, :)missing}" || ok "정적 검사 대상 ${#PRODUCT}개 (필수 ${#must}개 포함)"
leaks=()
TCALL=$'(^|[^A-Za-z0-9_])(t|_ib_t)[[:space:]]+[\'"]'     # t '…' / _ib_t "…" 호출
for f in $PRODUCT; do
  integer n=0; in_doc=0
  while IFS= read -r line; do
    (( ++n ))
    l=$line
    if [[ $f == *.py ]]; then
      # 독스트링(""" … """)과 주석은 개발자용 설명이라 제외
      if (( in_doc )); then [[ $l == *'"""'* ]] && in_doc=0; continue; fi
      if [[ $l == [[:space:]]#'"""'* ]]; then [[ ${l#*'"""'} != *'"""'* ]] && in_doc=1; continue; fi
      [[ $l == [[:space:]]#'#'* ]] && continue
      l=${l%%[[:space:]]\#[[:space:]]*}
      has_hangul "$l" || continue
      [[ $l == *'"kr":'* ]] && continue                      # 언어별 표의 한국어 줄
    else
      [[ $l == [[:space:]]#'#'* ]] && continue
      l=${l%%[[:space:]]\#[[:space:]]*}; l=${l%%[[:space:]]\#}  # 줄 끝 주석
      has_hangul "$l" || continue
      [[ $l =~ $TCALL || $l == *'$IT2_L == kr'* ]] && continue     # t 호출, 또는 같은 줄에서 언어로 나눈 분기
    fi
    leaks+="$f:$n: ${l##[[:space:]]#}"
  done < $ROOT/$f
done
if (( $#leaks )); then
  ng "번역 함수 밖의 한글 ${#leaks}곳"; print -rl -- "     "${^leaks[1,15]}
else
  ok "제품 파일 ${#PRODUCT}개: 번역 함수 밖의 한글 없음"
fi

print
print -r -- "결과: 통과 $pass / 실패 $fail"
(( fail == 0 ))
