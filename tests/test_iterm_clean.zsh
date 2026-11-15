#!/bin/zsh -f
# iterm-clean 회귀 테스트 — 임시 폴더에 여러 언어 프로젝트를 만들어 검증한다(실제 프로젝트는 건드리지 않음).
#
#   zsh tests/test_iterm_clean.zsh            # 패키지의 bin/iterm-clean 검사
#   IT2_CLEAN_BIN=~/bin/iterm-clean zsh tests/test_iterm_clean.zsh   # 설치본 검사
#
# 휴지통 이동은 기본적으로 테스트 전용 폴더(mv 대체 경로)로 한다.
# 마지막 1건만 실제 macOS 휴지통(/usr/bin/trash)으로 보내고, 테스트가 만든 그 항목은 바로 지운다.
#   IT2_CLEAN_TEST_SKIP_REAL_TRASH=1 이면 그 1건도 건너뛴다.
# 픽스처의 .env 등은 테스트가 만든 빈 더미 파일이며, 어떤 파일의 내용도 읽지 않는다(존재 여부만 본다).

emulate zsh
setopt no_unset pipe_fail extended_glob

# 출력 언어 고정: [1]~[8] 의 문구 검사는 한국어 기준. 이 Mac 의 언어·설정 파일·호출한 셸의 IT2_LANG 과 무관하게 같은 결과가 나오게 한다.
# 영어 출력은 [9] 에서 명령마다 IT2_LANG=en 을 붙여 따로 검사한다.
export IT2_LANG=kr

HERE=${0:A:h}
CLEAN=${IT2_CLEAN_BIN:-$HERE/../bin/iterm-clean}; CLEAN=${CLEAN:A}
[[ -x $CLEAN ]] || { print -u2 "실행 파일 없음: $CLEAN"; exit 2 }
W=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/iterm-clean-test.XXXXXX") || exit 2
W=${W:A}
TOKEN=it2clean-e2e-${W:t:e}-$$
trap '/bin/rm -rf -- "$W"; /bin/rm -rf -- ~/.Trash/$TOKEN.egg-info(N) ~/.Trash/"$TOKEN.egg-info "*(N)' EXIT

integer pass=0 fail=0 skip=0
ok() { print -r -- "  ✅ $1"; (( ++pass )); return 0 }
ng() { print -r -- "  ❌ $1"; (( ++fail )); return 0 }
sk() { print -r -- "  ⏭  $1"; (( ++skip )); return 0 }
same() { [[ $2 == $3 ]] && ok $1 || { ng $1; print -r -- "     기대: ${(V)3}"; print -r -- "     실제: ${(V)2}" } }

GIT_OK=""
if [[ -n ${commands[git]:-} ]]; then
  if [[ ${commands[git]} != /usr/bin/git ]] || { d=$(/usr/bin/xcode-select -p 2>/dev/null) && [[ -d $d ]] }; then GIT_OK=1; fi
fi

f() { local x; for x; do /bin/mkdir -p -- ${x:h}; print -r -- data > $x; done }

# ── 픽스처 ──────────────────────────────────────────────────
build_fixture() {  # $1 = 만들 폴더
  local P=$1
  # Python
  f $P/py/app.py $P/py/pyproject.toml $P/py/pkg/__pycache__/m.cpython-312.pyc $P/py/.pytest_cache/v \
    $P/py/.mypy_cache/x $P/py/stray.py $P/py/stray.pyc $P/py/only.pyc $P/py/demo.egg-info/PKG-INFO $P/py/build/lib/x.py \
    $P/py/.venv/pyvenv.cfg $P/py/.venv/lib/site/__pycache__/z.pyc
  # Rust / Maven / Gradle
  f $P/rust/Cargo.toml $P/rust/src/main.rs $P/rust/target/debug/app $P/rust/target/.DS_Store
  f $P/maven/pom.xml $P/maven/src/A.java $P/maven/target/classes/A.class
  f $P/gradle/build.gradle.kts $P/gradle/src/B.kt $P/gradle/build/libs/a.jar $P/gradle/.gradle/8.0/x
  # Node
  f $P/node/package.json $P/node/src/index.ts $P/node/node_modules/lodash/index.js \
    $P/node/node_modules/lodash/__pycache__/q.pyc $P/node/dist/main.js $P/node/.next/cache/x \
    $P/node/tsconfig.tsbuildinfo $P/node/coverage/lcov.info
  # .NET / Swift / Flutter / Elixir / PHP / iOS / CMake
  f $P/dotnet/App.csproj $P/dotnet/Program.cs $P/dotnet/bin/Debug/a.dll $P/dotnet/obj/x.json
  f $P/swift/Package.swift $P/swift/Sources/main.swift $P/swift/.build/debug/x
  f $P/flutter/pubspec.yaml $P/flutter/lib/main.dart $P/flutter/.dart_tool/x $P/flutter/build/app.apk
  f $P/elixir/mix.exs $P/elixir/lib/a.ex $P/elixir/_build/dev/x $P/elixir/deps/plug/mix.exs
  f $P/php/composer.json $P/php/index.php $P/php/vendor/autoload.php
  f $P/ios/Podfile $P/ios/App.swift $P/ios/Pods/Manifest.lock
  f $P/cmake/CMakeLists.txt $P/cmake/main.c $P/cmake/build/CMakeFiles/x $P/cmake/cmake-build-debug/y
  f $P/cmake-insrc/CMakeLists.txt $P/cmake-insrc/CMakeCache.txt $P/cmake-insrc/Makefile $P/cmake-insrc/CMakeFiles/x
  f $P/.DS_Store
  # 남아야 하는 것(증거 없음·보호 대상·앱 번들 안)
  f $P/neg/bin/run.sh $P/neg/build/make.sh $P/neg/target/notes.md $P/neg/dist/README \
    $P/neg/go.mod $P/neg/vendor/lib.go $P/neg/env/settings.py $P/neg/venv/notes.txt $P/neg/Pods/readme \
    $P/neg/.env $P/neg/.env.local $P/neg/.idea/workspace.xml $P/neg/.vscode/settings.json \
    $P/neg/package-lock.json $P/neg/yarn.lock $P/neg/Tool.app/Contents/node_modules/x/index.js \
    $P/neg/.env.venv/pyvenv.cfg
  # 이상한 이름(공백·한글·- 로 시작·줄바꿈)
  f "$P/odd/my app/__pycache__/a.pyc" "$P/odd/한글 프로젝트/Cargo.toml" "$P/odd/한글 프로젝트/target/x" \
    "$P/odd/-dash/__pycache__/a.pyc" "$P/odd/new"$'\n'"line/__pycache__/a.pyc"
  # 바깥을 가리키는 심볼릭 링크(따라가면 안 됨)
  f $W/outside/keep.txt
  /bin/ln -s $W/outside $P/py/node_modules
  /bin/ln -s $W/outside/keep.txt $P/py/.DS_Store
}

