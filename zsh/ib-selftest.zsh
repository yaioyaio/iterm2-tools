#!/bin/zsh
# iterm2-tools: ib-selftest.zsh — iTerm2 custom 버튼 클릭 경로 자가 테스트
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
print -r -- "$(t '이 세션의 iTerm2 버전' 'iTerm2 version of this session'): ${TERM_PROGRAM_VERSION:-$(t '알 수 없음' 'unknown')}"
print -rn -- "$(t '아래 별 버튼을 클릭하세요 →' 'Click the star button below →')  "
printf '\e]1337;Button=type=custom;code=42;icon=star.fill\a\n'
print -r -- "$(t '(10초 동안 기다립니다)' '(waiting 10 seconds)')"
stty -echo -icanon min 0 time 100
bytes=$(dd bs=64 count=1 2>/dev/null | xxd -p)
stty sane
print -r -- "$(t '받은 바이트' 'Bytes received'): ${bytes:-$(t '<없음>' '<none>')}"
if [[ $bytes == 1b5b3f313333373b34327e* ]]; then
  print -r -- "$(t '✅ 성공: 버튼 기능을 사용할 수 있습니다' '✅ Success: buttons work in this iTerm2')"
else
  print -r -- "$(t '❌ 실패: 버튼이 보이지 않았다면 iTerm2 3.7 이상으로 재시작이 필요합니다' '❌ Failed: if no button appeared, restart into iTerm2 3.7 or later')"
fi
printf '\e]1337;Button=type=custom\a'
