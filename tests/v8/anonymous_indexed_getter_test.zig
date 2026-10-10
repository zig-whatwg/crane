//! WebIDL 2.5.6.1 / 3.9: an anonymous indexed property getter, `getter T
//! (unsigned long index)` - bound as `call_getter(instance, u32)` - makes
//! its object support indexed properties: obj[i], `i in obj`,
//! Object.getOwnPropertyDescriptor and Object.keys see the supported
//! property indices (those below `length`), and any other index is no
//! property at all. The binding installed indexed access only for a named
//! `item` getter (call_item), so `dataTransfer.items[0]` read undefined.
//! Codegen gates the anonymous getter (Meta.indexed_getter_implemented),
//! and the binding installs indexed access only where the impl has it.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agents.

const std = @import("std");
const runtime = @import("runtime");
const protocol = @import("engine");
const interfaces = @import("interfaces");

comptime {
    // Implemented: the binding installs indexed access.
    std.debug.assert(interfaces.DataTransferItemList.Meta.indexed_getter_implemented);
    std.debug.assert(interfaces.TextTrackList.Meta.indexed_getter_implemented);
    // Not implemented yet: no indexed access, and the gated delegate compiles.
    std.debug.assert(!interfaces.AudioTrackList.Meta.indexed_getter_implemented);
    std.debug.assert(!interfaces.SourceBufferList.Meta.indexed_getter_implemented);
    // A named `item` getter, and a merged indexed+named anonymous pair, carry
    // no constant.
    std.debug.assert(!@hasDecl(interfaces.HTMLCollection.Meta, "indexed_getter_implemented"));
    std.debug.assert(!@hasDecl(interfaces.HTMLFormElement.Meta, "indexed_getter_implemented"));
}

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

var pools_ready = false;

fn setup() !void {
    try protocol.initializeEngine(.{});
    if (pools_ready) return;
    interfaces.process_hooks.startHooksForTest();
    runtime.SlabAllocator.init(std.heap.page_allocator);
    runtime.ArenaAllocator.init(std.heap.page_allocator);
    pools_ready = true;
}

const no_hooks: protocol.HostHooks = .{};

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const agent = try protocol.createAgent(.{ .can_block = false, .from_snapshot = false, .hooks = &no_hooks, .host = null });
        errdefer protocol.destroyAgent(agent);
        const realm = try protocol.createWindowRealm(&.{
            .agent = agent,
            .allocator = std.heap.c_allocator,
            .from_snapshot = false,
            .timer = null,
            .origin = "https://example.test",
            .create_global_object = WindowHost.createGlobalObject,
        });
        return .{ .agent = agent, .realm = realm };
    }

    fn close(self: Page) void {
        protocol.destroyWindowRealm(self.realm, .global_detached);
        protocol.destroyAgent(self.agent);
    }

    /// Whether `source` evaluates to true; nothing reported.
    fn holds(self: Page, source: []const u8) !bool {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try std.testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.toBoolean(self.realm, held.value);
    }
};

test "an anonymous indexed getter: obj[i], i in obj, own property descriptors and keys" {
    const page = try Page.open();
    defer page.close();
    try std.testing.expect(try page.holds(
        \\globalThis.dt = new DataTransfer();
        \\globalThis.items = dt.items;
        \\globalThis.first = items.add('a', 'text/plain');
        \\items.add('b', 'text/html');
        \\items.length === 2
    ));
    try std.testing.expect(try page.holds("items[0] === first && items[0].type === 'text/plain' && items[1].type === 'text/html'"));
    try std.testing.expect(try page.holds("items[0] === items[0] && items[1] === items[1]"));
    // Unsupported indices are no property: undefined, not a throw.
    try std.testing.expect(try page.holds("items[2] === undefined && items[100] === undefined && items[4294967294] === undefined && items[4294967295] === undefined && items[-1] === undefined"));
    try std.testing.expect(try page.holds("(0 in items) && (1 in items) && !(2 in items)"));
    try std.testing.expect(try page.holds(
        \\(() => {
        \\  const d = Object.getOwnPropertyDescriptor(items, 0);
        \\  return d.value === items[0] && d.writable === false && d.enumerable === true && d.configurable === true &&
        \\    Object.getOwnPropertyDescriptor(items, 2) === undefined;
        \\})()
    ));
    try std.testing.expect(try page.holds("JSON.stringify(Object.keys(items)) === '[\"0\",\"1\"]'"));
    // WebIDL 3.7.9 step 1: an indexed getter's %Symbol.iterator% is %Array.prototype.values%.
    try std.testing.expect(try page.holds("DataTransferItemList.prototype[Symbol.iterator] === Array.prototype.values && Array.from(items, i => i.type).join() === 'text/plain,text/html'"));
    // The getter is anonymous: no `item` operation on the prototype.
    try std.testing.expect(try page.holds("!('item' in DataTransferItemList.prototype)"));
    // Live: after a removal the indices follow the store.
    try std.testing.expect(try page.holds("items.remove(0); items.length === 1 && items[0].type === 'text/html' && items[1] === undefined && !(1 in items)"));
}
