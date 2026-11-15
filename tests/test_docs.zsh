#!/bin/zsh -f
# 문서 짝 검사 — 영어·한국어 문서가 한 쌍으로 맞는지 확인한다(파일 내용은 바꾸지 않음).
#   짝: 최상위 README.md(영어 메인) ↔ docs/kr/README.md, docs/en/<이름> ↔ docs/kr/<이름>
#   1) 짝 파일: 한쪽 언어에만 있는 문서가 없다
#   2) 언어 전환 줄: 제목 아래 자기 언어는 굵게, 상대 언어는 짝 파일 링크
#   3) 구조: 제목 단계·번호, 표 행, 목록 항목·들여쓰기, 코드 블록 수·언어 표시,
#            셸 코드 블록(sh/zsh/bash/표시 없음)은 주석을 뺀 명령 줄이 글자 그대로 같다
#   4) 링크: 문서 안 상대 링크가 실제 파일을 가리킨다
#   5) 두 사용 설명서 머리의 문서 목록이 다른 문서들의 두 언어 링크를 갖는다
# 사용: zsh tests/test_docs.zsh [패키지 폴더]   (기본 = 이 파일의 상위 폴더)
emulate -L zsh
setopt no_unset pipe_fail extended_glob null_glob
ROOT=${1:-${0:A:h:h}}
ROOT=${ROOT:A}
EN=$ROOT/docs/en KR=$ROOT/docs/kr
pass=0 fail=0
ok() { print -r -- "  ✅ $1"; (( ++pass )); return 0 }
ng() { print -r -- "  ❌ $1"; (( ++fail )); return 0 }

print -r -- "[문서 짝 검사] ${ROOT:t}: README.md ↔ docs/kr/README.md, docs/en ↔ docs/kr"
[[ -d $EN && -d $KR ]] || { ng "docs/en 또는 docs/kr 폴더가 없습니다"; print -r -- "결과: 통과 $pass / 실패 $fail"; exit 1 }

# 구조 골격: "줄번호<TAB>기록" — 기록만 비교하고 줄번호는 차이 위치 안내에 쓴다
skeleton() {
  /usr/bin/awk '
    function indent(s) { match(s, /^[ \t]*/); return RLENGTH }
    /^[ \t]*```/ {
      if (!code) {
        code = 1; tag = $0; sub(/^[ \t]*```/, "", tag); gsub(/[ \t]/, "", tag)
        shell = (tag == "" || tag == "sh" || tag == "zsh" || tag == "bash")
        printf "%d\tcode-begin indent=%d lang=%s\n", NR, indent($0), tag
      } else { code = 0; printf "%d\tcode-end\n", NR }
      next
    }
    code {
      if (!shell) next
      l = $0; sub(/(^|[ \t])#.*$/, "", l); sub(/[ \t]+$/, "", l)
      if (l != "") printf "%d\tcmd %s\n", NR, l
      next
    }
    /^#+[ \t]/ {
      num = ($2 ~ /^([0-9]+|[A-Z])([-.][0-9A-Z]+)*\.$/) ? " " $2 : ""
      printf "%d\theading %s%s\n", NR, $1, num; next
    }
    /^[ \t]*\|/                         { printf "%d\ttable-row\n", NR; next }
    /^[ \t]*([-*]|[0-9]+\.)[ \t]/       { printf "%d\tlist-item indent=%d\n", NR, indent($0); next }
  ' "$1"
}

# 상대 링크 목록(코드 블록·인라인 코드 제외, http·mailto·#앵커 제외)
links() {
  /usr/bin/awk '/^[ \t]*```/ { code = !code; next } !code' "$1" |
    /usr/bin/sed -e 's/`[^`]*`//g' |
    /usr/bin/grep -oE '\]\([^)]+\)' | /usr/bin/sed -e 's/^](//' -e 's/)$//' -e 's/#.*//' |
    /usr/bin/grep -vE '^(https?:|mailto:|$)' || true
}

check_links() {  # <문서>
  local doc=$1 t bad=0
  for t in ${(f)"$(links $doc)"}; do
    [[ -e ${doc:h}/$t ]] || { ng "${doc#$ROOT/}: 깨진 링크 → $t"; bad=1 }
  done
  (( bad )) || ok "${doc#$ROOT/}: 상대 링크 정상"
}

