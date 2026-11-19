# Workflow: A --full dry run in your own closed window restarts the host's shared wpt serve

**Date**: 2026-11-18
**Lesson**: `crane-pool.sh wpt <mirror> ... --full` inside the mirror's own closed window starts with `crane-exclusive.sh restart-serve` (a fresh serve for the window run). Pass `--full` to the real run only, never to a dry run. And a closing notice does not mean the previous window's runs have ended.

**Why**: The fresh serve is right for the run it precedes, because a long-lived serve's children grow and stall. But crane-pool decides only from the window marker (closed, owner = this mirror). It does not check whether another run still uses the serve. So any --full job sent after the marker changes owner restarts the serve, even an input-check dry run, which needs no serve restart at all.

**What Happened**: Lane dom1 got main's closing notice for server1 (owner dom1-l) at 9:35 PM ET. css1's generation-229 base run (bug-finding, 16 runners) was still on its last repeat; main's WINDOW GO was to follow when it ended. Lane dom1 then sent its window2 dry run with `--full` (copied from the real command). crane-pool printed "a fresh wpt serve for this window run" and stopped the old serve. Two of css1's in-flight files lost their connection:
- `consume-user-activation/window-open.html` read ERROR "Page load error: error.NetworkError".
- `clear-window-name.https.html` read 11/1 instead of TIMEOUT 11/0.
Their base repeat 2 needed a re-run for those files.

**Fix**:
1. A dry run (`DRY=1`) goes without `--full`, or with `CRANE_FRESH_SERVE=0`, since it only checks inputs.
2. Before any `--full` job in a newly closed window, check that the previous owner's runs have ended (`pgrep -fa crane-measure` on the host), not just that the marker names you.
3. If a restart did hit someone's run, find the records that differ from every other repeat around the restart time, and report them to the integrator. Here css1 re-ran the two files x3 and patched repeat 2 before anyone compared.
4. The pool now guards it: since 2026-11-18, a `--full` run exits 96 rather than restart the serve while any crane-measure run is active on the host. Exit 96 means another run is still using the serve: wait for it to end, never work around it.

**Takeaway**: **`--full` in your own closed window restarts the shared wpt serve: use it for the real run only, after the previous owner's runs have ended, never for a dry run.**
