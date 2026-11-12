# Spec Compliance: A script location's column is the JS engine's convention

**Date**: 2026-11-12
**Lesson**: Before building plumbing to report "the running script's" line and column (CSP violations, error events, reports), measure which column V8 gives for the exact statement a WPT test pins - a test written against one engine's column passes only in that engine.

**Why**: Neither ECMAScript nor HTML defines what column "the currently executing script" is at. CSP 2.4.1 step 2 says only "if the user agent is currently executing script, and can extract a source file's URL, line number, and column number" (and its own issue asks "Is this kind of thing specified anywhere?"). Each engine reports the position its bytecode carries: SpiderMonkey the start of the expression, JavaScriptCore the `.` of a property store, V8 the `=` of an assignment and the callee's start for a call.

**What Happened**: Lane quick1 (batch 1, cluster C22) set out to make four `content-security-policy/securitypolicyviolation/securitypolicyviolation-block-*image*.sub.html` files pass: they assert `lineNumber == 25 && columnNumber == 5` for `    i.src = "...";`. Only Firefox passed (wpt.fyi stable 24ddf405a0): Chrome reports no location at all (the violation is made at fetch time, when no script runs), Safari reports column 6. Gecko captures the location when "update the image data" queues its microtask (ImageLoadTask's `JSCallingLocation::Get()`, installed as `AutoFallback` when the load runs, dom/base/nsImageLoadingContent.cpp:91-123) - the right model, and Safari does the same. But a native measurement in Crane (engine.runningScriptLocation through src/dom/csp_violations.zig) gave column 17 for `    d.innerHTML = 'x';` (the `=`) and column 5 for `    eval('1')` (the callee). So the capture would report 25:11, and all four files would stay 0/1. The measurement took one native test run; the plumbing would have touched six files for no gate gain.

**Fix**:
1. Write a throwaway native test that triggers a synchronous violation inside the same kind of statement (a setter: `el.innerHTML = 'x'` under `require-trusted-types-for 'script'`; a call: `eval('1')` under a script-src without `'unsafe-eval'`) and read `e.lineNumber`/`e.columnNumber` from a `securitypolicyviolation` listener. Make the test FAIL with the values in its message: the launcher prints only failing tests' output.
2. Compare with the column the WPT test asserts and with each browser's message on wpt.fyi.
3. If only one engine's convention passes, the mechanism (capturing a location) is still golden rule 2's majority, but it is not a gate fix: queue it as correctness work and bring the files to the integrator as "one browser only".

**Takeaway**: **The column of "the running script" is defined by no spec - it is the JS engine's own; measure V8's for the exact statement before promising a WPT file that pins one.**
