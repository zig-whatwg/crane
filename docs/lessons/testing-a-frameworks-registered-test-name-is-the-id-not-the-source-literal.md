# Testing: A framework's registered test name is the test's id, not the string in its source

**Date**: 2026-11-11
**Lesson**: Exclusion lists and filters that name a framework's tests must use the names the framework registered at run time (QUnit.config.modules[].tests, Mocha's suite tree), never the title literal read from the test file: the framework rewrites some names, and loops build others.

**Why**: QUnit gives two tests of one module the same name only once: the second is renamed by appending a space (qunit.js, Test: `this.testName += ' '`). Loops build names from data (`"jQuery.ajax() - " + type + " support" + label`). A filter regex anchored on the source's literal (`^(?:...)$`) misses the renamed or built test, which then runs instead of being excluded - silently.

**What Happened**: Lane fw1 b2 built jQuery 4.0.0's needs-server list from the test sources. `ajax.js` defines "gh-2587 - when content-type not xml, but looks like one" twice (lines 2502, 2519); the run's journal had a second test of that name ending in a space, which the list lacked, and offset.js's two "absolute" tests did the same. Dynamic names (If-Modified-Since/Etag x cache/no cache, method/type set globally) only exist as QUnit registered them.

**Fix**:
1. Read the registered names from the page (the reader prints QUnit.config.modules / Mocha's `fullTitle()` of every test, run or not).
2. Build each list entry from those names (matching a dynamic title's literal prefix within its module), and let the tool fail when an entry names no registered test (`fw_matrix` checks every entry against the page's `defined` list on every run).
3. A name ending in a space gets a comment in the list saying why: the space is invisible.

**Takeaway**: **Name a framework's tests the way the framework does at run time, and check every exclusion against that registry on every run.**
