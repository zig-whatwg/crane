# Testing: A test that reads a checked-in file at run time stays cached when only that file changes

**Date**: 2026-11-24
**Lesson**: A test run step is cached on its executable's bytes (the launcher's default seed, "digest"). So a test that reads a checked-in data file at run time - tests/wpt_runner/config.zig's "the directory allowlist matches every directory in the generated worklist" reads tests/wpt_0_1_worklist.txt - is not re-run when a commit changes only that file, unless the file is an input of its run step.

**Why**: Zig's build cache reruns a step when its declared inputs change. The worklist is read with readFileAlloc inside the test, invisible to the build graph, so an unchanged wpt_runner test executable keeps its cached "passed".

**What Happened**: Lane a11y1's worklist commit caba1dcf7 added core-aam/, dpub-aam/, graphics-aria/ and svg-aam/ files without adding the directories to the runner's allowlist (the lesson workflow-a-new-worklist-directory-joins-the-runners-allowlist-too). The lane's merged-tree gates on server1 and chat.local passed: their test.log shows `+- test wpt_runner-config cached`, because no wpt_runner source had changed since that mirror's previous gate. Main's next merge gate (lane mcp1's), with a different cache, failed the test in each of the 8 wpt_runner suites on both OSes.

**Fix**: Add the directories to `in_scope_categories` (39024df2c). For the gap: the runner's harness suites now take the worklist as a run input (build.zig, `run_harness_tests.addFileInput(b.path("tests/wpt_0_1_worklist.txt"))`, 7c3bc1507), so changing only the worklist re-runs them. Any other suite that reads a checked-in file at run time needs the same declaration (the integrator's audit); until it has one, gate a change to that file with `zig build test -Dspec=<dir> -Dlaunch-seed=random` (never cached).

**Takeaway**: **A "cached" test in a gate's summary proves nothing about a data file the test reads at run time: when a commit changes such a file, rerun the tests that read it with `-Dlaunch-seed=random`, or make the file a declared input.**
