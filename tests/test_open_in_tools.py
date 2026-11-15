"""
open_in_tools.py 회귀 테스트 (iTerm2 없이 실행)

iTerm2 연결만 가짜로 바꾸고, 메뉴 등록·RPC 디스패치는 iterm2 라이브러리의 실제 코드를 통과시킨다.
외부 프로그램 실행(asyncio.create_subprocess_exec)은 가로채서 '무엇을 실행하려 했는지'만 기록한다.

실행:  <iTerm2 런타임 python3> tests/test_open_in_tools.py [검사할 open_in_tools.py 경로]
판정:  메뉴 항목 하나를 누르면 그 항목의 도구 '하나만' 실행되어야 PASS.
"""
import sys
sys.dont_write_bytecode = True      # 대상 폴더(AutoLaunch 등)에 __pycache__ 를 남기지 않는다

import asyncio
import importlib.util
import json
import os
import re
import sys
import tempfile

os.environ["IT2_LANG"] = "kr"        # 기존 검사는 한국어 화면 기준(이 Mac 의 언어와 무관하게 고정). 언어별 검사는 check_languages()

import iterm2
import iterm2.api_pb2 as pb
import iterm2.capabilities
import iterm2.notifications as notifications
import iterm2.rpc

TARGET = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "python", "open_in_tools.py")
CWD = tempfile.mkdtemp(prefix="iterm2-tools-test-")
launched = []                       # 실행하려던 argv 기록
tabs = []                           # 새로 열려던 탭의 프로필 설정(dict)
CLEAN_BIN = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bin", "iterm-clean"))
registered = []                     # iTerm2 로 보낸 등록 요청 (표시이름, RPC 이름, 인자)


# ── iTerm2 쪽 가짜 ──────────────────────────────────────────
async def fake_notification_request(connection, subscribe, ntype, session, rpc_req, *a, **k):
    if rpc_req is not None:
        attrs = rpc_req.context_menu_attributes
        sub = attrs.submenu if "submenu" in attrs.DESCRIPTOR.fields_by_name else ""
        registered.append((attrs.display_name, rpc_req.name,
                           tuple(x.name for x in rpc_req.arguments), sub))
    msg = pb.ServerOriginatedMessage()
    msg.notification_response.status = pb.NotificationResponse.Status.Value("OK")
    return msg

async def fake_send_rpc_result(*a, **k):
    return None

class FakeSession:
    async def async_get_variable(self, name):
        return CWD if name == "path" else None

class FakeWindow:
    async def async_create_tab(self, profile=None, command=None, index=None, profile_customizations=None):
        tabs.append({k: json.loads(v) for k, v in profile_customizations.values.items()} if profile_customizations else {"command": command})   # 값은 JSON 문자열로 전달됨(iTerm2 가 디코드)
        return None

class FakeApp:
    def get_session_by_id(self, sid):
        return FakeSession() if sid == "S1" else None
    def get_window_and_tab_for_session(self, session):
        return FakeWindow(), None

async def fake_get_app(connection):
    return FakeApp()

async def fake_exec(*argv, **kw):
    launched.append(list(argv))
    class P:
        returncode = 0
        async def wait(self): return 0
    return P()

# 라이브러리 버전에 따라 함수를 모듈 경유(2.11) 또는 이름으로 직접 import(2.29+) 하므로 양쪽 모두 바꾼다
import iterm2.registration
for _mod in (iterm2.rpc, notifications, iterm2.registration):
    if hasattr(_mod, "async_notification_request"):
        _mod.async_notification_request = fake_notification_request
    if hasattr(_mod, "async_send_rpc_result"):
        _mod.async_send_rpc_result = fake_send_rpc_result
for _mod in (iterm2.capabilities, iterm2.registration):
    if hasattr(_mod, "check_supports_context_menu_provider"):
        _mod.check_supports_context_menu_provider = lambda c: None
iterm2.async_get_app = fake_get_app
iterm2.run_forever = lambda main: None          # 스크립트가 import 될 때 실제 연결하지 않도록
asyncio.create_subprocess_exec = fake_exec


class FakeConnection:
    iterm2_protocol_version = (1, 99)


def load_target():
    spec = importlib.util.spec_from_file_location("open_in_tools_under_test", TARGET)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


