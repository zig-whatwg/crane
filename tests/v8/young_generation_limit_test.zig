//! engine.AgentOptions.young_generation_limit [young_generation_limit]: the
//! most memory an agent's young generation may take. A host that runs many
//! agents, or runs on a phone, gives a small one; a host that ships for
//! desktop can permit the engine's own (the user's direction, 2026-11-12: "a
//! configurable value for the js engine protocol").
//!
//! On V8 the young generation is two semispaces and a new large object space
//! of a semispace's size, and it only grows while what it holds survives
//! (Heap::ShouldResizeNewSpace: survivors since the last expansion exceed its
//! capacity). So each test keeps everything it allocates - strings and
//! closures, about 150 MB, which no allocation site pretenures into the old
//! generation as it does array and object literals that keep surviving -
//! which takes an unlimited young generation past 16 MB of semispaces, and
//! reads what the heap has committed to "new_space"
//! (Isolate::GetHeapSpaceStatistics: both semispaces) when the script
//! returns. Values are made the way a page makes them: script in a Window
//! realm.
const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");
const ffi = v8.ffi;

const mb = 1024 * 1024;

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

/// 2,000,000 strings and 2,000,000 closures, each with its own context,
/// every one kept: about 150 MB that all survives its young collections, so
/// the young generation grows as far as it is allowed. (Not array or object
/// literals: once those keep surviving, V8's allocation-site pretenuring
/// makes them in the old generation and the young one stops growing - the
/// first form of this test read 8 MB of semispaces with no limit at all.)
const grow = "globalThis.kept = []; for (let i = 0; i < 2000000; i++) { kept.push('k' + i, () => i); } String(kept.length)";

/// What a new agent made with `limit` has committed to its two semispaces
/// once `grow` has run in its Window realm.
fn semispacesAfterGrowth(limit: ?usize) !usize {
    const own_runtime = test_process.OwnRuntime.begin(std.testing.allocator);
    defer own_runtime.end();
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator, .young_generation_limit = limit });
    defer engine.destroyAgent(agent);
    const realm_options: engine.WindowRealmOptions = .{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://young-generation.test", .create_global_object = createGlobal };
    const realm = try engine.createWindowRealm(&realm_options);
    defer engine.destroyWindowRealm(realm, .global_detached);
    const text = try engine.evaluateClassicScriptToString(realm, .{ .utf8 = grow }, "grow.js", null, std.testing.allocator, reporter);
    defer std.testing.allocator.free(text);
    try std.testing.expectEqualStrings("4000000", text);
    const isolate: *ffi.Isolate = @ptrCast(@alignCast(agent));
    return ffi.v8_Debug_HeapSpaceCommittedBytes(isolate, "new_space");
}

/// A page of slack: V8 rounds a space's committed size to its pages.
const slack = 512 * 1024;

fn expectCeiling(limit: usize, semispace: usize) !void {
    const committed = try semispacesAfterGrowth(limit);
    if (committed > 2 * semispace + slack or committed + slack < 2 * semispace) {
        std.debug.print("young_generation_limit {d} MB: {d} KB committed to the semispaces after 150 MB of survivors (two semispaces of {d} MB allowed)\n", .{ limit / mb, committed / 1024, semispace / mb });
    }
    // Never more than two semispaces of the size the limit allows...
    try std.testing.expect(committed <= 2 * semispace + slack);
    // ...and it did grow to that ceiling: the limit is what stopped it.
    try std.testing.expect(committed + slack >= 2 * semispace);
}

fn twentyFourMegabytes() !void {
    // V8 13.1's ceiling: three 8 MB semispaces' worth.
    try expectCeiling(24 * mb, 8 * mb);
}

test "young_generation_limit: 24 MB keeps the semispaces at 8 MB each" {
    if (comptime engine.capabilities.young_generation_limit == .unsupported) return error.SkipZigTest;
    try onThread(twentyFourMegabytes);
}

fn sixMegabytes() !void {
    try expectCeiling(6 * mb, 2 * mb);
}

test "young_generation_limit: 6 MB keeps the semispaces at 2 MB each" {
    if (comptime engine.capabilities.young_generation_limit == .unsupported) return error.SkipZigTest;
    try onThread(sixMegabytes);
}

fn roundedDown() !void {
    // 20 MB holds three 4 MB semispaces, not three of 8: the engine rounds
    // DOWN to a size it supports, never past what the host said.
    try expectCeiling(20 * mb, 4 * mb);
}

test "young_generation_limit: a limit between two sizes rounds down, never up" {
    if (comptime engine.capabilities.young_generation_limit == .unsupported) return error.SkipZigTest;
    try onThread(roundedDown);
}

fn noLimit() !void {
    // Null: the engine's own sizing, exactly as without the option - V8 15.7
    // grows its semispaces to 32 MB, so the same script commits well over
    // the 16 MB that a 24 MB limit allows.
    const committed = try semispacesAfterGrowth(null);
    if (committed <= 16 * mb + slack) {
        std.debug.print("no young_generation_limit: only {d} KB committed to the semispaces after 150 MB of survivors\n", .{committed / 1024});
    }
    try std.testing.expect(committed > 16 * mb + slack);
}

test "young_generation_limit: null leaves the engine's own ceiling" {
    if (comptime engine.capabilities.young_generation_limit == .unsupported) return error.SkipZigTest;
    try onThread(noLimit);
}

test "young_generation_limit: an agent whose host says nothing gets the protocol's one default" {
    const options: engine.AgentOptions = .{ .can_block = false, .from_snapshot = false, .hooks = &hooks };
    try std.testing.expectEqual(engine.default_young_generation_limit, options.young_generation_limit);
}

test "young_generation_limit: a limit becomes three power-of-two semispaces, rounded down, never under V8's smallest" {
    const convert = v8.young_generation.maxYoungGenerationBytes;
    try std.testing.expectEqual(@as(usize, 0), convert(null));
    // V8 13.1's ceiling and Chrome's on a phone below its high-end threshold.
    try std.testing.expectEqual(@as(usize, 24 * mb), convert(24 * mb));
    // V8 15.7's own, which Chrome 157 ships on desktop.
    try std.testing.expectEqual(@as(usize, 96 * mb), convert(96 * mb));
    // Down, never up: 20 MB holds three 4 MB semispaces, not three of 8.
    try std.testing.expectEqual(@as(usize, 12 * mb), convert(20 * mb));
    try std.testing.expectEqual(@as(usize, 24 * mb), convert(47 * mb));
    try std.testing.expectEqual(@as(usize, 48 * mb), convert(48 * mb));
    // Never under the semispace V8 starts with.
    try std.testing.expectEqual(@as(usize, 3 * mb), convert(1));
    try std.testing.expectEqual(@as(usize, 3 * mb), convert(3 * mb));
    try std.testing.expectEqual(@as(usize, 3 * mb), convert(5 * mb));
    try std.testing.expectEqual(@as(usize, 6 * mb), convert(6 * mb));
}