# 1) 짝 파일 — 메인 사용 설명서: 최상위 README.md(영어) ↔ docs/kr/README.md, 그 밖: docs/en/<이름> ↔ docs/kr/<이름>
typeset -a en_docs kr_docs P_EN P_KR P_ENL P_KRL others
en_docs=( ${EN}/**/*.md(.N) ); en_docs=( ${en_docs#$EN/} )
kr_docs=( ${KR}/**/*.md(.N) ); kr_docs=( ${kr_docs#$KR/} )
if [[ -f $ROOT/README.md && -f $KR/README.md ]]; then
  P_EN+=README.md P_KR+=docs/kr/README.md
  P_ENL+='**English** | [한국어](docs/kr/README.md)' P_KRL+='[English](../../README.md) | **한국어**'
else
  ng "메인 사용 설명서 짝 없음: 최상위 README.md ↔ docs/kr/README.md"
fi
for f in $en_docs; do
  if [[ $f == README.md ]]; then ng "docs/en/README.md 는 두지 않는다 — 영어 사용 설명서는 최상위 README.md"; continue; fi
  if (( ${kr_docs[(Ie)$f]} )); then
    parts=( ${(s:/:)f} ); up=""; repeat $#parts up+="../"      # 짝 파일까지의 상대 경로(하위 폴더 깊이만큼 ../)
    P_EN+=docs/en/$f P_KR+=docs/kr/$f others+=$f
    P_ENL+="**English** | [한국어](${up}kr/$f)" P_KRL+="[English](${up}en/$f) | **한국어**"
  else
    ng "docs/en/$f 의 한국어 짝 docs/kr/$f 없음"
  fi
done
for f in $kr_docs; do [[ $f == README.md ]] || (( ${en_docs[(Ie)$f]} )) || ng "docs/kr/$f 의 영어 짝 docs/en/$f 없음"; done
(( $#P_EN )) && ok "문서 짝 ${#P_EN}개: ${(j:, :)P_EN} (영어 쪽)" || ng "문서 짝이 하나도 없습니다"

integer k
for (( k = 1; k <= $#P_EN; k++ )); do
  en=$P_EN[k] kr=$P_KR[k]
  print -r -- "  · $en ↔ $kr"
  # 2) 언어 전환 줄
  grep -qF -- "$P_ENL[k]" $ROOT/$en && ok "$en: 언어 전환 줄" || ng "$en: 언어 전환 줄 없음 (기대: $P_ENL[k])"
  grep -qF -- "$P_KRL[k]" $ROOT/$kr && ok "$kr: 언어 전환 줄" || ng "$kr: 언어 전환 줄 없음 (기대: $P_KRL[k])"

  # 3) 구조 비교
  se=$(skeleton $ROOT/$en) sk=$(skeleton $ROOT/$kr)
  if [[ ${(F)${${(f)se}#*$'\t'}} == ${(F)${${(f)sk}#*$'\t'}} ]]; then
    ok "$en ↔ $kr: 구조 일치 ($(print -r -- $se | grep -c $'\theading') 제목, $(print -r -- $se | grep -c $'\ttable-row') 표 행, $(print -r -- $se | grep -c $'\tcmd ') 명령 줄)"
  else
    ng "$en ↔ $kr: 구조 불일치 (- = en, + = kr)"
    /usr/bin/diff -u --label $en --label $kr \
      <(print -r -- ${(F)${${(f)se}#*$'\t'}}) <(print -r -- ${(F)${${(f)sk}#*$'\t'}}) |
      /usr/bin/sed -n '3,14p' | /usr/bin/sed 's/^/       /'
    # 첫 차이의 원문 줄번호
    typeset -a ae ak; ae=( ${(f)se} ) ak=( ${(f)sk} ); integer i
    for (( i = 1; i <= ${#ae} || i <= ${#ak}; i++ )); do
      [[ ${ae[i]-}  == ${ak[i]-} ]] && continue
      [[ ${${ae[i]-}#*$'\t'} == ${${ak[i]-}#*$'\t'} ]] && continue
      print -r -- "       첫 차이: $en ${${ae[i]-끝}%%$'\t'*}행 ↔ $kr ${${ak[i]-끝}%%$'\t'*}행"; break
    done
  fi
done

# 4) 링크
for (( k = 1; k <= $#P_EN; k++ )); do check_links $ROOT/$P_EN[k]; check_links $ROOT/$P_KR[k]; done

# 5) 두 사용 설명서 머리의 문서 목록: 다른 문서들의 두 언어 링크
check_list() {  # <사용 설명서> <링크 접두: 영어 문서> <링크 접두: 한국어 문서> <상대 사용 설명서 링크>
  local doc=$1 enp=$2 krp=$3 other=$4 f; local -a missing=()
  [[ -f $ROOT/$doc ]] || return 0
  grep -qF "]($other)" $ROOT/$doc || missing+=$other
  for f in $others; do
    grep -qF "](${enp}$f)" $ROOT/$doc || missing+=${enp}$f
    grep -qF "](${krp}$f)" $ROOT/$doc || missing+=${krp}$f
  done
  (( $#missing )) && ng "$doc: 문서 목록에 링크 없음: ${(j:, :)missing}" || ok "$doc: 문서 목록에 모든 문서의 두 언어 링크 있음"
}
check_list README.md docs/en/ docs/kr/ docs/kr/README.md
check_list docs/kr/README.md ../en/ '' ../../README.md

print
print -r -- "결과: 통과 $pass / 실패 $fail"
(( fail == 0 ))
