# Workflow: A second module graph of the target's own platform must be private

**Date**: 2026-11-05
**Lesson**: build.zig's `addCraneModules` registers a graph's modules by name (`b.addModule`) when the graph's platform is `config.public_platform`; a second graph built for the target's own platform (another optimize mode) must set `public_platform` to another platform, or the configure step panics on the duplicate name before anything compiles.

**Why**: `graphModule` is `b.addModule(name, ...)` for the public graph and `b.createModule(...)` otherwise, and `addModule` asserts each name once. The WPT runner's own graph never hit this because it is the `.testing` platform's, which is not the target's.

**What Happened**: Lane perf0 gave the console (`repl`) a release graph of its own under `-Dwpt-runner-release` (`addCraneModules(b, target, target_platform, repl_config)`, copied from the runner's). The first `zig build repl-exe -Dwpt-runner-release` died in the configure process (`configure command terminated with signal ABRT`, at the `addCraneModules` call) in 0.4 s.

**Fix**: `repl_config.public_platform = if (target_platform == .testing) .darwin else .testing;` with a comment that the graph is private; then build the new mode once before relying on it.

**Takeaway**: **A graph that is not the public one says so through `public_platform`; any new graph of the target's platform is a configure panic until it does.**
