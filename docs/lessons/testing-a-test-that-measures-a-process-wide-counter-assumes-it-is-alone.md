# Testing: A test that measures a process-wide counter assumes it is alone in its process

**Date**: 2026-11-02
**Lesson**: A test that reads a process-wide count (live Global handles, live agents, mapped memory) before and after its own work, and fails on a difference, assumes no other instance runs in the process; beside a second Browser it fails, though nothing it did leaked.

**Why**: Crane runs many Browsers on many threads of one process (docs/instances.md). Every engine counter the Crane test runner and the leak tests read - `engine.live_*`, global handle bytes, `BrowserScope.liveCount()`, the process's mapped memory - counts every instance in the process, not the test's.

**What Happened**: Lane tsan1 ran tests-v8 beside a busy Browser on another thread (-Dmany-browsers). Fifteen tests failed or flaked with "left 1 Context Globals", "weak records 0 -> 401", "live_agents expected 1, found 2", "3211264 bytes ... newly mapped over 32 worker threads": context_counter_test (12), indexed_property_semantics_test, realm_end_finalize_test, diagnostic_live_counters_test, worker_thread_state_test and others. Each passed alone. Nothing they made leaked; the busy Browser's own iterations moved the same counters while they measured. The runner's own state check avoids this by holding the busy Browser between iterations while it reads; a test's in-flight measurement cannot.

**Fix**: Measure what the test owns - a count kept per agent or per realm - or declare the test a process measurement, so a variant holds or skips the second instance for it (V8 does: `'d8/d8-os': [SKIP]` in mjsunit.status's isolates section). Findings: docs/testing/test-variant-findings-2026-11-02.tsv (M2).

**Takeaway**: **A count the whole process shares is not a test's to compare. Count per agent, or declare the test needs the process to itself.**
