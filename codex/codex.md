# Codex History Manual

## Purpose
This document serves as the authoritative history book for the agent to learn the project and the instructor. Every step I take with the instructor should be guided by it, and it should become the first source I study before fulfilling new demands.

## Goal
The final goal for this document is to make the agent understand the behavior style, questioning style and demand style the instructor, so that it can truely and fully understand the project's development direction which is hidden in the mind of the instructor and so that the agent can help efficiently automize the procedures to the most.

## Reference Material
- `prj.md` for requirements, priorities, and the instructor's expectations for the exact project.
- The current repository structure (`config/`, `modules/`, `scripts/`, etc.) to understand how features are wired together.
- This manual (`codex.md`) itself for the process rhythm and a record of past decisions.

## Instructor Working Style
The instructor expects me to follow the rhythm: **Clarify → Plan → Solve → Verify → Integrate → Reflect**.
1. **Clarify** every request by summarizing what is being asked and identifying success criteria.
2. **Plan** how to approach the work, breaking it into manageable steps before touching code.
3. **Solve** the problem with careful coding, documentation, and testing.
4. **Verify** the result (manually or with automated checks) to confirm it meets the requirements.
5. **Integrate** the change cleanly into the repository, updating related files or docs.
6. **Reflect** by describing what changed, why, and any remaining risks.

Every conversation should begin with a mental reminder of this cycle, ensuring consistent style across tasks.

## Logging Discipline
Each demand from the instructor must leave a visible trace in this manual. Append a block that follows `codex/log.template` exactly—copy the keys and sections, providing context, options, decision, result, and lessons. The template lives at `codex/log.template`; use it as the pattern for every entry. Leave the previously recorded entries intact so the history remains cumulative.

## History Entries
This section collects the log entries recorded after each demand.

---
id: demand-001
date: 2025-11-27T13:07:51Z
type: refactor
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
The instructor asked Codex to reorganize the prompts to always reflect the instructor's working style and to replace `trae.md` with a new `codex.md` history book that guides the workflow (clarify → plan → solve → verify → integrate → reflect). The new history log must use `codex/log.template` for every demand.

## Options
1. Keep the existing Trae documents and live prompts, leaving no trace.
2. Build a dedicated `codex.md` manual, rewrite the prompt so the style is front of mind, and start logging each demand here.

## Decision
Selected option 2: create `codex.md`, refresh the prompt guidance, and start capturing history entries.

## Result
- Drafted `codex.md` as the central history manual with process guidance and the first log entry.
- Prepared to update the prompt files to reference `codex.md`, `prj.md`, and the working style steps.
- Added this log entry as the first record.

## Lessons
History logging with the template ensures future demands build upon a clear chronological record.

---
id: demand-002
date: 2025-11-27T13:18:27Z
type: refactor
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
The instructor asked Codex to condense `prj.md`, removing trivial logs/history sections so the document stays focused on actionable requirements and architecture.

## Options
1. Leave the historical status/log sections intact, even though they are redundant.
2. Remove the project status/history portion and keep the rest of the requirements/architecture content.

## Decision
Chosen option 2: remove the obsolete status/log section so `prj.md` remains concise and feature-oriented.

## Result
- Deleted the “Project Status” section and renumbered the next sections accordingly.
- Ensured `prj.md` now flows directly from requirements to project management without extra logs.

## Lessons
Documentation should highlight current priorities; history logs belong in `codex.md` rather than `prj.md` to avoid clutter.

---
id: demand-003
date: 2025-11-27T13:26:29Z
type: feature
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
The instructor wants to run the tool on fresh Ubuntu 22/24 installs, dynamically add modules, and prefer a numeric selection flow (e.g., entering `1,3,4`) after seeing the available modules.

## Options
1. Require users to memorize module names and keep the CLI strictly argument-based.
2. Add an interactive `--select-modules` flag that lists module scripts by number and builds the target sequence from the selected numbers.

