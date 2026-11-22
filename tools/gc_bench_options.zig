//! gc_bench's per-cycle script, chosen from its command line.
//!
//! One cycle runs one statement, in a loop of fresh scripts (gc_bench.zig
//! explains why fresh). By default it is `document.createElement` and discard
//! - the Phase 6 criterion - or, under `--control`, a plain JS object of about
//! a wrapper's cost. `--body=<script>` replaces the statement, so the same
//! counters measure any per-call cost: a getter that leaks a handle per read
//! shows up as +1.00 per cycle in the live-handle counters.
//!
//! Kept apart from gc_bench.zig, which links the engine, so its rules are
//! tested on their own.

const std = @import("std");

/// The statement each cycle runs.
pub const default_body = "void document.createElement('div');";
/// `--control`'s: shaped to cost the engine about what a wrapper does - an
/// object with a couple of properties - while touching no DOM state at all.
pub const control_body = "void ({ a: i, b: 'x' });";

const body_flag = "--body=";

/// The configuration of gc_bench's allocator, the Browser's (unless
/// `--c-alloc` swaps in malloc): the DebugAllocator defaults with no stack
/// traces, as the WPT runner's sweep allocator has (runner_allocator.zig).
///
/// Not the Debug-mode default of six frames. Zig 0.16's
/// `std.debug.captureCurrentStackTrace` on aarch64-macos leaks the DWARF
/// unwinder's state on every capture: `StackIterator.next` switches to
/// frame-pointer unwinding (`it.* = .{ .fp = fp }`, lib/std/debug.zig:1056)
/// without deinit'ing the SelfUnwinder it replaces, so its CFI VM columns
/// and stack - about 830 B - stay in std.debug's page_allocator arena (VM
/// that vmmap shows as "Untagged", outside malloc and outside this
/// allocator's own count). A DebugAllocator that captures a trace on every
/// alloc and every free turned each Zig allocation a measured call made
/// into RSS that never came back: `e.hasAttribute("title")` read 660 B per
/// call, and every DOM call with a string argument or result looked like a
/// leak while nothing leaked.
pub const allocator_config: std.heap.DebugAllocatorConfig = .{
    .stack_trace_frames = 0,
    .safety = true,
};

/// The statement a cycle runs, from gc_bench's arguments (`args[0]` is the
/// program): the last `--body=<script>` if any - a non-empty one - else the
/// control's under `--control`, else the default. The result borrows from
/// `args` or is static.
pub fn cycleBody(args: []const [:0]const u8) []const u8 {
    var body: ?[]const u8 = null;
    var bench: ?*const Bench = null;
    var control = false;
    for (args[@min(1, args.len)..]) |arg| {
        if (std.mem.startsWith(u8, arg, body_flag) and arg.len > body_flag.len) body = arg[body_flag.len..];
        if (std.mem.startsWith(u8, arg, bench_flag)) bench = benchNamed(arg[bench_flag.len..]);
        if (std.mem.eql(u8, arg, "--control")) control = true;
    }
    if (body) |b| return b;
    if (bench) |named| return named.body;
    return if (control) control_body else default_body;
}

const bench_flag = "--bench=";

