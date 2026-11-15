#!/bin/zsh
# iterm2-tools 제거 스크립트 — 이 패키지가 설치한 파일만 지운다.
# 설치 때와 같은 규칙(lib/common.zsh)으로 그 Mac 의 실제 설치 경로를 계산한다.
emulate -L zsh
setopt no_unset pipe_fail

ROOT=${0:A:h}
source "$ROOT/lib/common.zsh"

targets=(
  "$IT2_BIN_DIR/iterm-open"
  "$IT2_BIN_DIR/iterm-clean"
  "$IT2_DP_FILE"
  "$IT2_AL_FILE"
  "$IT2_ZSH_DIR/iterm-buttons.zsh"
  "$IT2_ZSH_DIR/ib-selftest.zsh"
)
for f in $targets; do
  if [[ ! -e $f ]]; then
    print -r -- "  - $(t '없음     ' 'Not found   ') ${f/#$HOME/~}"
  elif [[ $f == *.json ]] || /usr/bin/grep -qE "$IT2_OWN_RE" "$f"; then
    /bin/rm -f -- "$f" && print -r -- "  ✅ $(t '삭제     ' 'Removed     ') ${f/#$HOME/~}"
  else
    print -r -- "  ⚠️  $(t '건너뜀  ' 'Skipped     ') ${f/#$HOME/~} $(t '(이 패키지 파일이 아님)' '(not a file from this package)')"
  fi
done
/bin/rmdir "$IT2_ZSH_DIR" 2>/dev/null || true
# install.sh --lang 이 저장한 언어 설정과 (비었으면) 그 폴더. ~/.config 자체는 건드리지 않는다
if [[ -e $HOME/.config/iterm2-tools/lang ]]; then
  /bin/rm -f -- "$HOME/.config/iterm2-tools/lang" && print -r -- "  ✅ $(t '삭제     ' 'Removed     ') ~/.config/iterm2-tools/lang"
fi
/bin/rmdir "$HOME/.config/iterm2-tools" 2>/dev/null || true
# 테스트·실행이 남겼을 수 있는 이 패키지의 바이트코드 캐시만 정리
/bin/rm -f "${IT2_AL_FILE:h}/__pycache__"/open_in_tools.*.pyc(N) 2>/dev/null
/bin/rmdir "${IT2_AL_FILE:h}/__pycache__" 2>/dev/null || true
print
print "  $(t '남은 일' 'Remaining steps'):"
print "  - $(t "~/.zshrc 에 'iterm2-tools/iterm-buttons.zsh' 줄을 넣었다면 직접 지우세요." "If you added an 'iterm2-tools/iterm-buttons.zsh' line to ~/.zshrc, remove it yourself.")"
print "  - $(t "우클릭 '현재 폴더' 항목은 실행 중인 스크립트가 끝나는 다음 iTerm2 재시작 때 사라집니다." "The right-click 'current folder' items disappear at the next iTerm2 restart, when the running script ends.")"
print "  - $(t "'우클릭 도구' 프로필은 iTerm2 가 자동으로 목록에서 내립니다." "The 'Right-click tools' profile is removed from the list by iTerm2 automatically.")"