## Decision
Implemented option 2: introduce an interactive selection mode that enumerates the module scripts and supports number-based selection for running specific modules.

## Result
- Added helper functions in `main.sh` to enumerate module scripts and capture numeric selections.
- Introduced the `--select-modules` flag and wired its output into the module execution pipeline.
- Documented the new option in `prj.md` and added a usage example showing how to invoke the interactive selector.

## Lessons
Interactive selection keeps the workflow fresh on new systems and supports flexible module ordering without needing to remember module names.

---
id: demand-004
date: 2025-11-27T13:30:41Z
type: experiment
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked to try the second suggestion, which proposed a quick automated smoke check (e.g., `bash main.sh -t --modules init`) to validate fresh Ubuntu boots before executing full automation.

## Options
1. Keep the smoke check as an informal instruction in the reply and do not change the code.
2. Implement a dedicated `--dry-run` flag or smoke-check script.

## Decision
Option 1 for now: provide the smoke-check command as a recommended action without coding a new flag, since it already aligns with existing `-t` and module selection semantics.

## Result
- Logged the intention to try the smoke check via `bash main.sh -t --modules init` before running other modules.
- Left code unchanged; the existing `-t` flag already triggers a safe configuration loading mode suitable for smoke testing.

## Lessons
When a quick verification is needed on a fresh system, reusing `-t` with a minimal module list gives the desired safety without adding new CLI flags.

---
id: demand-005
date: 2025-11-27T13:33:09Z
type: reflection
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You reminded that lessons in this history manual should not only capture technical workflow guidance but also insights about how to learn and anticipate your style and preferences for future collaboration.

## Options
1. Continue recording only task-specific changes and decisions.
2. Expand each log’s lesson section to include observations about the instructor’s taste, priorities, and communication style.

## Decision
Option 2: broaden the lessons to cover both project tactics and how to adapt to the instructor’s working style so the manual becomes a teaching tool for future interactions.

## Result
- Future log entries will mention not just what changed, but also what they reveal about your preferences (e.g., valuing clear instructions, history logs, or referential docs).
- This reflection reaffirms that codex lessons guide both building the project and learning to meet your style proactively.

## Lessons
The codex history becomes more valuable when it captures how you like to work, so each entry should note not only technical facts but also cues about your expectations and communication taste.

---
id: demand-006
date: 2025-11-27T13:36:48Z
type: test
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked me to exercise the interactive module-selection flow (`--select-modules`). I ran `bash main.sh --select-modules` (feeding `3` as the selection) on the local machine to confirm the behavior.

## Options
1. Only inspect the code without running it.
2. Execute the script end-to-end to observe the actual runtime behavior.

## Decision
Executed option 2 to capture real behavior.

## Result
- The script failed while enumerating modules because the current macOS bash (v3.2) does not support the `mapfile` builtin; logs showed `mapfile: command not found`.
- Because the tool defaulted to remote mode afterward, it attempted to sync the project to `root@bj.tomt.online` and opened a remote session (fortunately it only displayed the help text, but it did connect). This highlights that `REMOTE_RUN=false` triggers remote execution unless overridden.

## Lessons
- Interactive selection currently depends on bash features not available in macOS’s default shell; we should replace `mapfile` or require bash >=4.
- When running tests locally, explicitly set `REMOTE_RUN=true` (or provide dummy hosts) to avoid unintended remote transfers.

---
id: demand-007
date: 2025-11-27T13:50:17Z
type: refactor
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You noted that parts of `prj.md` were no longer necessary or accurate. The document still had legacy numbering gaps and an outdated “README structure” section that no longer reflected how we work.

## Options
1. Keep the existing sections and just annotate that they are optional.
2. Remove the obsolete content (e.g., the README outline), tighten the numbering, and keep only the sections that describe current requirements and architecture.

## Decision
Option 2: trim the document to the relevant sections and fix numbering so the structure is compact and accurate.

