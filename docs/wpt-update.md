# Updating WPT (the fork and the pool)

How Crane moves its WPT tree (`tests/wpt`, the fork zig-whatwg/wpt) to a newer upstream
web-platform-tests revision. The first update after the pin (lane wptup1, 2026-11-14: upstream
afe89a5df4 -> 2358bd4835, generation 224) followed this procedure. Follow it again, step by step.

**Read this first.** Bump the main checkout's `tests/wpt` submodule ONLY inside the cutover window.
A `crane-remote.sh` job named `main`, run from the main checkout, rsyncs that checkout's `tests/wpt`
with `--delete` into the live tree of whichever host it lands on (`tmp/remote/crane-remote.sh`,
`share_wpt=0`). So a bump outside the window moves a host's tree under the lanes that run there.

## The model

- **The fork takes upstream's TREE, not its commits.** Each sync is one commit on top of the fork's
  `main`, whose tree is upstream's tree plus Crane's own files. Crane's files are `crane/`, the
  `crane` wptrunner product, the macOS `spawn` patch in `tools/serve/serve.py`,
  `.crane-upstream-revision` and `CRANE-UPSTREAM.md`. `CRANE-UPSTREAM.md` in the fork records every
  base, and its "Syncing" section has the merge commands.
- **The target is wpt.fyi's newest ALIGNED stable run** of Chrome, Firefox and Safari, not
  upstream's tip. Golden-rule-2 evidence on wpt.fyi then comes from exactly the files Crane runs. Ask
  the integrator before moving a target. Check that every upstream PR of ours that you expect is an
  ancestor of the target (`gh api repos/web-platform-tests/wpt/compare/<pr-commit>...<target>` gives
  `behind` when it is included).
- **One live tree and one serve per host.** `~/crane-work/main/tests/wpt` is the live tree. The
  mirrors link to it, `crane-remote.sh` copies Crane tests into it, and `crane-pool.sh sync-wpt`
  replaces it. `crane-exclusive.sh restart-serve [tree]` starts the host's one `wpt serve`.
- **Every frozen generation keeps its own tree.** `~/crane-wpt/<upstream rev10>` is a full copy per
  revision, made by `~/crane-wpt-tree.sh snapshot`; `freeze-gen.sh` links the frozen dir's
  `tests/wpt` to that copy and writes `wpt-revision`. The runner reads files from `--wpt-root` but
  fetches them from the serve, so both sides of a comparison need ONE revision. After an update,
  every A/B uses the WPT-update generation as its base. A lane window script checks that with
  `~/crane-wpt-tree.sh check "$G/tests/wpt" || exit 2`.
- **The update generation explains its own losses.** `tools/wpt_progress.py` marks a generation
  measured on another upstream revision as `wpt_update`. A loss there is explained only by a
  `kind = upstream-test-change` entry, and only where the test file or a resource it loads changed
  between the two fork commits. Loaded resources include run-time loads: `fetch()`, workers and
  XHR. `--upstream-test-changes` proposes those entries for review. The parser refuses one for a
  byte-identical file.

## Before the window (no host is touched)

1. **The sync commit**, in a scratch clone of the fork under your worktree's `tmp/`. Fetch upstream
   shallow, down to the previous base. Then:
   `git merge-tree --write-tree --merge-base=<previous base> origin/main <target>`.
   Build the commit from that tree. Set `.crane-upstream-revision` to the target, and update
   `CRANE-UPSTREAM.md`: the rule, the three browser versions and wpt.fyi run ids, the upstream
   commit count, and which of our upstream fixes are and are not included. Then
   `git commit-tree <tree> -p origin/main`. Check two things: outside `crane/` the tree differs
   from the target only in Crane's files, and `crane/` equals the fork main's (the same tree object).
   Push nothing yet.
2. **The manifest**:
   `python3 wpt.py --venv <main checkout>/tests/wpt/_venv3 --skip-venv-setup manifest -p MANIFEST.json --no-download`
   (about 16 s; MANIFEST.json is gitignored in the fork).
3. **The worklist delta**: `python3 tools/wpt_subset.py --manifest <clone>/MANIFEST.json --worklist tmp/<x>.txt`.
   On the OLD manifest the script must still write today's worklist byte for byte. Follow upstream
   renames in INCLUDE/EXCLUDE, and drop entries for deleted files. For every new file, apply the
   scope line: ratified spec, shipped by at least one browser, not tentative, no geometry. Use the
   wpt.fyi summaries of the target run (`results_url` in `/api/runs`) as evidence. Check
   `tools/wpt_gate_exemptions.txt`, `tools/wpt_loss_dispositions.txt` and
   `tools/wpt_build_differences.txt` for paths that are gone.
4. **Read the upstream harness diff**: `resources/` (testharness, testdriver), `common/`,
   `tools/serve`, `tools/wptserve`, the manifest code, and new META keys. Also read Crane's five
   integration files in the fork against upstream's changes. That is where an update breaks the
   runner (2026-11: `// META: pac=` proxy tests).
5. **The snapshot of the outgoing tree** (`~/crane-wpt-tree.sh snapshot` on each host with frozen
   dirs). It only reads the live tree, so it may run in a quiet gap.

## The cutover window (the integrator closes all three hosts)

Each step reports its check. A failed check runs that step's undo and stops the window.

