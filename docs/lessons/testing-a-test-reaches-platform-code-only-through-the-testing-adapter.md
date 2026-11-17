# Testing: A test reaches platform code only through the testing adapter - a pure rule goes in the kit, an adapter's own behaviour in the conformance file

**Date**: 2026-11-17
**Lesson**: Every test under tests/ is bound to the testing platform, and a platform adapter is a module of its own directory, so code written inside the darwin or linux adapter cannot be imported by any test: decide where a new platform behaviour will be tested BEFORE choosing the file it lives in.

**Why**: build.zig gives tests `platform` (the facade) and through it `platform.adapter`, which in a test build is the testing adapter's `protocol` namespace. The testing adapter cannot `@import("../linux/x.zig")` - a file outside a module's root directory is not importable - and the kit modules are imported only by adapters. The one test file build.zig binds to each built-in adapter (one executable per binding) is tests/platform/protocol_conformance_test.zig, which uses only the facade.

**What Happened**: Lane mp1's approved design put the Linux memory-pressure rule (the text of /proc/meminfo -> normal, warning, critical) in src/platform/adapters/linux/memory_pressure.zig and its test in tests/platform. The test could not reach it. Nor could any test start the real observers (the darwin dispatch source, the linux poller thread): the testing adapter has none by design, so `zig build test` would never have run their start and stop - only WPT runs and the console would. Both needed a grant from the integrator, asked for after the design was approved.

**Fix**:
1. A pure rule an adapter needs goes in the kit (src/platform/kit/posix/meminfo.zig), which every adapter imports; the testing adapter exposes it as a test control (`platform.adapter.memoryPressureLevelOfMeminfo`), and tests/platform calls that.
2. An adapter's own run-time behaviour - an observer's start and stop, a thread's join - is tested in protocol_conformance_test.zig through the facade alone (createBrowserPlatform / destroyBrowserPlatform with a counting EventSink), so the same test runs against every binding, and against the real darwin and linux code on their own hosts.
3. An event a test needs is posted through a testing-adapter control that calls the same EventSink an observer calls (`platform.adapter.postEvent`), never through a path of the test's own into Crane's receiver.

**Takeaway**: **For platform work, name the test's route in the design: kit + a testing-adapter control for a pure rule, the per-adapter conformance file for what only a real adapter does.**