/// A named measurement, `--bench=<name>`: a statement per cycle (gc_bench
/// runs it in its loop of fresh scripts) with the counts it is read at,
/// whether it collects, and what gc_bench reports for it beside its table.
/// Named so a phase's red test and its gate read the same thing as the base
/// it is compared with: the wrapper redesign's (tmp/redesign/
/// wrapper-redesign-design.md section 7, P0: `wide`, `qsa-deep`,
/// `wrapper-churn-nogc`, `pause`) and the breakdown's kept-node bodies
/// (tmp/plans/perf2b8-breakdown.md: `div`, `text`).
pub const Bench = struct {
    name: []const u8,
    /// What it measures, printed with its report.
    what: []const u8,
    /// The statement each cycle runs.
    body: []const u8,
    /// The counts when none are given (gc_bench <cycles> <every>).
    cycles: usize,
    every: usize,
    gc: Gc,
    /// Report the wrappers made per cycle: the engine's wrapper creations
    /// (its `object_globals_from.ObjectTemplate_NewInstance` counter) between
    /// the first and last reading, over the cycles.
    wrappers_per_cycle: bool = false,
    /// The row's shape, where its figure depends on it: how many node
    /// wrappers BELOW its kept tree's root are alive at every collection
    /// (`holdsShape`). Null: the row keeps no tree whose wrappers decide
    /// what it measures.
    kept_wrappers: ?usize = null,

    /// The node wrappers a run may keep beyond `kept_wrappers`: the tree's
    /// root, the document, and the last few a batch's loop still names when
    /// the reading is taken.
    pub const kept_wrappers_slack = 8;

    /// Whether a run held the row's shape: `kept`, the node wrappers alive
    /// at its last reading less those alive at its first (the engine's
    /// `node_wrappers` counter), is the tree's `kept_wrappers` and at most
    /// `kept_wrappers_slack` more. A row without a shape always holds it.
    ///
    /// Why a row has one (lane nm2's cost window, lesson
    /// testing-a-cost-row-that-wraps-and-forgets-is-two-valued.md): a
    /// wrapper script neither holds nor has added anything to may be dropped
    /// by a young collection, but one still there at the next full
    /// collection is promoted, and the walk over its tree keeps it from then
    /// on. A row that wraps a kept tree's elements and forgets them
    /// therefore ran with 2 wrappers or with about 6,000, by which
    /// collection came first, and read two values on one binary.
    pub fn holdsShape(self: *const Bench, kept: i64) bool {
        const want = self.kept_wrappers orelse return true;
        const least: i64 = @intCast(want);
        return kept >= least and kept <= least + kept_wrappers_slack;
    }

    /// Whether a run collects before each reading (gc_bench's `--gc`).
    pub const Gc = enum {
        /// As `--gc` says.
        either,
        /// Always: the bench reads what is kept, so garbage must not count.
        forced,
        /// Never: the bench reads what the engine's own schedule leaves, and
        /// `--gc` is refused.
        never,
    };

    /// Whether the run collects before each reading, given `--gc`.
    pub fn collects(self: *const Bench, gc_flag: bool) error{GcRefused}!bool {
        return switch (self.gc) {
            .either => gc_flag,
            .forced => true,
            .never => if (gc_flag) error.GcRefused else false,
        };
    }
};

