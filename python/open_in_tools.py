#!/usr/bin/env python3
# iterm2-tools: open_in_tools.py
# iTerm2 우클릭 메뉴(어디서 우클릭해도 표시)에 "현재 폴더를 다른 도구로 열기" 항목을 추가한다.
#
# 설치 위치: ~/Library/Application Support/iTerm2/Scripts/AutoLaunch/open_in_tools.py
# 필요 조건: iTerm2 Python 런타임 (Scripts > Manage > Install Python Runtime)
# 호환성   : iTerm2 3.6.x 는 하위 메뉴(submenu)를 지원하지 않으므로 최상위 항목으로 등록한다.
#
# 주의(실측된 결함 수정): iterm2 라이브러리는 메뉴 RPC 를 "함수 이름(인자)" 로 구분한다.
#   항목마다 함수 이름이 같으면 한 항목을 눌러도 같은 이름의 콜백이 모두 실행된다
#   (예: VS Code 를 누르면 Finder 도 열림). 그래서 항목마다 이름이 다른 함수로 등록한다.
import asyncio
import os
import re
import subprocess

import iterm2


def find_code_cli():
    """VS Code CLI 경로. 없으면 None."""
    if os.environ.get("ITERM2_TOOLS_NO_CODE_CLI"):   # 테스트용: VS Code CLI 가 없는 Mac 흉내
        return None
    apps = ["/Applications/Visual Studio Code.app",
            os.path.expanduser("~/Applications/Visual Studio Code.app")]
    try:
        out = subprocess.run(["/usr/bin/mdfind", 'kMDItemCFBundleIdentifier == "com.microsoft.VSCode"'],
                             capture_output=True, text=True, timeout=5).stdout
        apps += [line for line in out.splitlines() if line]
    except Exception:
        pass
    for app in apps:
        cli = os.path.join(app, "Contents/Resources/app/bin/code")
        if os.access(cli, os.X_OK):
            return cli
    return None


CODE_CLI = find_code_cli()
VSCODE_ARGV = [CODE_CLI, "--"] if CODE_CLI else ["/usr/bin/open", "-b", "com.microsoft.VSCode", "--"]
FINDER_ARGV = ["/usr/bin/open", "--"]

APP = None  # main() 에서 설정


async def open_current_dir(session_id, argv_prefix):
    """우클릭한 세션의 현재 폴더를 argv_prefix 로 연다."""
    session = APP.get_session_by_id(session_id) if APP else None
    if session is None:
        return
    path = await session.async_get_variable("path")
    if not path or not os.path.isdir(path):
        return
    # 셸을 거치지 않는 exec — 경로에 공백·특수문자가 있어도 하나의 인자로 전달된다
    await asyncio.create_subprocess_exec(*argv_prefix, path)


# 항목마다 함수 이름이 달라야 한다(위 주의 참고). 이름이 곧 iTerm2 쪽 RPC 이름이다.
@iterm2.ContextMenuProviderRPC
async def iterm2_tools_open_in_vscode(session_id=iterm2.Reference("id")):
    await open_current_dir(session_id, VSCODE_ARGV)


@iterm2.ContextMenuProviderRPC
async def iterm2_tools_open_in_finder(session_id=iterm2.Reference("id")):
    await open_current_dir(session_id, FINDER_ARGV)


# 정리(clean)는 우클릭 즉시 실행하지 않고, 그 폴더에서 새 탭을 열어 iterm-clean --menu 를 실행한다.
CLEAN_BIN = os.path.expanduser("~/bin/iterm-clean")
SAFE_CMD_PATH = re.compile(r"[A-Za-z0-9_./-]+")


def clean_tab_profile(path):
    """정리용 새 탭 설정. 안전하게 넘길 수 없는 경로면 None."""
    # iTerm2 는 명령 문자열을 다시 해석하고 작업 폴더의 $$이름$$ 을 치환하므로, 그런 글자가 있으면 열지 않는다
    if not SAFE_CMD_PATH.fullmatch(CLEAN_BIN) or "$$" in path or "\\(" in path:
        return None
    lwop = iterm2.profile.LocalWriteOnlyProfile()
    lwop.set_use_custom_command(iterm2.profile.Profile.USE_CUSTOM_COMMAND_ENABLED)
    lwop.set_command(CLEAN_BIN + " --menu")            # 폴더는 명령 인자가 아니라 작업 폴더로 넘긴다
    lwop.set_initial_directory_mode(iterm2.profile.InitialWorkingDirectory.INITIAL_WORKING_DIRECTORY_CUSTOM)
    lwop.set_custom_directory(path)
    lwop.set_close_sessions_on_end(True)
    return lwop


