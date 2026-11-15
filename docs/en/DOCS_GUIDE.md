# Documentation rules

**English** | [한국어](../kr/DOCS_GUIDE.md)

This package keeps English and Korean documentation as **separate files** and maintains the two files as a pair.

## 1. Locations and pairs

| Location | Contents |
|---|---|
| `README.md` (package top level) | Landing page. Only language links and a one-line introduction (no body) |
| `docs/en/<name>.md` | English document |
| `docs/kr/<name>.md` | Korean document — paired with the file of the **same name** in `docs/en` |

- Do not keep a document in only one language. Create every new document in both languages.
- File names are in English (shared by both languages).
- Both languages ship with the package (they travel together when copied to another Mac).

## 2. Document header

Put a language-switch line right below the title. Bold the current language and link the other to the pair file.

```markdown
# Title

**English** | [한국어](../kr/<name>.md)
```

Korean documents use `[English](../en/<name>.md) | **한국어**`.

## 3. Rules that keep the languages aligned

The two documents are kept as **line-for-line translations**. `tests/test_docs.zsh` compares the structure below.

| Compared | Must match |
|---|---|
| Headings | Level (`#`, `##`, `###` …) and order, number before the heading (`2-1.` etc.) |
| Tables | Number of table rows in each section |
| Lists | Number of list items (`-`, `1.`) and indentation in each section |
| Code blocks | Number of blocks, language tag. Shell blocks (`sh` · `zsh` · `bash` · untagged): **command lines identical character for character once comments are removed** |

- Not compared: ordinary paragraphs, quote (`>`) paragraphs, and text inside tables and lists. Write explanations needed in one language only as an ordinary or quote paragraph.
- Inside shell code blocks, translate only `#` comments. Never change commands, options, paths or rule strings.
- Keep measured values, versions, counts (e.g. number of tests, speed) and "not verified" markers the same in both languages. When one side changes, change the other too.
- **On-screen text:** the executables have both English and Korean screens (language choice: manual section 2-5). Each document quotes **its own language's on-screen text exactly**. Example: the English document says `Current folder: Clean…`, the Korean one `현재 폴더: 정리(clean)…`. When on-screen text changes (`t '한국어' 'English'` in the executables), update that text in both documents.

## 4. Editing order

1. Edit the document in one language.
2. Edit the same place in the pair document (in the same commit / same task).
3. Check:
   ```sh
   zsh tests/test_docs.zsh
   ```
   It is also part of the full test run (`zsh install.sh test`).
4. On FAIL, read the printed difference (`-` = English, `+` = Korean) and fill in the side that is missing.

## 5. Adding a document

1. Create `docs/en/<name>.md` and `docs/kr/<name>.md` together.
2. Add the language-switch line from section 2.
3. Add links in both languages to the document list in the top-level `README.md`.
4. Check with `zsh tests/test_docs.zsh`.

## 6. On-screen text in the executables (English/Korean)

Each executable keeps both languages' text in one file and picks the language at run time (selection order: manual section 2-5).

| Files | How to write text |
|---|---|
| `bin/*`, `install.sh`, `uninstall.sh`, `lib/common.zsh`, `zsh/ib-selftest.zsh` | `t '한국어' 'English'` — keep the shared language-selection code at the top (the `# ── 언어 선택` block) identical character for character in every file |
| `zsh/iterm-buttons.zsh` (sourced into the shell) | `_ib_t '한국어' 'English'` — decides the language only at the first message, so shell startup stays fast |
| `python/open_in_tools.py` | Write menu names in both the `"kr"` and `"en"` lines of the `TITLES` table |

- Write new text in both languages from the start. Korean-only text fails the static check in `tests/test_lang.zsh` (Korean comments are fine).
- Keep these language-independent: the confirmation input `yes`, menu keys `1/2/3/q`, category names `cache/build/deps`, options, exit codes, `--print0` output, file markers (`# iterm2-tools:`), and the right-click menu's RPC names and unique IDs.
- When the shared language-selection code changes, change it in every file, and align Python's `it2_lang` and the buttons' `_ib_t` with the same rule (checked by the selection-order table in the tests).
- Pin the language in tests that compare on-screen text (`export IT2_LANG=kr`). Check English separately with `IT2_LANG=en`, and make sure English output has no Hangul.
- When on-screen text changes, also update that text in both language documents, following the on-screen text rule in section 3.
- Check:
  ```sh
  zsh tests/test_lang.zsh
  ```
  It is also part of the full test run (`zsh install.sh test`).
