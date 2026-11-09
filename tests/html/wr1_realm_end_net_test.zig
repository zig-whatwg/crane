//! Refcount step 7a's realm-end net after the wrapper redesign's P2 (lane wr1
//! batch 2; the integrator's conditions of 2026-11-09 03:39 UTC).
//!
//! A node's wrapper is its agent's, in its own slot (node_wrappers), so a
//! realm's end no longer meets node wrappers in its cache. The net the
//! cache's sweep made - a realm's detached trees freed at its end whatever
//! their counts - is kept for trees no wrapper reaches any more
//! (node_wrappers.endRealm, endedRealmNet), and never for a tree a live
//! wrapper still reaches:
//!
//! 1. Cross-realm: a node of a same-origin frame's document, held by its
//!    parent's script, stays usable after the frame is removed - a property
//!    read, an expando, appending it into the parent's document. Browsers
//!    keep it (Blink and WebKit keep a node and its document while script
//!    holds it; HTML "destroy a child navigable" frees nothing script
//!    reaches). The inline slot makes the case structural: a node's one
//!    wrapper is its relevant realm's (the frame's), so the parent's hold is
//!    a hold on the frame's realm, whose end cannot come under it.
//! 2. Holders: a removed frame's detached <img> whose image update is still
//!    pending - the update counts its element, and only the frame's end
//!    would have let it go - is freed by the net once its wrapper goes, and
//!    the update's later end touches nothing (the tests' allocators poison a
//!    freed block: a read would see 0xdd).
//!
//! Each test runs on a thread of its own with a Browser of its own.

const std = @import("std");
const testing = std.testing;
const h = @import("refcount_holders_helpers.zig");
const runtime = h.runtime;
const engine = h.engine;
const dom = h.dom;
const onFreshThread = h.onFreshThread;

const frame_page = "<!doctype html><body><iframe></iframe></body>";

/// `ok`, or the test fails naming what did not hold (the thread's error
/// return carries no trace).
fn check(ok: bool, what: []const u8) !void {
    if (ok) return;
    std.debug.print("wr1_realm_end_net_test: did not hold: {s}\n", .{what});
    return error.TestUnexpectedResult;
}

/// Load `markup` into the page (the helper's page is a bare body), then turn
/// the loop so the frame's document exists.
fn loadPage(page: h.Page, markup: []const u8) !void {
    const context = page.browser.current_context orelse return error.NoPage;
    try context.loadHTML(markup, .{ .base_url = "http://example.test/wr1-net" });
    _ = try page.browser.runEventLoopBlocking(20);
}

/// The instance `source` evaluates to in the page's realm, and its slab
/// generation - read without keeping a wrapper of it.
fn instanceOf(page: h.Page, source: []const u8) !struct { instance: *runtime.Instance, generation: u64 } {
    const held = try page.browser.evaluateScript(source);
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    const instance = engine.convertToPlatformObject(realm, held.borrow()) orelse return error.NotAPlatformObject;
    return .{ .instance = instance, .generation = runtime.SlabAllocator.generationOf(instance) };
}

/// Whether `source` evaluates to true in the page's realm.
fn holds(page: h.Page, source: []const u8) !bool {
    const held = try page.browser.evaluateScript(source);
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    return engine.toBoolean(realm, held.borrow());
}

