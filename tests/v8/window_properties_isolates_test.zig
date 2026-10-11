//! The WindowProperties template is each isolate's (window_properties.zig):
//! kept on its agent's record, as Blink keeps its templates in
//! V8PerIsolateData. It was one process-wide cache keyed by the last isolate
//! that made one, read and written unlocked on every window realm's
//! creation - so two Browsers making window realms on two threads at once
//! could hand one isolate the other's template.
//!
//! Two agents on two threads each make and end window realms at once, and
//! every realm's global has a WindowProperties object of its own isolate in
//! its prototype chain.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

const realms_per_agent = 150;

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

const Side = struct {
    failure: ?anyerror = null,
    checked: usize = 0,

    fn run(self: *Side) void {
        self.steps() catch |err| {
            self.failure = err;
        };
    }

    fn steps(self: *Side) !void {
        // Each agent a Browser of its own: its objects from its own scope.
        var scope = runtime.BrowserScope.init(std.heap.page_allocator);
        defer scope.deinit();
        const no_hooks: protocol.HostHooks = .{};
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        defer protocol.destroyAgent(agent);
        for (0..realms_per_agent) |_| {
            const realm = try protocol.createWindowRealm(&.{
                .agent = agent,
                .allocator = std.heap.c_allocator,
                .from_snapshot = false,
                .timer = null,
                .origin = "https://example.test",
                .browser_scope = &scope,
                .create_global_object = WindowHost.createGlobalObject,
            });
            defer protocol.destroyWindowRealm(realm, .global_detached);
            var reports: Reports = .{};
            const answer = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = "Object.prototype.toString.call(Object.getPrototypeOf(Window.prototype))" }, "", null, testing.allocator, reports.reporter());
            defer testing.allocator.free(answer);
            if (reports.count != 0) return error.ScriptThrew;
            if (!std.mem.eql(u8, answer, "[object WindowProperties]")) {
                std.debug.print("WindowProperties: {s}\n", .{answer});
                return error.WrongWindowProperties;
            }
            self.checked += 1;
        }
    }
};

test "two agents on two threads make window realms at once, each with its own WindowProperties template" {
    // The engine, the standalone runtime and the hooks start on this thread
    // first, as crane.Process starts them before any Browser.
    try protocol.initializeEngine(.{});
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();

    var sides = [_]Side{ .{}, .{} };
    var threads: [2]std.Thread = undefined;
    for (&threads, &sides) |*thread, *side| thread.* = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Side.run, .{side});
    for (threads) |thread| thread.join();
    for (sides) |side| {
        if (side.failure) |err| return err;
        try testing.expectEqual(@as(usize, realms_per_agent), side.checked);
    }
}