async def click(conn, rpc_name, arg_names):
    """iTerm2 가 메뉴 항목 클릭 시 보내는 것과 같은 RPC 알림을 만들어 라이브러리 디스패처에 넘긴다."""
    msg = pb.ServerOriginatedMessage()
    rpc = msg.notification.server_originated_rpc_notification.rpc
    rpc.name = rpc_name
    for n in arg_names:
        a = rpc.arguments.add()
        a.name = n
        a.json_value = json.dumps("S1")
    msg.notification.server_originated_rpc_notification.request_id = "r1"
    handlers, sub = notifications._get_notification_handlers(msg)
    for h in handlers:
        await h(conn, sub)
    await asyncio.sleep(0)
    return len(handlers)


async def run():
    mod = load_target()
    if hasattr(mod, "CLEAN_BIN"):
        mod.CLEAN_BIN = CLEAN_BIN        # 설치 전에도 패키지의 iterm-clean 으로 검사
    conn = FakeConnection()
    await mod.main(conn)

    print(f"대상: {os.path.relpath(TARGET)}")
    print("등록된 메뉴:")
    for disp, name, args, sub in registered:
        where = f"[{sub}] " if sub else ""
        print(f"  - {where}{disp!r:32} RPC={name}({','.join(args)})")

    names = [r[1] for r in registered]
    ok = True
    n_clean = sum(1 for n in names if "clean" in n)
    print(f"  정리 메뉴 항목 수: {n_clean}  {'✅' if n_clean == 1 else '❌ (1개여야 함)'}")
    ok &= n_clean == 1
    if len(set(names)) != len(names):
        print("  ❌ RPC 이름 중복 → 한 항목 클릭에 여러 도구가 실행됨")
        ok = False

    for disp, name, args, sub in registered:
        launched.clear(); tabs.clear()
        n = await click(conn, name, args)
        if name.endswith("_clean"):
            # 정리는 즉시 실행하지 않고, 그 폴더에서 확인용 새 탭을 하나 연다
            t = tabs[0] if len(tabs) == 1 else {}
            good = (n == 1 and not launched and t.get("Custom Command") == "Yes"
                    and t.get("Command") == f"{CLEAN_BIN} --menu"
                    and t.get("Custom Directory") == "Yes" and t.get("Working Directory") == CWD)
            print(f"  클릭 {disp!r:32} → 콜백 {n}개, 실행 {len(launched)}건, 새 탭 {len(tabs)}개 "
                  f"[{t.get('Command', '').replace(CLEAN_BIN, 'iterm-clean')} @ 우클릭한 폴더]  {'✅' if good else '❌'}")
            ok &= good
            ok &= await check_clean_tab(mod, conn, name, args, t)
            continue
        single = len(launched) == 1 and CWD in launched[0] and not tabs   # 정확히 1건, 우클릭한 세션의 폴더 대상
        print(f"  클릭 {disp!r:32} → 콜백 {n}개, 실행 {len(launched)}건 {launched_summary(launched)}  {'✅' if single else '❌'}")
        ok &= single
    print("결과:", "PASS" if ok else "FAIL")
    return ok


async def check_clean_tab(mod, conn, name, args, t):
    """새 탭이 실제로 실행할 명령을 그 폴더에서 돌려 본다(q 로 취소 → 아무것도 바꾸지 않음)."""
    import subprocess
    good = True
    if t:
        r = subprocess.run(t["Command"].split(" "), cwd=t["Working Directory"], input="q\n\n",
                           capture_output=True, text=True, timeout=30)
        started = r.returncode == 0 and "현재 폴더 정리" in r.stdout and "취소했습니다" in r.stdout
        started &= "드라이런" in r.stdout
        print(f"    └ 새 탭 명령을 그 폴더에서 실행(q 입력) → rc={r.returncode}  {'✅' if started else '❌'}")
        good &= started
    # 명령 문자열 재해석·$$치환 위험이 있는 경로는 탭을 열지 않아야 한다
    global CWD
    saved = CWD
    for bad in ("$$HOST$$", "a\\(b)"):
        CWD = tempfile.mkdtemp(prefix="it2-" + bad.replace("/", "_"))
        tabs.clear()
        await click(conn, name, args)
        refused = not tabs
        print(f"    └ 위험한 폴더 이름 {bad!r} → 새 탭 {len(tabs)}개  {'✅' if refused else '❌'}")
        good &= refused
        os.rmdir(CWD)
    CWD = saved
    return good


