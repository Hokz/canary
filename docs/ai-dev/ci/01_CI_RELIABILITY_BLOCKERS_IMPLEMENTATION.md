# CI Reliability Blocker Fix 01 - Implementation Handoff

## Scope

Closed-spec infrastructure maintenance task, independent of PR #38
(`ai-dev/global-combat-2026-foundation-01`). Branched from
`main@4209ba583a4dcb2ae528750dcfeb2e7c0109863a` (PR #37 merge commit).
No combat/gameplay/quest behavior touched except the one authorized
Change D line. No PR #38 branch/commits touched or merged into this
branch.

## Base SHA verification

- `origin/main` at task start: `4209ba583a4dcb2ae528750dcfeb2e7c0109863a`
- Branch `chore/ci-reliability-blockers-01` created from that exact
  commit (verified via `git rev-parse HEAD` immediately after
  `git checkout -b`, before any edits).

## Changes

### A - Docker quickstart image repository lowercasing

File: `.github/workflows/reusable-docker-quickstart-smoke.yml`

`github.repository` resolves with the repository's original case
(`Hokz/canary` on this fork). GHCR requires all image path components
to be lowercase, so `ghcr.io/${{ github.repository }}:pr` was rejected
outright. Added a step that lowercases `$GITHUB_REPOSITORY` via bash's
`${VAR,,}` expansion into a step output, consumed by the existing PR
image env var. General solution - works for any owner/repo name, not
hardcoded to a specific fork.

Commit: `ba3e75d42`

### B - Linux dependency install hardening

File: `.github/workflows/reusable-build-linux.yml`

Root cause of the observed hang (Linux builds stuck 3.5+ hours on
"Install Linux Dependencies" with no step progression, confirmed via
`gh api .../actions/jobs/<id>`): the step had no timeout and no apt
retry/timeout bounds, so a network stall or interactive prompt could
block indefinitely.

- Added `timeout-minutes: 10` to the step (hard kill on hang).
- Added `DEBIAN_FRONTEND: noninteractive` (no interactive prompts can
  block).
- Added bounded apt options: `Acquire::Retries=3`,
  `Acquire::http::Timeout=15`, `Acquire::https::Timeout=15`,
  `DPkg::Lock::Timeout=60`.
- Consolidated the previously-separate `mono-complete` install
  (its own "Install mono for NuGet" step, with its own
  `apt-get update`) and the duplicate `mysql-client` install (`Import
  Database Schema` step re-ran `apt-get update && apt-get install -y
  mysql-client` even though it was already installed upfront) into
  the single upfront install. Same packages end up installed, same
  build/test/artifact behavior preserved - purely fewer redundant
  apt-get round-trips.

Commit: `6d2fe1b68`

### C - autofix-ci scoped to PR-changed files

File: `.github/workflows/autofix-ci.yml`

Previously ran clang-format, StyLua, and cmake-format over the entire
repository tree on every triggering PR, regardless of what the PR
actually touched. This is the confirmed root cause of the earlier
incident where PR #38's head SHA changed unexpectedly mid-CI-wait: the
bot's own auto-formatting commit
(`2991444fd8941ab9a486c5b8bb1f2837083366b0`) modified a one-line quote
style in `actions_master_debater_documents.lua`, a file PR #38 never
touched.

New "Determine changed files" step computes
`git diff --diff-filter=ACMR -z --name-only <base-sha> <head-sha>`
(base/head from `github.event.pull_request.{base,head}.sha`,
NUL-delimited throughout) and partitions the result into three
NUL-delimited file lists by extension: C/C++
(`.cpp/.cc/.cxx/.hpp/.h/.hxx`, `src/protobuf/` excluded as before),
Lua (`.lua`), and CMake (`CMakeLists.txt`, `*.cmake`). Each formatter
now runs only over its own partition via `xargs -0 -a <list> <tool>
--`; a step is skipped entirely (`if: steps.changed-files.outputs.has_*
== 'true'`) when its partition is empty.

Edge cases handled:
- **Special characters in filenames** (spaces, etc.): every list is
  NUL-delimited (`-z`, `printf '%s\0'`, `read -r -d ''`, `xargs -0`),
  so no filename is ever split on whitespace or subject to word
  splitting.
- **Untrusted filenames**: filenames are never interpolated into a
  YAML `${{ }}` expression or into a shell string - they only ever
  flow through `xargs -0 -a <file>`, so a PR-controlled filename
  cannot inject shell or YAML-expression syntax. This is also why the
  DoozyX clang-format-lint-action and JohnnyMorganz stylua-action
  wrappers were replaced with direct CLI invocations (clang-format-17,
  stylua binary download): neither wrapper accepts a discrete file
  list without round-tripping it through a YAML `args:` string, which
  would have reintroduced the interpolation risk this change is
  specifically closing.
- **Renames**: `--diff-filter=ACMR` includes renames, and
  `--name-only` (as opposed to `--name-status`) already resolves a
  rename to its post-rename path, so the renamed file is formatted at
  its current location.
- **Empty partition**: each formatter step is conditioned on its
  partition being non-empty; an empty partition just skips that step,
  no error.
- **Fork PRs**: checkout already used `fetch-depth: 0`, which keeps
  both `base.sha` and `head.sha` reachable for `git diff` regardless
  of whether the PR originates from a fork.

The final `autofix-ci/action` commit step is unchanged; it now simply
sees a smaller diff because only the relevant partitions were
formatted.

Commit: `d6e592af5`

### D - One proven baseline Lua quote-style fix

File:
`data-otservbr-global/scripts/quests/the_secret_library_quest/the_order_of_the_falcon/actions_master_debater_documents.lua`

Among the six `bookText` string literals in this file, five contain an
embedded double-quote character (the riposte lines, quoted in-universe
text) and are correctly single-quoted to avoid escaping under StyLua's
default quote preference. Exactly one - the `writing_desk_2` / "Grand
Master of Verbal Debate IV" entry - contains no embedded double quote,
making it the one line StyLua's default (prefer double quotes unless
that would require escaping) actually flags for single-to-double
conversion. This is the same one-line delta autofix-ci previously
applied to this file on PR #38's head
(`2991444fd8941ab9a486c5b8bb1f2837083366b0`), applied here directly to
the `main`-based baseline instead of relying on the (now-scoped)
autofix bot to apply it against an unrelated PR.

