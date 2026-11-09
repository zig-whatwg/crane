//! A holder that outlives its node through a teardown the counts do not
//! decide - a realm's coordinated teardown, the browser's final registry
//! sweep - lets it go without touching the freed node.
//!
//! Those teardowns free a node's NodeBase and can leave its slab slot, and
//! so its generation, live. Since the wrapper redesign's P6 a hold has no
//! link on the node (the per-node chain and `node_holds.nodeReleased` are
//! gone): it reads the slot's stamp - the generation, and the teardown-begun
//! flag that Node.deinit and the final sweep's release of the NodeBase set -
//! and reads a node whose teardown began as gone, forgetting its reference
//! (a teardown net, not the behaviour). The slab is the Browser's, so a hold
//! must not outlive its node's Browser: the tests let go inside it. Run
//! under std.testing.allocator, whose freed blocks are poisoned.
const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const helpers = @import("edges_node_holders_helpers.zig");
const onFreshThread = helpers.onFreshThread;

fn holderOutlivesItsFramesTeardown() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe id=f></iframe></body>", .{ .base_url = "http://example.test/holds" });
    _ = try browser.runEventLoopBlocking(20);
    // The list lives in the parent's realm and holds nodes of the frame's
    // document, which goes with the frame's realm.
    try page.runScript(
        \\const frameDocument = document.getElementById('f').contentDocument;
        \\frameDocument.body.innerHTML = '<p id=x>x</p><p id=y>y</p>';
        \\globalThis.list = frameDocument.querySelectorAll('p');
        \\if (list.length !== 2) throw new Error('length');
    );
    try page.runScript("document.getElementById('f').remove()");
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript(
        \\TestUtils.gc();
        \\TestUtils.gc();
        \\if (list.length !== 2) throw new Error('a static list keeps its length');
        \\const first = list.item(0);
        \\// Kept by the list and read back, or freed with the frame's realm and
        \\// read as null - never a freed node.
        \\if (first !== null && first.id !== 'x') throw new Error('a freed node read back: ' + first);
    );
    const outcome = try page.evaluateScriptToString("list.item(0) === null ? 'released with the frame' : 'kept by the list'", testing.allocator);
    defer testing.allocator.free(outcome);
    std.log.debug("a frame's node held across its realm's end: {s}", .{outcome});
    try page.runScript("delete globalThis.list; TestUtils.gc(); TestUtils.gc();");
    _ = try browser.runEventLoopBlocking(20);
}

test "a static list in a parent realm outlives the nodes of a removed frame and lets go cleanly" {
    try onFreshThread(holderOutlivesItsFramesTeardown);
}

fn holderOutlivesItsRealmsTeardown() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body><iframe id=f></iframe></body>", .{ .base_url = "http://example.test/holds" });
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript("document.getElementById('f').contentDocument.body.innerHTML = '<p id=held>held</p>'");
    const document = page.document_instance orelse return error.NoDocument;
    const frame = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("f"))) orelse return error.NoFrame;
    const frame_document = (try interfaces.HTMLIFrameElement.get_contentDocument(frame)) orelse return error.NoFrameDocument;

    // A node of the frame's document, held by a holder of the test's own.
    // Removing the frame ends its realm: the realm's coordinated teardown
    // frees the frame document's tree whatever the counts say, through each
    // node's deinit, with the slab generation left live.
    const held = (try interfaces.Document.call_getElementById(frame_document, runtime.DOMString.initInterned("held"))) orelse return error.NoElement;
    var holder = dom.node_holds.Holder.init(testing.allocator);
    defer holder.release();
    try holder.hold(*runtime.Instance, &.{held});
    try testing.expect(holder.get(0) == held);

    try page.runScript("document.getElementById('f').remove()");
    _ = try browser.runEventLoopBlocking(20);

    // Torn down, or still the frame's: never a freed node read back. A node
    // whose teardown began reads as gone, and the deferred release - inside
    // the Browser, whose slab its stamp is in - touches nothing of it.
    if (holder.get(0)) |node| try testing.expect(node == held);
}

test "a holder that outlives its node's realm teardown lets go without touching the freed node" {
    try onFreshThread(holderOutlivesItsRealmsTeardown);
}

/// The final sweep's probe: a sweep the test adds after the Document's
/// (`teardown_sweeps.withSweepForTest`), which runs once the `.nodes` sweep
/// released every node's NodeBase (poisoned) and before the Browser's slab
/// goes - the window a hold could be read in.
const SweptProbe = struct {
    var ref_hold: dom.node_holds.RefHold = .{};
    var counted: dom.node_holds.CountedRef = .{};
    var holder: ?dom.node_holds.Holder = null;
    var node: ?*runtime.Instance = null;
    var ran: bool = false;
    var read_live: bool = false;

    fn sweep(_: *runtime.BrowserScope) void {
        ran = true;
        const orphan = node orelse return;
        // Each reads the node as gone - no write to its released NodeBase.
        read_live = ref_hold.holds(orphan) or (if (holder) |*h| h.get(0) != null else false);
        ref_hold.release();
        counted.release(orphan);
        if (holder) |*h| h.release();
        holder = null;
    }
};

fn holdsReadANodeTheFinalSweepReleasedAsGone() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    var browser_alive = true;
    defer if (browser_alive) browser.deinit();
    // The holds keep their node past every realm end on purpose: the final sweep is what this tests.
    @import("dom").refcount_teardown.allowLiveNodesAtAgentEnd(&browser.agent_host.deferred_teardown, "holds outlive the final registry sweep, which is what this tests");
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const document = context.document_instance orelse return error.NoDocument;

    // An element made natively and never inserted or wrapped: an orphan only
    // the final registry sweep frees, held by three holds of the test's own.
    const orphan = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("section"), .{ .was_passed = false, .value = undefined });
    const base = dom.instance_bridge.getNodeBase(@ptrCast(orphan)) orelse return error.NoNodeBase;
    SweptProbe.node = orphan;
    SweptProbe.ref_hold.set(orphan);
    SweptProbe.counted.take(orphan, base);
    SweptProbe.holder = dom.node_holds.Holder.init(testing.allocator);
    try SweptProbe.holder.?.hold(*runtime.Instance, &.{orphan});
    try testing.expect(SweptProbe.ref_hold.holds(orphan));

    const probe = dom.teardown_sweeps.withSweepForTest(.documents, &SweptProbe.sweep);
    defer probe.restore();
    browser_alive = false;
    browser.deinit();

    try testing.expect(SweptProbe.ran);
    try testing.expect(!SweptProbe.read_live);
}

test "a counted hold on a node the browser's final sweep released reads it as gone and lets go without touching it" {
    try onFreshThread(holdsReadANodeTheFinalSweepReleasedAsGone);
}