EXPECT_CACHE=(
  .DS_Store node/.next node/tsconfig.tsbuildinfo py/.mypy_cache py/.pytest_cache py/demo.egg-info
  py/pkg/__pycache__ py/stray.pyc cmake/cmake-build-debug
  "odd/my app/__pycache__" "odd/-dash/__pycache__" "odd/new"$'\n'"line/__pycache__"
)
EXPECT_BUILD=(
  rust/target maven/target gradle/build gradle/.gradle node/dist node/coverage dotnet/bin dotnet/obj
  swift/.build flutter/.dart_tool flutter/build elixir/_build cmake/build py/build "odd/한글 프로젝트/target"
)
EXPECT_DEPS=( py/.venv node/node_modules elixir/deps php/vendor ios/Pods )

sorted() { print -rl -- ${(o)@} }                        # 비교용(줄바꿈 이름은 그대로 한 원소)
listed() {  # $1 폴더, 나머지 = 옵션 → 상대 경로 정렬 목록
  local P=$1; shift
  local -a r=( ${(0)"$($CLEAN --print0 $@ $P)"} )
  r=( ${r#$P/} ); sorted $r
}
snap() { /usr/bin/find $1 -exec /usr/bin/stat -f '%N|%z|%m|%p' {} + 2>/dev/null | /usr/bin/sort }

print -r -- "대상: ${CLEAN/#$HOME/~}"
print -r -- "임시 폴더: ${W/#$HOME/~}"

# ── 1. 판정(언어별 후보) ─────────────────────────────────────
print -r -- "[1] 언어별 판정"
P=$W/t1; build_fixture $P
same "기본(cache,build) 후보 목록"      "$(listed $P)"            "$(sorted $EXPECT_CACHE $EXPECT_BUILD)"
same "-c all 후보 목록(의존성 포함)"    "$(listed $P -c all)"     "$(sorted $EXPECT_CACHE $EXPECT_BUILD $EXPECT_DEPS)"
same "-c cache 후보 목록"               "$(listed $P -c cache)"   "$(sorted $EXPECT_CACHE)"
same "-c deps 후보 목록"                "$(listed $P -c deps)"    "$(sorted $EXPECT_DEPS)"
all=$(listed $P -c all)
[[ $all != *neg/* ]] && ok "증거 없는 bin·build·target·dist·vendor·env·venv·Pods, .env·.idea·잠금파일·앱 번들 안은 후보 아님" \
                     || ng "neg/ 아래가 후보에 섞임: ${(V)all}"
[[ $all != *.venv/lib* && $all != *node_modules/lodash* && $all != *target/.DS_Store* && $all != *build/CMakeFiles* ]] &&
  ok "후보 폴더 안쪽 항목은 따로 세지 않음(중복 없음)" || ng "안쪽 항목 중복"
[[ $(listed $P) != *py/node_modules* && $all != *py/node_modules* && $(listed $P -c cache) != *py/.DS_Store* ]] &&
  ok "심볼릭 링크(폴더·파일)는 후보 아님" || ng "심볼릭 링크가 후보에 포함됨"
l=$(listed $P -c build)
[[ $l == *node/dist* && $l == *node/tsconfig.tsbuildinfo* ]] && ok "-c build: dist 와 tsbuildinfo 를 함께 지움(dist 만 지우면 tsc 가 다시 출력 안 함 — 실측)" || ng "dist·tsbuildinfo 분리됨"
[[ $(listed $P -c cache) == *node/tsconfig.tsbuildinfo* && $(listed $P -c deps) != *tsbuildinfo* ]] && ok "tsbuildinfo 는 캐시·빌드 어느 선택에서도 지움" || ng "선택에 따라 tsbuildinfo 가 남음"
[[ $all != *only.pyc* && $all == *py/stray.pyc* ]] && ok ".py 가 옆에 있는 .pyc 만 대상(.py 없는 .pyc 는 유일한 사본일 수 있어 보존)" || ng ".pyc 원본 확인 실패"
[[ $all != *cmake-insrc* ]] && ok "소스 폴더에 직접 빌드한 CMakeFiles 는 단독으로 지우지 않음" || ng "in-source CMakeFiles 가 대상"
TS=$W/t1ts; f $TS/package.json $TS/dist/a.js; print -r -- '{"compilerOptions":{"incremental":true,"tsBuildInfoFile":".cache/x"}}' > $TS/tsconfig.json
[[ $($CLEAN $TS) == *"tsBuildInfoFile 파일도 지워야"* ]] && ok "tsBuildInfoFile 로 위치를 바꾼 프로젝트는 경고 표시" || ng "tsBuildInfoFile 경고 없음"
out=$($CLEAN $P)
[[ $out == *"참고: 선택하지 않은 범주 [의존성] 5개"* ]] && ok "제외한 의존성 개수 안내" || ng "의존성 제외 안내 없음"

# ── 2. 드라이런은 아무것도 바꾸지 않는다 ────────────────────
print -r -- "[2] 드라이런"
before=$(snap $P); $CLEAN -c all $P >/dev/null; rc=$?; $CLEAN --print0 -c all $P >/dev/null
same "드라이런 종료 코드 0" $rc 0
same "드라이런 전후 트리 동일(이름·크기·수정시각·권한)" "$(snap $P)" "$before"

# ── 3. 확인 없이는 아무것도 하지 않는다 ─────────────────────
print -r -- "[3] 확인(yes) 절차"
export IT2_CLEAN_NO_TRASH_CMD=1 IT2_CLEAN_TRASH_DIR=$W/trash3
for ans in no '' YES y; do
  print -r -- $ans | $CLEAN --trash $P >/dev/null
  same "입력 '${ans:-<빈 줄>}' → 취소, 변화 없음" "$(snap $P)" "$before"
done
$CLEAN --trash $P </dev/null >/dev/null
same "입력 없음(EOF) → 취소, 변화 없음" "$(snap $P)" "$before"
[[ ! -e $W/trash3 ]] && ok "취소 시 휴지통 폴더도 만들지 않음" || ng "취소했는데 휴지통 폴더가 생김"

# ── 4. yes 입력 → 휴지통으로 이동(대체 경로 mv) ─────────────
print -r -- "[4] 휴지통으로 이동 (mv 대체 경로, 테스트 전용 휴지통)"
P=$W/t4; build_fixture $P
neg_before=$(snap $P/neg); out_before=$(snap $W/outside)
cands=( ${(0)"$($CLEAN --print0 $P)"} )
print -r -- yes | $CLEAN --trash $P >$W/out4.txt; rc=$?
same "종료 코드 0" $rc 0
left=0; for c in $cands; do [[ -e $c || -L $c ]] && (( left++ )); done
same "후보 ${#cands}개 모두 원래 자리에서 사라짐" $left 0
n=$(/bin/ls -1A $IT2_CLEAN_TRASH_DIR | /usr/bin/wc -l | /usr/bin/tr -d ' ')
same "휴지통 항목 수 = 후보 수" $n ${#cands}
pyc=( $IT2_CLEAN_TRASH_DIR/__pycache__(|\ <->)(N) )
same "같은 이름(__pycache__ 4개) 충돌 없이 모두 보관" ${#pyc} 4
same "남아야 할 neg/ 트리 그대로" "$(snap $P/neg)" "$neg_before"
same "심볼릭 링크가 가리키는 바깥 폴더 그대로" "$(snap $W/outside)" "$out_before"
[[ -L $P/py/node_modules && -L $P/py/.DS_Store ]] && ok "심볼릭 링크 자체도 그대로" || ng "심볼릭 링크가 사라짐"
[[ -e $P/neg/.env && -e $P/neg/.env.local && -e $P/rust/Cargo.toml && -e $P/py/app.py && -e $P/node/package.json ]] &&
  ok ".env·소스·빌드 파일 보존" || ng "보존돼야 할 파일이 사라짐"
[[ -d $P/py/.venv && -d $P/node/node_modules ]] && ok "선택 안 한 의존성(.venv·node_modules) 보존" || ng "의존성이 지워짐"
same "다시 실행하면 정리할 것 없음(의존성 제외)" "$(listed $P)" ""

# ── 5. git 보호 ─────────────────────────────────────────────
print -r -- "[5] git 보호"
if [[ -n $GIT_OK ]]; then
  G=$W/t5/repo
  f $G/package.json $G/dist/bundle.js $G/node_modules/x/i.js $G/src/__pycache__/a.pyc
  f $W/t5/nest/CMakeLists.txt $W/t5/nest/build/sub/.git/HEAD $W/t5/nest/build/sub/x.c
  git -C $G init -q && git -C $G add package.json dist/bundle.js
  out=$($CLEAN -c all $W/t5)
  l=$(listed $W/t5 -c all)
  [[ $l != *repo/dist* && $out == *"repo/dist — git 이 추적하는 파일 포함"* ]] && ok "git 추적 중인 dist/ 는 건너뜀(이유 표시)" || ng "추적 중인 dist/ 가 후보에 포함: ${(V)l}"
  [[ $l == *repo/node_modules* && $l == *repo/src/__pycache__* ]] && ok "추적 안 하는 node_modules·__pycache__ 는 후보" || ng "추적 안 하는 항목 누락: ${(V)l}"
  [[ $l != *nest/build* && $out == *"nest/build — 안에 별도 git 저장소"* ]] && ok "안에 다른 .git 이 있는 build/ 는 건너뜀" || ng "내부 저장소가 있는 build/ 가 후보"
  print -r -- yes | $CLEAN --trash -c all $W/t5 >/dev/null
  [[ -e $G/dist/bundle.js && -e $W/t5/nest/build/sub/x.c && ! -e $G/node_modules ]] && ok "이동 후에도 추적 파일·내부 저장소 보존" || ng "git 보호 실패"
else
  sk "git(개발자 도구) 없음 — git 보호 테스트 생략"
fi

# git 이 없는 Mac(개발자 도구 미설치): 저장소 안 후보는 추적 여부를 알 수 없으므로 건너뛰어야 한다
N=$W/t5b; f $N/repo/.git/HEAD $N/repo/package.json $N/repo/node_modules/x/i.js $N/plain/__pycache__/a.pyc
out=$(IT2_CLEAN_NO_GIT=1 $CLEAN -c all $N); l=$(IT2_CLEAN_NO_GIT=1 listed $N -c all)
[[ $l == plain/__pycache__ && $out == *"repo/node_modules — git 저장소 안인데 git 이 없어"* ]] &&
  ok "git 없음: 저장소 안 항목은 건너뜀, 저장소 밖은 후보" || ng "git 없음 처리 실패: ${(V)l}"

# ── 6. 위험한 시작 폴더 거부 ───────────────────────────────
print -r -- "[6] 시작 폴더 거부"
for r in / $HOME $HOME/Library /usr /Applications; do
  [[ -d $r ]] || continue
  $CLEAN --print0 $r >/dev/null 2>&1; same "거부: ${r/#$HOME/~}" $? 2
done
$CLEAN -c nope $W/t1 >/dev/null 2>&1; same "알 수 없는 범주 → 오류(2)" $? 2

# ── 7. 우클릭 메뉴 모드(--menu) ────────────────────────────
print -r -- "[7] 메뉴 모드"
P=$W/t7; build_fixture $P; before=$(snap $P)
export IT2_CLEAN_TRASH_DIR=$W/trash7
(cd $P && print -r -- $'q\n' | $CLEAN --menu >/dev/null)
same "q → 취소, 변화 없음" "$(snap $P)" "$before"
(cd $P && print -r -- $'\nno\n' | $CLEAN --menu >/dev/null)
same "기본 범위 선택 후 no → 변화 없음" "$(snap $P)" "$before"
(cd $P && print -r -- $'2\nyes\n' | $CLEAN --menu >$W/out7.txt)
[[ ! -e $P/py/pkg/__pycache__ && -d $P/rust/target && -d $P/node/node_modules ]] &&
  ok "2(캐시만) + yes → 캐시만 이동, 빌드·의존성 보존" || ng "메뉴 캐시만 정리 실패"
/usr/bin/grep -q 'Enter 키를 누르면' $W/out7.txt && ok "끝나면 Enter 로 닫기 안내" || ng "닫기 안내 없음"
(cd $HOME && print -r -- $'\n' | $CLEAN --menu >$W/out7h.txt 2>&1); same "홈 폴더에서 메뉴 실행 → 거부(2)" $? 2
/usr/bin/grep -q '홈 폴더 전체는 정리할 수 없습니다' $W/out7h.txt && /usr/bin/grep -q 'Enter 키를 누르면' $W/out7h.txt &&
  ok "거부 메시지를 보여 주고 Enter 를 기다린 뒤 닫힘(탭이 바로 사라지지 않음)" || ng "메뉴 모드 거부 시 Enter 대기 없음"

# ── 7-2. 정리 메뉴의 드라이런 단계: 결과 확인 → yes 면 그 결과 그대로 정리 / Enter 면 종료 ──
print -r -- "[7-2] 정리 메뉴 — 드라이런 결과 확인 후 정리"
P=$W/t72; build_fixture $P; before=$(snap $P)
export IT2_CLEAN_TRASH_DIR=$W/trash72
(cd $P && print -r -- $'\n\n' | $CLEAN --menu >$W/out72a.txt)
same "드라이런 후 Enter → 변화 없음" "$(snap $P)" "$before"
/usr/bin/grep -q '드라이런 결과입니다. 아직 아무것도 바꾸지 않았습니다' $W/out72a.txt &&
  /usr/bin/grep -q 'rust/target/' $W/out72a.txt && ok "드라이런 결과 목록과 '변경 없음' 안내 표시" || ng "드라이런 결과 표시 없음"
(cd $P && print -r -- $'1\nno\n' | $CLEAN --menu >/dev/null)
same "드라이런 후 no → 변화 없음" "$(snap $P)" "$before"
(cd $P && $CLEAN --menu </dev/null >/dev/null)
same "드라이런 후 입력 없음(EOF) → 변화 없음" "$(snap $P)" "$before"
dry=( ${(0)"$($CLEAN --print0 $P)"} )
(cd $P && print -r -- $'1\nyes\n' | $CLEAN --menu >$W/out72b.txt); rc=$?
same "드라이런 후 yes → 종료 코드 0" $rc 0
left=0; for c in $dry; do [[ -e $c || -L $c ]] && (( left++ )); done
n=$(/bin/ls -1A $IT2_CLEAN_TRASH_DIR | /usr/bin/wc -l | /usr/bin/tr -d ' ')
[[ $left == 0 && $n == ${#dry} ]] && ok "드라이런에서 본 ${#dry}개 그대로 휴지통으로 이동" || ng "드라이런 목록과 이동 결과 불일치(남음 $left, 휴지통 $n, 목록 ${#dry})"
[[ -d $P/node/node_modules && -e $P/neg/.env && -e $P/rust/Cargo.toml ]] && ok "목록에 없던 것(의존성·.env·소스) 보존" || ng "목록 밖 항목이 사라짐"
$CLEAN --trash --dry-run $P >/dev/null 2>&1; same "--trash 와 --dry-run 동시 지정 → 오류(2)" $? 2
same "-n / --dry-run 단독 = 기본 드라이런과 같은 목록" "$(listed $P -n)" "$(listed $P)"
unset IT2_CLEAN_NO_TRASH_CMD IT2_CLEAN_TRASH_DIR

# ── 8. 실제 macOS 휴지통(1건) ──────────────────────────────
print -r -- "[8] 실제 휴지통(/usr/bin/trash)"
if [[ -n ${IT2_CLEAN_TEST_SKIP_REAL_TRASH:-} ]]; then sk "IT2_CLEAN_TEST_SKIP_REAL_TRASH 설정 — 생략"
elif [[ ! -x /usr/bin/trash ]]; then sk "/usr/bin/trash 없음(macOS 14 이하) — mv 대체 경로는 [4]에서 검증"
else
  E=$W/t8; f $E/$TOKEN.egg-info/PKG-INFO
  print -r -- yes | $CLEAN --trash -c cache $E >/dev/null; rc=$?
  [[ $rc == 0 && ! -e $E/$TOKEN.egg-info && -d ~/.Trash/$TOKEN.egg-info ]] &&
    ok "실제 휴지통으로 이동 확인(테스트 항목은 곧바로 지움)" || ng "실제 휴지통 이동 실패(rc=$rc)"
fi

# ── 9. 영어 출력(IT2_LANG=en) ───────────────────────────────
# 모든 사용자 출력 경로를 영어로 실행해 출력(stdout+stderr)을 $EN/*.txt 에 모은 뒤 한글이 없는지 본다.
# 휴지통 이동은 모두 테스트 전용 폴더(mv 대체 경로)로 한다 — 실제 휴지통은 쓰지 않는다.
print -r -- "[9] 영어 출력 (IT2_LANG=en)"
EN=$W/en9; /bin/mkdir -p $EN
en() { IT2_LANG=en IT2_CLEAN_NO_TRASH_CMD=1 IT2_CLEAN_TRASH_DIR=${TR9:-$W/trash9} $CLEAN "$@" }
kr() { IT2_LANG=kr IT2_CLEAN_NO_TRASH_CMD=1 IT2_CLEAN_TRASH_DIR=${TR9:-$W/trash9} $CLEAN "$@" }
# 한글 검사: 픽스처 자체의 한글 이름("한글 프로젝트")과 임시·홈 폴더 경로는 지운 뒤 본다
has_hangul() {   # 문자 단위로 비교하도록 이 함수 안에서만 UTF-8 로케일 사용(호출한 셸의 로케일과 무관)
  local LC_ALL=en_US.UTF-8
  local s=${1//한글 프로젝트/}; s=${s//$W/}; s=${s//$HOME/}
  [[ $s == *[가-힣ㄱ-ㅎㅏ-ㅣ]* ]]
}
has_hangul "$(kr -h)" && ok "검사기 대조군: 한국어 출력에서는 한글을 찾음" || ng "한글 검사기가 한국어 출력도 못 찾음(검사 무효)"

P=$W/t9; build_fixture $P; before=$(snap $P)
TR9=$W/trash9
en -h >$EN/help.txt 2>&1
en --rules >$EN/rules.txt 2>&1
en $P >$EN/dry.txt 2>&1; rc_en=$?
kr $P >$W/dry9kr.txt 2>&1; rc_kr=$?
en -c all $P >$EN/dry-all.txt 2>&1
en -n -c cache $P >$EN/dry-cache.txt 2>&1
o=$(<$EN/help.txt); same "영어 -h 첫 줄" "${o%%$'\n'*}" "Usage: iterm-clean [options] [folder]   (default folder: the current folder)"
o=$(<$EN/rules.txt); same "영어 --rules 머리글" "${o%%$'\n'*}" "Cat.    Type  Name                 Evidence (— = the name alone decides)"
o=$(<$EN/dry.txt); same "영어 드라이런 첫 줄" "${o%%$'\n'*}" "Dry run — nothing will be changed. Categories: cache, build"
[[ $(<$EN/dry.txt) == *"Note: left out 5 items in the unselected category [deps] (to include them, use -c all)."* &&
   $(<$EN/dry.txt) == *"To move these to the Trash: iterm-clean --trash "* && $(<$EN/dry-all.txt) == *"(contains pyvenv.cfg)"* &&
   $(<$EN/dry-all.txt) == *"(source stray.py exists)"* ]] &&
  ok "영어 드라이런: 제외 범주 안내·다음 명령·증거 표시" || ng "영어 드라이런 문구 누락"
same "드라이런 종료 코드 영어=한국어" $rc_en $rc_kr
rows() { local l; for l in ${(f)"$(<$1)"}; do [[ $l == '  ['* ]] && print -r -- "${${l#*\] }%%   \(*}"; done }
same "드라이런 목록(순서·크기·경로) 영어=한국어" "$(rows $EN/dry.txt)" "$(rows $W/dry9kr.txt)"
for a in '' '-c all' '-c deps'; do
  kr --print0 ${=a} $P >$W/p0kr.bin; en --print0 ${=a} $P >$W/p0en.bin
  /usr/bin/cmp -s $W/p0kr.bin $W/p0en.bin && [[ -s $W/p0en.bin ]] && ok "--print0 ${a:-(기본)} 출력 바이트 동일(한국어=영어)" ||
    ng "--print0 ${a:-(기본)} 출력이 언어에 따라 다름"
done

# 건너뜀(안전) 이유 · tsBuildInfoFile 경고
S=$W/t9s
f $S/repo/.git/HEAD $S/repo/package.json $S/repo/node_modules/x/i.js
f $S/nest/CMakeLists.txt $S/nest/build/sub/.git/HEAD $S/nest/build/sub/x.c
f $S/ts/package.json $S/ts/dist/a.js; print -r -- '{"compilerOptions":{"tsBuildInfoFile":".cache/x"}}' > $S/ts/tsconfig.json
f $S/prot/.env.egg-info/PKG-INFO            # 이름만 .env* 인 빈 더미(보호 대상 이름 규칙 확인용)
IT2_CLEAN_NO_GIT=1 en -c all $S >$EN/skip-nogit.txt 2>&1
o=$(<$EN/skip-nogit.txt)
[[ $o == *"Skipped (for safety):"* && $o == *"repo/node_modules — inside a git repository, but git is not available to check what is tracked"* &&
   $o == *"nest/build — contains a separate git repository (.git)"* && $o == *"prot/.env.egg-info — protected name"* &&
   $o == *"(package.json, note: also remove the tsBuildInfoFile set in tsconfig, or tsc will not rebuild)"* ]] &&
  ok "영어 건너뜀 이유(git 없음·내부 .git·보호 이름)와 tsBuildInfoFile 경고" || ng "영어 건너뜀 이유 문구 누락"
IT2_CLEAN_NO_GIT=1 kr --print0 -c all $S >$W/p0kr.bin; IT2_CLEAN_NO_GIT=1 en --print0 -c all $S >$W/p0en.bin
/usr/bin/cmp -s $W/p0kr.bin $W/p0en.bin && ok "건너뜀이 있는 경우에도 --print0 바이트 동일" || ng "건너뜀 픽스처 --print0 이 언어에 따라 다름"
/bin/mkdir -p $W/fakegit; print -r -- $'#!/bin/sh\nexit 1' > $W/fakegit/git; /bin/chmod +x $W/fakegit/git
PATH=$W/fakegit:$PATH en -c all $S >$EN/skip-gitfail.txt 2>&1      # git 이 실패하는 경우
[[ $(<$EN/skip-gitfail.txt) == *"repo/node_modules — could not check git tracking"* ]] && ok "영어: git 확인 실패 이유" || ng "영어 git 확인 실패 문구 없음"
if [[ -n $GIT_OK ]]; then
  G=$W/t9g/repo; f $G/package.json $G/dist/b.js; git -C $G init -q && git -C $G add package.json dist/b.js
  en $W/t9g >$EN/skip-tracked.txt 2>&1
  [[ $(<$EN/skip-tracked.txt) == *"repo/dist — contains files tracked by git"* ]] && ok "영어: git 추적 파일 이유" || ng "영어 git 추적 문구 없음"
else
  sk "git(개발자 도구) 없음 — 영어 git 추적 문구 생략"
fi
/bin/mkdir -p $W/t9e
en $W/t9e >$EN/empty.txt 2>&1
[[ $(<$EN/empty.txt) == *"Nothing to clean."* ]] && ok "영어: 정리할 것 없음" || ng "영어 '없음' 문구 없음"

# 확인(yes) 절차 — [3] 을 영어로: yes 이외는 모두 취소, 아무것도 바꾸지 않음
for ans in no '' YES y; do
  print -r -- $ans | en --trash $P >$EN/confirm-${ans:-empty}.txt 2>&1
  same "영어: 입력 '${ans:-<빈 줄>}' → 취소, 변화 없음" "$(snap $P)" "$before"
done
en --trash $P </dev/null >$EN/confirm-eof.txt 2>&1
same "영어: 입력 없음(EOF) → 취소, 변화 없음" "$(snap $P)" "$before"
[[ ! -e $TR9 ]] && ok "영어: 취소 시 휴지통 폴더도 만들지 않음" || ng "영어: 취소했는데 휴지통 폴더가 생김"
o=$(<$EN/confirm-no.txt)
[[ $o == *"above ("*") to the Trash? Type yes to continue (anything else cancels): Cancelled. Nothing was changed."* ]] &&
  ok "영어 확인 질문·취소 문구" || ng "영어 확인 질문/취소 문구 다름: ${(V)${o##*$'\n'}}"
[[ $(<$EN/confirm-eof.txt) == *"Cancelled (no input). Nothing was changed."* ]] && ok "영어 입력 없음 취소 문구" || ng "영어 EOF 취소 문구 없음"

# 메뉴 — [7]·[7-2] 를 영어로
(cd $P && print -r -- $'q\n' | en --menu >$EN/menu-q.txt 2>&1)
same "영어 메뉴 q → 취소, 변화 없음" "$(snap $P)" "$before"
(cd $P && print -r -- $'2\n\n' | en --menu >$EN/menu-2enter.txt 2>&1)
same "영어 메뉴 2 + Enter → 변화 없음" "$(snap $P)" "$before"
(cd $P && print -r -- $'\n\n' | en --menu >$EN/menu-enter.txt 2>&1)
same "영어 메뉴 기본 + Enter → 변화 없음" "$(snap $P)" "$before"
(cd $P && print -r -- $'1\nno\n' | en --menu >$EN/menu-no.txt 2>&1)
same "영어 메뉴 드라이런 후 no → 변화 없음" "$(snap $P)" "$before"
(cd $P && en --menu </dev/null >$EN/menu-eof.txt 2>&1)
same "영어 메뉴 입력 없음(EOF) → 변화 없음" "$(snap $P)" "$before"
[[ ! -e $TR9 ]] && ok "영어 메뉴: 취소 시 휴지통 폴더도 만들지 않음" || ng "영어 메뉴: 휴지통 폴더가 생김"
[[ $(<$EN/menu-q.txt) == *"Cancelled. Nothing was changed."*"Press Enter to close this tab."* &&
   $(<$EN/menu-enter.txt) == *"(to include them, choose option 3)."* &&
   $(<$EN/menu-2enter.txt) == *"Dry run — nothing will be changed. Categories: cache"$'\n'* &&
   $(<$EN/menu-2enter.txt) == *"▲ These are the dry-run results. Nothing has been changed yet."* ]] &&
  ok "영어 메뉴: 취소·범위 3 안내·드라이런 결과 안내" || ng "영어 메뉴 문구 누락"

# yes → 드라이런 목록 그대로 이동 (--trash / --menu)
P=$W/t9y; build_fixture $P; TR9=$W/trash9y
dry=( ${(0)"$(en --print0 $P)"} )
print -r -- yes | en --trash $P >$EN/trash-yes.txt 2>&1; rc=$?
left=0; for c in $dry; do [[ -e $c || -L $c ]] && (( left++ )); done
n=$(/bin/ls -1A $TR9 | /usr/bin/wc -l | /usr/bin/tr -d ' ')
[[ $rc == 0 && $left == 0 && $n == ${#dry} ]] && ok "영어 --trash yes → 드라이런의 ${#dry}개 그대로 이동" || ng "영어 --trash yes 결과 불일치(rc $rc, 남음 $left, 휴지통 $n, 목록 ${#dry})"
[[ $(<$EN/trash-yes.txt) == *"Moved to the Trash: ${#dry} / failed or skipped: 0"* ]] && ok "영어 이동 결과 요약" || ng "영어 이동 결과 요약 없음"
P=$W/t9m; build_fixture $P; TR9=$W/trash9m
dry=( ${(0)"$(en --print0 $P)"} )
(cd $P && print -r -- $'1\nyes\n' | en --menu >$EN/menu-yes.txt 2>&1); rc=$?
left=0; for c in $dry; do [[ -e $c || -L $c ]] && (( left++ )); done
n=$(/bin/ls -1A $TR9 | /usr/bin/wc -l | /usr/bin/tr -d ' ')
[[ $rc == 0 && $left == 0 && $n == ${#dry} ]] && ok "영어 메뉴 yes → 드라이런의 ${#dry}개 그대로 이동" || ng "영어 메뉴 yes 결과 불일치(rc $rc, 남음 $left, 휴지통 $n, 목록 ${#dry})"
[[ -d $P/node/node_modules && -e $P/neg/.env && -e $P/rust/Cargo.toml ]] && ok "영어 메뉴: 목록에 없던 것 보존" || ng "영어 메뉴: 목록 밖 항목이 사라짐"
o=$(<$EN/menu-yes.txt)
[[ $o == *"  Review the list above. Type yes to move exactly these items to the Trash, or press Enter to finish without cleaning."$'\n'"Move the "* &&
   $o == *"To undo, find the items in the Trash in Finder and restore them."* && $o == *"Press Enter to close this tab." ]] &&
  ok "영어 메뉴 확인 안내·복원 안내·닫기 안내" || ng "영어 메뉴 yes 문구 누락"

# 이동 실패 · 그 사이 바뀐 항목
F=$W/t9f; f $F/a/__pycache__/m.pyc
TR9=/dev/null/x; print -r -- yes | en --trash $F >$EN/trash-fail.txt 2>&1; rc_en=$?
print -r -- yes | kr --trash $F >/dev/null 2>&1; rc_kr=$?; TR9=$W/trash9f
[[ $rc_en == 4 && $rc_kr == 4 && $(<$EN/trash-fail.txt) == *"  Failed: $F/a/__pycache__"*"failed or skipped: 1"* && -d $F/a/__pycache__ ]] &&
  ok "영어: 옮기지 못하면 'Failed' 표시, 종료 코드 4(한국어와 같음)" || ng "영어 이동 실패 처리 다름(en $rc_en, kr $rc_kr)"
f $F/b/__pycache__/m.pyc
/usr/bin/mkfifo $W/fifo9
en --trash $F <$W/fifo9 >$EN/trash-changed.txt 2>&1 &
pid=$!
exec {fd9}>$W/fifo9
for i in {1..100}; do [[ -f $EN/trash-changed.txt && $(<$EN/trash-changed.txt) == *"Type yes"* ]] && break; /bin/sleep 0.05; done
/bin/rm -rf -- $F/a/__pycache__            # 목록을 보여 준 뒤 확인 전에 사라진 항목
print -r -u $fd9 -- yes; exec {fd9}>&-
wait $pid; rc=$?
[[ $rc == 4 && $(<$EN/trash-changed.txt) == *"  Skipped (changed in the meantime): $F/a/__pycache__"* && ! -e $F/b/__pycache__ ]] &&
  ok "영어: 확인 사이에 바뀐 항목은 'Skipped (changed in the meantime)'" || ng "영어 '그 사이 바뀜' 처리 다름(rc $rc)"

# 오류 · 거부(종료 코드 2, 한국어와 같은 종료 코드)
bad=()
err() {  # $1 이름, 나머지 인자
  local name=$1 a b; shift
  en "$@" </dev/null >$EN/err-$name.txt 2>&1; a=$?
  kr "$@" </dev/null >/dev/null 2>&1; b=$?
  [[ $a == 2 && $b == 2 ]] || bad+=( "$name(en $a, kr $b)" )
}
err bogus --bogus $W/t9e;  err noarg -c;  err badcat -c nope $W/t9e;  err twofolders $W/t9e $W/t9e
err trashdry --trash --dry-run $W/t9e;  err notdir $W/nope;  err root /;  err home $HOME
err library $HOME/Library;  err usr /usr;  err broad /Users
(( $#bad == 0 )) && ok "영어 오류·거부 11가지 모두 종료 코드 2(한국어와 같음)" || ng "오류 종료 코드 다름: $bad"
[[ $(<$EN/err-bogus.txt) == "iterm-clean: Unknown option: --bogus (see iterm-clean -h)" &&
   $(<$EN/err-trashdry.txt) == "iterm-clean: --trash and --dry-run cannot be used together" &&
   $(<$EN/err-root.txt) == "iterm-clean: The root folder (/) cannot be cleaned." &&
   $(<$EN/err-home.txt) == "iterm-clean: The whole home folder cannot be cleaned. Run this in a project folder." ]] &&
  ok "영어 오류 문구(알 수 없는 옵션·--trash+--dry-run·루트·홈)" || ng "영어 오류 문구 다름"
for r in / $HOME; do
  (cd $r && print -r -- $'\n' | en --menu >$EN/menu-refuse-${${r:t}:-root}.txt 2>&1); rc=$?
  o=$(<$EN/menu-refuse-${${r:t}:-root}.txt)
  [[ $rc == 2 && $o == *"cannot be cleaned"* && $o == *"Press Enter to close this tab." ]] &&
    ok "영어 메뉴에서 ${r/#$HOME/~} 거부 → 메시지 후 Enter 대기, 종료 코드 2" || ng "영어 메뉴 거부 처리 다름(${r/#$HOME/~}, rc $rc)"
done

# 모은 영어 출력 전부: 한글 없음
hb=(); nf=0
for x in $EN/*.txt; do (( ++nf )); has_hangul "$(<$x)" && hb+=( ${x:t} ); done
(( $#hb == 0 && nf >= 30 )) && ok "영어 출력 ${nf}개 모두 한글 없음(픽스처의 한글 이름 제외)" || ng "영어 출력에 한글 섞임(파일 ${nf}개 중): $hb"

# 언어 결정 순서: IT2_LANG → 설정 파일($HOME/.config/iterm2-tools/lang) → macOS 언어(IT2_TEST_SYS_LANG) → en
# 가짜 HOME 을 쓰므로 실제 ~/.config 는 건드리지 않는다
real_cfg=$(/usr/bin/stat -f '%z|%m' ~/.config/iterm2-tools/lang 2>/dev/null)
LH=$W/home9; /bin/mkdir -p $LH/.config/iterm2-tools
lang_case() {  # $1 기대(en|kr), $2 IT2_LANG(-: 없음), $3 설정 파일 내용(-: 파일 없음), $4 IT2_TEST_SYS_LANG
  local got
  /bin/rm -f -- $LH/.config/iterm2-tools/lang
  [[ $3 != - ]] && print -r -- $3 > $LH/.config/iterm2-tools/lang
  got=$( unset IT2_LANG; [[ $2 != - ]] && export IT2_LANG=$2; HOME=$LH IT2_TEST_SYS_LANG=$4 $CLEAN -h 2>&1 )
  case $got in (Usage:*) got=en ;; (사용법:*) got=kr ;; (*) got="?" ;; esac
  same "언어 결정: IT2_LANG=$2 · 설정 파일=$3 · macOS=${4:-<빈 값>} → $1" $got $1
}
lang_case en en kr ko-KR
lang_case kr kr en en-US
lang_case kr - kr en-US
lang_case en - en ko-KR
lang_case kr - - ko-KR
lang_case kr - - ko
lang_case en - - en-US
lang_case en - - ''
same "실제 ~/.config/iterm2-tools/lang 은 그대로" "$(/usr/bin/stat -f '%z|%m' ~/.config/iterm2-tools/lang 2>/dev/null)" "$real_cfg"

print
print -r -- "결과: 통과 $pass / 실패 $fail / 생략 $skip"
(( fail == 0 ))
