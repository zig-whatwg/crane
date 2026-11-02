//! engine.AgentOptions.random_seed [seeded_random] and .clock [host_clock]:
//! an agent made with a seed replays Math.random from it, in every realm it
//! makes, and one made with a clock has Date read it - each per agent, never
//! per process (V8's --random-seed gives every isolate one sequence). An
//! agent made with neither reads V8's own entropy and the process's clock,
//! exactly as before. Values are made the way the binding makes them: script
//! in a Window realm (engine.createWindowRealm), read back as a string.
const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const clock = @import("clock");

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}
fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}
const reporter: engine.Reporter = .{ .report = report, .host = null };
const hooks: engine.HostHooks = .{};

/// Run `body` on a thread of its own: its agents are that thread's host
/// agents, and nothing it makes is left on the test's thread.
fn onThread(comptime body: fn () anyerror!void) !void {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = body();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}

/// `source`'s completion value as a string, OWNED by the testing allocator,
/// in a new agent made with `options` (its seed and clock) - in its first
/// Window realm, or, with `second_realm`, in a second one made after the
/// first ran `source` too.
fn evaluateInNewAgent(options: engine.AgentOptions, source: []const u8, second_realm: bool) ![]u8 {
    const own_runtime = test_process.OwnRuntime.begin(std.testing.allocator);
    defer own_runtime.end();
    const agent = try engine.createAgent(options);
    defer engine.destroyAgent(agent);
    const realm_options: engine.WindowRealmOptions = .{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://detplat1.test", .create_global_object = createGlobal };
    const first = try engine.createWindowRealm(&realm_options);
    defer engine.destroyWindowRealm(first, .global_detached);
    const text = try engine.evaluateClassicScriptToString(first, .{ .utf8 = source }, "detplat1.js", null, std.testing.allocator, reporter);
    if (!second_realm) return text;
    std.testing.allocator.free(text);
    const second = try engine.createWindowRealm(&realm_options);
    defer engine.destroyWindowRealm(second, .global_detached);
    return engine.evaluateClassicScriptToString(second, .{ .utf8 = source }, "detplat1.js", null, std.testing.allocator, reporter);
}

fn agentOptions(seed: ?u64, agent_clock: ?engine.AgentClock) engine.AgentOptions {
    return .{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator, .random_seed = seed, .clock = agent_clock };
}

const randoms = "JSON.stringify(Array.from({ length: 8 }, () => Math.random()))";

fn sameSeedReplays() !void {
    const a = try evaluateInNewAgent(agentOptions(0x5eed, null), randoms, false);
    defer std.testing.allocator.free(a);
    const replay = try evaluateInNewAgent(agentOptions(0x5eed, null), randoms, false);
    defer std.testing.allocator.free(replay);
    const other = try evaluateInNewAgent(agentOptions(0x5eee, null), randoms, false);
    defer std.testing.allocator.free(other);
    const unseeded = try evaluateInNewAgent(agentOptions(null, null), randoms, false);
    defer std.testing.allocator.free(unseeded);
    const unseeded_again = try evaluateInNewAgent(agentOptions(null, null), randoms, false);
    defer std.testing.allocator.free(unseeded_again);

    try std.testing.expectEqualStrings(a, replay);
    try std.testing.expect(!std.mem.eql(u8, a, other));
    // Without a seed, V8's own entropy: two agents differ, as before.
    try std.testing.expect(!std.mem.eql(u8, unseeded, unseeded_again));
    try std.testing.expect(!std.mem.eql(u8, a, unseeded));
}

test "seeded_random: the same seed replays Math.random; another seed, and none, do not" {
    if (comptime engine.capabilities.seeded_random == .unsupported) return error.SkipZigTest;
    try onThread(sameSeedReplays);
}

fn everyRealmReplays() !void {
    // The second realm's state is seeded from the agent's generator the
    // first time its script asks (math-random.cc): it replays too.
    const a = try evaluateInNewAgent(agentOptions(7, null), randoms, true);
    defer std.testing.allocator.free(a);
    const replay = try evaluateInNewAgent(agentOptions(7, null), randoms, true);
    defer std.testing.allocator.free(replay);
    const first_realm = try evaluateInNewAgent(agentOptions(7, null), randoms, false);
    defer std.testing.allocator.free(first_realm);
    try std.testing.expectEqualStrings(a, replay);
    try std.testing.expect(!std.mem.eql(u8, a, first_realm));
}

test "seeded_random: a seeded agent's second realm replays its own sequence" {
    if (comptime engine.capabilities.seeded_random == .unsupported) return error.SkipZigTest;
    try onThread(everyRealmReplays);
}

const FixedClock = struct {
    ns: i64,
    fn wallNow(context: ?*anyopaque) callconv(.c) i64 {
        const self: *FixedClock = @ptrCast(@alignCast(context.?));
        return self.ns;
    }
};

fn dateReadsTheAgentsClock() !void {
    // 2026-01-01T00:00:00.123456789Z: Date floors to the millisecond.
    var fixed: FixedClock = .{ .ns = 1_767_225_600_123_456_789 };
    const fixed_clock: engine.AgentClock = .{ .context = &fixed, .wall_now = FixedClock.wallNow };
    const text = try evaluateInNewAgent(agentOptions(null, fixed_clock), "[Date.now(), new Date().getTime(), new Date(Date()).getUTCFullYear()].join()", false);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("1767225600123,1767225600123,2026", text);

    // Before the epoch: floored, not truncated.
    fixed.ns = -1;
    const before = try evaluateInNewAgent(agentOptions(null, fixed_clock), "Date.now()", false);
    defer std.testing.allocator.free(before);
    try std.testing.expectEqualStrings("-1", before);
}

test "host_clock: Date reads the agent's clock" {
    if (comptime engine.capabilities.host_clock == .unsupported) return error.SkipZigTest;
    try onThread(dateReadsTheAgentsClock);
}

fn dateReadsTheProcessClockWithout() !void {
    const before = clock.wallMillis();
    const text = try evaluateInNewAgent(agentOptions(null, null), "Date.now()", false);
    defer std.testing.allocator.free(text);
    const after = clock.wallMillis();
    const now = try std.fmt.parseInt(i64, text, 10);
    try std.testing.expect(before <= now and now <= after);
}

test "host_clock: an agent made without a clock reads the process's" {
    try onThread(dateReadsTheProcessClockWithout);
}
