# Testing: Open a project's test pages at the URL its own runner builds, host included

**Date**: 2026-11-14
**Lesson**: A framework suite can register tests by the page's host name; open its pages at the exact URL its own runner opens (jquery-test-runner: `http://localhost:<port>/test/?module=<m>`), or a test silently becomes "skipped by the project".

**Why**: jQuery's "jQuery.append with crossorigin attribute" is `QUnit[ location.hostname === "localhost" ? "test" : "skip" ]`: it needs a second origin, and reaches it by rewriting "localhost" to "127.0.0.1" (both name the test server). The harness opened every page at 127.0.0.1, so the suite skipped the test itself and the matrix counted it as "skipped by the project" for three batches - nothing failed, nothing said why.

**What Happened**: In fw1 b4 the pages moved to jQuery's own test server and to the URL its runner builds (`lib/buildTestUrl.js`: host "localhost", path "/test/" - the exact path its server also decorates). The one project-skipped jQuery test ran and passed; the 118 tests that needed the server passed too (one moved to rendering).

**Fix**: The manifest's `server.host` (default "localhost") names the host the page URLs use; the readiness check still asks 127.0.0.1. When a suite has a "skipped by the project" count, read each skip's condition at the tag before accepting it.

**Takeaway**: **A page's host and path are part of the test: use the URL the project's own runner builds, and read every project skip's condition.**
