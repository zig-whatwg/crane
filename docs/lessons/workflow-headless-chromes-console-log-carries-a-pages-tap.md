# Workflow: Headless Chrome's console log carries a page's TAP

**Date**: 2026-11-11
**Lesson**: To read an in-page suite's result from Chrome without Node or a DevTools client, run Chrome headless with `--enable-logging=stderr --log-level=0` and turn on QUnit's own TAP reporter in the page; each `console.log` reaches stderr as `INFO:CONSOLE:<line>] "<message>", source: ...`.

**Why**: Probes run headless with a throwaway profile (no focus taken, no tab left), and the matrix allows no Node, so there is no Puppeteer or CDP client; `--dump-dom` dumps at load, before an async suite ends. QUnit 2.24 reports TAP when `QUnit.config.reporters.tap = true` is set before `QUnit.start()`, and it colours the lines with ANSI escapes.

**What Happened**: Lane fw1 b3's first Chrome run waited its whole 300 s for an end line that had been printed at 55 s: the waiter looked for `# fail N` and `CONSOLE(N)`, but Chrome 157 writes `CONSOLE:N]` and the TAP summary was `# \e[31mfail 9\e[39m`. macOS's BSD `sed` does not read `\x1b` in a pattern, so stripping the escapes with it silently did nothing.

**Fix**: `perl -pe 's/\e\[[0-9;]*m//g'` before matching `"# fail [0-9]*"`; extract lines with `grep -o 'CONSOLE:[0-9]*\] ".*'`. Add `--disable-background-networking --disable-component-update`, or Chrome starts its updater from the probe. Kill Chrome and the page's server by their own pids; delete the profile.

**Takeaway**: **Headless Chrome's stderr is the result channel for an in-page suite: TAP on, ANSI stripped with perl (not BSD sed), matched on `CONSOLE:<n>]`.**