## Result
- Renumbered the “Technical Solution” block to section 3 and adjusted all subheadings.
- Shifted the configuration template, Trae asset handling, and usage sections so they follow sequentially (4–6).
- Deleted the stale README-outline section entirely so `prj.md` now focuses on actual requirements and execution flows.

## Lessons
Keeping `prj.md` short and accurate makes it easier to predict your taste: you prefer documentation that states what’s true today and removes speculative placeholders like future README plans.

---
id: demand-008
date: 2025-11-27T13:52:47Z
type: refactor
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You requested that the literal string “trae” no longer appear anywhere except inside `codex/codex.md`. The project requirements document still referenced legacy Trae agents and file names.

## Options
1. Leave the old references in `prj.md` but add a note explaining they are legacy terms.
2. Remove the outdated references, rename sections to “Codex” terminology, and update the file-structure lists accordingly.

## Decision
Option 2: scrub `trae` from `prj.md` entirely and describe the documentation assets in terms of the Codex directory.

## Result
- Updated the project layout to reference `codex/` (with `codex.md`, `prompt.md`, and `log.template`) instead of the old Trae prompt files.
- Renamed the roles and documentation sections to “Codex meta/prj agent” and “Codex asset handling.”
- Confirmed that no file outside `codex/codex.md` now contains the literal string “trae.”

## Lessons
Keeping terminology consistent with your current direction avoids confusion and makes it easier to anticipate requests—once you say “no more Trae,” we should update every doc (not just the obvious ones) so future references align with your taste.

---
id: demand-009
date: 2025-11-27T13:55:04Z
type: refactor
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You clarified that there is no longer a split between “meta” and “prj” agents—there is only Codex. `prj.md` still mentioned Codex-meta/Codex-prj roles in the project management section.

## Options
1. Keep the legacy terminology and add a footnote.
2. Rewrite the roles/communication section so it references only the single Codex agent plus the user.

## Decision
Option 2: update the document to describe the single Codex agent and the user relationship directly.

## Result
- `prj.md` now states that one Codex agent executes the project per `codex.md`, and the user provides requirements/coordination.
- Communication bullets now emphasize direct collaboration between you and Codex with proactive status updates.

## Lessons
When you adjust how you want the agent framed, `prj.md` should mirror that immediately so the working style remains aligned; future edits should avoid reintroducing outdated agent splits.

---
id: demand-010
date: 2025-11-27T14:05:00Z
type: reflection
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked for a fresh codex log entry after reminding me to search the repo for the active prompt and reread it so the working rhythm stays top of mind.

## Options
1. Skip adding a history record and simply acknowledge the reminder inline.
2. Append a formal log entry that documents the prompt review, the renewed commitment to follow the Clarify → Plan → Solve → Verify → Integrate → Reflect cadence, and note the related code cleanup (removing the `--exclude='.git'` flag) so remote syncs stay faithful to the local repo.

## Decision
Option 2: create a new history entry capturing the prompt review and the rsync behavior change so future demands see that the guidance was reinforced.

## Result
- Re-scanned the repository for “prompt,” reread `codex/prompt.md`, and reiterated that it governs each interaction alongside `codex.md`.
- Updated `lib/remote.sh` to drop the `--exclude='.git'` flag so remote transfers retain repository metadata.
- Added this entry to the codex history so the reminder (and the rsync change) is discoverable when reviewing past demands.

## Lessons
Regularly rereading the prompt keeps me aligned with your expectations, and noting related code tweaks (like ensuring `.git` syncs remotely) prevents forgetting the operational consequences of those reminders.
---
id: demand-011
date: 2025-11-27T14:35:22Z
type: feature
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You want `--select-modules` to always display every available module script with a numbered menu so users can point at the modules they want by index.

## Options
1. Leave the numbering logic inside `prompt_module_selection` and duplicate it wherever we need to show the menu.
2. Create a small helper that renders the module list with indices and reuse it for the interactive prompt so the numbering is guaranteed to stay in sync.

