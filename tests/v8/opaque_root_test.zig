//! The opaque-root operations (refcount design 2.2-2.3, section 7 step 4):
//! `joinOpaqueRoot` / `leaveOpaqueRoot`, which the host (dom.mutation) calls
//! for a wrapped subtree root that gains or loses a parent, in place of the
//! adapter's own mutation hooks. On V8 they are node tracing's edges: a
//! wrapped node's wrapper holds its parent's - its node document's while it
//! is a root, one slot (dom.node_document.traced_slot, lane ownerdoc) - and a
//! parent's holds a Set of its wrapped children's. WebKit computes the same
//! rule at marking time (JSNodeOwner::isReachableFromOpaqueRoots, the root
//! node as the opaque root); V8 13.1 has no public way to, short of cppgc
//! (decision D4).
//!
//! Wrappers are made the way the binding makes them (script) and collected by
//! the engine; the operations are also called directly, on a node that stays
//! in its tree, to pin what each one draws.

const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

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
    runtime.initializeRuntime(std.heap.page_allocator);
    pools_ready = true;
}

const Page = struct {
    agent: *protocol.Agent,
    realm: runtime.Context,

    fn open() !Page {
        try setup();
        const no_hooks: protocol.HostHooks = .{};
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

    fn eval(self: Page, source: []const u8) !void {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
    }

    fn instance(self: Page, source: []const u8) !*runtime.Instance {
        var reports: Reports = .{};
        const held = try protocol.evaluateClassicScript(self.realm, .{ .utf8 = source }, "", null, reports.reporter());
        defer held.release();
        try testing.expectEqual(@as(usize, 0), reports.count);
        return protocol.convertToPlatformObject(self.realm, held.value) orelse error.NotAPlatformObject;
    }

    fn collect(self: Page) !void {
        const Collect = struct {
            fn steps(data: ?*anyopaque) void {
                protocol.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
            }
        };
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
        try protocol.runInRealm(self.realm, Collect.steps, self.agent);
    }

    fn answer(self: Page, source: []const u8) ![]u8 {
        var reports: Reports = .{};
        return protocol.evaluateClassicScriptToString(self.realm, .{ .utf8 = source }, "", null, testing.allocator, reports.reporter());
    }

    fn expect(self: Page, source: []const u8, expected: []const u8) !void {
        const got = try self.answer(source);
        defer testing.allocator.free(got);
        testing.expectEqualStrings(expected, got) catch |err| {
            std.debug.print("{s}\n", .{source});
            return err;
        };
    }
};

const xhtml = "http://www.w3.org/1999/xhtml";

/// What `node`'s upward slot holds is `expected`'s wrapper.
fn expectSlot(page: Page, node: *runtime.Instance, expected: *runtime.Instance) !void {
    const value = protocol.tracedValue(node, dom.node_document.traced_slot) orelse return error.EmptySlot;
    defer value.release();
    try testing.expect(protocol.sameValue(page.realm, value.borrow(), .{ .instance = expected }));
}

test "a wrapped node inserted under a parent joins its opaque root: the parent's wrapper keeps it" {
    const page = try Page.open();
    defer page.close();
    try page.eval(
        \\globalThis.d = new Document();
        \\globalThis.p = d.createElement('div');
        \\(() => { const c = d.createElement('span'); c.mark = 'kept'; p.appendChild(c); })();
    );
    const parent = try page.instance("p");
    const child = try page.instance("p.firstChild");
    try expectSlot(page, child, parent);
    try page.collect();
    // Only the parent's wrapper reached the child's: its expando survived.
    try page.expect("p.firstChild.mark", "kept");

    // Left directly (the node stays in its tree): the edges between the two
    // go, and the child's wrapper is the collector's; the node is its
    // tree's, and a later read makes a new wrapper.
    protocol.leaveOpaqueRoot(child, parent);
    try expectSlot(page, child, try page.instance("d"));
    try page.collect();
    try page.expect("String(p.firstChild.mark)", "undefined");

    // Joined again: the new wrapper is kept again.
    try page.eval("p.firstChild.mark = 'again'");
    protocol.joinOpaqueRoot(child, parent);
    try expectSlot(page, child, parent);
    try page.collect();
    try page.expect("p.firstChild.mark", "again");
}

test "a removed wrapped root keeps its node document through the same slot, and its old parent lets it go" {
    const page = try Page.open();
    defer page.close();
    try page.eval(
        \\globalThis.d = new Document();
        \\globalThis.p = d.createElement('div');
        \\globalThis.c = p.appendChild(d.createElement('span'));
        \\c.mark = 'root';
    );
    const child = try page.instance("c");
    try expectSlot(page, child, try page.instance("p"));
    try page.eval("p.removeChild(c)");
    try expectSlot(page, child, try page.instance("d"));
    // Moved under another parent with moveBefore: the edges follow it.
    try page.eval("globalThis.q = d.createElement('section'); d.appendChild(q); d.documentElement.appendChild(p); q.appendChild(c); 'ok'");
    try page.eval("p.moveBefore(c, null)");
    try expectSlot(page, child, try page.instance("p"));
}

test "joining under a parent script has not seen wraps the parent's chain: the wrapped part of a tree is upward-closed" {
    const page = try Page.open();
    defer page.close();
    const document = try page.instance("globalThis.d = new Document(); d");
    var nodes: [3]*runtime.Instance = undefined;
    for (&nodes) |*node| {
        node.* = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    }
    _ = try interfaces.Node.call_appendChild(nodes[0], nodes[1]);
    try testing.expect(!protocol.hasWrapper(nodes[0]));
    // The leaf is wrapped, then inserted natively under the unwrapped middle.
    const leaf = try protocol.retainValue(page.realm, .{ .instance = nodes[2] });
    defer leaf.release();
    _ = try interfaces.Node.call_appendChild(nodes[1], nodes[2]);
    try testing.expect(protocol.hasWrapper(nodes[1]));
    try testing.expect(protocol.hasWrapper(nodes[0]));
    try expectSlot(page, nodes[2], nodes[1]);
    try expectSlot(page, nodes[1], nodes[0]);
}

// ============================================================================
// keepOpaqueRoot: a holder's wrapper keeps a node's opaque root
// ============================================================================

const kept_slot: protocol.TracedSlot = .{ .name = "rc4:opaque-root-test" };

test "keepOpaqueRoot: a wrapped member is kept by the owner's wrapper itself" {
    const page = try Page.open();
    defer page.close();
    try page.eval(
        \\globalThis.d = new Document();
        \\globalThis.owner = new Event('holder');
        \\globalThis.m = d.createElement('b'); m.mark = 'member';
    );
    const owner = try page.instance("owner");
    const member = try page.instance("m");
    protocol.keepOpaqueRoot(owner, member, kept_slot);
    try expectKept(page, owner, member);
    const generation = runtime.SlabAllocator.generationOf(member);
    try page.eval("delete globalThis.m");
    try page.collect();
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(member));
    // The same wrapper, expando and all.
    const value = protocol.tracedValue(owner, kept_slot) orelse return error.EmptySlot;
    defer value.release();
    try testing.expect(protocol.sameValue(page.realm, value.borrow(), .{ .instance = member }));
}

