//! `engine.WindowRealmOptions.entered_for_life` (lane cdph, the host API's
//! host-opened tabs): a parentless realm the host makes for a tab beside its
//! first page is entered only for the calls that run in it, as a frame's and a
//! popup's are, so two tabs never stack entered contexts and either can end
//! first. The default - the Browser's first page - stays entered for its life.
//!
//! What is observable through the protocol: outside script the entry realm
//! (engine.entryRealm, V8's entered context) is the realm entered for its
//! life, or none; script runs in each tab's realm whichever ended before it.

const std = @import("std");
const test_process = @import("test_process.zig");
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

fn tabRealm(agent: *protocol.Agent, entered_for_life: bool) !runtime.Context {
    return protocol.createWindowRealm(&.{
        .agent_cluster_cross_origin_isolated = false,
        .agent = agent,
        .allocator = std.heap.c_allocator,
        .from_snapshot = false,
        .timer = null,
        .origin = "https://example.test",
        .create_global_object = WindowHost.createGlobalObject,
        .entered_for_life = entered_for_life,
    });
}

fn ignoreReport(host: ?*anyopaque, info: *const protocol.ErrorInfo) void {
    _ = host;
    _ = info;
}

fn evaluates(realm: runtime.Context, source: []const u8, expected: []const u8) !void {
    const result = try protocol.evaluateClassicScriptToString(realm, .{ .utf8 = source }, "", null, testing.allocator, .{ .report = ignoreReport });
    defer testing.allocator.free(result);
    try testing.expectEqualStrings(expected, result);
}

fn sameRealm(a: ?runtime.Context, b: ?runtime.Context) bool {
    const x = a orelse return b == null;
    const y = b orelse return false;
    return x == y;
}

test "a host tab's realm is entered per call: outside script no realm is entered" {
    test_process.start();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);

    const tab = try tabRealm(agent, false);
    defer protocol.destroyWindowRealm(tab, .global_detached);
    try testing.expect(protocol.entryRealm() == null);
    // Script still runs in it: each call enters it.
    try evaluates(tab, "typeof document + ',' + (1 + 1)", "object,2");
    try testing.expect(protocol.entryRealm() == null);
}

test "two host tabs end in creation order beside a first page entered for its life" {
    test_process.start();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);

    // The Browser's first page: entered for its life, as before.
    const page = try tabRealm(agent, true);
    defer protocol.destroyWindowRealm(page, .global_detached);
    try testing.expect(sameRealm(protocol.entryRealm(), page));

    const first = try tabRealm(agent, false);
    const second = try tabRealm(agent, false);
    // Neither tab took the page's place as the entered realm.
    try testing.expect(sameRealm(protocol.entryRealm(), page));

    try evaluates(first, "globalThis.which = 'first'; which", "first");
    try evaluates(second, "globalThis.which = 'second'; which", "second");

    // The first tab ends while the second lives - the order two stacked
    // entered contexts could not end in.
    protocol.destroyWindowRealm(first, .global_detached);
    try testing.expect(sameRealm(protocol.entryRealm(), page));
    try evaluates(second, "which", "second");
    try evaluates(page, "typeof which", "undefined");
    protocol.destroyWindowRealm(second, .global_detached);
    try testing.expect(sameRealm(protocol.entryRealm(), page));
}

test "host tabs alone, with no page entered for its life, make and end in any order" {
    test_process.start();
    const no_hooks: protocol.HostHooks = .{};
    const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks });
    defer protocol.destroyAgent(agent);

    var tabs: [4]runtime.Context = undefined;
    for (&tabs) |*tab| tab.* = try tabRealm(agent, false);
    try testing.expect(protocol.entryRealm() == null);
    // Ends 1, 3, 0, 2: no order is required.
    for ([_]usize{ 1, 3, 0, 2 }) |index| {
        try evaluates(tabs[index], "'ok'", "ok");
        protocol.destroyWindowRealm(tabs[index], .global_detached);
        try testing.expect(protocol.entryRealm() == null);
    }
}
