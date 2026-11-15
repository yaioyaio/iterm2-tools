# iterm2-tools — right-click menus and click buttons for iTerm2

**English** | [한국어](../kr/README.md)

Adds the three features below to iTerm2 + zsh. Install only the ones you need.

> **Language:** every executable has English and Korean screens and picks one at run time (see 2-5). This document quotes the English screens.

| Feature | What it does | Ready to use | Requirements |
|---|---|---|---|
| **A. Right-click on a path** | Right-click a file or folder path printed in the terminal → `Open in VS Code` / `Show in Finder`. `file:line:col` jumps to that line | Right after install | None |
| **B. Right-click anywhere** | Right-click anywhere in the terminal → `Current folder: Open in VS Code` / `Current folder: Open in Finder` / `Current folder: Clean…` | After install, run the script once | iTerm2 3.4.0+, Python runtime, Python API allowed, Rosetta 2 (Apple Silicon) |
| **D. Folder clean** | Cleans caches, build outputs and dependency folders in the current folder (including subfolders). **It shows the dry-run result first** (no changes). After you check it, `yes` moves exactly that result to the Trash and Enter ends with no change. Runs in a new tab from the B menu, and as the command `iterm-clean` in any terminal | Right after install (`~/bin/iterm-clean`) | None (git protection works when git is present) |
| **C. Click buttons** | Draws icon buttons in terminal output; clicking one types or runs a command you registered | When iTerm2 3.7.0 or later is **running** | zsh, edit `~/.zshrc` |

---

## 0. Requirements (including other Macs)

| Item | Condition | Basis (measured) |
|---|---|---|
| macOS | **12 or later** (the installer stops on older versions) | The installer uses `plutil -extract … raw`, available from macOS 12 (`man plutil` HISTORY). The latest iTerm2 3.7.7 itself requires macOS 13 or later |
| CPU | Apple Silicon and Intel | Shell scripts and tests also PASS in x86_64 (Rosetta) mode |
| iTerm2 | A: 3.4.0+ recommended · **B: 3.4.0 or later** · **C: 3.7.0 or later** | B = API protocol 1.7 (since 3.4.0), C = custom button code (since 3.7.0) — compared in the release-tag sources |
| Rosetta 2 | **Required for B on Apple Silicon** | The iTerm2 Python runtime ships as x86_64 only (public manifest and installed copy checked). If missing: `softwareupdate --install-rosetta --agree-to-license` |
| Python API | On B's first run, answer `Enable Python API?` with **OK** | Off by default in new iTerm2 installs (`EnableAPIServer=NO`) |
| Extra software | None — only built-in macOS commands (`/bin`, `/usr/bin`). No Homebrew or Xcode needed | Every command used was checked |
| VS Code | Optional. Looked up in `/Applications`, `~/Applications`, then Spotlight; without the CLI it opens the app only (no line jump) | Tests PASS without the CLI |
| Permissions | Admin and Accessibility permissions **not needed** | — |
| Per-user differences | Home path (including spaces), user name, default profile name, relocated Scripts and DynamicProfiles folders, and the default profile's custom rules are **picked up automatically at install time** | Portability tests S1–S4 |

**Menu language:** iTerm2 menus follow the macOS language (there is no Korean translation, so a Korean system shows English). The menu positions are the same.

| This document | Japanese | German |
|---|---|---|
| Scripts → Manage → Install Python Runtime | スクリプト → 管理 → Pythonランタイムをインストール | Skripte → Verwalten → Python-Laufzeitumgebung installieren |

### Moving to another Mac

1. Copy the whole `iterm2-tools` folder (AirDrop, zip, USB, git — any of them).
2. On the receiving Mac, run it as **`zsh install.sh …`** — this works even if the execute bit was lost in the copy, and the quarantine flag on installed files is cleared automatically.
3. First run `zsh install.sh status` to check that Mac's conditions (macOS and iTerm2 versions, runtime, Rosetta, API).

---

## 1. Package contents