test "keepOpaqueRoot: an unwrapped member's tree is kept through its wrapped root, and forgetTracedChild ends it" {
    const page = try Page.open();
    defer page.close();
    try page.eval(
        \\globalThis.d = new Document();
        \\globalThis.owner = new Event('holder');
        \\globalThis.r = d.createElement('section'); r.mark = 'root';
    );
    const document = try page.instance("d");
    const root = try page.instance("r");
    // An unwrapped member deep in the tree.
    const middle = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
    const member = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("i"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(middle, member);
    _ = try interfaces.Node.call_appendChild(root, middle);
    try testing.expect(!protocol.hasWrapper(member));

    const owner = try page.instance("owner");
    protocol.keepOpaqueRoot(owner, member, kept_slot);
    // No wrapper made for the member: the edge goes to its tree's root.
    try testing.expect(!protocol.hasWrapper(member));
    try expectKept(page, owner, root);
    const generation = runtime.SlabAllocator.generationOf(member);
    try page.eval("delete globalThis.r");
    try page.collect();
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(member));

    // Ended: nothing keeps the tree, and it goes.
    protocol.forgetTracedChild(owner, kept_slot);
    try page.collect();
    try testing.expect(generation != runtime.SlabAllocator.generationOf(member));
}

test "keepOpaqueRoot: a tree with no wrapper has nothing to keep, and the slot is emptied" {
    const page = try Page.open();
    defer page.close();
    try page.eval(
        \\globalThis.d = new Document();
        \\globalThis.owner = new Event('holder');
        \\globalThis.w = d.createElement('p');
    );
    const owner = try page.instance("owner");
    const document = try page.instance("d");
    const member = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("i"), .{ .was_passed = false, .value = undefined });
    // A member kept earlier is replaced by the new one's (nothing).
    protocol.keepOpaqueRoot(owner, try page.instance("w"), kept_slot);
    protocol.keepOpaqueRoot(owner, member, kept_slot);
    try testing.expect(!protocol.hasWrapper(member));
    try testing.expect(protocol.tracedValue(owner, kept_slot) == null);
}

/// What `owner` keeps in `kept_slot` is `expected`'s wrapper.
fn expectKept(page: Page, owner: *runtime.Instance, expected: *runtime.Instance) !void {
    const value = protocol.tracedValue(owner, kept_slot) orelse return error.EmptySlot;
    defer value.release();
    try testing.expect(protocol.sameValue(page.realm, value.borrow(), .{ .instance = expected }));
}

test "joinOpaqueRoot, leaveOpaqueRoot and keepOpaqueRoot leave no global handle behind" {
    const page = try Page.open();
    defer page.close();
    const isolate: *v8.ffi.Isolate = @ptrCast(@alignCast(page.agent));
    try page.eval(
        \\globalThis.d = new Document();
        \\globalThis.p = d.createElement('div');
        \\globalThis.c = p.appendChild(d.createElement('span'));
        \\globalThis.owner = new Event('holder');
    );
    const parent = try page.instance("p");
    const child = try page.instance("c");
    const owner = try page.instance("owner");
    const document = try page.instance("d");
    const unwrapped = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("i"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(child, unwrapped);
    const Round = struct {
        fn run(member: *runtime.Instance, from: *runtime.Instance, holder: *runtime.Instance, deep: *runtime.Instance) void {
            protocol.leaveOpaqueRoot(member, from);
            protocol.joinOpaqueRoot(member, from);
            protocol.keepOpaqueRoot(holder, member, kept_slot);
            protocol.keepOpaqueRoot(holder, deep, kept_slot);
            protocol.forgetTracedChild(holder, kept_slot);
        }
    };
    // The first round makes what every later one reuses.
    Round.run(child, parent, owner, unwrapped);
    try page.collect();
    const before = v8.ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..32) |_| Round.run(child, parent, owner, unwrapped);
    try page.collect();
    const after = v8.ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after > before) {
        std.debug.print("global handles {d} -> {d} bytes over 32 rounds\n", .{ before, after });
        return error.HandlesLeaked;
    }
    try testing.expect(!protocol.hasWrapper(unwrapped));
}
