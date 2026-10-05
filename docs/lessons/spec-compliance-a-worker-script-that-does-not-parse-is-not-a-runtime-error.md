# Spec Compliance: A worker script that does not parse is not a runtime error

**Date**: 2026-10-05
**Lesson**: HTML treats a worker's top-level script that fails to PARSE ("run a worker" onComplete step 1: the script's error to rethrow is non-null - a plain `error` Event at the Worker, nothing run, nothing reported) differently from one that THROWS ("report an exception" for the worker's global, then an ErrorEvent at the Worker, then - unhandled - the owner's global). Implementing either path alone breaks the other's tests.

**Why**: "Create a classic script" records a parse failure as the script's parse error and error to rethrow, before anything runs; "run a worker" checks it before running. An engine operation that runs a script reports both kinds of exception through one reporter, so a host that cannot tell them apart takes one path for both.

**What Happened**: Workers 1B-ii implemented "report an exception" step 7's last clause - an error the Worker's handlers leave unhandled is reported for the owner's global (omitError) - which fixed workers/constructors/Worker/AbstractWorker.onerror.html and propagate-to-window-onerror.html (both runtime errors). The FULL A/B then showed constructor-utf16-bom.html go OK 2 -> ERROR: its worker script has a UTF-16 BOM, decodes as UTF-8 and fails to parse; the Worker's onerror did not cancel, so the page's window error fired and testharness called it an uncaught exception. Browsers fire a plain `error` there and nothing at the page.

**Fix**: engine.ErrorInfo.parse_error (the protocol's): the V8 adapter sets it on the compile-failed path of the classic-script operations; the worker host, while the worker's own script runs, takes onComplete step 1 for it instead of reporting. JSC/QuickJS leave it false, declared in docs/engine-protocol.md. Crane test: crane/wt-parse-error.html (a parse failure: a plain Event and nothing at the page; a runtime error: an ErrorEvent at the Worker, then the page).

**Takeaway**: **When a spec algorithm branches on how a script failed (parse error vs. thrown), the engine operation must report which - one reporter for both makes whichever branch you implement break the other's tests. Write the case for each branch before touching either.**
