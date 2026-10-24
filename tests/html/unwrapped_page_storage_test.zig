//! Lane unwrapped1: a page's end returns the storage of the nodes script
//! never wrapped.
//!
//! - (a) A node in its document when the realm ends is torn down by the
//!   realm's tree walk. Its registries went, but its slab slot did not: the
//!   coordinated teardown never released a slot (it may not query a wrapper
//!   cache then), so every unwrapped node kept its slot until the Browser
//!   ended. A long-lived Browser grew by every page's nodes
//!   (ce3-named-property-cost: +10,024 slots a page).
//! - (b) An ORPHAN - a subtree removed while nothing wrapped it - is reached
//!   by no tree teardown and no collector until reference counting decides
//!   (refcount design step 7), so it kept its registries and its slot until
//!   the Browser ended (ce3-state-selector-cost: +9,333 registry entries a
//!   page). Its realm's end now frees it, the way it frees its document's
//!   tree.
//!
//! Each test churns pages in one Browser and asserts that the slab and the
//! node registry come back to the page's own at every page: a page's count
//! must not include the pages before it. The Browser runs on
//! std.testing.allocator, so whatever is freed must be freed exactly once,
//! and each test runs on a thread of its own (tests/html is one executable;
//! a Browser's agent belongs to the thread that made it).

const std = @import("std");
const testing = std.testing;
const browser_mod = @import("browser");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const Counts = struct {
    /// Live slab slots of nodes (a counted VTable: runtime.lifetime).
    node_slots: usize,
    /// Every other live slab slot.
    other_slots: usize,
    nodes: usize,
    elements: usize,
};

fn countsOf(browser: *browser_mod.Browser) Counts {
    var counts: Counts = .{
        .node_slots = 0,
        .other_slots = 0,
        .nodes = runtime.InstanceRegistry(.node, u8).count(browser.scope),
        .elements = runtime.InstanceRegistry(.element, u8).count(browser.scope),
    };
    var slab = browser.scope.slab.slabs;
    while (slab) |each| : (slab = each.next) {
        for (&each.slots) |*slot| {
            const instance: *runtime.Instance = @ptrCast(slot);
            if (runtime.SlabAllocator.generationOf(instance) == runtime.SlabAllocator.dead_generation) continue;
            if (instance.vtable.counted != null) counts.node_slots += 1 else counts.other_slots += 1;
        }
    }
    return counts;
}

/// Navigate (ending the page before, if any), load an empty body, run
/// `script` in the new page and collect what it let go of - the about:blank
/// document the load replaced among it - so the counts are the page's own.
fn openPage(browser: *browser_mod.Browser, script: []const u8) !void {
    try browser.navigate("about:blank", .window);
    const page = browser.current_context orelse return error.NoPage;
    try page.loadHTML("<!doctype html><body></body>", .{ .base_url = "about:blank" });
    page.runScript(script) catch |err| {
        std.debug.print("script failed: {s}\n", .{script});
        return err;
    };
    _ = try browser.runEventLoopBlocking(20);
    try page.runScript("TestUtils.gc(); TestUtils.gc();");
    _ = try browser.runEventLoopBlocking(20);
}

/// Open `pages` pages running `script` each, and require each page's node
/// counts to be the first page's: no node of an ended page may stay, by
/// registry or by slab slot. (Three slots a page that are not nodes stay
/// with the Browser - the realm's Window and Location and one HTMLCollection
/// a document makes for itself - which this lane leaves: a realm's global
/// can outlive it.)
fn churn(script: []const u8, pages: usize, per_page: usize) !void {
    var browser = try browser_mod.Browser.init(testing.allocator, .{ .persist_storage = false, .snapshot_path = "" });
    defer browser.deinit();

    try openPage(browser, script);
    const first = countsOf(browser);
    // The page's own nodes are live while it is the current page.
    try testing.expect(first.nodes >= per_page);
    for (1..pages) |_| {
        try openPage(browser, script);
        const now = countsOf(browser);
        if (now.node_slots != first.node_slots or now.nodes != first.nodes or now.elements != first.elements) {
            std.debug.print("an ended page's nodes stayed: first page {any}, now {any}\n", .{ first, now });
            return error.PageStorageRetained;
        }
    }
}

fn unwrappedTreeAtRealmEnd() !void {
    // Parsed into the document, never read: no wrapper. The realm's end
    // tears them down with the document.
    try churn(
        \\document.body.insertAdjacentHTML('beforeend', '<div><span>t</span></div>'.repeat(200));
        \\if (document.body.childElementCount !== 200) throw new Error('not parsed');
    , 4, 600);
}

test "a page's unwrapped nodes give back their slots when its realm ends" {
    try helpers.onFreshThread(unwrappedTreeAtRealmEnd);
}

fn wrappedTreeAtRealmEnd() !void {
    // Made by script, so wrapped, and in the document when the realm ends:
    // its tree tears them down under their live wrappers, and the realm's
    // wrapper cache, which frees what is left, must free their slots too.
    try churn(
        \\for (let i = 0; i < 200; ++i) document.body.appendChild(document.createElement('div')).appendChild(document.createElement('span'));
        \\if (document.body.childElementCount !== 200) throw new Error('not appended');
    , 4, 400);
}