# 정리(clean): 새 탭에서 드라이런 결과를 먼저 보여 주고(변경 없음), 사용자가 확인한 뒤
# yes 면 그 결과 그대로 휴지통으로, Enter 면 아무것도 바꾸지 않고 끝낸다.
@iterm2.ContextMenuProviderRPC
async def iterm2_tools_clean(session_id=iterm2.Reference("id")):
    session = APP.get_session_by_id(session_id) if APP else None
    if session is None or not os.access(CLEAN_BIN, os.X_OK):
        return
    path = await session.async_get_variable("path")
    if not path or not os.path.isdir(path):
        return
    window, _tab = APP.get_window_and_tab_for_session(session)
    lwop = clean_tab_profile(path)
    if window is None or lwop is None:
        return
    await window.async_create_tab(profile_customizations=lwop)


# ── 언어 선택 (iterm2-tools 공통 규칙 — zsh 실행 파일의 it2_lang 과 같은 순서. tests/test_lang.zsh 가 일치를 확인) ──
#   IT2_LANG(en|kr) → ~/.config/iterm2-tools/lang (install.sh --lang 이 저장) → macOS 언어 → en
#   IT2_TEST_SYS_LANG: 테스트용 macOS 언어 흉내(설정돼 있으면 defaults 대신 사용, 빈 값 = 언어 정보 없음)
#   메뉴 이름은 스크립트가 시작할 때 정해진다 → 언어를 바꾸면 Scripts → AutoLaunch → open_in_tools.py 재실행
def it2_lang():
    v = os.environ.get("IT2_LANG", "")
    if not v:
        try:
            with open(os.path.expanduser("~/.config/iterm2-tools/lang"), encoding="utf-8") as f:
                v = f.read().rstrip("\n")
        except OSError:
            v = ""
    if not v:
        if "IT2_TEST_SYS_LANG" in os.environ:
            v = os.environ["IT2_TEST_SYS_LANG"]
        else:
            try:
                out = subprocess.run(["/usr/bin/defaults", "read", "-g", "AppleLanguages"],
                                     capture_output=True, text=True, timeout=5).stdout.splitlines()
                v = re.sub(r"[^A-Za-z_-]", "", out[1]) if len(out) > 1 else ""
            except Exception:
                v = ""
    v = v.lower()
    return "kr" if v in ("kr", "ko") or v.startswith(("ko-", "ko_")) else "en"


# 메뉴 이름(언어별) — 고유 ID·RPC 이름은 언어와 무관하게 같다
TITLES = {
    "kr": {"vscode": "현재 폴더: VS Code에서 열기", "finder": "현재 폴더: Finder에서 열기", "clean": "현재 폴더: 정리(clean)…"},
    "en": {"vscode": "Current folder: Open in VS Code", "finder": "Current folder: Open in Finder", "clean": "Current folder: Clean…"},
}

# (메뉴 키, 고유 ID, 처리 함수)
TOOLS = [
    ("vscode", "local.iterm2-tools.open-in.vscode", iterm2_tools_open_in_vscode),
    ("finder", "local.iterm2-tools.open-in.finder", iterm2_tools_open_in_finder),
    ("clean",  "local.iterm2-tools.clean",          iterm2_tools_clean),
]


async def main(connection):
    global APP
    names = [fn.__name__ for _, _, fn in TOOLS]
    if len(set(names)) != len(names):
        raise RuntimeError(f"duplicate menu handler names: {names}")
    titles = TITLES[it2_lang()]
    APP = await iterm2.async_get_app(connection)
    for key, uid, fn in TOOLS:
        await fn.async_register(connection, display_name=titles[key], unique_identifier=uid)


if __name__ == "__main__":
    iterm2.run_forever(main)