| File | Role | Installed to |
|---|---|---|
| `install.sh` | Install / status check / tests. Computes per-user values (home path, folder locations, default rules, profile GUID) at run time | — |
| `uninstall.sh` | Removes only the files this package installed (same path computation as install) | — |
| `lib/common.zsh` | Shared by install and uninstall: computes install paths from that Mac's iTerm2 settings | — |
| `bin/iterm-clean` | D's clean tool (dry-run, confirmation, move to Trash; rule table built in) | `~/bin/iterm-clean` |
| `bin/iterm-open` | A's launcher. Resolves the path (`~`, relative paths, `file://`, `:line:col`), then runs VS Code / Finder | `~/bin/iterm-open` |
| (generated) `dp-open-in.json` | A's Dynamic Profile. iTerm2's default Smart Selection rules + 1 path rule + 2 actions | `~/Library/Application Support/iTerm2/DynamicProfiles/` |
| `python/open_in_tools.py` | B's iTerm2 Python API script (context-menu provider) | `~/Library/Application Support/iTerm2/Scripts/AutoLaunch/` |
| `zsh/iterm-buttons.zsh` | C's zsh plugin (`ib_add`, `ib_bar`) | `~/.zsh/iterm2-tools/` |
| `zsh/ib-selftest.zsh` | C's click self-test | `~/.zsh/iterm2-tools/` |
| `tests/test_iterm_open.zsh` | A regression test (one launch command per action, injection blocked) | — |
| `tests/test_open_in_tools.py` | B regression test (one callback and one launch per menu item) — uses the iterm2 library's real dispatch | — |
| `tests/test_iterm_clean.zsh` | D regression test: builds fixtures for 12 languages/tools in a temp folder and checks judgment, dry-run, confirmation, Trash, git protection, refusals and menu mode, including English-screen checks (109 checks) | — |
| `tests/test_portability.zsh` | Portability test: reproduces "another Mac" conditions S1–S7 plus language (S8: English install, saving/switching with `--lang`, selection order) with a fake home and fake iTerm2 settings | — |
| `tests/test_lang.zsh` | Common language check: identical language-selection code in every executable, 12 selection-order cases, zero Hangul on English screens, no Hangul outside the translation function (static check) | — |
| (generated) `lang` | Screen language saved with `install.sh --lang en\|kr` (exists only when `--lang` is used) | `~/.config/iterm2-tools/lang` |
| `tests/test_docs.zsh` | Doc pair check: `docs/en` ↔ `docs/kr` file pairs, language-switch links, and matching structure (heading levels and numbers, table rows, lists, commands in code blocks) | — |
| `README.md` | Landing page: language choice (English / 한국어) | — |
| `docs/en/`, `docs/kr/` | Document bodies (English / Korean; files with the same name are a pair). Writing and maintenance rules: `DOCS_GUIDE.md` | — |

The `~/Library/Application Support/iTerm2/…` locations are defaults. If that Mac has a relocated Scripts folder (`UseCustomScriptsFolder`) or DynamicProfiles folder (`dynamicProfilesPath`), the installer **installs into the relocated folder**.

`install.sh` **does not modify** `~/.zshrc` or the iTerm2 settings file (plist).

---

## 2. Installation

### 2-1. Prepare — status check (changes nothing)

```sh
cd ~/iterm2-tools        # the folder where you put the package
zsh install.sh status
```

If you see the warning `Installed and running versions differ`, iTerm2 was updated but not restarted. You can still install A and B, but **restart iTerm2 when you finish your work** (see 5. Troubleshooting).

### 2-2. A. Right-click on a path

```sh
zsh install.sh path
```

1. From the iTerm2 menu bar, open a new tab/window with **Profiles → `Right-click tools`**.
   (This profile inherits every setting of your default profile and only adds the right-click actions.)
2. Print a path. Example: `ls -d ~/bin/iterm-open`
3. Right-click the printed path → **`Open in VS Code` / `Show in Finder`**.

> No restart or Settings change is needed. iTerm2 watches the DynamicProfiles folder and loads it right away.

### 2-3. B. Right-click anywhere

1. If there is no Python runtime: iTerm2 menu **Scripts → Manage → Install Python Runtime**.
   - It may **finish silently** with no window. It is done when `zsh install.sh status` shows `Python runtime present`.
