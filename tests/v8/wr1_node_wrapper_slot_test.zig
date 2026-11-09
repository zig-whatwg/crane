//! The V8 adapter's engine.NodeWrapperSlot (the wrapper redesign's P1,
//! tmp/redesign/wrapper-redesign-design.md sections 3.3 and 7): the node's
//! inline slot is `extern struct { handle: ?*anyopaque }`, today's alias of
//! the wrapper cache's `Global<Object>*` typed; the adapter reaches it only
//! through runtime.lifetime.slotOf (installed by dom.refcount), never by
//! naming NodeBase's field. A wrap writes it. (That a collected wrapper's
//! first pass empties it again, wrapper_cache.unbindNode, is P2's red test:
//! a node held only by a native counted reference - refcount.holderRef - was
//! FREED with its wrapper's collection here, count 2 before it, so this file
//! cannot keep a node past its wrapper yet; lane wr1's handoff.)

const std = @import("std");
const testing = std.testing;
const test_process = @import("test_process.zig");
const runtime = @import("runtime");
const v8 = @import("v8");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const WindowHost = struct {
    fn createGlobalObject(r: runtime.Context, global_this: runtime.JSValue, host: ?*anyopaque) ?*runtime.Instance {
        _ = global_this;
        _ = host;
        return interfaces.Window.init(std.heap.c_allocator, r) catch null;
    }
};

const Page = struct {
    agent: *engine.Agent,
    realm: runtime.Context,

    fn open() !Page {
        test_process.start();
        const no_hooks: engine.HostHooks = .{};
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

    fn close(self: Page) void {
        engine.destroyWindowRealm(self.realm, .global_detached);
        engine.destroyAgent(self.agent);
    }

    fn noReport(_: ?*anyopaque, info: *const engine.ErrorInfo) void {
        std.debug.print("reported: {s}\n", .{info.message});
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        const held = try engine.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, .{ .report = noReport, .host = null });
        defer held.release();
        return engine.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }
};

/// The binding's wrap of `instance` as an HTMLDivElement, in `realm`: the
/// handle it answers (BORROWED: the cache's).
const Wrap = struct {
    instance: *runtime.Instance,
    realm: runtime.Context,
    wrapper: ?*v8.ffi.Object = null,

    fn steps(data: ?*anyopaque) void {
        const self: *Wrap = @ptrCast(@alignCast(data.?));
        const isolate: *v8.ffi.Isolate = v8.ffi.v8_Isolate_GetCurrent().?;
        const context: *v8.ffi.Context = @ptrCast(@alignCast(self.realm.engine_ctx.?));
        self.wrapper = v8.template_registry.wrapInstanceAsV8Object(self.instance, "HTMLDivElement", isolate, context) catch null;
    }
};

const xhtml = "http://www.w3.org/1999/xhtml";

test "V8's slot is one pointer: 8 bytes, the alias typed, empty by default" {
    try testing.expectEqual(@as(usize, 8), @sizeOf(engine.NodeWrapperSlot));
    try testing.expectEqual(@as(usize, 8), @alignOf(engine.NodeWrapperSlot));
    const slot: engine.NodeWrapperSlot = .empty;
    try testing.expect(slot.isEmpty());
    try testing.expect(slot.handle == null);
}

test "slotOf answers the node's own slot, empty until the wrap writes the wrapper there" {
    const page = try Page.open();
    defer page.close();
    const document = try page.instance("globalThis.d = new Document(); d");
    const div = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    const node = dom.instance_bridge.getNodeBase(div).?;
    const slot = runtime.lifetime.slotOf(node);
    try testing.expect(slot == &node.wrapper);
    try testing.expect(slot.isEmpty());

    var wrap: Wrap = .{ .instance = div, .realm = page.realm };
    try engine.runInRealm(page.realm, Wrap.steps, &wrap);
    const wrapper = wrap.wrapper orelse return error.TestWrapFailed;
    try testing.expect(!slot.isEmpty());
    try testing.expect(slot.handle == @as(?*anyopaque, @ptrCast(wrapper)));

    // A second wrap, in any realm of the agent, answers the slot's wrapper.
    var again: Wrap = .{ .instance = div, .realm = page.realm };
    try engine.runInRealm(page.realm, Wrap.steps, &again);
    try testing.expect(again.wrapper.? == wrapper);
}