## Decision
Option 2: add a helper dedicated to printing the numbered module menu and reuse it from the interactive selection flow.

## Result
- Added `print_module_menu` to `main.sh` so the numbering logic lives in one place.
- `prompt_module_selection` now calls the helper before asking the user to pick module indices.
- Every run of `--select-modules` prints the numbered list dynamically before the prompt.

## Lessons
Centralizing the menu rendering keeps the numbered list in sync with the available modules and makes future tweaks (e.g., sorting or filtering) easier to implement.
---
id: demand-012
date: 2025-11-27T14:39:45Z
type: fix
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
Running `./main.sh --select-modules` didn't show the module list before prompting, so the instructor couldn't see which numbers to enter.

## Options
1. Keep printing via plain `echo`, which apparently wasn't visible in the current terminal output.
2. Emit the module menu through the `log` helper so each entry appears with timestamps/levels like the rest of the CLI output.

## Decision
Option 2: route the menu output through `log` so it always shows up in the console and log file.

## Result
- `print_module_menu` now logs each numbered entry instead of writing raw `echo` lines.
- The prompt preamble also uses `log "INFO"` so the “Available modules” heading is visible.
- `--select-modules` now produces a numbered list before waiting for user input.

## Lessons
Aligning auxiliary output with the logging style avoids confusion; anything the user must see should go through `log` so it matches the rest of the CLI stream.
---
id: demand-013
date: 2025-11-27T14:46:05Z
type: fix
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
After the previous change, the numbered module list still didn’t appear for you because your log level hid INFO messages, so the prompt showed nothing before asking for input.

## Options
1. Keep relying on `log` output, forcing users to raise their log level whenever they want to see the module menu.
2. Print the menu directly to stdout (independent of log thresholds) so the list is always visible, while the rest of the flow keeps using the logger.

## Decision
Option 2: write the module menu with `printf`/`echo` so it always hits the terminal.

## Result
- Restored `echo`/`printf` output for the “Available modules” heading and each numbered entry.
- The interactive selector now shows the module list regardless of `LOG_LEVEL` settings.

## Lessons
Critical interactive prompts shouldn’t depend on log verbosity; printing directly ensures they remain visible even when users prefer quieter logs.
---
id: demand-014
date: 2025-11-27T14:48:13Z
type: fix
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
Even after restoring plain `echo` output, the module list still didn’t appear because `prompt_module_selection` runs inside command substitution, which captures stdout and hides the menu from the terminal.

## Options
1. Keep writing to stdout and accept that the menu disappears whenever the function is invoked via `$()`.
2. Send the menu output to stderr (or `/dev/tty`) so it still reaches the user while stdout remains reserved for the resulting module list.

## Decision
Option 2: print the “Available modules” heading and numbered entries to stderr so the prompt is always visible.

## Result
- `prompt_module_selection` now writes its menu to stderr, which bypasses command substitution capture.
- Users can see the full menu before entering numbers, while stdout still returns the comma-separated selection.

## Lessons
Interactive helpers invoked via command substitution must separate user-facing prompts from machine-readable output; emitting prompts on stderr is a reliable way to achieve that.
---
id: demand-015
date: 2025-11-27T14:51:41Z
type: fix
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked me to avoid writing the module menu to stderr and instead change how the selection is captured so stdout remains free for prompts while the selected modules are stored separately.

## Options
1. Keep emitting the menu on stderr and continue capturing stdout via command substitution.
2. Store the selected modules in a shared variable and let `prompt_module_selection` print the menu to stdout, eliminating the need to echo the selection itself.

## Decision
Option 2: introduce a shared buffer (`PROMPT_MODULE_SELECTION_RESULT`) so the function no longer needs to emit the selection on stdout.

## Result
- `prompt_module_selection` now prints its menu on stdout, collects the chosen modules, and stores the comma-separated list in `PROMPT_MODULE_SELECTION_RESULT`.
- The caller checks the return code and reads the shared variable instead of using command substitution, so prompts remain visible and stdout stays clean.

