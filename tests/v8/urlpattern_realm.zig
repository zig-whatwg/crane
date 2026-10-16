//! A realm for the tests that construct and match URL patterns: an agent of
//! the V8 adapter and a Window realm of it, without a snapshot. A URL
//! pattern's components are regular expressions the engine compiles and
//! matches (src/urlpattern/regexp.zig, engine.regExpCreateCheck and
//! engine.regExpBuiltinExecCaptures), so these tests live in tests/v8, where
//! there is one; tests/urlpattern keeps the engine-free layers' tests
//! (tokenizer, parser, generator, canonicalization, init processing).
//!
//! Each test opens its own page and closes it: tests/v8 is one process.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
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

    fn report(host: ?*anyopaque, info: *const engine.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn reporter(self: *Reports) engine.Reporter {
        return .{ .report = report, .host = self };
    }
};

var pools_ready = false;

fn setup() !void {
    try engine.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: engine.HostHooks = .{};

pub const Page = struct {
    agent: *engine.Agent,
    realm: runtime.Context,

    pub fn open() !Page {
        try setup();
        const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer engine.destroyAgent(agent);
        const realm = try engine.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    pub fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
    }

    /// Run `source` in the page; nothing reported.
    pub fn run(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        try engine.runClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        try std.testing.expectEqual(@as(usize, 0), reports.count);
    }

    /// Whether `source` evaluates to true in the page; nothing reported.
    pub fn holds(self: Page, source: []const u8) !bool {
        var reports: Reports = .{};
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        return engine.toBoolean(self.realm, held.value);
    }
};