/// Every named measurement.
pub const benches = [_]Bench{
    .{
        .name = "wide",
        .what = "a detached tree of 50,000 parsed (unwrapped) children, one of them wrapped and held by script; " ++
            "the full-collection pause with it alive (the design's decision 7: a walk over a held path's children)",
        .body = "void (globalThis.wide ??= (() => { const r = document.createElement('div'); " ++
            "r.innerHTML = '<p></p>'.repeat(50000); return r.lastChild; })());",
        .cycles = 100_000,
        .every = 10_000,
        .gc = .forced,
    },
    .{
        .name = "qsa-deep",
        .what = "a fresh parsed tree per cycle - 1,000 leaves at depth 12 under 119 ancestors - and " ++
            "querySelectorAll of its leaves, each read once: the wrappers one query makes",
        .body = "{ const c = document.createElement('div'); c.innerHTML = (globalThis.qsaDeepHtml ??= (() => { " ++
            "let s = '<b></b>'.repeat(10); s = ('<i>' + s + '</i>').repeat(10); s = ('<u>' + s + '</u>').repeat(10); " ++
            "for (let d = 0; d < 9; d++) s = '<div>' + s + '</div>'; return s; })()); " ++
            "const l = c.querySelectorAll('b'); for (let k = 0; k < l.length; k++) void l[k]; }",
        .cycles = 2_000,
        .every = 500,
        .gc = .either,
        .wrappers_per_cycle = true,
    },
    .{
        .name = "wrapper-churn-nogc",
        .what = "100,000 wrapped elements made and dropped, never a forced collection: the footprint " ++
            "and the full collections the engine's own schedule runs",
        .body = "void document.createElement('div');",
        .cycles = 100_000,
        .every = 10_000,
        .gc = .never,
    },
    // The full-collection pause over a kept tree, in the two fixed forms a
    // collector cannot change (lane tl2; lane nm2's finding): every element
    // wrapped and its wrapper MODIFIED - a wrapper script has added a
    // property to is never dropped by a young collection, so all 10,100 are
    // walked in every collection - and no element wrapped below the root.
    // Their difference is the walk's cost per wrapped node. Until
    // 2026-11-17 `pause` wrapped each element and forgot it (`void e`): 2
    // wrappers or about 6,000 survived, by which collection came first.
    .{
        .name = "pause",
        .what = "a detached tree of 10,100 elements, every one wrapped, its wrapper given a property (so no collection " ++
            "drops it) and kept by script through the root, and one element made and dropped per cycle: the full-collection pause",
        .body = "void (globalThis.pauseTree ??= (() => { const r = document.createElement('div'); " ++
            "r.innerHTML = ('<section>' + '<p></p>'.repeat(100) + '</section>').repeat(100); " ++
            "for (const e of r.querySelectorAll('*')) e.pauseKept = true; return r; })()); void document.createElement('span');",
        .cycles = 100_000,
        .every = 10_000,
        .gc = .forced,
        .kept_wrappers = 10_100,
    },
    .{
        .name = "pause-bare",
        .what = "the same detached tree of 10,100 elements kept by script through its root, none of them wrapped, " ++
            "and one element made and dropped per cycle: the full-collection pause over unwrapped nodes",
        .body = "void (globalThis.pauseTree ??= (() => { const r = document.createElement('div'); " ++
            "r.innerHTML = ('<section>' + '<p></p>'.repeat(100) + '</section>').repeat(100); " ++
            "return r; })()); void document.createElement('span');",
        .cycles = 100_000,
        .every = 10_000,
        .gc = .forced,
        .kept_wrappers = 0,
    },
    .{
        .name = "div",
        .what = "a wrapped div kept per cycle in a script array (a root): the bytes a kept div costs",
        .body = "(globalThis.keep ??= []).push(document.createElement('div'));",
        .cycles = 50_000,
        .every = 10_000,
        .gc = .forced,
    },
    .{
        .name = "text",
        .what = "a wrapped Text kept per cycle in a script array (a root): the bytes a kept Text costs",
        .body = "(globalThis.keep ??= []).push(document.createTextNode('x'));",
        .cycles = 50_000,
        .every = 10_000,
        .gc = .forced,
    },
    // The two rows where MUCH DIES in a full collection (lane dm1's design,
    // tmp/plans/dom-memory-figure-design.md 3.5 and 6, batch B's gate; the
    // integrator's ruling 1): the trees a full collection finds dead are
    // walked inside its pause, where their bytes leave the figure the engine
    // is told (dom.dying_trees), so the pause grows with what one collection
    // kills. `pause` and `wide` hold a tree ALIVE and kill one element a
    // collection; these kill whole trees, on the engine's own schedule.
    .{
        .name = "clone-drop",
        .what = "a clone of a detached tree of 841 nodes made and dropped per cycle, never a forced collection: " ++
            "the full-collection pause when the dead trees of one collection are walked inside it",
        .body = "void (globalThis.cloneSource ??= (() => { const r = document.createElement('div'); " ++
            "r.innerHTML = '<ul><li><a href=x>one</a> two</li></ul>'.repeat(168); return r; })()).cloneNode(true);",
        .cycles = 3_000,
        .every = 100,
        .gc = .never,
    },
    .{
        .name = "parse-drop",
        .what = "a tree of 101 nodes parsed, its child list read (a holder of its root that dies with it) and dropped " ++
            "per cycle, never a forced collection: the full-collection pause when many small dead trees are walked inside it",
        .body = "{ const e = document.createElement('div'); e.innerHTML = (globalThis.parseDropHtml ??= '<p>some text</p>'.repeat(50)); " ++
            "void e.childNodes.length; }",
        .cycles = 26_000,
        .every = 2_000,
        .gc = .never,
    },
    // The engine's in-sandbox allocator (lane ab1: Crane's own in the V8
    // adapter, src/runtime/engines/v8/sandbox_allocator.zig, in place of
    // V8's default): the blocks behind ArrayBuffers, freed in batches by the
    // engine's collections, and the engine's own short-lived blocks, each
    // freed inside the call that took it. Time them with the process's CPU
    // time; the table reads what the allocator keeps.
    .{
        .name = "sandbox-small",
        .what = "an ArrayBuffer of 96 bytes made, written and dropped per cycle, never a forced collection: " ++
            "the in-sandbox allocator's small blocks, taken one by one and freed by the engine's own collections",
        .body = "{ const b = new ArrayBuffer(96); new Uint8Array(b)[0] = 1; }",
        .cycles = 400_000,
        .every = 40_000,
        .gc = .never,
    },
    .{
        .name = "sandbox-bigint",
        .what = "the square of a 9,800-bit BigInt and its decimal string per cycle, never a forced collection: " ++
            "the engine's own in-sandbox blocks (BigInt scratch digits), each taken and freed inside one call",
        .body = "void ((globalThis.big ??= 7n ** 3500n) * globalThis.big).toString().length;",
        .cycles = 20_000,
        .every = 2_000,
        .gc = .never,
    },
    .{
        .name = "sandbox-chunks",
        .what = "a 64 KiB Uint8Array made, filled and dropped per cycle, never a forced collection: " ++
            "the in-sandbox allocator's stream-chunk-sized blocks, whose memory goes back to the OS and is used again",
        .body = "void new Uint8Array(65536).fill(1);",
        .cycles = 40_000,
        .every = 4_000,
        .gc = .never,
    },
    .{
        .name = "sandbox-megabyte-loop",
        .what = "a 1 MiB ArrayBuffer made, written at both ends and freed at once (transfer(0) detaches it) per cycle: " ++
            "the in-sandbox allocator's free-then-allocate loop, which makes no system call per cycle when the freed chunk waits",
        .body = "{ const b = new ArrayBuffer(1048576); const v = new Uint8Array(b); v[0] = 1; v[1048575] = 1; b.transfer(0); }",
        .cycles = 20_000,
        .every = 2_000,
        .gc = .never,
    },
};