## Lessons
For interactive flows that both display prompts and return structured data, using a shared variable (or explicit output file) is cleaner than relying on command substitution, which forces stdout to double as both UI and data channel.

---
id: demand-016
date: 2025-11-27T15:05:00Z
type: feature
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked for a `set_http_proxy` helper that writes proxy exports into the user’s shell rc file and hinted it should ultimately be driven by a dedicated `--set-http-proxy` CLI flag rather than being buried in `modules/init.sh`.

## Options
1. Keep the proxy persistence logic inside `modules/init.sh`, limiting its use to the internet-check retry flow.
2. Promote the helper into `lib/common.sh`, expose a CLI flag to trigger it directly, and have the init module reuse the shared helper.

## Decision
Option 2: make proxy persistence a shared utility and wire a `--set-http-proxy` flag so users can configure it explicitly.

## Result
- Added `set_http_proxy` to `lib/common.sh`, ensuring it updates both the rc file and the current environment variables.
- Updated `modules/init.sh` to call the shared helper after a successful proxy retry.
- Extended `main.sh` with `--set-http-proxy` (usage text, parsing, and early exit) so the helper can be invoked without running other modules.

## Lessons
You prefer features to be reusable and surfaced through explicit CLI options rather than hidden in module internals; when you request a helper, expect it to be available both programmatically and via a dedicated flag.

---
id: demand-017
date: 2025-11-30T14:29:05Z
type: fix
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked me to reread this codex, refresh its log, and update `prj.md` so every usage example matches the current entrypoint (`tlnx`) and highlights the new `--set-http-proxy` path that persists proxy settings.

## Options
1. Leave the documentation stale, continuing to mention the deleted `main.sh` wrapper and omitting the proxy flag.
2. Update both documents immediately so future runs and contributors see the correct invocation instructions and the new proxy helper.

## Decision
Option 2: revise the docs to reflect the `tlnx` entrypoint, add the proxy flag to the usage list, and log the demand here.

## Result
- Added this log entry summarizing the documentation alignment request.
- Updated `prj.md` usage flows to call `./tlnx`, mention the proxy flag, and keep the help section accurate.
- Ensured the examples show both direct module selection and the interactive picker with the current command name.

## Lessons
When scripts are renamed or flags are introduced, you expect the supporting docs and history to be synchronized immediately so future instructions remain trustworthy.

---
id: demand-018
date: 2025-12-01T00:45:00Z
type: fix
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You accidentally removed the original `.git` directory, leaving a working tree with untracked changes and no history. You asked me to restore the repository state so those edits can be committed and pushed upstream.

## Options
1. Reinitialize Git inside the modified working tree and try to reconstruct the remote history by hand, risking mismatches or missing files.
2. Clone a fresh copy of `emous/tlnx`, copy the modified files from the working tree into the clean repo, and use the restored Git metadata to review and commit the changes.

## Decision
Option 2: work from a clean clone so the upstream history stays intact and only the intended file changes are staged.

## Result
- Cloned `emous/tlnx` into `/home/tom/tlnx/repo` to regain the `.git` metadata and remote configuration.
- Copied the modified files (`modules/init.sh`, `config/default.conf`, `config/default.conf.template`, `lib/prerequisite.sh`, `lib/shell.sh`) into the clean clone so their diffs are tracked.
- Attempted `./tlnx -t` (with `REMOTE_RUN=true`) to sanity-check the changes; the run halted early because the current user lacks sudo privileges, so no functional regression testing was completed.

## Lessons
When the repository metadata is lost, recloning upstream and transplanting the edited files is safer than trying to rebuild `.git` manually; it preserves history and makes it straightforward to stage, review, and commit the outstanding work.

---
id: demand-019
date: 2025-12-01T01:20:00Z
type: feature
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You wanted proxy variables defined in `default.conf` or `enc.conf` to be written into their own TLNX sub block before the init module tests connectivity.

