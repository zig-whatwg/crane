# Testing: wpt serve: a file added after it starts 404s, and stopping it means stopping all of it

Current practice: to restart the server, kill the listener on EVERY port (second section) - killing only :8000 (the first section's original advice) leaves its other children bound, and the next server fails.

## A test file added while `wpt serve` is running 404s, and a 404 reads as TIMEOUT

**Date**: 2026-09-22
**Lesson**: `wpt serve` fixes its file routing at startup. The runner REUSES a
live server. So a test file you create now is not servable until that server is
killed - and the symptom is a timeout, not an error.

**Why**: `tests/wpt_runner/wpt_server.zig` checks for an existing server (via
`.wpt_serve.lock`, falling back to the port) and sets `we_spawned = false` when
it finds one. That server keeps serving for as long as it lives - 35 minutes in
the case that produced this note - and 404s anything created after it started.
The runner then loads the 404 body as the test page, `window.__wpt_complete`
never becomes true, and the file is journalled TIMEOUT at the 10s ceiling. This
is the same in-band-failure laundering as [architecture-a-network-error-response-is-not-a-failed-call](architecture-a-network-error-response-is-not-a-failed-call.md).

**What Happened**: measured, because it looked exactly like a code regression.

    crane/ce-get.html        (Sep 21 14:30, before the server)  HTTP 200  OK, 2 subtests
    crane/ce-get-copy.html   (byte-identical copy, 00:44)       HTTP 404  TIMEOUT, 0 subtests
    crane/bisect-trivial.html (`assert_true(true)`, 00:39)      HTTP 404  TIMEOUT, 0 subtests

Server PID start time 00:15:00. Same directory, same permissions, same bytes,
same load - only the creation time differed. Adding the files to MANIFEST.json
changed nothing; `wpt serve` is not consulting the manifest for this.

A new rAF test went from 5 subtests on its first run to 0 subtests afterwards,
and the 0 was pure 404. Most of an hour went into bisecting a change that was
never at fault, including a discarded worktree build.

**Fix**: before trusting ANY result from a test file you just added:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://web-platform.test:8000/crane/<file>.html
```

200 means it is servable. 404 means kill the server and re-run:

```bash
lsof -t -nP -iTCP:8000 -sTCP:LISTEN | xargs -r kill
```

**Takeaway**: **A brand-new test reporting TIMEOUT with ZERO subtests is a 404
until proven otherwise.** Zero subtests means the harness never ran at all,
which is a different failure from a test that hangs - a real hang still reports
the subtests it got through.

## Stop `wpt serve` by killing all of it

**Date**: 2026-09-24
**Lesson**: `lsof -t -iTCP:8000 | xargs kill` (the advice in the first section) kills only the :8000 child. The server's other children keep 8001-8003, 8443-8446 and 9000. The next server then fails to bind those ports, shuts down its own :8000, and the runner reports `error.NetworkError` in 0 ms.

**Fix**: Kill the listener on every one of those ports, and the `wpt.py serve` parent.

```bash
for p in 8000 8001 8002 8003 8443 8444 8445 8446 9000; do lsof -t -nP -iTCP:$p -sTCP:LISTEN; done | sort -u | xargs -r kill
```

Then start a server that outlives any one runner: `python3 wpt.py serve --config config.json`, from `tests/wpt/`.
