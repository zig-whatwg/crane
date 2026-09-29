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
