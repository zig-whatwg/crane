//! The opaque-root operations (refcount design 2.2-2.3, section 7 step 4):
//! `joinOpaqueRoot` / `leaveOpaqueRoot`, which the host (dom.mutation) calls
//! for a wrapped subtree root that gains or loses a parent, and
//! `keepOpaqueRoot`, which a holder (dom.node_holds) calls for a member. They
//! are the `.emulated` engines' way to keep the browsers' wrapper
//! reachability rule (WebKit's JSNodeOwner::isReachableFromOpaqueRoots): edges
//! drawn when the host says a tree changed (public-API JavaScriptCore, design
//! 5.2).
//!
//! V8's wrapper tracing is NATIVE since the wrapper redesign's P7
//! (tmp/redesign/wrapper-redesign-design.md section 7): the walk keeps trees
//! in cppgc's atomic pause, and node tracing's JS edges are gone - the edge
//! each wrapped node drew to its parent's wrapper (its node document's for a
//! root), its parent's Set of wrapped children, and the upward closure that
//! wrapped every ancestor first. So the host calls none of them for a node
//! on V8 (the calls compile out), and V8's operations draw nothing for a
//! node; a holder's member that is not a node is still kept as traceChild
//! keeps it. The cases that pinned the edges went with them: "a wrapped node
//! inserted under a parent joins its opaque root" (the edge-only case: it ran
//! with the walk turned off, the one state the edges alone decided), "a
//! removed wrapped root keeps its node document through the same slot"
//! (tests/v8/wrapper_walk_test.zig's node -> document cases keep the rule),
//! "joining under a parent script has not seen wraps the parent's chain"
//! (inverted: tests/v8/wr7_edges_gone_test.zig), and keepOpaqueRoot's three
//! node cases (the holders' tracing keeps their nodes: tests/v8/
//! wr6_holder_tracing_test.zig).

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
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

/// What every test here needs started: the engine, the process's hooks and
/// the standalone runtime (test_process.zig).
fn setup() !void {
    test_process.start();
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

/// The slot `keepOpaqueRoot` keeps its member in.
const kept_slot: protocol.TracedSlot = .{ .name = "rc4:opaque-root-test" };

/// The key node tracing's upward edge was kept under, in traceChild's slot
/// namespace (`dom.node_document.traced_slot`, until P7).
const upward_slot: protocol.TracedSlot = .{ .name = "tree parent or node document" };

test "V8 traces node wrappers natively: the host's opaque-root calls compile out" {
    comptime std.debug.assert(protocol.capabilities.wrapper_tracing == .native);
}

test "joinOpaqueRoot and leaveOpaqueRoot draw nothing for a node on V8" {
    const page = try Page.open();
    defer page.close();
    try page.eval(
        \\globalThis.d = new Document();
        \\globalThis.p = d.createElement('div');
        \\globalThis.c = p.appendChild(d.createElement('span'));
    );
    const parent = try page.instance("p");
    const child = try page.instance("c");
    protocol.leaveOpaqueRoot(child, parent);
    protocol.joinOpaqueRoot(child, parent);
    for ([_]*runtime.Instance{ parent, child }) |node| {
        if (protocol.tracedValue(node, upward_slot)) |edge| {
            edge.release();
            return error.EdgeDrawn;
        }
    }
}

test "keepOpaqueRoot: a node member needs no edge on V8 - the slot is emptied - and a member that is not a node is kept as traceChild keeps it" {
    const page = try Page.open();
    defer page.close();
    try page.eval(
        \\globalThis.d = new Document();
        \\globalThis.owner = new Event('holder');
        \\globalThis.m = d.createElement('b');
        \\globalThis.other = new Event('member'); other.mark = 'member';
    );
    const owner = try page.instance("owner");
    const other = try page.instance("other");
    protocol.keepOpaqueRoot(owner, other, kept_slot);
    try expectKept(page, owner, other);
    const generation = runtime.SlabAllocator.generationOf(other);
    try page.eval("delete globalThis.other");
    try page.collect();
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(other));
    // A node member replaces it with nothing.
    protocol.keepOpaqueRoot(owner, try page.instance("m"), kept_slot);
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
        \\globalThis.member = new Event('member');
    );
    const parent = try page.instance("p");
    const child = try page.instance("c");
    const owner = try page.instance("owner");
    const member = try page.instance("member");
    const document = try page.instance("d");
    const unwrapped = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("i"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(child, unwrapped);
    const Round = struct {
        fn run(node: *runtime.Instance, from: *runtime.Instance, holder: *runtime.Instance, kept: *runtime.Instance, deep: *runtime.Instance) void {
            protocol.leaveOpaqueRoot(node, from);
            protocol.joinOpaqueRoot(node, from);
            protocol.keepOpaqueRoot(holder, kept, kept_slot);
            protocol.keepOpaqueRoot(holder, deep, kept_slot);
            protocol.keepOpaqueRoot(holder, kept, kept_slot);
            protocol.forgetTracedChild(holder, kept_slot);
        }
    };
    // The first round makes what every later one reuses.
    Round.run(child, parent, owner, member, unwrapped);
    try page.collect();
    const before = v8.ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    for (0..32) |_| Round.run(child, parent, owner, member, unwrapped);
    try page.collect();
    const after = v8.ffi.v8_Isolate_GetGlobalHandleBytes(isolate);
    if (after > before) {
        std.debug.print("global handles {d} -> {d} bytes over 32 rounds\n", .{ before, after });
        return error.HandlesLeaked;
    }
    try testing.expect(!protocol.hasWrapper(unwrapped));
}