/// The measurement named `name`, if there is one.
pub fn benchNamed(name: []const u8) ?*const Bench {
    for (&benches) |*bench| {
        if (std.mem.eql(u8, bench.name, name)) return bench;
    }
    return null;
}

/// The measurement gc_bench's arguments name (the last `--bench=<name>`), or
/// null for none. A name that is not one, or a `--bench=` beside a
/// `--body=` (which statement would run?), is refused.
pub fn benchOf(args: []const [:0]const u8) error{ UnknownBench, BenchAndBody }!?*const Bench {
    var name: ?[]const u8 = null;
    var body = false;
    for (args[@min(1, args.len)..]) |arg| {
        if (std.mem.startsWith(u8, arg, bench_flag)) name = arg[bench_flag.len..];
        if (std.mem.startsWith(u8, arg, body_flag)) body = true;
    }
    const given = name orelse return null;
    if (body) return error.BenchAndBody;
    return benchNamed(given) orelse error.UnknownBench;
}

/// gc_bench's positional count at `index` (1: cycles, 2: every), or
/// `default` when it is not given as a number.
pub fn countArg(args: []const [:0]const u8, index: usize, default: usize) usize {
    if (args.len <= index) return default;
    return std.fmt.parseInt(usize, args[index], 10) catch default;
}

const batch_flag = "--batch=";

/// The cycles one fresh script runs when `--batch=` does not say.
pub const default_batch: usize = 5000;

/// The cycles each fresh script runs - one script is one task of the page,
/// with the collection and the loop's turns (`--gc`, `--loop`) after it:
/// the last `--batch=<n>` with a positive `n`, else `default_batch`. A
/// workload that runs K operations in one task (a benchmark page's timed
/// `run(K)`) is read with `--batch=K`: what dies inside a task is torn down
/// only after it (runtime.gc.DeferredTeardown), so the batch decides the
/// peak (lane mem1).
pub fn batchSize(args: []const [:0]const u8) usize {
    var size: usize = default_batch;
    for (args[@min(1, args.len)..]) |arg| {
        if (!std.mem.startsWith(u8, arg, batch_flag)) continue;
        const n = std.fmt.parseInt(usize, arg[batch_flag.len..], 10) catch continue;
        if (n > 0) size = n;
    }
    return size;
}

/// Whether a reading waits until what the batch left dead is freed
/// (`--settle`): after the collections, the event loop turns until idle and
/// the engine collects again, twice, so the trees those collections found
/// dead - which the agent's queue frees between tasks - are gone before the
/// counters are read, and a reading is what the page KEEPS. Without it the
/// last collection's dead trees still wait in the queue at the reading (the
/// loop turns before the collection), which is how the published rows have
/// always read, so it is opt-in (lane mem1).
pub fn settlesBeforeReading(args: []const [:0]const u8) bool {
    for (args[@min(1, args.len)..]) |arg| {
        if (std.mem.eql(u8, arg, "--settle")) return true;
    }
    return false;
}

/// Whether the run ends with the Browser's live platform objects counted by
/// interface (`--live-types`): the "live objects" column says how many
/// there are, this says WHAT they are - two builds' lists side by side name
/// the type one of them keeps (lane mem1).
pub fn listsLiveTypes(args: []const [:0]const u8) bool {
    for (args[@min(1, args.len)..]) |arg| {
        if (std.mem.eql(u8, arg, "--live-types")) return true;
    }
    return false;
}

