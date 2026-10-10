//! A holder that outlives its node through a teardown the collector does not
//! run - a realm's coordinated teardown, the browser's final registry sweep -
//! lets it go without touching the freed node.
//!
//! Those teardowns free a node's NodeBase and can leave its slab slot, and
//! so its generation, live; `node_holds.nodeReleased` (called by Node.deinit
//! and the sweep just before the NodeBase goes) nulls every hold on it. The
//! holder then reads null - a teardown net, not the behaviour - and skips
//! the hold when it lets go. Run under std.testing.allocator.
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
    var browser_alive = true;
    defer if (browser_alive) browser.deinit();
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body><p id=held>held</p></body>", .{ .base_url = "about:blank" });
    const document = context.document_instance orelse return error.NoDocument;

    // A node of a document with a window: held with no rescue (its root is
    // kept) by a holder of the test's own that outlives the browser. The
    // realm's coordinated teardown frees the document's tree through each
    // node's deinit, with the slab generation left live.
    const held = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("held"))) orelse return error.NoElement;
    var holder = dom.node_holds.Holder.init(testing.allocator, document);
    defer holder.release();
    try holder.hold(*runtime.Instance, &.{held}, null);
    try testing.expect(holder.get(0) == held);
    try testing.expectEqual(@as(usize, 0), holder.rescues.entries.items.len);

    browser_alive = false;
    browser.deinit();

    try testing.expect(holder.get(0) == null);
}

test "a holder that outlives its node's realm teardown lets go without touching the freed node" {
    try onFreshThread(holderOutlivesItsRealmsTeardown);
}

fn holderOutlivesTheFinalSweep() !void {
    const browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    var browser_alive = true;
    defer if (browser_alive) browser.deinit();
    try browser.navigate("about:blank", .window);
    const context = browser.current_context orelse return error.NoPage;
    try context.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    const document = context.document_instance orelse return error.NoDocument;

    // An element made natively and never inserted or wrapped: an orphan only
    // the final registry sweep frees. Held here by a holder of the test's own
    // - told that its root is the document, so it takes no rescue (which
    // would wrap the orphan and hand it to the collector) - that outlives
    // the browser.
    const orphan = try interfaces.Document.call_createElement(document, runtime.DOMString.initInterned("section"), .{ .was_passed = false, .value = undefined });
    const document_base = dom.instance_bridge.getNodeBase(@ptrCast(document)) orelse return error.NoNodeBase;
    var holder = dom.node_holds.Holder.init(testing.allocator, document);
    defer holder.release();
    try holder.hold(*runtime.Instance, &.{orphan}, document_base);
    try testing.expect(holder.get(0) == orphan);

    browser_alive = false;
    browser.deinit();

    // The sweep freed the orphan and nulled the hold; release (deferred above)
    // touches nothing of it.
    try testing.expect(holder.get(0) == null);
}

test "a holder that outlives the browser's final registry sweep lets go without touching the freed node" {
    try onFreshThread(holderOutlivesTheFinalSweep);
}
