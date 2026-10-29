# AGENTS.md

Guide for AI agents (and people) working on **TidyWin**: a Windows 10/11 utility that sets up and looks after a PC from one window. A WPF panel (`scripts/TidyWin.ps1`) shows pages; each page is a PowerShell script that describes its options, and runs with the answers. Everything is Windows PowerShell 5.1, no build step, no dependencies.

Read this whole file before changing anything. The "Gotchas" section lists bugs that already happened here.

---

## 1. Project at a glance

| | |
|---|---|
| Run (users) | `irm androksi.github.io/tidywin/run \| iex` → asks for admin, opens the panel |
| Run (local copy) | `powershell -ExecutionPolicy Bypass -STA -File .\scripts\TidyWin.ps1` as Administrator |
| Language | **Windows PowerShell 5.1** (`powershell.exe`, Desktop edition) only. Not PowerShell 7 |
| UI | WPF from XAML inside `TidyWin.ps1`, dark/light from the Windows theme, Segoe Fluent Icons |
| Text in the app, code, comments, docs | **English** |
| Maintainer | Writes in **Portuguese (pt-BR)**: answer in Portuguese, keep the code and the UI in English |
| License | GPL-3.0 |
| Site | GitHub Pages, built by `web/build.sh` (see §8) |

Core promises (also in the README; never break them):

- **Nothing comes selected.** Only what the user turns on is changed, and **Review** lists it before **Apply**.
- **Everything can be undone**: an Undo page, `-Revert`, a Backup tab, or a backup/restore point taken first.
- **Untouched**: Windows Defender and Safe Browsing. Windows Update and the Firewall only change from their own pages.
- **Runs again safely**: every page can be applied more than once.
- **Leaves nothing behind**: downloaded scripts live in `%TEMP%\tidywin` and are deleted when the panel closes. State that must survive lives in `%ProgramData%\TidyWin` (§7).

---

## 2. Repository layout

```
AGENTS.md / CLAUDE.md        this guide (CLAUDE.md imports it)
README.md                    centered header, disclaimer, "What's inside" table, counts (apps, fonts)
assets/banner.png            panel screenshot used by the README (2347×1581, dark theme)
assets/logo.svg              the logo (also drawn in code by New-Logo in TidyWin.ps1)
docs/*.md                    one page per area: windows, apps, fonts, browsers, backup, drivers, reinstall
scripts/TidyWin.ps1          the panel (≈2,300 lines; XAML lives inside it)
scripts/<area>/<verb>-<noun>.ps1   one script per page (lowercase names)
web/launcher.ps1             the "run" shortcut (ASCII, no BOM)
web/build.sh, web/index.html GitHub Pages site
.github/workflows/lint.yml   BOM check + PSScriptAnalyzer (errors only)
.github/workflows/pages.yml  builds and publishes the site on every push to main
.editorconfig, .gitattributes   encodings and line endings (§9)
```

### Pages (sidebar) → scripts

The menu is `Get-Menu` in `scripts/TidyWin.ps1` (section 1). Every entry is `New-MenuEntry <group> <id> <icon> <name> <title> <desc> <points> <action> <steps> -Form`.

| Group | Page (id) | Script(s) | Notes |
|---|---|---|---|
| Set up | Windows (`windows`) | `windows/configure-windows.ps1` | Tabs: Privacy, Apps, Appearance, File Explorer, Screen, System, Power, Network, Misc. Restore point + log on the Desktop |
| Set up | Updates (`updates`) | `windows/configure-updates.ps1` | Normal / Security only (defer features 365 days) / Off (red "danger" warning); Drivers from Windows Update or not, apart from the mode |
| Set up | Apps (`apps`) | `apps/configure-apps.ps1` | 106 apps in category tabs, WinGet/Store/Windows feature; **Search** tab (`-Search`) |
| Set up | Fonts (`fonts`) | `fonts/install-fonts.ps1` | 19 fonts; `-Revert` undoes |
| Set up | Browsers (`browsers`) | `browsers/configure-chrome.ps1`, `configure-brave.ps1`, `configure-firefox.ps1` | One page, a switch per browser; each script describes its own part |
| Maintenance | Remove apps (`uninstall`) | `apps/uninstall-apps.ps1` | Official uninstallers + leftovers (install folder, user profile, registry keys, shortcuts; folders go to the Recycle Bin; a container left empty, like `.config` or `D:\Games`, goes too) |
| Maintenance | Disk space (`cleanup`) | `windows/clean-windows.ps1` | Measures each item while the page loads |
| Maintenance | Fix Windows (`repair`) | `windows/repair-windows.ps1` | DISM, sfc, disk check |
| Maintenance | Internet connection (`network-reset`) | `windows/reset-network.ps1` | Quick / Full; keeps the DNS |
| Maintenance | Firewall (`firewall`) | `windows/manage-firewall.ps1` | Tabs: Delete rules, Block an app, Networks, Backup |
| Back up | Create (`backup`) | `drivers/backup-drivers.ps1 -Export`, `apps/backup-apps.ps1 -Export`, `windows/backup-wifi.ps1 -Export` | Three steps, one page |
| Back up | Restore (`restore`) | same three with `-Import` (drivers → Wi-Fi → apps) | |
| Undo | Windows (`windows-revert`) | `windows/revert-configure-windows.ps1` | |
| Undo | Browsers (`browsers-revert`) | the three browser scripts with `-Revert` | |
| Undo | Fonts (`fonts-revert`) | `fonts/install-fonts.ps1 -Revert` | |