/// Whether each batch's script is followed by turns of the page's event
/// loop until it has nothing left to do (`--loop`): without it nothing a
/// cycle queues - a timer, a port's message, a task - ever runs, since the
/// batches are host scripts run back to back. With it the timers, messages
/// and tasks a batch queued have all run before the next batch and before
/// the reading, which is what a body measuring the loop needs (lane
/// timerheap1's timer row: one 0 ms timer a turn).
pub fn drivesLoop(args: []const [:0]const u8) bool {
    for (args[@min(1, args.len)..]) |arg| {
        if (std.mem.eql(u8, arg, "--loop")) return true;
    }
    return false;
}

/// Whether the cycle is gc_bench's own control run: `--control` with no
/// `--body` overriding it.
pub fn isControl(args: []const [:0]const u8) bool {
    return std.mem.eql(u8, cycleBody(args), control_body);
}

test "no flags: the createElement criterion" {
    try std.testing.expectEqualStrings(default_body, cycleBody(&.{"gc_bench"}));
    try std.testing.expectEqualStrings(default_body, cycleBody(&.{ "gc_bench", "20000", "5000", "--gc" }));
    try std.testing.expectEqualStrings(default_body, cycleBody(&.{}));
    try std.testing.expect(!isControl(&.{ "gc_bench", "--gc" }));
}

test "--control: the plain object" {
    try std.testing.expectEqualStrings(control_body, cycleBody(&.{ "gc_bench", "--control" }));
    try std.testing.expect(isControl(&.{ "gc_bench", "1000", "--control" }));
}

test "--body= replaces the statement, wherever it is and whatever else is given" {
    const script = "void document.documentElement.ownerDocument;";
    try std.testing.expectEqualStrings(script, cycleBody(&.{ "gc_bench", "20000", "5000", "--body=" ++ script }));
    try std.testing.expectEqualStrings(script, cycleBody(&.{ "gc_bench", "--body=" ++ script, "--gc" }));
    // It wins over --control, and the run is then not the control.
    try std.testing.expectEqualStrings(script, cycleBody(&.{ "gc_bench", "--control", "--body=" ++ script }));
    try std.testing.expect(!isControl(&.{ "gc_bench", "--control", "--body=" ++ script }));
    // The last one given.
    try std.testing.expectEqualStrings("b;", cycleBody(&.{ "gc_bench", "--body=a;", "--body=b;" }));
    // An '=' inside the script is the script's.
    try std.testing.expectEqualStrings("x = 1;", cycleBody(&.{ "gc_bench", "--body=x = 1;" }));
}

test "--loop turns the event loop after each batch, wherever it is given; nothing else does" {
    try std.testing.expect(!drivesLoop(&.{"gc_bench"}));
    try std.testing.expect(!drivesLoop(&.{ "gc_bench", "10000", "5000", "--gc" }));
    try std.testing.expect(drivesLoop(&.{ "gc_bench", "10000", "5000", "--loop" }));
    try std.testing.expect(drivesLoop(&.{ "gc_bench", "--loop", "--body=setTimeout(() => {}, 0);" }));
    // Inside a body it is the body's text, not the flag.
    try std.testing.expect(!drivesLoop(&.{ "gc_bench", "--body=--loop" }));
    // The program name is never read as a flag.
    try std.testing.expect(!drivesLoop(&.{"--loop"}));
    try std.testing.expect(!drivesLoop(&.{}));
}

test "--batch= sets the cycles one script runs; anything but a positive count leaves the default" {
    try std.testing.expectEqual(default_batch, batchSize(&.{"gc_bench"}));
    try std.testing.expectEqual(@as(usize, 8000), batchSize(&.{ "gc_bench", "16000", "8000", "--batch=8000" }));
    // The last one given wins, as --body='s does.
    try std.testing.expectEqual(@as(usize, 250), batchSize(&.{ "gc_bench", "--batch=1000", "--batch=250" }));
    try std.testing.expectEqual(default_batch, batchSize(&.{ "gc_bench", "--batch=0" }));
    try std.testing.expectEqual(default_batch, batchSize(&.{ "gc_bench", "--batch=x" }));
    try std.testing.expectEqual(default_batch, batchSize(&.{ "gc_bench", "--batch=" }));
    // Inside a body it is the body's text; the program name is never a flag.
    try std.testing.expectEqual(default_batch, batchSize(&.{ "gc_bench", "--body=--batch=7" }));
    try std.testing.expectEqual(default_batch, batchSize(&.{"--batch=7"}));
}

