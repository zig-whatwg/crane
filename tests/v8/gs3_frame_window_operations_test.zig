//! A Window realm's window operations (engine.installWindowOperations: the
//! host's steps behind setTimeout, its clears and the animation frame methods)
//! are the realm's own (lane gstate3). A frame's realm takes its parent's when
//! it is made; at its end its own operations give up its timers
//! (WindowOperations.windowDestroyed) BEFORE they are forgotten, and the
//! parent's are untouched. They were one table per THREAD, ended by whichever
//! realm installed them last: one Browser's page end took them from another
//! Browser's windows on the same thread.
//!
//! Each test runs on a thread of its own: tests/v8 is one process, and an
//! earlier file may have left an isolate entered on the main one.

const std = @import("std");
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const no_hooks: protocol.HostHooks = .{};

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

/// What the operations were asked, per test thread (`Seen.current`).
const Seen = struct {
    timers: usize = 0,
    timer_realm: ?runtime.Context = null,
    destroyed: [4]?runtime.Context = @splat(null),
    destroyed_count: usize = 0,
    /// Whether the realm's own window operations were still set when its
    /// windowDestroyed ran.
    own_operations_at_destroy: bool = false,
};

/// The test thread's record: each test runs one thread, which sets it.
var current: ?*Seen = null;

fn initializeTimer(r: runtime.Context, handler: runtime.WindowTimerHandler, timeout: i32, arguments: []const runtime.JSValue, repeat: bool) i32 {
    _ = timeout;
    _ = repeat;
    switch (handler) {
        .function, .string => |h| protocol.releaseValue(.{ .value = h }),
    }
    for (arguments) |argument| protocol.releaseValue(.{ .value = argument });
    const seen = current.?;
    seen.timers += 1;
    seen.timer_realm = r;
    return @intCast(seen.timers);
}

fn clearTimer(_: runtime.Context, _: i32) void {}

fn requestAnimationFrame(_: runtime.Context, callback: runtime.JSValue) u32 {
    protocol.releaseValue(.{ .value = callback });
    return 1;
}

fn cancelAnimationFrame(_: runtime.Context, _: u32) void {}

fn windowDestroyed(r: runtime.Context) void {
    const seen = current.?;
    if (seen.destroyed_count < seen.destroyed.len) seen.destroyed[seen.destroyed_count] = r;
    seen.destroyed_count += 1;
    seen.own_operations_at_destroy = r.window_operations != null;
}

const operations = runtime.WindowOperations{
    .initializeTimer = initializeTimer,
    .clearTimer = clearTimer,
    .requestAnimationFrame = requestAnimationFrame,
    .cancelAnimationFrame = cancelAnimationFrame,
    .windowDestroyed = windowDestroyed,
};

const FrameRealm = struct {
    agent: *protocol.Agent,
    parent: runtime.Context,
    made: ?runtime.Context = null,
    failed: ?anyerror = null,

    fn make(self: *FrameRealm) !runtime.Context {
        try protocol.runInRealm(self.parent, steps, self);
        if (self.failed) |err| return err;
        return self.made.?;
    }

    fn steps(data: ?*anyopaque) void {
        const self: *FrameRealm = @ptrCast(@alignCast(data.?));
        self.made = protocol.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .parent = self.parent,
            .create_global_object = WindowHost.createGlobalObject,
        }) catch |err| {
            self.failed = err;
            return;
        };
    }
};

fn evalString(realm: runtime.Context, source: []const u8) ![]u8 {
    return protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, std.testing.allocator, .{ .report = struct {
        fn report(_: ?*anyopaque, info: *const protocol.ErrorInfo) void {
            std.debug.print("reported: {s}\n", .{info.message});
        }
    }.report });
}

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const got = try evalString(realm, source);
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(expected, got);
}

fn runOnThread(comptime body: fn () anyerror!void) !void {
    test_process.start();
    var failure: ?anyerror = null;
    const Run = struct {
        fn main(out: *?anyerror) void {
            body() catch |err| {
                out.* = err;
            };
        }
    };
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Run.main, .{&failure});
    thread.join();
    if (failure) |err| return err;
}

fn frameEndsThroughItsOwnOperations() !void {
    var seen: Seen = .{};
    current = &seen;
    defer current = null;

    const agent = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);
    const page = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(page, .global_detached);
    try protocol.installWindowOperations(page, &operations);
    try std.testing.expect(page.window_operations.? == &operations);

    var frame_realm: FrameRealm = .{ .agent = agent, .parent = page };
    const frame = try frame_realm.make();
    // The frame took its parent's operations, and its setTimeout is the
    // host's - in the frame's realm.
    try std.testing.expect(frame.window_operations.? == &operations);
    try expectEval(frame, "String(setTimeout(() => {}, 1))", "1");
    try std.testing.expectEqual(frame, seen.timer_realm.?);

    // The frame ends: its timers go through its own operations, once, while
    // they are still its own - and then they are forgotten.
    protocol.destroyWindowRealm(frame, .global_detached);
    try std.testing.expectEqual(@as(usize, 1), seen.destroyed_count);
    try std.testing.expectEqual(frame, seen.destroyed[0].?);
    try std.testing.expect(seen.own_operations_at_destroy);

    // The parent's operations are its own and untouched by the frame's end.
    try std.testing.expect(page.window_operations.? == &operations);
    try expectEval(page, "String(setTimeout(() => {}, 1))", "2");
    try std.testing.expectEqual(page, seen.timer_realm.?);
}

test "a frame's window operations are its parent's, and its end gives up its timers through them before they are forgotten" {
    try runOnThread(frameEndsThroughItsOwnOperations);
}

fn twoAgentsKeepTheirOwnOperations() !void {
    var seen: Seen = .{};
    current = &seen;
    defer current = null;

    const first = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(first);
    const first_page = try protocol.createWindowRealm(&.{
        .agent = first,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(first_page, .global_detached);
    try protocol.installWindowOperations(first_page, &operations);

    // A second agent's page installs its operations after the first's, and
    // ends.
    const second = try protocol.createAgent(.{ .can_block = true, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    const second_page = try protocol.createWindowRealm(&.{
        .agent = second,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    try protocol.installWindowOperations(second_page, &operations);
    protocol.destroyWindowRealm(second_page, .global_detached);
    protocol.destroyAgent(second);

    // The first page's setTimeout is still the host's.
    try expectEval(first_page, "String(setTimeout(() => {}, 1))", "1");
    try std.testing.expectEqual(first_page, seen.timer_realm.?);
}

test "another agent's page end on the thread leaves this page's window operations" {
    try runOnThread(twoAgentsKeepTheirOwnOperations);
}
