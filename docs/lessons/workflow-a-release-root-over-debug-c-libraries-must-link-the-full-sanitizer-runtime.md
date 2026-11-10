# Workflow: A release root over Debug C libraries must link the full sanitizer runtime

**Date**: 2026-11-04
**Lesson**: Every artifact whose root module is built in another mode than -Doptimize's links C libraries built in -Doptimize's mode - Debug by default, with Zig's full C sanitizer, so they call `__ubsan_handle_*`. Whether the UBSan runtime that defines those is linked is the ROOT's choice: Debug's default is the full runtime, ReleaseSafe's is `.trap`, which links none. A ReleaseSafe root over Debug C libraries fails to link.

**Why**: Zig compiles each C library with its own module's sanitizer setting and links the runtime only for the root's. The WPT runner never hit it because it builds its own C libraries in its own mode (`RunnerModes.ownCLibraries`, a graph of its own) and sets `sanitize_c = .full` on its root (tests/wpt_runner/build_mode.zig).

**What Happened**: lane console2 made the console ReleaseSafe by default (e46837f0dc1) and its first build stopped at the link: undefined `___ubsan_handle_mul_overflow` and seven more, from libbrotli. 8495b5a7b2a set the console root's `sanitize_c` from the runner's rule. The next batch (console3) fixed the snapshot generator's mode to Debug with a `-Dsnapshot-generator-optimize` override, and the first `=ReleaseSafe` build of it failed the same way, ten minutes into the compile.

**Fix**: any root whose mode can differ from the C libraries' asks for the full sanitizer in the safe modes: the console through `runner_build_mode.runnerModes(...).sanitize_c`, the generator through `tools/snapshot_generator_mode.zig` `sanitizeC` (ReleaseSafe: `.full`; Debug: Zig's default, already full; the fast modes: none). Pinned by each file's tests.

**Takeaway**: **Giving an artifact a root mode of its own is two decisions, not one: the optimizer, and which sanitizer runtime the root links for the C libraries it did not build. Make both from the same rule, and build each new mode once before relying on it.**

**Status 2026-11-10 (lane buildfix1):** "every runner bundles the runtime" is now "only a build whose C is compiled with the full sanitizer bundles it": the production WPT runner and the release console link none (tools/ubsan_symbols.zig checks it on each binary). See workflow-a-memoized-dependency-is-one-artifact-for-every-graph-that-asks-alike.md.