test "--settle frees what the collection found dead before the reading, wherever it is given; nothing else does" {
    try std.testing.expect(!settlesBeforeReading(&.{ "gc_bench", "10000", "5000", "--gc", "--loop" }));
    try std.testing.expect(settlesBeforeReading(&.{ "gc_bench", "10000", "5000", "--settle" }));
    try std.testing.expect(settlesBeforeReading(&.{ "gc_bench", "--settle", "--body=void 0;" }));
    try std.testing.expect(!settlesBeforeReading(&.{ "gc_bench", "--body=--settle" }));
    try std.testing.expect(!settlesBeforeReading(&.{"--settle"}));
}

test "--live-types lists the live objects by interface at the end, wherever it is given; nothing else does" {
    try std.testing.expect(!listsLiveTypes(&.{ "gc_bench", "10000", "5000", "--gc", "--settle" }));
    try std.testing.expect(listsLiveTypes(&.{ "gc_bench", "10000", "5000", "--live-types" }));
    try std.testing.expect(listsLiveTypes(&.{ "gc_bench", "--live-types", "--body=void 0;" }));
    try std.testing.expect(!listsLiveTypes(&.{ "gc_bench", "--body=--live-types" }));
    try std.testing.expect(!listsLiveTypes(&.{"--live-types"}));
}

test "an empty --body= is ignored" {
    try std.testing.expectEqualStrings(default_body, cycleBody(&.{ "gc_bench", "--body=" }));
    // The program name is never read as a flag.
    try std.testing.expectEqualStrings(default_body, cycleBody(&.{"--body=a;"}));
}

test "gc_bench's allocator captures no stack traces" {
    // Zig 0.16's stack capture on aarch64-macos leaks the DWARF unwinder's
    // state into std.debug's never-freed arena on every capture, and
    // DebugAllocator(.{}) captures one per allocation AND per free in Debug.
    // So every Zig allocation a measured call made read as ~660 B of RSS
    // "retained" per call (docs/lessons/testing-a-debugallocator-that-captures-traces-grows-rss-per-allocation.md).
    try std.testing.expectEqual(@as(usize, 0), allocator_config.stack_trace_frames);
    // The checks that matter for a leak hunt stay: a double free and an
    // invalid free still panic or log, and deinit still reports leaks.
    try std.testing.expect(allocator_config.safety);
}

// ---------------------------------------------------------------------------
// Named measurements (`--bench=<name>`)

test "--bench= names a measurement: its statement is the cycle's" {
    const wide = (try benchOf(&.{ "gc_bench", "--bench=wide" })).?;
    try std.testing.expectEqualStrings("wide", wide.name);
    try std.testing.expectEqualStrings(wide.body, cycleBody(&.{ "gc_bench", "--bench=wide" }));
    // Wherever it is given, after the counts as before them.
    try std.testing.expectEqualStrings(wide.body, cycleBody(&.{ "gc_bench", "20000", "5000", "--bench=wide" }));
    try std.testing.expect(!isControl(&.{ "gc_bench", "--bench=wide", "--control" }));
    // None given: none, and the plain statement.
    try std.testing.expect((try benchOf(&.{ "gc_bench", "--gc" })) == null);
    try std.testing.expect((try benchOf(&.{"--bench=wide"})) == null);
}

test "the wrapper redesign's measurements are each named, with the breakdown's two" {
    // tmp/redesign/wrapper-redesign-design.md section 7, P0; div and text are
    // tmp/plans/perf2b8-breakdown.md's bodies, the "outside the block" rows.
    for ([_][]const u8{ "wide", "qsa-deep", "wrapper-churn-nogc", "pause", "div", "text" }) |name| {
        const bench = benchNamed(name) orelse return error.TestBenchMissing;
        try std.testing.expectEqualStrings(name, bench.name);
        try std.testing.expect(bench.body.len > 0 and bench.what.len > 0);
        try std.testing.expect(bench.cycles > 0 and bench.every > 0 and bench.every <= bench.cycles);
    }
    try std.testing.expect(benchNamed("nope") == null);
}

test "an unknown --bench= name, or --bench= beside --body=, is refused" {
    try std.testing.expectError(error.UnknownBench, benchOf(&.{ "gc_bench", "--bench=nope" }));
    try std.testing.expectError(error.UnknownBench, benchOf(&.{ "gc_bench", "--bench=" }));
    try std.testing.expectError(error.BenchAndBody, benchOf(&.{ "gc_bench", "--bench=wide", "--body=void 0;" }));
}