2. Install (the same command reinstalls and updates):
   ```sh
   zsh install.sh anywhere
   ```
   A running older version is stopped automatically (so old code does not keep serving the menu).
3. Turn it on now: iTerm2 menu **Scripts → AutoLaunch → open_in_tools.py**.
   (It starts automatically from the next iTerm2 launch. Repeat this step after every install or update.)
4. Right-click **anywhere in the terminal → `Current folder: Open in VS Code` / `Current folder: Open in Finder` / `Current folder: Clean…`**.
   It appears in every window, regardless of profile.

### 2-4. C. Click buttons (when iTerm2 3.7 or later is running)

1. Install:
   ```sh
   zsh install.sh buttons
   ```
2. Self-test — click the star button and check that `✅ Success` appears:
   ```sh
   zsh ~/.zsh/iterm2-tools/ib-selftest.zsh
   ```
   If you get `❌`, the running iTerm2 is older than 3.7 → restart iTerm2 and try again.
3. Add to `~/.zshrc` **yourself**:
   ```zsh
   source ~/.zsh/iterm2-tools/iterm-buttons.zsh
   ib_add 1 hammer.fill 'make build'     # code (positive integer)  SF Symbol name  command
   ib_add 2 play.fill   'make run'
   # IB_MODE=run                         # to run immediately on click instead of the default (insert)
   ```
4. In a new shell, `ib_bar` → prints the button row.

### 2-5. Language (English / 한국어)

Every executable (installer, `iterm-clean`, `iterm-open`, right-click menus, buttons) has both English and Korean screens and picks the language at run time in this order.

| Order | Decided by | Example |
|---|---|---|
| 1 | Environment variable `IT2_LANG` (`en` / `kr`) | `IT2_LANG=en iterm-clean` |
| 2 | Saved setting `~/.config/iterm2-tools/lang` | Saved with `zsh install.sh --lang en status` |
| 3 | macOS language (first language in System Settings → General → Language & Region) | Korean → Korean |
| 4 | Anything else | English |

```sh
zsh install.sh --lang en path       # save English and install A (profile and right-click item names in English too)
zsh install.sh --lang kr status     # save Korean
zsh install.sh --lang auto status   # remove the saved value and follow the macOS language
```

- After changing the language, `iterm-clean`, `iterm-open` and the installer switch on their next run.
- A's profile and right-click item names change only after rerunning `zsh install.sh path` (the profile GUID is kept). B's menu names change only after rerunning **Scripts → AutoLaunch → open_in_tools.py**. The right-click menu and its clean tab are started by iTerm2 itself, so an `IT2_LANG` exported in `~/.zshrc` may not reach them — set their language with `--lang`.
- iTerm2's own menus (Scripts, Profiles etc.) and messages from macOS, git and `trash` are not changed by this package.
- Categories (`cache`/`build`/`deps`), the confirmation input `yes`, and menu keys `1`/`2`/`3`/`q` are the same in both languages.
- This document describes the English screens. For the Korean screens, see the Korean document.

### Install everything at once

```sh
zsh install.sh all
```

---

## 3. Usage summary

### A. Right-click on a path — recognized text
| Printed text | Action |
|---|---|
| `src/main.py`, `./a/b.txt`, `~/dev/x.js`, `../x/y`, `/abs/dir` | That file or folder |
| `main.py:12:3`, `app/x.ts:7` | That line and column in VS Code |
| `README.md` (file name with an extension) | That file |
| `error: foo.c:3: bad` | The `foo.c:3` inside the message |

- Relative paths are resolved against **that tab's current folder** (no shell integration needed).
- If the path does not exist, nothing opens; only a notice is shown.
- **⌘-click** on a path = the first action (Open in VS Code).
- Paths containing spaces are not recognized.

### B. Right-click anywhere
- Opens the right-clicked tab's current folder in VS Code / Finder.
- `Current folder: Clean…` does not delete anything right away. It opens a **new tab** in that folder and runs the D procedure below.

### D. Folder clean

