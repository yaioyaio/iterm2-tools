#!/bin/zsh -f
# iterm-open 회귀 테스트 — 실제로 열지 않고(IO_DRYRUN) 실행할 명령만 검사한다.
# iTerm2 Smart Selection 과 같은 방식(인자 셸 이스케이프 → /bin/sh -c)으로 호출한다.
# 판정: 동작 하나당 실행 명령이 정확히 1개이고 대상 도구가 맞아야 PASS.
emulate -L zsh
export IT2_LANG=kr        # 화면 문구 언어 고정(이 Mac 의 언어와 무관). 영어 검사는 tests/test_lang.zsh
ROOT=${0:A:h:h}
W=${1:-$ROOT/bin/iterm-open}
T=$(mktemp -d)/"dir with space"; mkdir -p "$T/src" && touch "$T/src/a.py" "$T/README.md"
fail=0

check() {  # <target> <매치 텍스트> <기대: vscode|vscode-line|finder-dir|finder-reveal|missing>
  local out rc n
  out=$(IO_DRYRUN=1 IO_NO_CODE_CLI=${NOCLI:-} /bin/sh -c "${(q)W} $1 ${(q)T} ${(q)2}" 2>&1); rc=$?
  n=$(print -r -- "$out" | grep -c '^DRY:')
  local ok=0
  case $3 in
    vscode)        [[ $n == 1 && $out == *"/code' -- "* ]] && ok=1 ;;
    vscode-line)   [[ $n == 1 && $out == *"/code' -g -- "*:12:3* ]] && ok=1 ;;
    vscode-app)    [[ $n == 1 && $out == "DRY: /usr/bin/open -b com.microsoft.VSCode -- "* ]] && ok=1 ;;
    finder-dir)    [[ $n == 1 && $out == "DRY: /usr/bin/open -- "* ]] && ok=1 ;;
    finder-reveal) [[ $n == 1 && $out == "DRY: /usr/bin/open -R -- "* ]] && ok=1 ;;
    missing)       [[ $n == 0 && $rc != 0 ]] && ok=1 ;;
  esac
  (( ok )) || fail=1
  printf '  %-7s %-22s → 실행 %s건  %s\n' $1 "$2" $n "$( ((ok)) && print ✅ || print "❌ ($out)")"
}

print "대상: ${W/#$HOME/~}"
# 기대값은 "이 Mac 에 VS Code CLI 가 있는가"에 따라 달라진다(실행기 자신의 판정을 그대로 사용)
if CLI=$(/bin/zsh -f "$W" which-code 2>/dev/null); then
  print "  (이 Mac: VS Code CLI 있음 → CLI 로 실행, 줄 이동 지원)"
  E_FILE=vscode E_LINE=vscode-line
else
  print "  (이 Mac: VS Code CLI 없음 → 앱으로 열기 대체, 줄 이동 불가)"
  E_FILE=vscode-app E_LINE=vscode-app
fi
check vscode src/a.py          $E_FILE
check vscode src/a.py:12:3     $E_LINE
check vscode README.md         $E_FILE
check finder src               finder-dir
check finder src/a.py          finder-reveal
check vscode nope.txt          missing
check vscode 'x$(touch PWNED)' missing
print "  (VS Code CLI 가 없는 Mac 흉내)"
NOCLI=1 check vscode src/a.py vscode-app
[[ -e $T/PWNED || -e PWNED ]] && { print "  ❌ 명령 주입 발생"; fail=1 } || print "  ✅ 명령 주입 없음"
rm -rf "${T:h}"
print "결과: $( ((fail)) && print FAIL || print PASS)"
exit $fail
