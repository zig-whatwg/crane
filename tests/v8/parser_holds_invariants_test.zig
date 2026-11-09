//! The two facts the parser's native holds rest on (tmp/plans/parser-holds-
//! design.md 2, L1 and L2; 6.1 S11). The live parser holds its stack of open
//! elements, head and form pointers with no wrapper, and roots ONE wrapper -
//! the detached tree's root - when script detaches a tree it holds. That is
//! safe only while:
//!
//! - L1: the collector frees a node only as a root, or inside a root's subtree:
//!   a parented node whose wrapper dies is kept (`treeOwns`), and an unwrapped
//!   root is never freed by the collector at all;
//! - L2: one rooted wrapper keeps its tree's root - until the wrapper
//!   redesign's P7 because wrappers in a tree were upward-closed and linked
//!   both ways (wrapping a node wrapped every ancestor), since P7 because its
//!   reference counts in the tree's total (refcount step 7) and the walk
//!   keeps the tree's wrappers. The parser no longer leans on L2: since P6
//!   the Document traces its parser's held nodes and the rescue is gone.
//!
//! A change to either - freeing parented nodes on collection - voids the
//! proof, so these tests pin both, the predicate's default included; P7's
//! "a wrap wraps no ancestor" is pinned where the upward closure was.
//!
//! The file shares tests/v8's process: it starts the engine as any file may
//! (initializeEngine is idempotent) and makes its own agent.

const std = @import("std");
const test_process = @import("test_process.zig");
const testing = std.testing;
const runtime = @import("runtime");
const v8 = @import("v8");
const protocol = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");

const treeOwns = v8.wrapper_cache_mod.treeOwns;

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
};

const xhtml = "http://www.w3.org/1999/xhtml";

/// A detached root > middle > leaf chain of divs, made natively in a fresh
/// Document script holds: no node of it has a wrapper.
const Chain = struct {
    root: *runtime.Instance,
    middle: *runtime.Instance,
    leaf: *runtime.Instance,
    generations: [3]u64,

    fn make(page: Page) !Chain {
        const document = try page.instance("globalThis.d = new Document(); d");
        var nodes: [3]*runtime.Instance = undefined;
        for (&nodes) |*node| {
            node.* = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned(xhtml), runtime.DOMString.initInterned("div"), .{ .was_passed = false, .value = undefined });
        }
        _ = try interfaces.Node.call_appendChild(nodes[0], nodes[1]);
        _ = try interfaces.Node.call_appendChild(nodes[1], nodes[2]);
        var chain: Chain = .{ .root = nodes[0], .middle = nodes[1], .leaf = nodes[2], .generations = undefined };
        for (nodes, 0..) |node, i| chain.generations[i] = runtime.SlabAllocator.generationOf(node);
        return chain;
    }

    /// Frees the chain the test made and script never saw: its root, with
    /// its subtree, as a native creator frees a node it is done with
    /// (dom.node_creation.releaseIfUnwrapped); a wrapped root is its
    /// wrapper's, and a root already freed is left alone.
    fn release(self: Chain) void {
        dom.node_creation.releaseIfUnwrapped(self.root, self.generations[0]);
    }

    fn alive(self: Chain, which: usize) bool {
        const node = switch (which) {
            0 => self.root,
            1 => self.middle,
            else => self.leaf,
        };
        return runtime.SlabAllocator.generationOf(node) == self.generations[which];
    }
};

test "L1: treeOwns keeps a parented node and, by default, not a parentless one" {
    const page = try Page.open();
    defer page.close();
    const chain = try Chain.make(page);
    defer chain.release();
    try testing.expect(treeOwns(chain.middle));
    try testing.expect(treeOwns(chain.leaf));
    try testing.expect(!treeOwns(chain.root));
    // A non-node is never a tree's.
    const headers = try interfaces.Headers.init(testing.allocator, page.realm);
    defer runtime.Instance.deinit(headers);
    try testing.expect(!treeOwns(headers));
}

test "L1: the collector never frees an unwrapped root, and frees a wrapped root with its whole subtree" {
    const page = try Page.open();
    defer page.close();
    const chain = try Chain.make(page);
    try page.collect();
    try testing.expect(chain.alive(0) and chain.alive(1) and chain.alive(2));

    // Wrap the root only, and let go of it.
    const root_wrapper = try protocol.retainValue(page.realm, .{ .instance = chain.root });
    root_wrapper.release();
    try testing.expect(!protocol.hasWrapper(chain.leaf));
    try page.collect();
    try testing.expect(!chain.alive(0));
    try testing.expect(!chain.alive(1));
    try testing.expect(!chain.alive(2));
}

test "L2, since P7: wrapping a deep node of a detached unwrapped tree wraps no ancestor" {
    const page = try Page.open();
    defer page.close();
    const chain = try Chain.make(page);
    defer chain.release();
    try testing.expect(!protocol.hasWrapper(chain.root));
    const leaf_wrapper = try protocol.retainValue(page.realm, .{ .instance = chain.leaf });
    defer leaf_wrapper.release();
    // Until P7 the wrap wrapped the middle and the root (node tracing's
    // upward closure); the walk keeps the tree's wrappers instead.
    try testing.expect(!protocol.hasWrapper(chain.middle));
    try testing.expect(!protocol.hasWrapper(chain.root));
}

test "L2: one rooted wrapper keeps its tree's root through a collection, and the tree goes with it" {
    const page = try Page.open();
    defer page.close();
    const chain = try Chain.make(page);
    // The parser's rescue roots the ROOT's wrapper; rooting any wrapper of the
    // tree must keep the root, wherever script moves the rooted node later.
    var held: ?protocol.Owned = try protocol.retainValue(page.realm, .{ .instance = chain.leaf });
    defer if (held) |owned| owned.release();
    try page.collect();
    try testing.expect(chain.alive(0) and chain.alive(1) and chain.alive(2));
    held.?.release();
    held = null;
    // The root still carries its native creator's reference: since P7 the
    // leaf's wrap no longer wrapped it (a root's first wrapper took that
    // reference over), so the creator lets go of it, as it does of a tree it
    // is done with - and nothing holds the tree any more.
    try page.collect();
    try testing.expect(chain.alive(0));
    chain.release();
    try page.collect();
    try testing.expect(!chain.alive(0));
    try testing.expect(!chain.alive(2));
}

test "L2: a rescued root keeps a subtree whose nodes have no wrapper" {
    const page = try Page.open();
    defer page.close();
    const chain = try Chain.make(page);
    const held = try protocol.retainValue(page.realm, .{ .instance = chain.root });
    defer held.release();
    try page.collect();
    try testing.expect(!protocol.hasWrapper(chain.leaf));
    try testing.expect(chain.alive(0) and chain.alive(1) and chain.alive(2));
}
