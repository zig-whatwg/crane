//! V8's page pool: a V8 BUILD option, `-Dv8-memory-pool-timeout-s` (declared
//! by engine_build.zig).
//!
//! When a collection frees a page of V8's heap, V8 15.7 does not give it back
//! to the operating system. It keeps it in a pool - `MemoryPool`, one for the
//! process, shared by every isolate in it (15.7.112.43 src/heap/memory-pool.h:
//! 69-73: heap pages, large pages up to 32 MB, the compilers' zone
//! reservations) - so that the next page any isolate needs comes without a
//! system call and without first-touch faults, and a worker's isolate can
//! start on the pages another's gave up (memory-pool.h:97-102). A task
//! empties the pool of what has waited `memory_pool_timeout` seconds, 8 by
//! default, so a freed page goes back 8 to 16 seconds after the collection
//! that freed it (memory-pool.cc:491-528); a memory-pressure notice empties
//! it at once (heap.cc:1265-1284). V8 13.1 pooled semispace pages only and
//! released them at every full collection.
//!
//! So in the seconds after a burst of work a process's footprint is V8's
//! heap PLUS what the pool holds, and a footprint read then is higher than
//! on V8 13.1 though the heap is not. The build can say otherwise:
//!
//!     zig build ... -Dv8-memory-pool-timeout-s=<seconds>
//!
//!   | -Dv8-memory-pool-timeout-s | V8 is started with        | what it is                          |
//!   |----------------------------|---------------------------|-------------------------------------|
//!   | not given                  | nothing                   | THE DEFAULT, `default_timeout_s`:   |
//!   |                            |                           | V8's own - the pool, 8 s. What      |
//!   |                            |                           | Chrome ships                        |
//!   | 0                          | --no-memory-pool          | no pool: a freed page goes back to  |
//!   |                            |                           | the operating system at once        |
//!   | n (1 and up)               | --memory-pool-timeout=n   | the pool, a page kept n to 2n s     |
//!   |                            |                           | (8 is V8's own value as a number)   |
//!
//! (V8 reads its own flag at 0 another way - "empty the pool when a full
//! collection starts", heap.cc:968-980, the pool itself staying. That mode
//! has no value here: nothing measured it against the two above; it is one
//! `-Dv8-extra-flags` away for whoever wants to.)
//!
//! THE DEFAULT IS V8'S OWN, and a default build passes V8 NO flag for it (the
//! user's ruling, 2026-11-13: "Option, Chrome default"): Chrome 157 ships the
//! pool on at 8 s - gin sets neither flag; its one switch for the pool is
//! kV8MemoryPoolReleaseOnMallocFailures, off (Chromium 157.0.8103.50
//! gin/gin_features.cc:93-94) - and nothing a default build measures moves
//! because this option exists. A host that wants the memory back sooner - a
//! server running many short-lived pages, where 8 to 16 seconds is a page's
//! whole life - builds with 0.
//!
//! Measured (lane v8up b8; chat.local, macOS, apple_m1; one console, the
//! flags as arms, the perf suite's 48 workloads, 7 alternating runs;
//! geometric means against V8's own, memory read at the suite's steady mark,
//! 0.5 s after each workload):
//!
//!   | pool           | time   | instructions | steady memory | peak   | rows over 1.03 of V8 13.1 |
//!   |----------------|--------|--------------|---------------|--------|---------------------------|
//!   | V8's own (8 s) | 1      | 1            | 1             | 1      | 25 of 48                  |
//!   | 1 s            | 0.9981 | 0.9976       | 0.9586        | 0.9646 | 21                        |
//!   | off (0)        | 0.9996 | 1.0007       | 0.9118        | 0.9359 | 16                        |
//!
//! Off, one row moved over 3% on time or instructions: fetch.loopback-json,
//! +0.8% instructions (fresh pages faulted in for its 4 MB bodies). The rows
//! it took back are the ones that free the most just before the mark:
//! fetch.loopback-stream 102.7 -> 69.5 MB, the streams page's four later rows
//! 381-386 -> 200-210 MB, timers.queue-microtask 77.8 -> 50.4 MB. At 1 s only
//! the rows whose workloads outlast the heartbeat moved: the mark is read at
//! 0.5 s. Ten seconds after the work the three read the same.
//!
//! What that suite does not measure is what V8 built the pool for: isolates
//! started and stopped (V8's own figure for the shared pool: JetStream
//! bomb-workers +3% on an M1, +4.5% on a Pixel 6, V8 f96fb79e95a; large
//! pages +0.3%, e5a7515627d), and another operating system's cost of mapping
//! and faulting a page. tests/perf/workloads/workers.html is the suite's
//! workload for the first, from round 8.
//!
//! Why a build option of this adapter and not an option of the engine
//! protocol: it is one engine's allocator. JavaScriptCore's public API has no
//! such switch and QuickJS takes its memory from malloc; and V8 reads its
//! flags once, when it starts, for the whole process - not per isolate, and
//! not at run time (the same reasons as young_generation.zig's). It is in
//! V8's flag string because V8 offers no other way: MemoryPool's
//! configuration is read from v8_flags when the isolate group is made
//! (src/init/isolate-group.cc:211-218), and the public API has nothing for
//! it.

const std = @import("std");
/// The adapter's own build options: declared by engine_build.zig, in an
/// options module only the engine adapter's module imports.
const adapter_options = @import("adapter_options");

/// THE DEFAULT, for a build that does not say: seconds, in
/// `-Dv8-memory-pool-timeout-s`'s unit; null is V8's own pool and timeout -
/// no flag at all. ONE constant, so the choice is one line. Null is the
/// user's ruling (2026-11-13): what Chrome ships.
pub const default_timeout_s: ?u32 = null;

/// What this build was given: `-Dv8-memory-pool-timeout-s` (null: not given).
pub const requested_timeout_s: ?u32 = adapter_options.memory_pool_timeout_s;

/// What this build adds to the flags V8 starts with - at run time and at
/// snapshot generation alike (snapshot_loader.zig `RUNTIME_V8_FLAGS`): empty,
/// or one flag led by the space that joins it to the set.
pub const flag: []const u8 = flagFor(requested_timeout_s orelse default_timeout_s);

/// The flag of a pool whose pages wait `timeout_s` seconds (null: V8's own
/// pool, no flag; 0: no pool), as V8 15.7.112.43 spells it
/// (src/flags/flag-definitions.h:2856-2863: `memory_pool`, a bool;
/// `memory_pool_timeout`, a size_t of seconds).
pub fn flagFor(comptime timeout_s: ?u32) []const u8 {
    const seconds = timeout_s orelse return "";
    if (seconds == 0) return " --no-memory-pool";
    return std.fmt.comptimePrint(" --memory-pool-timeout={d}", .{seconds});
}
