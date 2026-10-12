//! A namespace operation that takes the realm (WebIDL namespaces: console,
//! TestUtils) is handed the CURRENT realm (instances B2).
//!
//! The binding handed every such call one process-wide runtime context
//! (namespace.zig `global_context`), made by the first call and kept for the
//! process: console's count map, timer table and group stack - the Console
//! Standard's per-global state - were shared by every realm of every agent,
//! and mutated from every agent's thread with no lock (the mutex covered only
//! the context's creation). Two agents on two threads timing at once grew one
//! hash map from both.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) protocol.Reporter {
        return .{ .report = report, .host = self };
    }
};

const no_hooks: protocol.HostHooks = .{};

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    var reports: Reports = .{};
    const answer = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    defer testing.allocator.free(answer);
    if (reports.count != 0) return error.ScriptThrew;
    try testing.expectEqualStrings(expected, answer);
}

/// One agent with one window realm, on the calling thread.
const Page = struct {
    scope: runtime.BrowserScope,
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open(self: *Page, origin: []const u8) !void {
        self.scope = runtime.BrowserScope.init(std.heap.page_allocator);
        errdefer self.scope.deinit();
        self.agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(self.agent);
        self.realm = try protocol.createWindowRealm(&.{
            .agent = self.agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = origin,
            .browser_scope = &self.scope,
            .create_global_object = WindowHost.createGlobalObject,
        });
    }

    fn close(self: *Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
        self.scope.deinit();
    }
};

fn startProcess() !void {
    try protocol.initializeEngine(.{});
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();
}

/// A realm on a thread of its own: console.time `labels` labels, then the
/// realm's timer table must hold exactly them.
const Timing = struct {
    prefix: []const u8,
    labels: usize,
    failure: ?anyerror = null,

    fn run(self: *Timing) void {
        self.steps() catch |err| {
            self.failure = err;
        };
    }

    fn steps(self: *Timing) !void {
        var page: Page = undefined;
        try page.open("https://timing.test");
        defer page.close();
        var source_buf: [256]u8 = undefined;
        const source = try std.fmt.bufPrint(&source_buf, "for (let i = 0; i < {d}; i++) console.time('{s}' + i); 'timed'", .{ self.labels, self.prefix });
        try expectEval(page.realm, source, "timed");
        try testing.expectEqual(@as(u32, @intCast(self.labels)), page.realm.console_state.timer_table.count());
    }
};

test "console's timers and counts are the calling realm's" {
    try startProcess();
    var page: Page = undefined;
    try page.open("https://console.test");
    defer page.close();

    try expectEval(page.realm, "console.time('in6-timer'); console.count('in6-count'); console.count('in6-count'); 'ok'", "ok");
    try testing.expect(page.realm.console_state.timer_table.contains("in6-timer"));
    try testing.expectEqual(@as(?u32, 2), page.realm.console_state.count_map.get("in6-count"));
}

test "a second realm's console starts empty" {
    try startProcess();
    var first: Page = undefined;
    try first.open("https://first.test");
    defer first.close();
    try expectEval(first.realm, "console.time('in6-shared'); 'ok'", "ok");

    var second: Page = undefined;
    try second.open("https://second.test");
    defer second.close();
    try testing.expect(!second.realm.console_state.timer_table.contains("in6-shared"));
    try expectEval(second.realm, "console.time('in6-shared'); 'ok'", "ok");
    try testing.expect(second.realm.console_state.timer_table.contains("in6-shared"));
    try testing.expect(first.realm.console_state.timer_table.contains("in6-shared"));
}

test "two agents on two threads time at once, each in its own realm's table" {
    try startProcess();
    var sides = [_]Timing{ .{ .prefix = "in6-a-", .labels = 4000 }, .{ .prefix = "in6-b-", .labels = 4000 } };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Timing.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| if (side.failure) |err| return err;
}