def launched_summary(items):
    out = []
    for argv in items:
        if argv[0].endswith("/code"):
            out.append("VS Code")
        elif argv[:3] == ["/usr/bin/open", "-b", "com.microsoft.VSCode"]:
            out.append("VS Code(open -b)")
        elif argv[:2] == ["/usr/bin/open", "-b"]:
            out.append(f"앱 {argv[2]}")
        elif argv[0] in ("/usr/bin/open", "open"):
            out.append("Finder")
        else:
            out.append(" ".join(os.path.basename(a) if i == 0 else a.replace(CWD, "{dir}")
                                for i, a in enumerate(argv[:3])))
    return "[" + ", ".join(out) + "]"


HANGUL = re.compile("[\uac00-\ud7a3]")
EXPECT_TITLES = {
    "kr": ["현재 폴더: VS Code에서 열기", "현재 폴더: Finder에서 열기", "현재 폴더: 정리(clean)…"],
    "en": ["Current folder: Open in VS Code", "Current folder: Open in Finder", "Current folder: Clean…"],
}
# (IT2_LANG, 저장된 설정 파일 내용(None=없음), macOS 언어 흉내) → 기대 언어 — tests/test_lang.zsh 의 표와 같다
LANG_CASES = [
    ("", None, "ko-KR", "kr"), ("", None, "ko", "kr"), ("", None, "en-US", "en"), ("", None, "", "en"),
    ("", None, "ja-JP", "en"), ("", "kr", "en-US", "kr"), ("", "en", "ko-KR", "en"),
    ("kr", "en", "en-US", "kr"), ("en", "kr", "ko-KR", "en"), ("ko_KR", None, "", "kr"),
    ("KO", None, "", "kr"), ("fr", None, "ko-KR", "en"),
]


async def check_languages():
    """메뉴 이름이 언어별로 정확하고(영어에 한글 없음) RPC 이름은 언어와 무관한지, 언어 선택 순서가 맞는지."""
    print("언어별 메뉴:")
    ok = True
    names = {}
    for lang in ("kr", "en"):
        os.environ["IT2_LANG"] = lang
        registered.clear()
        mod = load_target()
        await mod.main(FakeConnection())
        titles = [r[0] for r in registered]
        names[lang] = [r[1] for r in registered]
        good = titles == EXPECT_TITLES[lang] and (lang == "kr" or not any(HANGUL.search(t) for t in titles))
        print(f"  {lang}: {titles}  {'✅' if good else '❌ 기대 ' + repr(EXPECT_TITLES[lang])}")
        ok &= good
    same = names["kr"] == names["en"]
    print(f"  RPC 이름이 언어와 무관하게 같음  {'✅' if same else '❌'}")
    ok &= same

    print("언어 선택 순서 (IT2_LANG → ~/.config/iterm2-tools/lang → macOS 언어 → en):")
    saved = {k: os.environ.get(k) for k in ("IT2_LANG", "IT2_TEST_SYS_LANG", "HOME")}
    home = tempfile.mkdtemp(prefix="it2-lang-home-")
    bad = []
    try:
        os.environ["HOME"] = home
        cfg = os.path.join(home, ".config", "iterm2-tools", "lang")
        for env_lang, file_lang, sys_lang, want in LANG_CASES:
            os.environ["IT2_LANG"] = env_lang
            os.environ["IT2_TEST_SYS_LANG"] = sys_lang
            if file_lang is None:
                if os.path.exists(cfg):
                    os.remove(cfg)
            else:
                os.makedirs(os.path.dirname(cfg), exist_ok=True)
                with open(cfg, "w", encoding="utf-8") as f:
                    f.write(file_lang + "\n")
            got = mod.it2_lang()
            if got != want:
                bad.append((env_lang, file_lang, sys_lang, want, got))
    finally:
        for k, v in saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        import shutil
        shutil.rmtree(home, ignore_errors=True)
    print(f"  {len(LANG_CASES)}가지 경우  {'✅' if not bad else '❌ ' + repr(bad)}")
    ok &= not bad
    print("언어 검사 결과:", "PASS" if ok else "FAIL")
    return ok


async def run_all():
    ok = await run()
    ok &= await check_languages()       # 등록을 다시 하므로 클릭 검사(run) 뒤에 실행
    return ok


if __name__ == "__main__":
    sys.exit(0 if asyncio.run(run_all()) else 1)
