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
    const b = host.first_child.?;
    try testing.expect(b.bound_v8_wrapper == null);
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

fn nodeFreedUnderTheHold() !void {
    var hold: dom.node_holds.ReachableHold = .{};
    {
        const page = try open();
        defer page.close();
        try page.run("globalThis.target = document.body.appendChild(document.createElement('p')); 0;");
        const base = try page.node("target");
        hold.take(instanceOf(base), base);
        try expectCount(2, base, "the wrapper's (the born reference, adopted) and the hold's");
    }
    // The realm's end freed the node and emptied the hold: nothing is held,
    // and the release makes no engine call and writes nothing.
    try testing.expect(hold.get() == null);
    hold.release();
    hold.release();
}

test "a ReachableHold whose node its realm's end freed holds nothing, and lets go of nothing" {
    try onFreshThread(nodeFreedUnderTheHold);
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
