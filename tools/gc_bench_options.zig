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
    .{
        .name = "pause",
        .what = "a detached tree of 10,100 elements, every one wrapped and kept by script through its root, " ++
            "and one element made and dropped per cycle: the full-collection pause",
        .body = "void (globalThis.pauseTree ??= (() => { const r = document.createElement('div'); " ++
            "r.innerHTML = ('<section>' + '<p></p>'.repeat(100) + '</section>').repeat(100); " ++
            "for (const e of r.querySelectorAll('*')) void e; return r; })()); void document.createElement('span');",
        .cycles = 100_000,
        .every = 10_000,
        .gc = .forced,
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
