# Testing: An unknown META global is dropped, and the file runs where it never asked to

**Date**: 2026-09-30
**Lesson**: The WPT runner parsed `// META: global=` with a table that did not know `dedicatedworker-module` or `sharedworker-module`; it dropped them, found the list empty, and ran the file with the `.any.js` defaults - a window and a classic dedicated worker.

**Why**: `parseAnyJs` gives a file with no globals the defaults, and an unknown name is skipped silently. A file whose every global was unknown looked like a file with none.

**What Happened**: import-meta-url/object/resolve.any.js and microtasks/evaluation-order-{1-nothrow,1-throw}-static-import, -2, -3.any.js (7 of the scripting-1 batch's 25 blocking files) are module-worker-only. Run as `.any.html` and `.any.worker.html`, their top-level `import` statements are SyntaxErrors in a classic script, and every one timed out with 0 subtests. It read as "module workers are broken"; they were never run as module workers at all.

**Fix**: The runner knows the three module globals (`GlobalType.worker_module`, `sharedworker_module`, `serviceworker_module`) and their wrappers (`.any.worker-module.html`, `.any.sharedworker-module.html`); the dedicated and shared ones run, now that module workers do (lane/scripts e1acbff5d). A test pins that a file of only module globals gets those globals, not the defaults.

**Takeaway**: **A global the runner does not know must be run or deliberately skipped, never dropped: an empty list is the defaults, so a file of unknown globals runs in contexts it never asked for.**
