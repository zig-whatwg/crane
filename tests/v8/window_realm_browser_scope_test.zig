//! `engine.WindowRealmOptions.browser_scope` (docs/engine-protocol.md,
//! "Browser"): the engine records the realm's Browser before it asks the host
//! for the realm's Window, so the Window - the realm's first platform object -
//! is made knowing which Browser it belongs to. A frame's realm is given its
//! parent's.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

/// What `create_global_object` saw of its realm.
const Seen = struct {
    scope: ?*runtime.BrowserScope = null,
    calls: usize = 0,

    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        const self: *Seen = @ptrCast(@alignCast(host.?));
        self.calls += 1;
        self.scope = r.browser_scope;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

test "a window realm's Browser is recorded before its Window is made, and a frame's is given its parent's" {
    try setup();
    var scope = runtime.BrowserScope.init(testing.allocator);
    defer scope.deinit();

    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
    defer protocol.destroyAgent(agent);

    var page_seen: Seen = .{};
    const page = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .browser_scope = &scope,
        .create_global_object = Seen.createGlobalObject,
        .host = &page_seen,
    });
    defer protocol.destroyWindowRealm(page, .global_detached);
    try testing.expectEqual(@as(usize, 1), page_seen.calls);
    try testing.expectEqual(@as(?*runtime.BrowserScope, &scope), page_seen.scope);
    try testing.expectEqual(@as(?*runtime.BrowserScope, &scope), page.browser_scope);

    var frame_seen: Seen = .{};
    const frame = try protocol.createWindowRealm(&.{
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .parent = page,
        .browser_scope = page.browser_scope,
        .create_global_object = Seen.createGlobalObject,
        .host = &frame_seen,
    });
    defer protocol.destroyWindowRealm(frame, .navigable_destroyed);
    try testing.expectEqual(@as(?*runtime.BrowserScope, &scope), frame_seen.scope);
}