test "a page's wrapped nodes give back their slots when its realm ends" {
    try helpers.onFreshThread(wrappedTreeAtRealmEnd);
}

fn orphansAtRealmEnd() !void {
    // `host` is wrapped; the parsed divs never are, and `innerHTML = ''`
    // orphans them: removed while nothing wrapped them.
    try churn(
        \\const host = document.body.appendChild(document.createElement('section'));
        \\host.innerHTML = '<div><span>t</span></div>'.repeat(200);
        \\host.innerHTML = '';
        \\if (host.childNodes.length !== 0) throw new Error('not dropped');
    , 4, 1);
}

test "a page's orphans are freed when its realm ends" {
    try helpers.onFreshThread(orphansAtRealmEnd);
}

fn mixedAtRealmEnd() !void {
    // Wrapped and unwrapped nodes side by side: in the document, orphaned,
    // removed with only their root wrapped (its wrapper - not the realm -
    // owns that subtree, and frees its unwrapped descendants), and held by
    // script past the page's end.
    try churn(
        \\const host = document.body.appendChild(document.createElement('section'));
        \\host.innerHTML = '<p><b>1</b><i>2</i></p>'.repeat(50);
        \\const kept = [host.querySelector('b'), host.lastElementChild.lastElementChild];
        \\const removed = document.createElement('div');
        \\removed.innerHTML = '<ul><li>a</li><li>b</li></ul>'.repeat(50);
        \\document.body.appendChild(removed);
        \\removed.innerHTML = '';
        \\document.body.insertAdjacentHTML('beforeend', '<em>x</em>'.repeat(50));
        \\const detached = host.children[10];
        \\detached.remove();
        \\globalThis.keep = [kept, detached];
    , 4, 1);
}

test "wrapped, unwrapped and orphaned nodes together leave nothing of an ended page" {
    try helpers.onFreshThread(mixedAtRealmEnd);
}

// [wrap_tracking] on the custom element paths, which need a Browser's HTML
// host hooks (tests/v8/wrap_tracking_test.zig pins the others): an element
// upgraded or constructed by a custom element class is bound to its `this`
// through setInstanceWithTypeInfo, which marks it.

const dom = @import("dom");
const engine = @import("engine");

/// The first or last element child of `node`, found natively - reading it
/// from script would wrap it.
fn elementChild(node: *dom.NodeBase, comptime first: bool) ?*dom.NodeBase {
    var child = if (first) node.first_child else node.last_child;
    while (child) |c| : (child = if (first) c.next_sibling else c.previous_sibling) {
        if (c.node_type == dom.NodeBase.ELEMENT_NODE) return c;
    }
    return null;
}

fn instanceOf(node: *dom.NodeBase) *runtime.Instance {
    return @ptrCast(@alignCast(node.owner_instance.?));
}

fn customElementsMarked() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const context = page.browser.current_context orelse return error.NoPage;
    // The document script sees (wrapped already): the walk below finds the
    // parsed element without wrapping it.
    const document = blk: {
        const held = try context.evaluateScript("document");
        defer held.release();
        break :blk engine.convertToPlatformObject(context.realm orelse return error.NoPage, held.value) orelse return error.NoDocument;
    };
    const document_base = dom.instance_bridge.getNodeBase(document) orelse return error.NoDocument;

    const html = elementChild(document_base, true) orelse return error.NoDocumentElement;
    const body = elementChild(html, false) orelse return error.NoBody;

    try page.run("document.body.innerHTML = '<x-up></x-up>';");
    const parsed = instanceOf(elementChild(body, true) orelse return error.NotParsed);
    try testing.expect(!runtime.instance_lifecycle.wasWrapped(parsed));

    // The upgrade constructs the parsed element: `super()` binds it.
    try page.run(
        \\customElements.define('x-up', class extends HTMLElement { constructor() { super(); this.made = true; } });
        \\if (!document.querySelector('x-up').made) throw new Error('not upgraded');
    );
    try testing.expect(runtime.instance_lifecycle.wasWrapped(parsed));

    // Construction: `new` and createElement of a defined name.
    try page.run(
        \\customElements.define('x-new', class extends HTMLElement {});
        \\document.body.append(new (customElements.get('x-new'))(), document.createElement('x-new'));
    );
    const created = elementChild(body, false) orelse return error.NotConstructed;
    const constructed = created.previous_sibling orelse return error.NotConstructed;
    try testing.expect(runtime.instance_lifecycle.wasWrapped(instanceOf(created)));
    try testing.expect(runtime.instance_lifecycle.wasWrapped(instanceOf(constructed)));
}

test "custom element construction and upgrade mark the element they bind" {
    helpers.onFreshThread(customElementsMarked) catch |err| {
        std.debug.print("custom elements: {s}\n", .{@errorName(err)});
        return err;
    };
}
