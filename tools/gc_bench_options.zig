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
    var control = false;
    for (args[@min(1, args.len)..]) |arg| {
        if (std.mem.startsWith(u8, arg, body_flag) and arg.len > body_flag.len) body = arg[body_flag.len..];
        if (std.mem.eql(u8, arg, "--control")) control = true;
    }
    return body orelse if (control) control_body else default_body;
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
