//! Control for the deferred-import task leak measurement.
//! Same Window, agent, fresh thread and 64 import requests; no task allocation.
//! Compare both executables under leaks --atExit: the engine registry is shared scaffolding.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");

const Capture = struct {
    window: ?*runtime.Instance = null,
    request: ?*engine.ImportRequest = null,
    realm: ?runtime.Context = null,

    fn load(host: ?*anyopaque, realm: runtime.Context, _: engine.ImportReferrer, _: []const u8, _: ?[]const u8, request: *engine.ImportRequest) void {
        const self: *Capture = @ptrCast(@alignCast(host.?));
        std.debug.assert(self.request == null);
        self.realm = realm;
        self.request = request;
    }

    fn makeWindow(realm: runtime.Context, _: runtime.JSValue, data: ?*anyopaque) ?*runtime.Instance {
        const self: *Capture = @ptrCast(@alignCast(data.?));
        const window = interfaces.Window.init(testing.allocator, realm) catch return null;
        self.window = window;
        return window;
    }
};

fn report(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
    std.debug.print("sc2 deferred import fixture: {s}\n", .{info.message});
}

fn evaluate(realm: runtime.Context, source: []const u8) !bool {
    const value = try engine.evaluateClassicScript(realm, .{ .utf8 = source }, "https://sc2.test/referring.js", null, .{ .report = report });
    defer value.release();
    return engine.toBoolean(realm, value.value);
}

fn run() !void {
    runtime.initializeRuntime(testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    try engine.initializeEngine(.{});
    var capture: Capture = .{};
    const hooks: engine.HostHooks = .{ .loadImportedModule = Capture.load };
    const agent = try engine.createAgent(.{
        .can_block = false,
        .from_snapshot = false,
        .allocator = testing.allocator,
        .host = &capture,
        .hooks = &hooks,
    });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{
        .agent = agent,
        .allocator = testing.allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://sc2.test",
        .create_global_object = Capture.makeWindow,
        .host = &capture,
    });
    defer engine.destroyWindowRealm(realm, .global_detached);
    defer if (capture.request) |request| engine.finishDynamicImport(request, .{ .failure = runtime.JSValue.jsUndefined });
    _ = capture.window orelse return error.NoWindow;
    try testing.expect(try evaluate(realm, "globalThis.sc2Dropped = 0; true"));

    // Finish the same real requests directly, without DynamicImportTask.
    for (0..64) |_| {
        try testing.expect(try evaluate(realm, "import('./imported.js').catch(() => { ++sc2Dropped; }); true"));
        try testing.expectEqual(realm, capture.realm.?);
        const request = capture.request orelse return error.NoImportRequest;
        capture.request = null;
        engine.finishDynamicImport(request, .{ .failure = runtime.JSValue.jsUndefined });
        try engine.performMicrotaskCheckpoint(agent);
    }
    try testing.expect(try evaluate(realm, "sc2Dropped === 64"));
}

fn onThread(result: *anyerror!void) void {
    result.* = run();
}

test "sc2: direct import completion controls Window realm fixture leaks" {
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{ .stack_size = 16 * 1024 * 1024 }, onThread, .{&result});
    thread.join();
    try result;
}