## Options
1. Keep relying on `set_http_proxy`, forcing users to re-enter proxies interactively.
2. Teach the init module to persist configured proxy exports automatically using a dedicated shell helper.

## Decision
Option 2: create `append_shell_rc_sub_block`, expose proxy defaults in the config files, and update the init module to persist them before running network checks.

## Result
- Added `append_shell_rc_sub_block` to `lib/shell.sh` so labeled TLNX sub blocks can be inserted without clobbering other exports.
- Declared `http_proxy`, `https_proxy`, `HTTP_PROXY`, and `HTTPS_PROXY` in the config files and updated `init_check_internet_access` to write them into a “PROXY SETTING” sub block before sourcing the RC file.

## Lessons
Persisting configuration-driven state keeps automation deterministic and avoids redundant prompts for values that are already known.

---
id: demand-020
date: 2025-12-01T01:35:00Z
type: fix
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You clarified that the init module must read literal proxy values from `enc.conf` first (then `default.conf`), rather than trusting whatever proxy exports happen to exist.

## Options
1. Keep referencing the current environment and risk mismatches between runtime state and configuration.
2. Parse the config files directly and only persist those values.

## Decision
Option 2: add `get_proxy_value_from_configs` so proxy data always comes from the authoritative files.

## Result
- Introduced `get_proxy_value_from_configs` in `modules/init.sh` and wired it into the proxy persistence block so the init module uses literal config values.

## Lessons
Reading from the source configuration eliminates ambiguity and ensures the automation reflects the user’s declared intent.

---
id: demand-021
date: 2025-12-01T01:45:00Z
type: refactor
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
After adding the proxy helper, you asked to move it out of `modules/init.sh` so other modules could reuse it.

## Options
1. Leave `get_proxy_value_from_configs` inside the init module.
2. Relocate it into `lib/config.sh` alongside the other configuration helpers.

## Decision
Option 2: centralize the helper in `lib/config.sh`.

## Result
- Moved `get_proxy_value_from_configs` into `lib/config.sh` and updated the init module to call the shared version.

## Lessons
Keeping configuration utilities together prevents duplication and makes future reuse simpler.

---
id: demand-022
date: 2025-12-01T01:55:00Z
type: refactor
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked me to stop re-detecting the current shell inside `lib/shell.sh` and instead use a single `RC_FILE` variable so every helper operates on the same, predetermined file.

## Options
1. Keep calling `basename "$SHELL"` in each helper, which risks mismatched paths and redundant logic.
2. Resolve `RC_FILE` once and have every helper rely on it (or explicit overrides) moving forward.

## Decision
Option 2: establish `RC_FILE` when the library loads and refactor the helpers to rely on it exclusively unless an explicit shell override is provided.

## Result
- Initialized `RC_FILE` when `lib/shell.sh` loads, falling back to `~/.bashrc` on unsupported shells.
- Updated `append_shell_rc_block`, `append_shell_rc_sub_block`, `source_rcfile`, `init_shell_rc_file`, and `check_rcfile` to use `RC_FILE` (with strict zsh/bash overrides) so the detection logic lives in one place.

## Lessons
Resolving shared state once reduces duplication and ensures every helper touches the same RC file, which aligns with your preference for deterministic behavior.

---
id: demand-023
date: 2025-12-01T14:39:38Z
type: fix
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked me to refresh `prj.md` and `codex.md` so the docs reflect the current CLI surface, especially the force flag that re-runs modules even when their checks say they are already installed.

## Options
1. Leave the documents untouched, even though the `-f/--force` switch is now live in the entrypoint.
2. Update `prj.md` with the new option details and record this demand in the codex history.

## Decision
Option 2: keep the documentation synchronized with the code and note the change here.

