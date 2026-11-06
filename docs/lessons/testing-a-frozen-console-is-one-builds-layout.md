# Testing: A frozen console is one build's layout - rebuild both sides on the timing host before chasing a gap

**Date**: 2026-11-06
**Lesson**: A sub-microsecond row can differ by 13% between two frozen release consoles whose instructions per operation agree within 0.5%. That is the layout of one build, and the pool makes layouts vary twice over: any source change moves code, and a build on another pool host is compiled for that host's CPU with its SDK. Before you profile, bisect or align anything, rebuild both sides on the host that times them, and count instructions retired.

**Why**:
- `build.zig` calls `b.standardTargetOptions(.{})` with no default, so every build targets the CPU of the host that compiles it: chat2 is an Apple M2, chat.local an Apple M4 Pro. The hosts also differ in SDK and linker (chat2: Xcode's 27.0 SDK, ld-27037.1; chat.local: the 27.2 Command Line Tools, ld-27106.1).
- crane-remote.sh places a build on whichever host has a free slot, and a frozen console follows its mirror from host to host.
- Nothing records which CPU a console was built for. `repl.modes` names the optimize modes and the allocator; the perf_bench pin names the commit, the build line and V8; SHA256SUMS prove a file is unchanged, not how it was made.

So a "tip against main" pair can compare binaries from two hosts while both read as "ReleaseSafe, libc malloc".

**What Happened**: Lane perf2's Crane-only perf window put dom.getter-loop (`el.id` over 16 elements) at +13.4% for the tip: 0.1081 against main's 0.0953 us/op, the 7 runs per side disjoint. Main was flat against round 0, and perf2's diff touched nothing on that path. A `sample` profile put the extra time in `InstanceRegistry(.element).get`, which was byte-identical in both binaries (272 bytes) but at another address. Batch 1 disproved two hypotheses (main's own delta; the hash layout, by padding the page with 0-13 elements) and escalated.

Batch 1b measured:
- Table state, with a temporary instrumented `get` in both trees: during the loop both tables read the same. Mean extra probe 0.250 per get; cap 262,144; about 21,000 live; 235,000 free; meanMissProbe 0; the same seed.
- Instructions retired per iteration (a page of 2,000,000 iterations minus a 0-iteration control, 7 rounds, `/usr/bin/time -l`): 2,550-2,565 in every console below. No new work anywhere.
- The binaries: the frozen tip had been built on chat2 by perf2's PRE gate, while main and round 0 had been built on chat.local. Code shape follows the host. A chat2 build of either tree has about 51 KB more `__text`, through other inlining decisions: `Element.call_hasAttribute` is 1,004 bytes against 596, `tables.check` 12,712 against 6,792. The function count and the function-alignment histogram are the same.
- A quiet chat.local window, each console against main's chat.local console, 7 alternating runs:

| console (built on) | suite getter-loop, us/op vs main | bare-page cycles vs main |
|---|---|---|
| tip (chat2), the frozen one | 0.1062 vs 0.0944 (+12.6%) | +15.4% |
| main (chat2), the same source as the base | 0.0950 vs 0.0944 (+0.6%) | +1.4% |
| tip (chat.local) | 0.0944 vs 0.0950 (-0.6%) | -0.05% |
| tip (chat.local) with `get` `align(64)` | 0.0944 vs 0.0947 (-0.3%) | +17.7% |

Main built on chat2 is not slower, so the M2 target does not make a build slow by itself. The chat2 build of the tip landed a slow layout. The chat.local build of the same tip did not, and it is the product. Aligning the hot function was no fix: it was neutral on the suite page and 17.7% slower on the bare page, where the probe loop iterates (cap 32 at 75% load).

**Fix**:
1. A gap in a sub-microsecond row first gets the check from [A cost bar that moves with no new instructions is code placement](testing-a-cost-bar-that-moves-with-no-new-instructions-is-code-placement.md): instructions retired, page minus a control. Within 0.5%, there is no new work.
2. Then rebuild BOTH consoles on the host that times them, from the two trees, and time those. A row that moves only between builds from two hosts is the layout lottery, not the change.
3. Never "fix" a layout accident with `align(N)` without timing it on more than one page: an alignment moves the hot loop's boundary as well as its entry.
4. Hygiene, queued for lane perf2's batch 2 (the user decides a fixed target, because it also affects the published comparison with the browsers): build every console of a window on its timing host, or with one pinned `-Dcpu`; record the target CPU in `repl.modes` and the journal's build identity; have `perf_bench check` refuse pins whose targets differ.

**Takeaway**: **Two builds of one source are two layouts, and a build from another pool host is also another CPU target: when a sub-microsecond row moves with the same instructions, rebuild both sides on the timing host before you profile, bisect or align anything.**
