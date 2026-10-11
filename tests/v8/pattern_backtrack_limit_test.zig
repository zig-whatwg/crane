//! engine.matchesPatternAttribute stops a pattern that backtracks without end,
//! and answers "does not match", as Blink and WebKit do.
//!
//! A page writes the pattern, so a catastrophic one - `(\d+)*$` against a
//! long run of digits ending in a letter, about 2^n backtracks - would hold
//! the agent's thread for as long as it runs: the page freezes
//! (html/semantics/forms/constraints/infinite_backtracking.tentative.html ran
//! into the runner's timeout). Blink compiles every ScriptRegexp, the pattern
//! attribute's included, with V8's RegExp::NewWithBacktrackLimit and a limit
//! of 1,000,000 (third_party/blink/renderer/platform/bindings/script_regexp.cc,
//! kBacktrackLimit). Past the limit V8 returns a match failure (v8-regexp.h),
//! ScriptRegexp::Match answers -1, and BaseTextInputType::PatternMismatchPerValue
//! reads that as a mismatch. wpt.fyi (stable, 2026-10-10): Chrome 155 and
//! Safari 27 pass that WPT file (the input is :invalid), Firefox 157 times out.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent, without a
//! snapshot (pattern_attribute_snapshot_test.zig covers a snapshot agent).

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const clock = @import("clock");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: protocol.HostHooks = .{};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    fn matches(self: Page, pattern: []const u8, value: []const u8) !bool {
        return protocol.matchesPatternAttribute(self.realm, pattern, value);
    }
};

/// `n` copies of `unit`, then `tail`.
fn repeated(buffer: []u8, unit: u8, n: usize, tail: []const u8) []const u8 {
    @memset(buffer[0..n], unit);
    @memcpy(buffer[n..][0..tail.len], tail);
    return buffer[0 .. n + tail.len];
}

test "past the backtrack limit a pattern does not match, even where an alternative would" {
    const page = try Page.open();
    defer page.close();
    var buffer: [64]u8 = undefined;
    // `(a+)+$` fails on "a...ac" only after trying every split of the a's,
    // about 2^n backtracks, before `.*c` matches the whole value. Under the
    // limit (n = 10, ~2^10) the second alternative is reached and matches;
    // past it (n = 26, ~2^26) the match fails as a whole, as in Blink.
    try std.testing.expect(try page.matches("(a+)+$|.*c", repeated(&buffer, 'a', 10, "c")));
    try std.testing.expect(!try page.matches("(a+)+$|.*c", repeated(&buffer, 'a', 26, "c")));
    // The same compiled pattern (cached per agent) still answers under the limit.
    try std.testing.expect(try page.matches("(a+)+$|.*c", repeated(&buffer, 'a', 12, "c")));
    try std.testing.expect(try page.matches("(a+)+$|.*c", repeated(&buffer, 'a', 26, "")));
}

test "a catastrophic pattern returns promptly: infinite_backtracking.tentative.html's" {
    const page = try Page.open();
    defer page.close();
    // An engine with no limit fails here, after a second or so, instead of
    // hanging on the patterns below.
    try std.testing.expect(!try page.matches("(a+)+$|.*c", "aaaaaaaaaaaaaaaaaaaaaaaaaac"));
    const start = clock.monotonicMillis();
    // About 2^38 backtracks without a limit.
    try std.testing.expect(!try page.matches("(\\d+)*$", "12345678901234567890123456789123456789z"));
    try std.testing.expect(!try page.matches("(a|a)*b", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
    const elapsed = clock.monotonicMillis() - start;
    if (elapsed > 2000) {
        std.debug.print("two limited matches took {d} ms\n", .{elapsed});
        return error.TooSlow;
    }
    // Ordinary patterns are untouched.
    try std.testing.expect(try page.matches("(\\d+)*$", "1234567890"));
    try std.testing.expect(try page.matches("[a-z]+@[a-z]+\\.[a-z]{2,}", "someone@example.test"));
}
