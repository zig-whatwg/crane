//! An agent's ObservableArrays are its own (instances B2): their states are
//! on its agent record (observable_array.Registry), made by its first array
//! and freed by its end.
//!
//! They were one process-wide map under a mutex that every thread took, and
//! every collected array's weak callback scanned the whole map - every
//! agent's entries - to find its own state; only a thread's host agent's end
//! freed the rest. Two agents on two threads now each count only their own,
//! and one's end leaves the other's arrays as they were.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const v8 = @import("v8");

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

/// An agent with a window realm that keeps `arrays` ObservableArrays alive.
const Side = struct {
    arrays: usize,
    /// Run, between making its arrays and checking them again, on the same
    /// thread: another agent's whole life on a thread of its own.
    other: ?*Side = null,
    failure: ?anyerror = null,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
        };
    }

    fn steps(self: *Side) !void {
        var scope = runtime.BrowserScope.init(std.heap.page_allocator);
        defer scope.deinit();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        defer protocol.destroyAgent(agent);
        const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(agent));
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://arrays.test",
            .browser_scope = &scope,
            .create_global_object = WindowHost.createGlobalObject,
        });
        defer protocol.destroyWindowRealm(realm, .global_detached);

        var source_buf: [160]u8 = undefined;
        const source = try std.fmt.bufPrint(&source_buf, "globalThis.keep = []; for (let i = 0; i < {d}; i++) keep.push(new Document().adoptedStyleSheets); String(keep.length)", .{self.arrays});
        var expected_buf: [16]u8 = undefined;
        try expectEval(realm, source, try std.fmt.bufPrint(&expected_buf, "{d}", .{self.arrays}));
        // Its own arrays, and no other agent's.
        try testing.expectEqual(self.arrays, v8.observable_array.liveCount(isolate));

        if (self.other) |other| {
            const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Side.run, .{other});
            thread.join();
            if (other.failure) |err| return err;
            // The other agent's end left these.
            try testing.expectEqual(self.arrays, v8.observable_array.liveCount(isolate));
            try expectEval(realm, "keep.every((a) => Array.isArray(a) && a.length === 0) ? 'kept' : 'lost'", "kept");
        }
    }
};

test "each agent keeps its own ObservableArrays, and another agent's end leaves them" {
    try protocol.initializeEngine(.{});
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();

    var other: Side = .{ .arrays = 20 };
    var page: Side = .{ .arrays = 30, .other = &other };
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Side.run, .{&page});
    thread.join();
    if (page.failure) |err| return err;
}