Semantic equivalence: pure quote-delimiter change. Lua honors escape
sequences (`\n`) identically in single- and double-quoted strings, and
the string contains no other special characters, so the runtime value
is byte-identical before and after. Verified via
`luaparser.ast.parse` (successful parse, no syntax errors).

No other line in this file, and no other file, was touched.

Commit: `fee1f93b5`

## Explicitly out of scope (not touched)

PR #38 / `ai-dev/global-combat-2026-foundation-01` and all GLOBAL 2026
combat behavior (protocol features, Wheel of Destiny, runes, party XP,
potions, vocation spells, Blood Rage, Chained Penance); any Secret
Library behavior beyond the single Change D line; Repository Audit
duplicate Action ID findings (`action.item_id` 2874, 3452, 6276,
12724 - untouched, still the accepted 4-finding baseline); any other
runtime-smoke warnings, quest bugs, or content registrations not
named above.

No `NEXT_BLOCKER_REQUIRES_DIRECTOR_SPEC` conditions were hit - no
additional baseline formatting drift or other out-of-scope blocker was
discovered beyond the two root causes (Linux install hang, autofix
scope) this task was scoped to fix.

## Local validation performed

- `git diff --check` - clean, no whitespace errors, on all four
  changed files.
- YAML parse (`yaml.safe_load`) - all three workflow files parse
  successfully.
- Lua parse (`luaparser.ast.parse`) - the Change D file parses
  successfully post-edit.
- `bash -n` syntax check on every new/modified `run:` script block
  (Change A lowercase step, Change B install step, Change C
  partitioning step) - all pass.
- Deterministic lowercase test: `GITHUB_REPOSITORY="Hokz/canary"`
  through the exact `${GITHUB_REPOSITORY,,}` expression used in the
  workflow yields `hokz/canary`.
- Deterministic changed-file partitioning test: a synthetic
  NUL-delimited file list (including a filename with a space, a
  `src/protobuf/` file, and files with no matching partition) run
  through the exact partitioning loop used in the workflow correctly
  isolates the C/C++, Lua, and CMake partitions, excludes the
  protobuf file, and correctly reports an empty partition as `false`.

**Not exercised**: no GitHub Actions workflow run was triggered or
observed for this branch. All validation above is local/static
(syntax and logic-level); actual CI execution (Docker image push
across the lowercase boundary, a real Linux dependency install under
load, an autofix run against a real PR diff with base/head SHAs) has
not been observed and is not claimed as verified. This is left for
ChatGPT's independent validation once a PR is opened.

## Commits (5 total, in order)

1. `ba3e75d42` - `ci(docker): normalize GHCR image repository to lowercase`
2. `6d2fe1b68` - `ci(linux): bound and harden the dependency install step`
3. `d6e592af5` - `ci(autofix): scope formatting to PR-changed files only`
4. `fee1f93b5` - `style(secret-library): normalize one bookText string to double quotes`
5. This handoff doc commit