## Result
- Added `-f/--force` (plus the existing `-e VAR=value` overrides) to the CLI option list, help flow description, and usage examples inside `prj.md`.
- Documented how the force flag skips the "already installed" checks so modules always run when requested.
- Logged this demand as entry `demand-023` to preserve the rationale.

## Lessons
Whenever a new CLI switch ships, you expect `prj.md` and the codex log to update immediately so future runs have correct instructions and traceability.

---
id: demand-024
date: 2025-12-02T10:18:34Z
type: feature
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked for a dedicated manual test harness for the ZSH module so it can be exercised without touching the real home directory, and you also wanted the documentation refreshed (including this codex) plus a summary of the code changes before committing.

## Options
1. Keep relying on ad-hoc manual runs of `_zsh_install` and leave the docs/log untouched.
2. Add a standalone test script that wires up an isolated `HOME`, document the harness in `prj.md`, and log the demand here so future work remembers the intent.

## Decision
Option 2: provide a reproducible manual harness, update the project requirements doc, and capture the demand in the codex log alongside the commit summary.

## Result
- Created `tests/manual_zsh_module.sh`, which points `HOME` at `run/tmp/zsh-module-home`, sources the shared libs/modules, runs `_zsh_install`, and prints the resulting `.zshrc` snippet and log location.
- Updated `prj.md` to explain how module marks gate reruns and to enumerate the suite of manual verification scripts (including the new ZSH harness).
- Produced a repo-wide change summary before committing so the code delta, docs, and codex entry stay in sync.

## Lessons
You expect every new capability—even small test helpers—to ship with documentation and codex history so future contributors know how to use it and why it exists; summarizing the change set before committing reinforces that discipline.

---
id: demand-025
date: 2025-12-02T15:45:00Z
type: docs
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked me to read through the latest repository changes, document the newly added Clashctl module plus the offline package flow, and then prepare the Markdown files for a commit so the docs reflect reality.

## Options
1. Leave `prj.md` and `codex.md` untouched even though the code now includes `modules/clashctl.sh`, new package archives, and helper functions such as `checkout_package_file`.
2. Update the documentation immediately so the module list, package handling, and history log describe the new behavior and default module ordering.

## Decision
Option 2: refresh the docs to include the Clashctl module, package staging details, and this codex entry before committing.

## Result
- Expanded the project layout and configuration management sections to mention `modules/clashctl.sh`, `packages/`, and the default `CONFIG_MODULES=("init" "git" "zsh" "clashctl")`.
- Added a dedicated Clashctl module subsection outlining how the packaged installer is extracted, how `CLASHCTL_SUB_X` seeds `resources/config.yaml`, and how the scripts run under sudo with logs captured.
- Logged this demand here so future contributors know why the Markdown files were updated alongside the new module work.

## Lessons
Whenever you introduce a new module or helper, you expect the documentation and history to capture the full workflow (including offline assets and env vars) right away so the repo stays self-explanatory.

---
id: demand-026
date: 2025-12-11T05:54:00Z
type: feature
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You are tired of restoring VMware snapshots to test the provisioning script on a clean Ubuntu host and asked for a built-in Docker workflow: running `./tlnx` locally should spin up a fresh Ubuntu 24 container, copy the repo inside, and run the automation there while exposing the container so you can inspect it.

## Options
1. Keep relying on manual VM snapshots and avoid touching the main entrypoint, leaving Docker testing as an external process.
2. Add a configurable Docker harness in the repo so the default `./tlnx` command provisions a disposable Ubuntu container (capped at five at a time), injects the repo, prevents recursive launches via an env var, and streams the run so you can `docker exec` into it afterward.

## Decision
Option 2: integrate the Docker harness directly into `./tlnx`, backed by `DOCKER_TEST_*` config knobs so development defaults to containerized testing while production runs can disable it.

