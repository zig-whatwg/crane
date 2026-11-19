# Testing: A test that waits one turn races a step that went parallel

**Date**: 2026-11-19
**Lesson**: When a change makes a step asynchronous - a fetch that used to complete at insertion now runs in parallel - every native test that waits a fixed number of event-loop turns for that step becomes a race, red only on a loaded host.

**Why**: `runEventLoopBlocking(20)` returns when 20 ms pass or the loop has no pending work. While a script fetch completed synchronously at insertion, one call always found the script run. Once the fetch runs in parallel and the run is queued from the task that delivers its response, the same call is a deadline: on an idle host the response beats it, on a loaded one it does not.

**What Happened**: dom1's 8898f7c003a made a script-inserted external SVG script force-async (SVG 2 15.2, as HTML's), which fixed execution-timing/136.html. tests/html/sc1_svg_current_script_test.zig still waited one `page.turn()` after inserting three `data:` SVG scripts. css2's macOS gate at main+css2 read "0::true" - none of the three had run. css2's run was tests-html at batch 1 - 2,922 test processes in 393 s on 8 cores - and the test failed in its batch and once more alone. Away from that load the old test passed test-verify 10/10 batched and 5/5 alone, once under TSAN, and 10/10 + 5/5 beside a busy Browser (-Dmany-browsers): the race needs a loaded host, so the merge's own gates never saw it.

**Fix**: Wait for the state the assertion reads, bounded: the test now runs the loop until `sc1SvgLoaded` reaches 3 (at most 500 turns of 20 ms) and then checks the same expectation (a3c73d7ac38). The pattern is the `runUntil` helper several tests/html files already carry (coi1, gs2, nav2): evaluate the condition, turn the loop, repeat to a bound.

Related: [a sweep round bounded by one loop turn ends the sweep early under load](testing-a-sweep-round-bounded-by-one-loop-turn-ends-the-sweep-early-under-load.md) - the same fixed-time wait, there in an out-of-memory sweep.

**Takeaway**: **A change that moves a step off the inserting call (parallel fetch, a queued task) must grep the native tests that wait a fixed number of turns for it, and make each wait for the condition it asserts, not for a turn.**