## PR state

Draft PR only, against `main`. Not marked ready. Not merged. No CI
gate polling performed as part of this task.

## Independent Audit Correction 01

ChatGPT's independent audit of PR #39 found four issues in the Change C
(`autofix-ci.yml`) scoping logic and one item requiring validation-only
confirmation. All four were corrected in place on the same file; no
other authorized file besides this handoff doc was touched.

**Finding 1 - nested CMakeLists.txt paths missed.** The partition
pattern `CMakeLists.txt|*.cmake` never matched a nested
`src/foo/CMakeLists.txt`, since bare `CMakeLists.txt` only matches the
literal root-relative string. Changed to
`CMakeLists.txt|*/CMakeLists.txt|*.cmake` (bash `case` patterns match
`/` like any other character, so `*/CMakeLists.txt` correctly matches
any depth). Also added back the original `find`-based exclusions for
`build/` and `vcpkg_installed/` (at any depth: `build/*|*/build/*` and
`vcpkg_installed/*|*/vcpkg_installed/*`), which the file-list
partitioning had dropped when it replaced the old `find | grep -v`
pipeline. Verified: root `CMakeLists.txt` selected, nested
`src/foo/CMakeLists.txt` selected, `path/to/file.cmake` selected,
`build/CMakeLists.txt` excluded, `vcpkg_installed/x64-linux/CMakeLists.txt`
excluded.

**Finding 2 - C/C++ coverage silently expanded.** The original
DoozyX/clang-format-lint-action surface was `source: "src tests"`,
`exclude: "src/protobuf"`, `extensions: "cpp,hpp,h"` - i.e. only files
under `src/` or `tests/`, only `.cpp/.hpp/.h`. The replacement
partition logic matched `*.cpp|*.cc|*.cxx|*.hpp|*.h|*.hxx` anywhere in
the repo, which both added two extensions (`.cc`, `.cxx`... and
`.hxx`) and dropped the directory restriction. Narrowed the case
pattern to `src/*.cpp|src/*.hpp|src/*.h|tests/*.cpp|tests/*.hpp|tests/*.h`
(again relying on `*` matching `/` for nested paths under those two
roots). Verified: `src/foo.cpp` selected, `tests/foo.hpp` selected,
`src/foo.h` selected, `src/protobuf/foo.cpp` excluded (unchanged
protobuf exclusion), `other/foo.cpp` excluded, `src/foo.cc` excluded,
`src/foo.cxx` excluded, `src/foo.hxx` excluded.

**Finding 3 - StyLua install assumed `/usr/local/bin` writability.**
Replaced the `/usr/local/bin` extraction (which needs root and doesn't
reflect a runner-owned location) with extraction into
`${RUNNER_TEMP}/stylua` (no `sudo`), then appended that directory to
`GITHUB_PATH` so `stylua` resolves by bare name in the following step
without hardcoding an absolute path there. Version pinning left as
`latest` (unchanged). Hardened the download itself:
`curl --retry 3 --retry-connrefused --connect-timeout 10 --max-time 120`,
plus a `timeout-minutes: 5` step-level backstop.

**Finding 4 - autofix clang-format apt install unbounded.** The
`clang-format-17` apt install had no step timeout and no
noninteractive/retry configuration - the same class of problem as the
Linux dependency install fixed in Change B. Added `timeout-minutes: 10`,
`DEBIAN_FRONTEND: noninteractive`, and the same bounded apt options
used in Change B (`Acquire::Retries=3`, `Acquire::http::Timeout=15`,
`Acquire::https::Timeout=15`, `DPkg::Lock::Timeout=60`), plus
`--no-install-recommends` (clang-format-17 has no recommended packages
that affect formatting correctness, so this is a safe narrowing).

**Temporary file safety - validated, not redesigned.** Confirmed
`all_changed.txt`, `cpp_files.txt`, `lua_files.txt`, and
`cmake_files.txt` are created in the runner's working directory but
never `git add`ed, so they remain untracked for the lifetime of the
job. `autofix-ci/action` applies its commit from a plain `git diff`
against the tracked tree, and plain `git diff` (no `--no-index`, no
explicit pathspec pulling in untracked content) never includes
untracked files - so these temp files cannot leak into the bot's
commit or be mistaken for intentional formatting output. No redesign
was needed; this is a validation finding, not a code change.

**Correction commit**: `ci(autofix): preserve formatter scope and
harden tool setup`.

**Files changed by this correction**: `.github/workflows/autofix-ci.yml`
and this handoff doc only. No other file (Docker lowercase fix, Linux
dependency fix, Secret Library quote fix, PR #38, Repository Audit
findings) was touched.