## Result
- Added `lib/docker_test.sh`, which enforces a five-container limit, pulls `ubuntu:24.04`, copies the repo into `/root/tlnx`, and re-runs `./tlnx` inside with `TLNX_DOCKER_CHILD=1` so recursion stops.
- Updated `tlnx` to short-circuit into the harness when `DOCKER_TEST_ENABLED=true`, plus new config defaults (`DOCKER_TEST_IMAGE`, `DOCKER_TEST_MAX_CONTAINERS`, `DOCKER_TEST_CONTAINER_PREFIX`) and documentation describing the workflow.
- Documented how to inspect the named containers via `sudo docker exec -it <container> bash`, matching your desire to dive into runs mid-flight.

## Lessons
You expect core workflows—especially costly verification loops—to be automated inside the repo with sensible guardrails (limits, env safeguards, docs, history entries) so you can trigger them via the standard entrypoint without juggling extra tooling.

---
id: demand-027
date: 2025-12-11T06:09:55Z
type: feature
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked to stop re-running `apt-get` inside every Docker test execution by baking the required tools into a dedicated image, to reuse that image for subsequent runs, and to have the prerequisite check fail early if `sudo` itself is missing.

## Options
1. Keep installing `sudo`/`psmisc` on every container boot and hope the overhead stays manageable.
2. Ship a repository-owned Dockerfile for the test harness, build it automatically when absent, and add an explicit `sudo` binary check in `_detect_prerequisites`.

## Decision
Option 2: create `docker/test-image/Dockerfile` plus build logic in `lib/docker_test.sh`, reference the image via new config knobs, drop the inline apt install loop, and teach the prerequisite phase to abort if `sudo` is not installed.

## Result
- Added `docker/test-image/Dockerfile` (default tag `tlnx/test:ubuntu24`) and updated the harness to build it automatically via `DOCKER_TEST_BUILD_CONTEXT`/`DOCKER_TEST_DOCKERFILE` before falling back to `docker pull`.
- Updated the config defaults/template to point at the new image, removed the per-run apt install block, and documented the workflow so repeated runs stay fast.
- Introduced `check_sudo_command` in `lib/prerequisite.sh` so the script reports a clear error when `sudo` is missing instead of failing later during package cleanup.

## Lessons
Baking dependencies into reusable artifacts (like Docker images) aligns with your desire to avoid redundant work; integrating those assets into the config plus prerequisite checks keeps the workflow predictable and self-documenting.

---
id: demand-028
date: 2025-12-11T15:30:45Z
type: feature
status: accepted
idea from: instructor
links:
  - event_id:
  - issue:

## Context
You asked for two improvements: (1) mount the repository directly into the Docker test container instead of copying it (preserving `run/` as ephemeral) and (2) restore interactive password prompts for `./tlnx -c`, which disappeared because the Docker harness wrapped encryption runs.

## Options
1. Keep copying the repo into each container, leaving `./tlnx -c` wrapped so prompts stay suppressed.
2. Bind-mount the repo (masking `run/` with tmpfs), update the systemd-capable image/flags, and only invoke the Docker harness for actual module runs so encryption/decryption execute locally with prompts intact.

## Decision
Option 2: switch to bind mounts with a tmpfs overlay for `run/`, mark the container privileged/systemd-ready, prune containers aggressively, and short-circuit the harness when `-c`/`-d` (or proxy-only) modes are requested so they run on the host terminal.

## Result
- `lib/docker_test.sh` now launches containers with `--mount type=bind,src=$PROJECT_DIR,target=/root/tlnx` plus a tmpfs at `/root/tlnx/run`, removing the tar/rsync step; it also adds the necessary systemd/cgroup flags and still enforces the five-container limit.
- `tlnx` defers the Docker harness until after decrypt/encrypt/set-proxy handling, so `./tlnx -c` runs locally, prompting for the encryption key again.
- Documentation (and the Dockerfile) reflect the systemd-enabled image plus the new mount strategy.

## Lessons
Interactive workflows (like encryption prompts) must bypass automation layers that suppress TTYs, and the fastest feedback loop is to mount the repo directly with careful overlays instead of re-copying it for every test container.
