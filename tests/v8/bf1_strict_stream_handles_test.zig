//! Rejected WebIDL dictionary callbacks release every temporary Get handle.
const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const ffi = @import("v8").ffi;

fn createGlobal(realm: runtime.Context, _: runtime.JSValue, _: ?*anyopaque) ?*runtime.Instance {
    return interfaces.Window.init(realm.allocator, realm) catch null;
}
fn report(_: ?*anyopaque, _: *const engine.ErrorInfo) void {}

fn reject(realm: runtime.Context) !void {
    const value = try engine.evaluateClassicScript(realm, .{ .utf8 =
        \\(() => {
        \\  try { new WritableStream({}, {size: 42}); }
        \\  catch (e) { if (e instanceof TypeError) return true; throw e; }
        \\  throw new Error('non-callable size was accepted');
        \\})()
    }, "bf1-strict-stream.js", null, .{ .report = report });
    value.release();
}

fn check() !void {
    try engine.initializeEngine(.{});
    runtime.initializeRuntime(std.testing.allocator);
    defer runtime.deinitializeRuntime();
    interfaces.process_hooks.startHooksForTest();
    const hooks: engine.HostHooks = .{};
    const agent = try engine.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &hooks, .allocator = std.testing.allocator });
    defer engine.destroyAgent(agent);
    const realm = try engine.createWindowRealm(&.{ .agent = agent, .allocator = std.testing.allocator, .from_snapshot = false, .timer = null, .origin = "https://bf1.test", .create_global_object = createGlobal });
    defer engine.destroyWindowRealm(realm, .global_detached);
    try reject(realm);
    const isolate: *ffi.Isolate = @ptrCast(agent);
    const before = ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..64) |_| try reject(realm);
    try std.testing.expectEqual(before, ffi.v8_Isolate_GetGlobalHandleBytes(isolate));
}

test "strict WritableStream callback rejection releases its dictionary member" {
    const Run = struct {
        fn run(result: *anyerror!void) void {
            result.* = check();
        }
    };
    var result: anyerror!void = {};
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    try result;
}