test "the two much-dies pause rows are named, never force a collection, and build the trees their reports say" {
    inline for (.{ "clone-drop", "parse-drop" }) |name| {
        const bench = benchNamed(name) orelse return error.TestBenchMissing;
        try std.testing.expectEqualStrings(name, bench.name);
        try std.testing.expect(bench.body.len > 0 and bench.what.len > 0);
        try std.testing.expect(bench.cycles > 0 and bench.every > 0 and bench.every <= bench.cycles);
        // The engine's own schedule decides when the dead are found.
        try std.testing.expectEqual(Bench.Gc.never, bench.gc);
        try std.testing.expectError(error.GcRefused, bench.collects(true));
        try std.testing.expectEqualStrings(bench.body, cycleBody(&.{ "gc_bench", "--bench=" ++ name }));
    }
    // clone-drop: a div over 168 lists of ul > li > (a > "one"), " two" -
    // 1 + 168 * 5 = 841 nodes a clone.
    const clone = benchNamed("clone-drop").?;
    try std.testing.expect(std.mem.indexOf(u8, clone.body, "'<ul><li><a href=x>one</a> two</li></ul>'.repeat(168)") != null);
    try std.testing.expect(std.mem.indexOf(u8, clone.body, ".cloneNode(true)") != null);
    // parse-drop: a div over 50 paragraphs of one text - 1 + 50 * 2 = 101
    // nodes a cycle - and its childNodes read.
    const parse = benchNamed("parse-drop").?;
    try std.testing.expect(std.mem.indexOf(u8, parse.body, "'<p>some text</p>'.repeat(50)") != null);
    try std.testing.expect(std.mem.indexOf(u8, parse.body, ".childNodes") != null);
}

test "the in-sandbox allocator's four rows are named and never force a collection" {
    inline for (.{ "sandbox-small", "sandbox-bigint", "sandbox-chunks", "sandbox-megabyte-loop" }) |name| {
        const bench = benchNamed(name) orelse return error.TestBenchMissing;
        try std.testing.expectEqualStrings(name, bench.name);
        try std.testing.expect(bench.body.len > 0 and bench.what.len > 0);
        try std.testing.expect(bench.cycles > 0 and bench.every > 0 and bench.every <= bench.cycles);
        // The engine's own collections free the blocks, as on a page.
        try std.testing.expectEqual(Bench.Gc.never, bench.gc);
        try std.testing.expectEqualStrings(bench.body, cycleBody(&.{ "gc_bench", "--bench=" ++ name }));
    }
    // Each takes memory from the engine's in-sandbox allocator, not the DOM.
    try std.testing.expect(std.mem.indexOf(u8, benchNamed("sandbox-small").?.body, "new ArrayBuffer(96)") != null);
    try std.testing.expect(std.mem.indexOf(u8, benchNamed("sandbox-bigint").?.body, "7n ** 3500n") != null);
    try std.testing.expect(std.mem.indexOf(u8, benchNamed("sandbox-chunks").?.body, "new Uint8Array(65536)") != null);
    // The loop frees its buffer itself, each cycle: detached by transfer(0).
    const loop = benchNamed("sandbox-megabyte-loop").?;
    try std.testing.expect(std.mem.indexOf(u8, loop.body, "new ArrayBuffer(1048576)") != null);
    try std.testing.expect(std.mem.indexOf(u8, loop.body, ".transfer(0)") != null);
}

test "each measurement says whether it collects: wrapper-churn-nogc never, the kept-object ones always" {
    const churn = benchNamed("wrapper-churn-nogc").?;
    try std.testing.expectEqual(Bench.Gc.never, churn.gc);
    try std.testing.expectError(error.GcRefused, churn.collects(true));
    try std.testing.expectEqual(false, try churn.collects(false));
    for ([_][]const u8{ "wide", "pause", "div", "text" }) |name| {
        const bench = benchNamed(name).?;
        try std.testing.expectEqual(Bench.Gc.forced, bench.gc);
        try std.testing.expectEqual(true, try bench.collects(false));
    }
    const qsa = benchNamed("qsa-deep").?;
    try std.testing.expectEqual(true, try qsa.collects(true));
    try std.testing.expectEqual(false, try qsa.collects(false));
}