**Procedure** — right-click `Current folder: Clean…` (= `iterm-clean --menu`)
1. Choose the scope: `1` cache + build (default, Enter) / `2` cache only / `3` everything (including dependencies) / `q` cancel
2. **Dry-run result** — per item: category, size and the reason it matched (e.g. `rust/target/ (Cargo.toml)`), the total, and skipped items with reasons. **Nothing is changed.**
3. After checking the result: **`yes`** = move **exactly** this dry-run list to the Trash / **Enter** (or any other input) = end without cleaning
4. Press Enter to close the tab

To see only the dry-run, press Enter at step 3; to clean right away, type `yes` at step 3 — one menu does both. Items move only when you type exactly `yes`. `no`, an empty line, `y`, `YES` or no input **cancels (changes nothing)**. Only the listed items are moved, to the Trash (not permanently deleted), and you can restore them from the Finder Trash.

**As a command** (works outside iTerm2 too)
```sh
iterm-clean                    # dry-run of the current folder (default — changes nothing). Same as -n / --dry-run
iterm-clean --menu             # dry-run result → after checking, yes cleans exactly that result, Enter ends
iterm-clean -c all ~/work/app  # dry-run including dependencies
iterm-clean --trash            # list → yes confirmation → Trash
iterm-clean --rules            # rule table
```

**Categories and rules** (full table: `iterm-clean --rules`)

| Category | Matched when | Examples |
|---|---|---|
| `cache` | The name alone is a sure cache or OS leftover | `__pycache__` `.pytest_cache` `.mypy_cache` `.ruff_cache` `.tox` `*.egg-info` `*.pyc` (only when the source `.py` is next to it) `.next` `.nuxt` `.svelte-kit` `.turbo` `.parcel-cache` `*.tsbuildinfo` `.kotlin` `cmake-build-*` `DerivedData` `.zig-cache` `.DS_Store` |
| `build` | **Only when a build file is in the same folder** | `target`+`Cargo.toml`/`pom.xml`/`build.sbt` · `build`+`build.gradle(.kts)`/`CMakeLists.txt`/`pubspec.yaml`/`setup.py`/`pyproject.toml` · `dist`+`package.json`/`pyproject.toml` · `bin`·`obj`+`*.csproj` · `.build`+`Package.swift` · `.dart_tool`+`pubspec.yaml` · `_build`+`mix.exs` · `.gradle`·`.stack-work`·`dist-newstyle`·`zig-out`·`.angular`·`coverage` · `*.tsbuildinfo` (removed whether you pick cache or build) |
| `deps` | Installed dependencies (reinstall after removal) — excluded by default | `node_modules` `bower_components` `.pnpm-store` · `.venv`/`venv`/`env` (with `pyvenv.cfg` inside) · `vendor`+`composer.json` · `Pods`+`Podfile` · `deps`+`mix.exs` |

**Principle: clean removes everything that can be regenerated, but never leaves a half-clean state that will not rebuild.**

**TypeScript `*.tsbuildinfo` — why it is removed in every selection (measured with tsc 5.6.3)**

| Removed | Running `tsc` / `tsc -b` again |
|---|---|
| tsbuildinfo only | Fine — full rebuild (just slower once) |
| dist only (tsbuildinfo kept) | **Output files are not regenerated** — the "already built" record is still there |
| Both | Fine |

So tsbuildinfo is removed whether you pick cache or build (it is always removed together with dist). Projects that move it with `tsBuildInfoFile` in `tsconfig.json` cannot be found, so the list shows a **warning** — delete that file yourself too, or build with `tsc -b --force`.