Every script also runs on its own in a console (arrow-key menus), without the panel.

---

## 3. How the panel and a page script talk

### Running a script
- `Get-StepCommand` writes a tiny runner `.ps1` to `%TEMP%` (UTF-8 in/out, `$ProgressPreference` off, TLS 1.2, downloads the script from `$Base/scripts/...` when there is no local copy) and runs it with `powershell.exe -NoProfile -ExecutionPolicy Bypass -File`.
- `TidyWinPanel.Runner` (C# in `TidyWin.ps1`) starts it with `TIDYWIN_PANEL=1`, redirected stdin/stdout/stderr, and queues the output lines. `Stop()` kills the whole tree (`taskkill /T /F`).
- A `DispatcherTimer` (70 ms) runs `Update-Run`: shows output, handles questions, finishes describes and searches.

### The page lifecycle
1. **Describe** — opening a page runs each step with `-Describe <file>`. The script reads the PC, writes the page as JSON to `<file>` and exits. Nothing changes.
2. **Form** — the panel builds the tabs and rows (`New-Form`, `New-FieldRow`). A page with no changes is read again when reopened after 30 s.
3. **Review** — `Get-FormChanges` lists what is picked, grouped by tab.
4. **Apply** — `Invoke-Apply` writes every field's value to `%TEMP%\tidywin-<id>-answers.json` and runs the steps with `-Answers <file>`. The log shows the script's output. Afterwards every page is read again (`Reset-Pages`).

### Page JSON (`Write-OptionsPage`)
```json
{ "tabs": ["Tab A", "Tab B"], "notes": ["yellow line at the top"], "fields": [ { "tab": "...", "id": "...", "kind": "...", ... } ] }
```

### Field kinds (`New-Field <tab> <id> <kind> <label> <desc> <default> @{ more }`)

| kind | What it is | Value in the answers |
|---|---|---|
| `toggle` | switch | `true`/`false` |
| `choice` | buttons side by side (`options = @(Opt value label, ...)`); clicking the chosen one unchooses it | value or `''` |
| `select` | combo box; `parent` + `optionsBy` = options that depend on another select | value or `''` |
| `checklist` | list of checkboxes with "Select all" per group; items: `value, label, note, warn, status, statusBrush, statusTip, group, flag` | array of values |
| `text` | text box; `validate = 'ipv4' \| 'ipv6' \| 'url'`, `optional`, `placeholder` | string |
| `path` | text + Browse; `pick = 'file'` (with `filter`) or a folder; `required` | string |
| `search` | box + button; the page script runs again with `-Search`/`-SearchOut` (Apps only today) | array of `source\|id\|name` |
| `header` | a title inside a tab | — |
| `info` | text only, optional `status = 'ok' \| 'warn' \| 'bad'` on the right | — |
| `guide` | explanation card: `items = @(@{ label; text; brush })`, optional `tip` (Firewall → Networks) | — |

Common properties: `desc` (grey), `warn` (yellow; red with `danger = $true`), `badge` (+ `badgeBrush`: `Accent`, `Ok`, `Warn`, `Err`, `Fg2`), `when` (one `@{ field; is }` or a list, all needed; compare as strings: `$true` → `'True'`), `indent`, `setting` (doesn't count as a change), `footer` (the one extra checkbox next to the buttons), `quiet` (Browsers: the per-browser switch).
The panel accepts a `when` list. The base console `Read-Options` only understands a single condition, and list support exists only in the `backup-*` copies. (`configure-windows.ps1` uses a list for the DNS adapter rows, so do not copy its console handling as the reference.)
Checklist item extras: `status` shows "• text" next to the name (green, or `statusBrush`); `statusTip` adds an ⓘ icon with a tooltip (first line bold); `flag`/`flagLabel`/`flagHint` add a second box per item (Apps: Interactive). A flagged checklist also sends `<id>.flags` (the checked flag values) next to `<id>`.
Browser scripts: toggles become one checklist (`Get-BrowserFields`); a toggle's `section` becomes its item group (e.g. "Extensions and passwords", "Right-click menu", "Main menu"). Sectioned items must come last and be contiguous.

### Questions while a script runs (stdout → panel → stdin)
- `Write-Host` lines carry color: `[char]1 + ConsoleColor + [char]2 + text`.
- A question is one line `##TIDYWIN {json}`; the answer comes back as one JSON line `{ "value": ... }` on stdin (`Request-Panel`). Types: `choose` (`question`, `options`, `default` → index), `checklist` (`items`, `search`, → `{ checked: [indexes] }`), `text`, `folder`, `file`, `wait` (`button`, `untilGone` = registry/file path; goes on by itself when it disappears), `keep` (keep a risky change or go back by itself).
- **Progress while describing** (non-blocking, no answer): `Write-Loading 'what is being read' <0-100>` → `##TIDYWIN {"type":"progress",...}`. The panel shows it under the loading ring. Call it before each slow read.

---

## 4. Anatomy of a page script

Copy an existing script of the same shape (`windows/reset-network.ps1`, `windows/configure-updates.ps1`, `windows/manage-firewall.ps1` are small, recent examples).

1. `#Requires -RunAsAdministrator`, then a header comment: one line saying what it does, **HOW TO RUN**, what each option does in plain words, where state is saved, **FILE LAYOUT**.
2. `param([string]$Describe, [string]$Answers)` (+ `-Revert`, `-Export`/`-Import`, `-Search`/`-SearchOut` where needed).
3. `#region PANEL` — copied between scripts but **not byte-identical**. Twelve scripts share the base copy (`reset-network.ps1` is a good reference): `Write-PanelHost`, `Request-Panel`, `Write-Loading`, the `Write-Host`/`Read-Host` overrides, `Opt`, `New-Field`, `Write-OptionsPage`, `Read-Options`, `Ask`. The three `backup-*` scripts add `when` lists and start a select on its default instead of always offering "Skip"; `manage-firewall.ps1` adds the console `guide` case. Change the shared parts in every script and keep those extras.
4. `#region 1. HELPERS` — `Write-Step`, `Choose` (arrow-key menu, numbered fallback), `Ask`, `Write-Result` (`[OK]`, `[WARNING]`, `[ERROR]`), then the page's own helpers. End with the PowerShell 7 guard (`if ($PSVersionTable.PSEdition -ne 'Desktop') { ...; return }`).
5. `#region 2. ...` — the changes, one function per action.
6. `#region 3. EXECUTION` — `Write-Loading` → read the PC → build `$fields` → `if ($Describe) { Write-OptionsPage $Describe $fields $notes; return }` → `$v = Read-Options $fields $Answers` → "Nothing was selected, so nothing was changed." when empty → backup/restore point when the change is risky → apply with `Write-Step`/`Write-Result` → "Done." and how to undo.

Rules for scripts:
- Never ask anything when `-Answers` is given; everything comes from the file.
- Every change has a way back, and the way back removes **only what TidyWin set** (mark things: the `TidyWin` firewall group, `TidyWin:` CSS markers, state files listing what was added).
- Read before writing: a value that is already like that is reported, not rewritten.
- Errors don't stop the page: one failed step logs `[ERROR]` and the next one runs (`Invoke-Step` in `configure-windows.ps1`).
- A backup that fails stops everything before any change (Firewall).

### Adding a page — checklist
1. Script in `scripts/<area>/<verb>-<noun>.ps1`, UTF-8 **with BOM**, structure above.
2. `New-MenuEntry` in `Get-Menu` (`TidyWin.ps1`): group, id (also the site name), Segoe Fluent icon code (`'E770'`), sidebar name, title, one-line description, 1-3 points, button text, `New-Step`s, `-Form`.
3. An undo path (Undo page, `-Revert`, or a Backup/restore option on the page).
4. Docs: the area's `docs/*.md`; README "What's inside" table and links; counts if they change (README, `docs/apps.md`, the menu points); README "Good to know" if a promise changes.
5. Test (§6). Refresh `assets/banner.png` when the sidebar changes visibly.

---

## 5. Writing the text people see

The audience is **not technical**. The maintainer pushes hard on this; follow it.

- Short, direct sentences in plain words. Say what happens to the user, not how: "Open to other devices, even on public Wi-Fi", not "Inbound allow rule, profile Any".
- Avoid semicolons and long chains of clauses. One idea per sentence.
- Labels are actions: "Turn off telemetry", "Delete every rule of these apps", "Remove "View Page Source"".
- Destructive actions say so plainly ("deleted for good") and say how to get it back ("A backup is saved first").
- Use color to point at what matters: `warn` for caution, `danger` for unsafe (red), `badge`+`badgeBrush` for the current state, `statusBrush` for counts. Explain a confusing choice with a `guide` card instead of long descriptions.
- Hide technical detail behind a tooltip (`statusTip`) rather than in the row.
- Log lines: `Write-Result 'OK' '...'`, past tense, then a grey line with the next step if any.

---

## 6. Testing

There are no unit tests. Test by running the real code against the real PC **read-only**, or against scratch copies. **Never apply changes to the maintainer's PC without asking.** Most scripts need admin; the agent session usually isn't elevated.

- **Parse** every changed `.ps1`:
  `[Management.Automation.Language.Parser]::ParseFile($path, [ref]$t, [ref]$e)` → `$e.Count` must be 0.
- **Describe** (read-only): copy the script to a scratch folder with `#Requires -RunAsAdministrator` removed, set `$env:TIDYWIN_PANEL = '1'`, run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File copy.ps1 -Describe out.json`, and inspect the JSON (fields, items, `when`, warnings).
- **Logic** that writes: extract functions with the AST (`FindAll` on `FunctionDefinitionAst`, dot-source `.Extent.Text`), point them at scratch targets (a scratch folder, `HKCU:\Software\TidyWinTest`), mock system cmdlets with functions of the same name, and assert the before/after. Delete scratch registry keys with `[Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree('Software\TidyWinTest', $false)`.
- **The panel**: copy `scripts/` to a scratch folder, strip `#Requires`, force the dark theme, replace `[void]$W.ShowDialog()` with a harness that uses a `DispatcherTimer` to open a page (`Show-Page`), set controls, call `Show-Review`, render `$W.Content` with `RenderTargetBitmap` (draw `$W.Background` first, it is not part of the content) and `$W.Close()`. This opens a real window for a few seconds; it doesn't apply anything.
- **External tools** (winget, Firefox's `omni.ja`): read their real output on this PC before parsing it.

---

## 7. Where things are saved

| Path | Written by | What |
|---|---|---|
| `%ProgramData%\TidyWin\updates.json` | Updates → Off | Service startup types before Off (Normal puts them back) |
| `%ProgramData%\TidyWin\doh-servers.json` | Windows → Network (DoH address) | DoH servers TidyWin added to Windows' table (null) |
| `%ProgramData%\TidyWin\firewall\*.wfw` | Firewall | `netsh advfirewall export` before every change, last 5 kept |
| `%ProgramData%\TidyWin\network-reset\` | Internet connection → Full | DNS and DoH backup |
| `%ProgramData%\TidyWin\uninstall-backup\<date>\` | Remove apps | Exported registry keys and tasks + `deleted.txt`; folders and shortcuts go to the Recycle Bin when they fit |
| `%ProgramData%\TidyWin\fonts.json` | Fonts | Fonts installed by TidyWin (for `-Revert`) |
| `%ProgramData%\TidyWin\start-unpinned.json` | Windows → Start ad shortcuts | What was unpinned |
| Desktop `TidyWin log <date>.txt` | Windows | Log of everything applied (no user or PC name) |
| `HKLM:\SOFTWARE\Policies\...` | Windows, browsers, Updates | Policies; Firefox `Preferences`/`ExtensionSettings` are JSON objects merged entry by entry (`pref:`/`ext:` names) |
| `<Firefox profile>\chrome\userChrome.css` | Firefox menus | Block between `/* TidyWin: hidden menu lines (start/end) */` |
| Firefox folder `defaults\pref\autoconfig.js` + `tidywin.cfg` | Firefox Reader View icon | AutoConfig, skipped if another exists |

Restore points: Windows, Remove apps, Fix Windows (`Checkpoint-Computer`; Windows allows one per 24 h).

---

## 8. Site and launcher

- `web/build.sh <url>` builds `_site/`: `scripts/` copied as-is, `index.html` (landing page, `__SHORT__` replaced), and `run` = `web/launcher.ps1` with `__NAME__`, `__SCRIPT__`, `__ARGS__`, `__BASE__` replaced. It fails if a placeholder is left.
- `pages.yml` runs it on every push to `main` and deploys to GitHub Pages. **A push to main publishes.** Never push without the maintainer asking.
- The launcher: from the user's terminal it prints the logo, starts a hidden elevated PowerShell that runs the same shortcut, waits for **that process** (not its output pipe; child processes inherit it), then prints "Cya!". The elevated copy downloads `scripts/TidyWin.ps1` to `%TEMP%\tidywin`, runs it with `Start-Process -RedirectStandardError` to a file, shows errors in a message box, and deletes the folder.
- The panel downloads each page script from `$Base/scripts/...` when there is no local copy next to it.

---

## 9. Encoding, style and CI

- `.ps1`: **UTF-8 with BOM** (Windows PowerShell 5.1 misreads accents and symbols like `·`, `→`, `…` without it), CRLF in checkouts, 4 spaces. The lint workflow fails on a missing BOM. Editor tools often save without one; add it before finishing:
  `[IO.File]::WriteAllText($path, [IO.File]::ReadAllText($path), (New-Object Text.UTF8Encoding $true))`
- `web/launcher.ps1`: **ASCII only, no BOM** (a BOM breaks `irm | iex`).
- `.md`, `.yml`, `.html`, `.svg`, `.sh`: UTF-8 without BOM, LF, 2 spaces (4 for `.sh`).
- Git normalizes to LF in the repository (`.gitattributes`); the "LF will be replaced by CRLF" warnings are expected.
- CI (`lint.yml`): BOM check + `Invoke-ScriptAnalyzer -Severity Error` on `scripts/`. It runs on `pwsh` and never executes a page, so a green lint says nothing about behavior.
- Code style: comment the *why* in plain English above functions and non-obvious lines, like the existing code; regions with `#region ==================== N. NAME ====================`; aligned tables in long `@(...)` lists; names like `Set-…`, `Get-…`, `Test-…`, `Remove-…`; no aliases in scripts.
- PowerShell 5.1 only: no `??`, `?:`, `?.`, `&&`/`||` pipeline chains, `ForEach-Object -Parallel`, `-AsHashtable`, `Join-String`.

---

## 10. Gotchas (all of these happened in this repo)

1. **Variables ignore case.** `$wu` is `$WU`, `$n` is `$N`, `$w` is `$W` (the panel window), `$p` is `$P`. A local named like a script variable silently overwrites it in that scope. Use distinct names (`$TabNetworks`, `$service`, `$rw`).
2. **`@()` on a `System.Collections.Generic.List[object]`** holding hashtables or CIM objects throws "Argument types do not match". Use `.ToArray()`.
3. **`"$var:"`** inside a string is parsed as a scope/drive qualifier. Write `"${var}:"`.
4. **`continue` inside `switch`** continues the switch, not the enclosing loop. Use `if/else`.
5. **`Sort-Object` is not stable** in 5.1. To move some items last, filter twice and concatenate.
6. **Native arguments with double quotes** are split by 5.1 (`git commit -m "...\"..."` breaks). Write the message to a file and use `git commit -F`.
7. **`Start-Process -PassThru`**: read `$p.Handle` right after starting, or `ExitCode` comes back empty.
8. **Waiting on a process's output pipe** waits for every child that inherited it. Wait for the process itself.
9. **`Get-NetFirewallPortFilter -All`** can return nothing; pipe the rules into it instead. `Get-NetFirewallApplicationFilter -All` works.
10. **`winget search`**: with `--source` there is no Source column; the Match column text is translated; East Asian characters take two columns (cut rows by display width); a cut ID ends in `…` and must be dropped. Output to a pipe is not truncated.
11. **Firefox**: the `Preferences` and `ExtensionSettings` policies are single JSON values; merge entries (`Set-PrefPolicy`, `Set-Extension`), never overwrite the whole value.
12. **WPF rendering for screenshots**: `RenderTargetBitmap` of `$W.Content` has no background; paint `$W.Background` first. Tooltips are popups; render the `ToolTip` itself.
13. **`$PROFILE`** is an automatic variable; don't use `$Profile` as a parameter name.
14. **Windows features** (.NET 3.5) download from Windows Update; they fail when the Updates page turned it Off (service disabled).

---

## 11. Git and commits

- Work on `main` (the maintainer's flow). Commit only when asked; **never push** unless asked (a push publishes the site).
- Conventional commits, lowercase: `feat(scope): …`, `fix(scope): …`, `docs(readme): …`, `style(panel): …`, `refactor(…)`. Scopes used: `panel`, `windows`, `updates`, `apps`, `fonts`, `browsers`, `firefox`, `firewall`, `backup`, `utils`, `readme`.
- Subject says what the user gets; the body (wrapped at ~72) says what changed and why. Add the agent's attribution trailer when the environment asks for one.
- Stage only the files of the change (`git add <paths>`), check `git status` after committing.