test "qsa-deep's tree is 1,000 leaves at depth 12, wrapped once per query" {
    const qsa = benchNamed("qsa-deep").?;
    try std.testing.expect(qsa.wrappers_per_cycle);
    try std.testing.expect(std.mem.indexOf(u8, qsa.body, "querySelectorAll('b')") != null);
    try std.testing.expect(!benchNamed("wide").?.wrappers_per_cycle);
}

test "the counts default to the measurement's, and a count given wins" {
    const wide = benchNamed("wide").?;
    try std.testing.expectEqual(wide.cycles, countArg(&.{ "gc_bench", "--bench=wide" }, 1, wide.cycles));
    try std.testing.expectEqual(wide.every, countArg(&.{ "gc_bench", "--bench=wide" }, 2, wide.every));
    try std.testing.expectEqual(@as(usize, 3000), countArg(&.{ "gc_bench", "3000", "1000", "--bench=wide" }, 1, wide.cycles));
    try std.testing.expectEqual(@as(usize, 1000), countArg(&.{ "gc_bench", "3000", "1000", "--bench=wide" }, 2, wide.every));
    try std.testing.expectEqual(@as(usize, 10_000), countArg(&.{"gc_bench"}, 1, 10_000));
}

test "the pause row holds its tree's wrappers whatever a collector does first: each is given a property" {
    // Lane nm2's cost window: the row wrapped each element and forgot it
    // (`void e`), so a young collection could drop the wrapper and a full
    // one promoted whichever were left - 2 or about 6,000 by which came
    // first, +9.7% instructions on one binary.
    const pause = benchNamed("pause").?;
    try std.testing.expect(std.mem.indexOf(u8, pause.body, "for (const e of r.querySelectorAll('*')) e.pauseKept = true;") != null);
    try std.testing.expect(std.mem.indexOf(u8, pause.body, "void e;") == null);
    // 100 sections of 100 paragraphs: 10,100 elements below the root.
    try std.testing.expect(std.mem.indexOf(u8, pause.body, "('<section>' + '<p></p>'.repeat(100) + '</section>').repeat(100)") != null);
    try std.testing.expectEqual(@as(?usize, 10_100), pause.kept_wrappers);
    // The run checks it: all 10,100 and the few a reading may add (the
    // root, the document, the batch's last elements).
    try std.testing.expect(pause.holdsShape(10_100));
    try std.testing.expect(pause.holdsShape(10_102));
    try std.testing.expect(pause.holdsShape(10_100 + Bench.kept_wrappers_slack));
    // The two values the old row read are neither of them its shape.
    try std.testing.expect(!pause.holdsShape(2));
    try std.testing.expect(!pause.holdsShape(5_908));
    try std.testing.expect(!pause.holdsShape(6_101));
    try std.testing.expect(!pause.holdsShape(10_099));
    try std.testing.expect(!pause.holdsShape(10_100 + Bench.kept_wrappers_slack + 1));
    try std.testing.expect(!pause.holdsShape(-1));
}

test "pause-bare is the same tree with no wrapper below its root, and says so" {
    const pause = benchNamed("pause").?;
    const bare = benchNamed("pause-bare").?;
    try std.testing.expect(std.mem.indexOf(u8, bare.body, "('<section>' + '<p></p>'.repeat(100) + '</section>').repeat(100)") != null);
    try std.testing.expect(std.mem.indexOf(u8, bare.body, "querySelectorAll") == null);
    try std.testing.expect(std.mem.indexOf(u8, bare.body, "void document.createElement('span');") != null);
    try std.testing.expectEqual(pause.cycles, bare.cycles);
    try std.testing.expectEqual(pause.every, bare.every);
    try std.testing.expectEqual(Bench.Gc.forced, bare.gc);
    try std.testing.expectEqual(@as(?usize, 0), bare.kept_wrappers);
    try std.testing.expect(bare.holdsShape(0));
    try std.testing.expect(bare.holdsShape(2));
    try std.testing.expect(!bare.holdsShape(5_908));
    try std.testing.expectEqualStrings(bare.body, cycleBody(&.{ "gc_bench", "--bench=pause-bare" }));
}

test "a row with no kept tree has no shape to hold" {
    for ([_][]const u8{ "wide", "qsa-deep", "wrapper-churn-nogc", "div", "text", "clone-drop", "parse-drop" }) |name| {
        const bench = benchNamed(name).?;
        try std.testing.expectEqual(@as(?usize, null), bench.kept_wrappers);
        try std.testing.expect(bench.holdsShape(0));
        try std.testing.expect(bench.holdsShape(123_456));
    }
}