**Other rules that prevent half-clean states**
- A `*.pyc` outside `__pycache__` is removed only when a `.py` with the same name is next to it (a `.pyc` without its `.py` may be the module's only copy).
- `CMakeFiles` is removed only inside `build/` or `cmake-build-*` (together with that folder). An in-source build could be left half-clean with `CMakeCache.txt` and `Makefile` remaining; cmake was not available to measure this, so it is not removed.
- `*.egg-info` is removed as a standard Python clean target (`rm -rf build dist *.egg-info`). However, old-style editable installs (`setup.py develop`) refer to this folder, so you may need to rerun `pip install -e .` after cleaning — **not measured**, because setuptools could not be prepared offline.

**Adding rules** — not every language is covered (e.g. OCaml `_build`, Scala `.bloop`, Ruby `vendor/bundle`, Unity `Library`, IntelliJ `out` are not included). Add one line to `RULES` in `bin/iterm-clean` and reinstall with `zsh install.sh path` (or `anywhere`).
```zsh
#  category | d=folder f=file | name (glob) | evidence (empty = name only, comma = any one, in:X = X inside the folder)
  'build|d|_build|dune-project'          # e.g. OCaml (dune)
  'deps|d|vendor|Gemfile'                # e.g. Ruby — caution: a Rails vendor/ may be committed
```
Always give common names an evidence file, and check with `zsh tests/test_iterm_clean.zsh` after adding.

**Safety measures**
- Common names such as `build`, `dist`, `target`, `bin`, `vendor` and `env` are not targets without an evidence file (protects source folders). Go's `vendor` (committed) is not a target.
- Inside a git repository, **items that contain tracked files are skipped**. On a Mac without git (developer tools), items inside a repository cannot be checked, so **all of them are skipped**.
- Folders that contain their own `.git` repository are skipped (except dependencies).
- Never descends into `.git`, `.hg`, `.svn`, `*.app` or `*.framework`. Symbolic links are neither followed nor removed. Never crosses to another disk.
- Refused start folders: `/`, the home folder itself, `~/Library`, `~/.hidden-folders`, `/System`, `/Library`, `/Applications`, `/usr`, `/opt` and so on.
- `.env*`, `.idea`, `.vscode` and lock files (`package-lock.json` etc.) match no rule, and file **contents are never read** (only names are checked).
- Moving to the Trash: `/usr/bin/trash` (`man trash`: since macOS 15.0, handles duplicate names). On macOS 14 and earlier, items are moved straight to `~/.Trash` (same disk only; name collisions become `name 2` …) — this fallback was verified only with a test-only folder, **not verified** on a real macOS 14 or earlier.
- In menu mode, a refusal or error shows the message and waits for Enter before closing the tab.

### C. Click buttons
| Mode | On click |
|---|---|
| `IB_MODE=insert` (default) | Puts the command on the input line (replacing what you were typing). You press Enter |
| `IB_MODE=run` | Keeps what you were typing and runs immediately |

- When you run another command, existing buttons turn **gray (inactive)** — intended, so click signals never reach a running program (vim etc.). To use them again, run `ib_bar`.

---

## 4. Installation checklist

```sh
zsh install.sh status
```

| Check | Expected result |
|---|---|
| A | `Installed ~/bin/iterm-open`, `Installed …/dp-open-in.json`, `Profile file format OK` |
| B | `Installed …/open_in_tools.py`, `Python runtime present`, `open_in_tools.py running: 1` |
| C | `Installed …/iterm-buttons.zsh`, `Button setup found in .zshrc` |

Regression tests (no apps are actually opened) — all must be `PASS`:
```sh
zsh install.sh test
```

Check A's launcher alone (prints the command without opening anything):
```sh
IO_DRYRUN=1 ~/bin/iterm-open vscode "$PWD" README.md
```

---

## 5. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| The menu appears only on paths, not on empty space | **By design**, A works only on text that matches the rule | Install B to use it anywhere |
| In B, `Current folder: Open in VS Code` **also opens Finder** | Old-version defect: both menus were registered under the same RPC name (`handler`), and the iterm2 library ran every callback with that name on one click | Update with `zsh install.sh anywhere` → rerun **Scripts → AutoLaunch → open_in_tools.py** → confirm `zsh install.sh test` PASS |
| Warning `The running script is older than the installed file` | Only the file changed; the old version is still running | Rerun **Scripts → AutoLaunch → open_in_tools.py** (or rerun `zsh install.sh anywhere`) |
| (Other Mac) B items missing and `status` shows `… Rosetta 2 is missing → B will not run.` | Apple Silicon without Rosetta 2 to run the Intel-only Python runtime | Run `softwareupdate --install-rosetta --agree-to-license` in a terminal, then **Scripts → AutoLaunch → open_in_tools.py** |
| (Other Mac) B items missing and `status` shows `Python API off` | New iTerm2 default. `Enable Python API?` was cancelled on first run, or the dialog never appeared | Rerun **Scripts → AutoLaunch → open_in_tools.py** and press **OK** in the dialog. If it does not appear again, turn on iTerm2 Settings → General → Magic tab → *Enable Python API* (location checked in the 3.6.9 settings-screen definition file) |
| (Other Mac) Install stops with `macOS 12 or later is required` | macOS 11 or earlier | Update macOS |
| (Other Mac) `B requires iTerm2 3.4.0 or later` | Old iTerm2 | Update iTerm2 |
| (Other Mac) `./install.sh` fails with `Permission denied` | The execute bit was lost in the copy | Run it as `zsh install.sh …` |
| B items not in the menu | The script is not running | If `status` shows `open_in_tools.py running: 0`, use **Scripts → AutoLaunch → open_in_tools.py**. If still missing, check errors in **Scripts → Script Console** |
| Nothing happens after Install Python Runtime | The install finished without any display | Confirm `Python runtime present` with `zsh install.sh status` |
| `Right-click tools` missing from the Profiles menu | If **another file** in the DynamicProfiles folder is broken, iTerm2 ignores all changes | Check each file: `plutil -convert xml1 -o /dev/null <file>` |
| C buttons not shown, or self-test `❌` | The running iTerm2 is older than 3.7 (3.6.9 has no custom buttons) | Quit iTerm2 completely and restart |
| `Installed and running versions differ` / Settings will not open, or other odd behavior | iTerm2 was updated while running, so the running binary and the files on disk differ | Finish your work, then restart iTerm2 |
| VS Code does not jump to the line | The VS Code CLI was not found, so only the app was opened | Check that VS Code is in `/Applications` or `~/Applications` |
| The clean tab shows `The whole home folder cannot be cleaned` | The right-clicked tab's current folder is `~` | `cd` into a project folder and right-click again |
| The clean list skips items with `inside a git repository, but git is not available to check what is tracked` | A Mac without developer tools (git) | Install with `xcode-select --install`, or leave it (the safe behavior) |
| A folder you expected is not in the clean list | No evidence file (e.g. no build file next to `build`), tracked by git, or `deps` not selected | Check the rules with `iterm-clean --rules`; for dependencies use `-c all` (menu `3`) |
| Clicking `Current folder: Clean…` opens no tab | `~/bin/iterm-clean` not installed, or the folder name contains `$$` · `\(` (characters iTerm2 interprets again, so no tab is opened) | `zsh install.sh anywhere` / run `iterm-clean --trash` directly in a terminal |
| The screen is not in the language you want | The `IT2_LANG` environment variable or the saved setting takes priority over the macOS language | Check the language and its source on the first line of `zsh install.sh status` → `zsh install.sh --lang en status` (or `kr`, `auto`) |
| `…/bin/iterm-open already exists and is not from this package` | Protection for another file with the same name | Check its contents, clean it up yourself, and install again |

---

## 6. Security design

- A: iTerm2 shell-escapes the matched text before passing it. `iterm-open` handles arguments only in quotes, never `eval`s them, and the launch targets are fixed to the VS Code CLI / `open`. (Tested that `$(…)` injection attempts are not executed.)
- B: Runs via `exec` without a shell — special characters in paths are not interpreted as commands.
- D: Dry-run by default; items move only after typing exactly `yes`, and **only to the Trash** (never permanently deleted). After confirmation it does not search again; it moves only the list it showed. Paths are always passed as absolute paths — measured that `/usr/bin/trash` treats `--` as a **file name**, not as the end of options, so `--` is not used. The right-click menu passes the folder as the new tab's working directory, not as a command argument.
- C: Buttons can be drawn by any output, so the only value taken from a click is a **numeric code**, and what runs is looked up only in the table registered with `ib_add`.
- Permissions: no Accessibility or admin permissions required.

---

## 7. Uninstall

```sh
cd ~/iterm2-tools && zsh uninstall.sh
```
- Removes only the files this package installed (other files are skipped). The saved language setting (`~/.config/iterm2-tools/lang`) is removed too.
- Remove the C lines you added to `~/.zshrc` yourself.
- B menu items disappear at the next iTerm2 restart.

---

## 8. Verification history

| Item | Method | Result |
|---|---|---|
| Install, reinstall, uninstall | In a fake home folder containing spaces: `install.sh all` → rerun `path` → `uninstall.sh` | Passed; profile GUID kept on reinstall; no leftover files after uninstall |
| A path rule | 10 cases with the same ICU regex engine as iTerm2 | Passed |
| A launch path | Same escaping as iTerm2 + run via `/bin/sh -c` (dry-run) | Passed, injection not executed |
| A real right-click | Confirmed by the user on iTerm2 3.6.9 | Menu shown and working |
| B script | Syntax check with the iTerm2 runtime's Python 3.7/3.8/3.10/3.14 | Passed |
| B menu click → launched tool | `tests/test_open_in_tools.py`: reproduces each menu click with the iterm2 library's real registration and dispatch code (Python 3.10 · 3.14) | Old version FAIL reproduced (one click launched VS Code + Finder, 2 launches) → PASS after the fix (1 per item) |
| A action → launch command | `tests/test_iterm_open.zsh` (7 cases, paths with spaces) | PASS (1 per action, injection not executed) |
| B real right-click | Confirmed by the user on iTerm2 3.6.9 | Menu shown everywhere. After the fix, `Open in VS Code` → only VS Code, `Open in Finder` → only Finder |
| C plugin | Click bytes injected in a pty (insert/run modes, unregistered code) | Passed |
| C real click | — | **Not verified**. 3.6.9 has no buttons; check with `ib-selftest.zsh` after restarting into 3.7 or later |
| Portability S1 new Mac | Fake home with no settings file | PASS (installed in default locations, 12 rules, 0 leftovers after uninstall) |
| Portability S2 relocated folders | `dynamicProfilesPath` and `CustomScriptsFolder` (with spaces) set | PASS (installed to and removed from the relocated folders) |
| Portability S3 missing custom folder | `CustomScriptsFolder` points to a nonexistent path | PASS (uses the default location, like iTerm2) |
| Portability S4 custom rules | One custom rule in the default profile | PASS (rule inherited, 2 rules) |
| Portability S5 Python API | Off / on | PASS (notice shown when off) |
| Portability S6 version conditions | Simulated macOS 11.7/12.0, iTerm2 3.3.12/3.4.0/3.6.11/3.7.7 | PASS (stop / continue / warn thresholds exact) |
| Portability S7 Rosetta | Apple Silicon + Intel-only runtime, with/without Rosetta | PASS (warning + install command when missing) |
| Intel (x86_64) run | A and portability tests run with `arch -x86_64` | PASS |
| Mac without the VS Code CLI | Simulated no CLI in the A and B tests | PASS (1 launch via `open -b com.microsoft.VSCode`) |
| Moved package | `zsh install.sh` with quarantine flag set and execute bit removed | PASS (installs and runs normally) |
| **Real other macOS (Parallels VM)** | macOS 26.6.2 / Apple Silicon / no Xcode, CLT, Homebrew, Rosetta or VS Code / iTerm2 placed in `~/Applications`. As a regular user with a temporary HOME: `zsh install.sh test` → `all` → `status` → `uninstall.sh` | Every test that ran PASSed. The B unit test was **skipped** for lack of Rosetta (on that Mac B itself cannot run — the installer detects this and shows the install command). Checked install locations, profile format (12 rules), the no-VS Code fallback, and 0 leftovers after uninstall |
| Test defects found and fixed on the VM | — | ① A expectation assumed VS Code was present ② portability test looked for iTerm2 only in `/Applications` ③ on a Mac without Rosetta, ran the Intel-only Python and picked runtimes by string order ④ S7 assumed Rosetta was present. No product code defects |
| D judgment (per language) | `tests/test_iterm_clean.zsh` [1]: Python · Rust · Maven · Gradle · Node · .NET · Swift · Flutter · Elixir · PHP · iOS · CMake fixtures + `bin/build/target/dist/vendor/env/venv/Pods` without evidence, `.env`, an app bundle | PASS — candidate list per category exactly as expected, 0 false positives |
| D dry-run and confirmation | [2][3]: tree compared before/after (name, size, mtime, permissions); inputs `no`, empty line, `y`, `YES`, EOF | PASS — no change |
| D move to Trash | [4]: `yes` → 27 candidates moved; 4 same-named `__pycache__` kept without collision; names with spaces, Korean, leading `-`, newlines; symbolic links, `.env` and sources preserved / [8]: 1 item through the real `/usr/bin/trash` | PASS |
| D git protection | [5]: tracked `dist/` skipped, `build/` with an inner `.git` skipped, Mac without git simulated | PASS |
| D TypeScript | With tsc 5.6.3, in incremental and composite (`-b`) projects: removed tsbuildinfo only / dist only / both, then rebuilt · cleaned with `iterm-clean -c build`, then rebuilt | Removing only dist did not re-emit (defect confirmed) → fixed by giving it the same category; dist and tsbuildinfo now move together, and the rebuild regenerates `dist/a.js` |
| D clean menu (dry-run step) | [7-2]: after the dry-run, Enter, `no`, EOF → no change, result and "no change" notice shown; `yes` → exactly the 27 items seen in the dry-run moved, everything outside the list kept; `--trash` + `--dry-run` refused | PASS |
| D refusals and menu | [6][7]: `/`, `~`, `~/Library`, `/usr`, `/Applications` refused; menu `q` / `no` / `2+yes`; menu refused in the home folder | PASS |
| D speed | Dry-run of a synthetic project with 100,000 files (`target` 40k · `node_modules` 40k · `.venv` 20k, 300 `__pycache__`) | 1.6 s, exactly 303 candidates |
| D test self-check | Ran against 4 copies with planted defects (evidence rule removed, confirmation ignored, git protection removed, links followed) | All 4 caught as FAIL (links: double defense, caught when both were removed) |
| B clean menu | `tests/test_open_in_tools.py`: exactly one clean item registered; click → 0 launches and 1 new tab (command `iterm-clean --menu`, working directory = right-clicked folder); that command actually run and its start confirmed; folders with `$$` · `\(` open no tab — iterm2 2.11 · 2.30 | PASS |
| Doc pairs | `tests/test_docs.zsh`: compares the structure of the English and Korean documents; run against copies with only one side changed (section removed, command changed, table row added, pair file missing, link missing) | PASS — every changed copy caught as FAIL |
| Language selection | `tests/test_lang.zsh` [1][2] + `tests/test_open_in_tools.py`: the shared language-selection code is identical character for character in the 4 zsh executables; 12 selection-order cases (IT2_LANG > saved setting > macOS language > English) run against the 4 zsh executables, the button plugin and the Python menu (fake HOME) | PASS |
| English screens | Every path run with `IT2_LANG=en`: D [9] 51 checks (help, rules, dry-run, skip reasons, confirmation cancels on `no`/empty line/`YES`/`y`/EOF, `yes` moves, failures, refusals), install/status/uninstall (S8a), B menu names, `iterm-open`, `ib-selftest`, `ib_add` | PASS — zero Hangul in English output (except Korean fixture names); profile name and right-click items in English too |
| Language-independent behavior | Same folder run in Korean and English, then compared | PASS — `--print0` list byte-identical, same exit codes, only `yes` proceeds in both languages, same RPC names and unique IDs, profile GUID kept when reinstalling in another language |
| Missing-translation static check | `tests/test_lang.zsh` [4]: non-comment Hangul in product code outside the translation functions (`t`, `_ib_t`) or per-language tables | PASS — 0 places |
| Language test self-check | Copies with planted defects: an English message turned Korean (2 in iterm-clean, installer, iterm-open, ib-selftest), English mode accepting `y`, shared block changed, plugin language detection broken | All caught as FAIL |
| Full tests · 3 language environments | `zsh install.sh test` run with the default (this Mac: Korean), `IT2_LANG=en`, and simulated English macOS · B on iterm2 2.11 and 2.30, Python 3.7 · 3.10 · 3.14 | All PASS (existing checks pinned to Korean, independent of the environment) |
| Not verified | — | D's real iTerm2 right-click → new tab must be confirmed by the user (in iTerm2 after install). Real right-clicks and button clicks in the iTerm2 GUI were not done on the VM (on this Mac, A and B were confirmed by the user). The English menu and profile names were not checked on a real iTerm2 screen (tests only) |
