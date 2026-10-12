//! An agent's templates are its own (instances B2): another agent's end
//! leaves them, and every object made from them, as they were.
//!
//! The template registry was one process-wide table, and a process-wide
//! `cache_generation` was bumped by EVERY agent's end
//! (template_registry.clearForIsolate). Each isolate's template storage
//! (isolate_templates, data slot 1) carried the generation it was made at and
//! was thrown away whenever it no longer matched - so a worker's end, on its
//! own thread, emptied the page's storage, and the page's next iterator was
//! made from a NEW "<Interface> Iterator" template: its prototype was not the
//! one the realm's earlier iterators had (WebIDL 3.7.10: one %<Interface>
//! Iterator Prototype% per realm). Blink keeps an isolate's templates in its
//! V8PerIsolateData, which nothing of another isolate touches.

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

/// `source`'s completion value as a string, owned by std.testing.allocator.
fn eval(realm: runtime.Context, source: []const u8) ![]u8 {
    var reports: Reports = .{};
    const answer = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    errdefer testing.allocator.free(answer);
    if (reports.count != 0) return error.ScriptThrew;
    return answer;
}

fn expectEval(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const answer = try eval(realm, source);
    defer testing.allocator.free(answer);
    try testing.expectEqualStrings(expected, answer);
}

/// An agent with a window realm that runs script, then ends: what a worker
/// does on its own thread.
const OtherAgent = struct {
    failure: ?anyerror = null,

    fn run(self: *OtherAgent) void {
        self.steps() catch |err| {
            self.failure = err;
        };
    }

    fn steps(_: *OtherAgent) !void {
        var scope = runtime.BrowserScope.init(std.heap.page_allocator);
        defer scope.deinit();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        defer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://other.test",
            .browser_scope = &scope,
            .create_global_object = WindowHost.createGlobalObject,
        });
        defer protocol.destroyWindowRealm(realm, .global_detached);
        try expectEval(realm, "[...new URLSearchParams('x=1').entries()].length", "1");
    }
};

/// Agent A's side: a realm whose iterator prototypes are compared across
/// another agent's whole life, run on a thread of their own.
const Page = struct {
    failure: ?anyerror = null,

    fn run(self: *Page) void {
        self.steps() catch |err| {
            self.failure = err;
        };
    }

    fn steps(_: *Page) !void {
        var scope = runtime.BrowserScope.init(std.heap.page_allocator);
        defer scope.deinit();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        defer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://page.test",
            .browser_scope = &scope,
            .create_global_object = WindowHost.createGlobalObject,
        });
        defer protocol.destroyWindowRealm(realm, .global_detached);

        try expectEval(realm,
            \\globalThis.proto = Object.getPrototypeOf(new URLSearchParams('a=1').entries());
            \\globalThis.urlSearchParams = URLSearchParams;
            \\Object.getPrototypeOf(new URLSearchParams('b=2').keys()) === proto
        , "true");

        // Another agent, on a thread of its own, is made, runs, and ends.
        var other: OtherAgent = .{};
        const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, OtherAgent.run, .{&other});
        thread.join();
        if (other.failure) |err| return err;

        // This realm's iterators still have its one iterator prototype, and
        // its interface objects are the ones it had.
        try expectEval(realm, "Object.getPrototypeOf(new URLSearchParams('c=3').values()) === proto", "true");
        try expectEval(realm, "URLSearchParams === urlSearchParams && new URLSearchParams() instanceof urlSearchParams", "true");
    }
};

fn startProcess() !void {
    // The engine, the standalone runtime and the hooks start on this thread
    // first, as crane.Process starts them before any Browser.
    try protocol.initializeEngine(.{});
    if (runtime.BrowserScope.standalone() == null) runtime.initializeRuntime(std.heap.page_allocator);
    interfaces.process_hooks.startHooksForTest();
}

test "another agent's end, on another thread, leaves this agent's iterator prototypes as they were" {
    try startProcess();
    var page: Page = .{};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, Page.run, .{&page});
    thread.join();
    if (page.failure) |err| return err;
}
