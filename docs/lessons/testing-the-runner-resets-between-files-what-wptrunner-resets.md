# Testing: The runner resets between files what wptrunner resets - automation overrides too

**Date**: 2026-11-08
**Lesson**: A file whose flake was fixed once can flip again for a second cause. permissions/permissions-cg.https.html's second cause was an automation override - a test_driver.set_permission - that an earlier file in the same runner process left behind. wptrunner's Chrome executor resets those overrides before every test, and Crane's runner did not.

**Why**: One Browser serves every file of a runner process (up to 40). The runner cleared only the cookie jar between files, and the Browser's permission store (src/permissions/browser_store.zig, its OverrideStore) kept every override any file set. permissions/event-model.https.html ends with geolocation set to "granted" and never resets it. permissions-cg reads the initial state, adds a change listener and sets "granted": an override that changes nothing fires no change event, so the test waits until its harness timeout. wptrunner's ChromeDriverTestharnessProtocolPart.reset_browser_state (tools/wptrunner/wptrunner/executors/executorchrome.py) sends CDP Browser.resetPermissions before every test, from close_old_windows. Chromium implements it as PermissionControllerImpl::ResetPermissionOverrides: the overrides are dropped, then NotifyChangedSubscriptions runs. A Chrome run never sees the leftover. Firefox's and Safari's executors reset nothing, and wpt.fyi shows them TIMEOUT and ERROR on this file.

**What Happened**: Generation 208's flip was a real bug: PermissionStatus was not kept while it had a change listener. Lane listen1 fixed that, and the file was recorded `kind = fixed`. It flipped again in generation 210 (OK -> TIMEOUT). Generation 210's per-process report (`wptreport-journal.shard5-s26.json`) showed event-model at position 21, midi-permission at 22 and permissions-cg at 23. Measured on generation 210's runner (chat2, `wpt_runner --repeat`, one process per run):
- the pair [event-model, permissions-cg] in one process: 20/20 TIMEOUT;
- permissions-cg alone: 0/20;
- the process slice (19 files): 10/10 TIMEOUT.

**Fix** (lane flaky5): BrowserStore.resetOverrides follows Chromium's ResetPermissionOverrides. Each listener entry records the state it has without an override, so after the overrides are cleared every listener whose state changes is told so. TestDriver.resetPermissions, the CDP command's counterpart, is called beside the cookie jar's clear at each file's start. Red tests: tests/html/flaky5_permission_reset_test.zig ("expected null, found .granted"), and a runner-level case in tests/wpt_runner/ar3_command_lifetime_test.zig ("the previous test's override survived: granted").

**Takeaway**: **When a sweep-only flake is state an earlier file left in its process, compare the runner's between-file reset with what wptrunner's executors do (reset_browser_state) - permissions, not only storage - and reset through the automation's own path, as Chrome's executor does.**
