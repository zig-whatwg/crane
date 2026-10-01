//! Window agents one after another in one process.
//!
//! A host that makes more than one Browser in a process - a test binary, an
//! embedder that tears its browser down and starts another - ends one agent
//! and makes the next. Everything the adapter keeps per isolate (the template
//! registry, the per-interface template caches, window_properties) must end
//! with the agent that made it: V8 may give the next isolate the same address,
//! and a template of a disposed isolate used in a new one is a crash.
//! engine-boundary's worker-realm probe reported (unverified) that a second
//! agent's realm ABRTed; three agents in sequence through the protocol run
//! here without one, and this keeps it so.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// The host's side of a Window realm: it makes the realm's Window.
const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

/// What a script reported, if anything.
const Reports = struct {
    count: usize = 0,

    fn report(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
        const self: *Reports = @ptrCast(@alignCast(host.?));
        self.count += 1;
        std.debug.print("reported: {s}\n", .{info.message});
    }
};

var pools_ready = false;

fn ensurePools() void {
    if (pools_ready) return;
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

/// One agent's life: a Window realm made in it runs script that reaches the
/// platform (a platform object made and read, an interface object's
/// prototype chain), then the realm and the agent end.
fn oneAgent(from_snapshot: bool) !void {
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = from_snapshot, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);
    const realm = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = from_snapshot,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
    });
    defer protocol.destroyWindowRealm(realm, .global_detached);

    var reports: Reports = .{};
    const result = try protocol.evaluateClassicScriptToString(
        realm,
        .{ .utf8 = "const e = new Event('ping', { bubbles: true }); [e.type, e.bubbles, Object.getPrototypeOf(Event.prototype) === Object.prototype, typeof EventTarget].join()" },
        "",
        null,
        std.testing.allocator,
        .{ .report = Reports.report, .host = &reports },
    );
    defer std.testing.allocator.free(result);
    try std.testing.expectEqual(@as(usize, 0), reports.count);
    try std.testing.expectEqualStrings("ping,true,true,function", result);
}

test "a Window agent made after another has ended runs script in its realm" {
    try protocol.initializeEngine(.{});
    ensurePools();
    try oneAgent(false);
    try oneAgent(false);
    try oneAgent(false);
}
