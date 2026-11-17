//! Lane refcount5 (refcount step 5c): node_holds.ReachableHold, the
//! shadow-mode GCReachableRef with no wrap net - WebKit's GCReachableRef
//! (Source/WebCore/dom/GCReachableRef.h): a counted reference on the node and
//! a counted keep of its wrapper, which JSNodeOwner::isReachableFromOpaqueRoots
//! reads for a disconnected node. Each case observes the node's lifetime
//! directly (a WeakRef made in an earlier job, collections from native code
//! between jobs) and the count through dom.refcount.count: the wrapper's (1;
//! it adopted the node's born reference, lane refcount7) + the holds'.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;
const expectCount = h.expectCount;

fn open() !h.Page {
    return h.Page.open();
}

fn instanceOf(base: *dom.NodeBase) *runtime.Instance {
    return @ptrCast(@alignCast(dom.instance_bridge.getInstance(base).?));
}

fn expectTrue(page: h.Page, source: []const u8) !void {
    const value = try page.browser.evaluateScript(source);
    defer value.release();
    if (!engine.toBoolean(page.browser.getRealm().?, value.borrow())) {
        std.debug.print("expected true: {s}\n", .{source});
        return error.TestExpectedTrue;
    }
}

/// Two full collections from native code, outside any script job, after a
/// task turn (which ends the job's own WeakRef roots).
fn collect(page: h.Page) !void {
    const Collect = struct {
        fn steps(data: ?*anyopaque) void {
            engine.requestGarbageCollection(@ptrCast(@alignCast(data.?)));
        }
    };
    _ = try page.browser.runEventLoopBlocking(1);
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    const agent = page.browser.getAgent() orelse return error.NoAgent;
    try engine.runInRealm(realm, Collect.steps, agent);
    _ = try page.browser.runEventLoopBlocking(1);
    try engine.runInRealm(realm, Collect.steps, agent);
}

fn holdKeepsTheWrapperUntilReleased() !void {
    const page = try open();
    defer page.close();
    try page.run("globalThis.weak = new WeakRef(globalThis.target = document.createElement('p')); target.expando = 'kept'; 0;");
    const base = try page.node("target");
    var hold: dom.node_holds.ReachableHold = .{};
    defer hold.release();
    hold.take(instanceOf(base), base);
    try expectCount(2, base, "the wrapper's (the born reference, adopted) and the hold's");
    // Script lets go of the detached node; only the hold keeps it.
    try page.run("target = null; 0;");
    try collect(page);
    try expectTrue(page, "weak.deref() !== undefined && weak.deref().expando === 'kept'");
    hold.release();
    try collect(page);
    try expectTrue(page, "weak.deref() === undefined");
}

test "a ReachableHold counts its node and keeps its wrapper until it is released" {
    try onFreshThread(holdKeepsTheWrapperUntilReleased);
}

fn keepWaitsForTheWrapper() !void {
    const page = try open();
    defer page.close();
    try page.run("globalThis.host = document.createElement('div'); host.innerHTML = '<b></b>'; 0;");
    const host = try page.node("host");
    const b = host.firstChild().?;
    try testing.expect(b.wrapper.isEmpty());
    var hold: dom.node_holds.ReachableHold = .{};
    defer hold.release();
    // Taken while the node has no wrapper: the keep waits for one.
    hold.take(instanceOf(b), b);
    try expectCount(1, b, "the hold's alone: its insertion ended its born reference");
    try page.run("globalThis.weak = new WeakRef(host.firstChild); host.firstChild.expando = 'kept'; host.innerHTML = ''; host = null; 0;");
    try collect(page);
    try expectTrue(page, "weak.deref() !== undefined && weak.deref().expando === 'kept'");
    hold.release();
    try collect(page);
    try expectTrue(page, "weak.deref() === undefined");
}

test "a keep taken before the node has a wrapper is the wrapper's when it is made" {
    try onFreshThread(keepWaitsForTheWrapper);
}

/// A ReachableHold is no realm's: since refcount step 7b (lane rc7b) a
/// realm's end frees no node whatever its counts, so the hold keeps its node -
/// and the node's tree - past its realm's end, readable, and its release lets
/// the counts free it. (Until 7b the realm's end freed the node under the
/// hold, which then read it as gone and let nothing go.)
fn holdOutlivesItsRealm() !void {
    const page = try open();
    defer page.close();
    try page.run("globalThis.target = document.body.appendChild(document.createElement('p')); 0;");
    const base = try page.node("target");
    const instance = instanceOf(base);
    const generation = runtime.SlabAllocator.generationOf(instance);
    var hold: dom.node_holds.ReachableHold = .{};
    defer hold.release();
    hold.take(instance, base);
    try expectCount(2, base, "the wrapper's (the born reference, adopted) and the hold's");

    // The page ends - a fresh top-level traversable - and its realm with it;
    // the collections take the old page's wrappers.
    try page.browser.navigate("about:blank", .window);
    const context = page.browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    for (0..3) |_| try collect(page);
    try testing.expectEqual(generation, runtime.SlabAllocator.generationOf(instance));
    try testing.expect(hold.get() == instance);
    try testing.expectEqual(dom.NodeBase.ELEMENT_NODE, base.node_type);
    try expectCount(1, base, "the hold's alone, its wrapper collected with its realm");

    // The hold ends: the counts free the node, between tasks.
    hold.release();
    for (0..3) |_| try collect(page);
    try testing.expect(runtime.SlabAllocator.generationOf(instance) != generation);
}

test "a ReachableHold keeps its node past its realm's end, and its release lets the counts free it" {
    try onFreshThread(holdOutlivesItsRealm);
}

fn emptyHold() !void {
    var hold: dom.node_holds.ReachableHold = .{};
    try testing.expect(hold.get() == null);
    hold.release();
    try testing.expect(!hold.kept);
}

test "a ReachableHold never taken lets go of nothing" {
    try emptyHold();
}