| # | Who | Step | Check | Undo |
|---|-----|------|-------|------|
| 0 | integrator | Close all hosts. Check that no job runs and that no slot holder or queued job is named `main` (`crane-pool.sh status`). Commit the merged lanes' Crane tests to the fork; the main checkout's other uncommitted Crane tests must survive step 5. Then re-make the sync commit on the final fork main. | crane/ in the sync commit == crane/ at fork main | - |
| 1 | lane | Install the new `crane-exclusive.sh` (temp file + mv, keep `.bak`). Serve the old copy (`restart-serve ~/crane-wpt/<old>`) to prove a copy serves and reuses its `_venv3`. Go back to the live tree. | the report alias is served, https answers 200, `/.crane-upstream-revision` | mv `.bak` back, then restart-serve |
| 2 | lane | Install the scripts with `.bak` copies: `~/crane-wpt-tree.sh` and `~/crane-exclusive.sh` on the hosts; `.integ/freeze-gen.sh` and `gen-sweep.sh` in the integrate worktree AND in server1's `~/crane-work/integrate-l/.integ/`; the repo-side copies in `tmp/remote/` | sha256 equals the reviewed copy | mv each `.bak` back |
| 3 | lane | Link every `~/crane-frozen/*/tests/wpt` that points at the live tree to `~/crane-wpt/<old>`, and write `wpt-revision` | `ls -l` of each link; `crane-wpt-tree.sh check` | `ln -sfn ~/crane-work/main/tests/wpt` |
| 4 | lane | Push ONLY the sync branch to the fork | `git ls-remote`: the fork's `main` is unchanged | delete the remote branch |
| 5 | integrator | Main checkout: `git -C tests/wpt fetch` the branch, then `merge --ff-only <sync>`, with a `git status --short` before and after (they must be identical); regenerate MANIFEST.json (keep the old one in `tmp/`) | the revision file; the status diff is empty | `reset --keep <old>`, restore the manifest |
| 6 | integrator | Merge the lane; `python3 tools/wpt_subset.py`; commit the gitlink and the worklist (do not push) | the source/URL counts | revert the commit |
| 7 | lane | `crane-pool.sh sync-wpt` (server1, chat2); for chat.local the same rsync line by hand (sync-wpt skips it). Write the host in a shell variable as `${h}:path`, never `$h:path` (zsh colon modifiers) | `rsync -an --itemize-changes` lists 0 entries (server1 also lists symlink permission bits); `.crane-upstream-revision` on each host | rsync `~/crane-wpt/<old>/` back (chat2 has no copy: re-sync it from the Mac) |
| 8 | lane | `restart-serve` on each host | "(WPT <new>)", the alias, https 200 | step 7's undo, then restart |
| 9 | lane | `~/crane-wpt-tree.sh snapshot` (server1, chat.local) | revision and file count | - |
| 10 | integrator | The gate, plus `freeze-gen.sh` with PREV = the last generation on the old tree | its line ends `wpt=<new> (...)`; SHA256SUMS lists 5 binaries | - |
| 10b | lane | The gate answers from the cache when the sources equal the last tree's, so tests that open `tests/wpt` files at run time did not run. Re-run them uncached: `zig build test -Dspec=<platform\|mimesniff\|html\|v8\|wpt_runner> -Dtest-binaries=v8 -Dlaunch-seed=random -j2` | 0 failures | - |
| 11 | lane | Runner compatibility: the frozen production runner over the 1-in-4 sample, twice, then compare the two runs and the previous generation per file, where the file and its loads are byte-identical | 0 crashes, the two runs identical, 0 byte-identical files that differ | - |
| 12 | integrator, then lane | The WPT-UPDATE generation sweep (production + bug-finding). The lane builds the generation in a SCRATCH copy (never the main checkout's history), runs `--upstream-test-changes`, reviews every loss, and writes the entries and queue items | "0 unexplained subtest losses" | - |
| 13 | integrator | Fast-forward the fork's main to the sync commit; push main and gh-pages; reopen the hosts; the resume-brief line for lanes | - | - |

After the window, re-run the Chrome reference in a chat.local timed window. It takes about 60
minutes and uses Chrome for Testing at the aligned run's version. The scripts are in `tmp/remote/`:
`chrome-ref.sh` is lane chromeref1's script with lane wptup1's fixes (it reads V8 from
`jsengines/v8/<version>/include`, states its verify skip, and takes `REF_MIRROR=<mirror>`), and
`chrome-ref-freeze.sh` freezes the production runner.

The run, in your chat.local mirror:
1. `zig build wpt-runner snapshot` through `crane-remote.sh`.
2. `SHA=<main sha10> REF_MIRROR=<mirror> bash chrome-ref-freeze.sh`.
3. `REF_MIRROR=<mirror> bash chrome-ref.sh setup`.
4. A dry `check <sha10> <fork gitlink>` with `RUNNER_DIR`.
5. In the window: `rerun <sha10> <fork gitlink>` with `RUNNER_DIR` and `SWEEP_ENV=FILES_PER_RUNNER=40`.
6. `zig build wpt-site -- import-reference --engine=chrome --report=<B>/window2/chrome/wptreport.json --manifest=<B>/wpt/MANIFEST.json --worklist=tests/wpt_0_1_worklist.txt --meta=<B>/window2/run.json --out=<dir>`.

Then the integrator swaps `wpt-results/reference/<run>/` (the directory is untracked) and runs
`zig build wpt-progress`. The regeneration refreshes the latest generation's upstream revisions,
so the site's comparison stops saying that Crane's column and the reference are on different
upstream revisions.
Then the cleanup: the copies `prune` lists, the `.bak` scripts, scratch clones and branches.

## A lane whose branch predates the update

Merge main and take main's `tests/wpt` gitlink and worklist. Discard or re-freeze every frozen bin
made before the cutover, because its results are on the old tree. A/B only against the WPT-update
generation.