fn crossRealmNodeStaysUsable() !void {
    const page = try h.Page.open();
    defer page.close();
    try loadPage(page, frame_page);
    try page.run(
        \\globalThis.f = document.querySelector('iframe');
        \\globalThis.held = f.contentDocument.createElement('div');
        \\held.appendChild(f.contentDocument.createElement('span')).textContent = 'x';
        \\held.expando = 7;
        \\globalThis.other = f.contentDocument.createElement('p');
        \\0;
    );
    const node = try instanceOf(page, "held");
    const other = try instanceOf(page, "other");
    // Its navigable is destroyed: the frame's realm is detached, and lives on
    // for as long as script reaches anything of it (HTML "destroy a child
    // navigable"; protocol_realms' global_detached end). A node's one wrapper
    // is its relevant realm's - the frame's - so the parent's hold on it is
    // a hold on that realm: no end of the frame's realm can come while the
    // parent's script holds the node, and the realm-end net never meets it.
    try page.run("f.remove(); globalThis.f = null; 0;");
    try page.collect();
    try page.collect();
    try check(node.generation == runtime.SlabAllocator.generationOf(node.instance), "the node is not freed");
    try check(node.instance.ctx.hasEngine(), "the frame's realm lives while the parent's script reaches its node");
    // Script of the parent still reaches it, whole: no TypeError (a severed
    // wrapper), no poison (a freed node).
    try check(try holds(page, "held.localName === 'div'"), "a property read");
    try check(try holds(page, "held.expando === 7"), "its expando");
    try check(try holds(page, "held.firstChild.textContent === 'x'"), "its subtree");
    try page.run("document.body.appendChild(held); 0;");
    try check(try holds(page, "held.parentNode === document.body && held.ownerDocument === document && held.firstChild.localName === 'span'"), "appended into the parent's document");
    // Its NodeBase reads as a live element, not the 0xdd a freed block
    // reads as under the tests' poisoning allocators.
    const base = dom.instance_bridge.getNodeBase(node.instance) orelse return error.NotANode;
    try check(base.node_type == dom.NodeBase.ELEMENT_NODE and base.parent_node != null and dom.refcount.count(base) < 16, "its NodeBase reads live");
    // Once the parent lets go of the frame's last node, the frame's realm
    // ends and what only its wrappers held goes.
    try page.run("globalThis.other = null; 0;");
    var turns: usize = 0;
    while (turns < 8 and runtime.SlabAllocator.generationOf(other.instance) == other.generation) : (turns += 1) try page.collect();
    try check(runtime.SlabAllocator.generationOf(other.instance) != other.generation, "the frame's unheld node goes once the parent lets go");
    try check(try holds(page, "held.parentNode === document.body && held.firstChild.textContent === 'x'"), "the adopted node stays the parent's");
}

test "a node of a removed frame's document, held by its parent's script, stays usable: the frame's realm cannot end under it" {
    try onFreshThread(crossRealmNodeStaysUsable);
}

fn removedFramePendingImage() !void {
    const page = try h.Page.open();
    defer page.close();
    try loadPage(page, frame_page);
    // The frame's own script makes a detached img with an update pending (a
    // fetch that does not answer before the frame goes): the update counts
    // its element (refcount step 5d), and nothing of the page holds it.
    try page.run(
        \\globalThis.f = document.querySelector('iframe');
        \\f.contentWindow.Function("globalThis.i = new Image(); i.src = 'http://example.test/wr1-net-never.png';")();
        \\0;
    );
    const img = try instanceOf(page, "f.contentWindow.i");
    const img_node = dom.instance_bridge.getNodeBase(img.instance) orelse return error.NotANode;
    try check(dom.refcount.count(img_node) >= 2, "the img's update counts it");
    try page.run("f.remove(); globalThis.f = null; 0;");
    // Its realm ended; its wrapper goes with the collections, and the net
    // frees the tree its update still holds - in a slice, after them.
    var turns: usize = 0;
    while (turns < 6 and runtime.SlabAllocator.generationOf(img.instance) == img.generation) : (turns += 1) try page.collect();
    try check(runtime.SlabAllocator.generationOf(img.instance) != img.generation, "the net freed the img");
    // The update's end (its fetch answered or cancelled, at the latest at
    // the page's end) finds its element freed and lets nothing go twice:
    // an underflow or a poisoned read is an error log, which fails the test.
    _ = try page.browser.runEventLoopBlocking(20);
}

test "a removed frame's detached img with a pending update is freed by the net once its wrapper goes, and the update's end touches nothing" {
    try onFreshThread(removedFramePendingImage);
}
