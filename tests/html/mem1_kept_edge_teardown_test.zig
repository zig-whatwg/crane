//! Lane mem1: an element's kept child that native code handed out ends its
//! edge when the element is torn down.
//!
//! An element makes some children once and keeps them in its rare data for
//! its life - element.style's CSSStyleProperties, its shadow root
//! (dom.node_rare_data `Kept`). The first hand-out of one draws an edge from
//! the element's wrapper to the child's (rare_data.keptHandOut ->
//! engine.traceChild), which makes the child's wrapper. An element script
//! never wrapped has no wrapper to hang the edge from, so the engine keeps
//! the child's wrapper STRONGLY, waiting for the element's (V8 adapter:
//! wrapper_cache.deferEdge). Native code read element.style of unwrapped
//! elements on every join (execcommand/style_values.declarationOf), so the
//! element's teardown must end that wait (engine.forgetTracedChild), as it
//! already did for its ElementInternals. It did not for its two kept
//! children: the style object's wrapper stayed, and the storage
//! runtime.gc.releaseOwned left to that wrapper with it, until the realm
//! ended - in edit4's delete-join row one CSSStyleProperties per operation,
//! past the undo history's bound (lane tpc's K-sweep; `gc_bench
//! --live-types`: 11,003 after 16,000 operations with 5,003 HTML elements
//! alive). The shadow root's case is pinned too, though it never leaked:
//! attachShadow's own edge from the shadow root to its host wraps the host.
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const native_read_page = @import("native_read_page.zig");
const loop_settle = @import("loop_settle.zig");

const Page = native_read_page.Page;

/// Collections until what the dropped objects let go of is collected too,
/// and an idle loop (the trees' and wrappers' teardowns run between tasks).
fn collectAll(page: Page) !void {
    for (0..4) |_| try page.collect();
    try loop_settle.settle(page.browser);
}

fn styleOfAnUnwrappedElementGoesWithIt(page: Page) !void {
    // Made natively and never inserted: no wrapper, only its creator.
    const div = try page.uninserted("div");
    // A native read, as editing's style reads make one.
    const style = try interfaces.HTMLElement.get_style(div);
    const generation = runtime.SlabAllocator.generationOf(style);
    dom.node_creation.destroyUninserted(div);
    try collectAll(page);
    // The style object's slot was given back: nothing kept its wrapper.
    try testing.expect(runtime.SlabAllocator.generationOf(style) != generation);
}

test "element.style read natively on an element script never wrapped is freed when the element is" {
    try native_read_page.onPage(styleOfAnUnwrappedElementGoesWithIt);
}

fn shadowRootOfAnUnwrappedHostGoesWithIt(page: Page) !void {
    const host = try page.uninserted("div");
    // Attached natively, as a declarative shadow root's parser attaches it.
    const shadow = try interfaces.Element.call_attachShadow(host, .{ .mode = ._open_ });
    const generation = runtime.SlabAllocator.generationOf(shadow);
    dom.node_creation.destroyUninserted(host);
    try collectAll(page);
    try testing.expect(runtime.SlabAllocator.generationOf(shadow) != generation);
}

test "a shadow root attached natively to a host script never wrapped is freed when the host is" {
    try native_read_page.onPage(shadowRootOfAnUnwrappedHostGoesWithIt);
}

/// The Browser's live CSSStyleProperties, the orphaned ones among them, and
/// its HTML elements.
const Census = struct {
    styles: usize = 0,
    /// Style objects whose element is gone: their destructor ran
    /// (runtime.gc.releaseOwned, from the element's teardown), and their
    /// slot and storage wait for a wrapper's end - which never comes while
    /// the engine holds that wrapper for the dead element.
    orphaned_styles: usize = 0,
    html_elements: usize = 0,

    fn visit(self: *Census, instance: *runtime.Instance) void {
        // By interface name, not by state: an orphan's state was torn down.
        if (std.mem.eql(u8, instance.vtable.name, "CSSStyleProperties")) {
            self.styles += 1;
            if (runtime.instance_lifecycle.isCleanedUp(instance)) self.orphaned_styles += 1;
        }
        if (instance.stateAs(interfaces.HTMLElement.State) != null) self.html_elements += 1;
    }

    fn take(page: Page) Census {
        var census: Census = .{};
        page.browser.scope.slab.forEachLive(&census, visit);
        return census;
    }
};

fn deleteJoinKeepsNoStyleObjectPastItsElement(page: Page) !void {
    // Edit4's delete-join row (lane tpc's K-sweep), in one script: past the
    // undo history's 1,000 steps, each step's dropped tree dies, and with it
    // every style object its elements' typing-style reads made.
    const held = try page.browser.evaluateScript(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.contentEditable = 'true';
        \\host.focus();
        \\for (let i = 0; i < 2500; i++) {
        \\  host.innerHTML = '<p><b>foo</b></p><p><span style="color:red">bar</span></p>';
        \\  const r = document.createRange();
        \\  r.setStart(host.lastChild.firstChild.firstChild, 0);
        \\  r.collapse(true);
        \\  getSelection().removeAllRanges();
        \\  getSelection().addRange(r);
        \\  document.execCommand('delete');
        \\}
        \\if (host.childNodes.length !== 1) throw new Error('no join: ' + host.innerHTML);
    );
    held.release();
    try collectAll(page);
    const census = Census.take(page);
    // No style object outlives its element (element.style is the
    // element's for its life, and goes with it).
    if (census.orphaned_styles != 0) {
        std.debug.print("{d} CSSStyleProperties outlive their elements ({d} alive, {d} HTML elements)\n", .{ census.orphaned_styles, census.styles, census.html_elements });
        return error.StyleObjectsOutliveTheirElements;
    }
}

test "a delete-join loop past the undo bound keeps no element.style object past its element" {
    try native_read_page.onPage(deleteJoinKeepsNoStyleObjectPastItsElement);
}

fn editingStyleReadsMakeNoStyleObject(page: Page) !void {
    // Joins whose typing-style record reads the inline style of every
    // element on the way up (overrides.recordTypingStyleAcrossMerge ->
    // specifyingDepth), and a span whose own style attribute the join reads
    // (delete.zig, the span's cssText): reads, which Blink makes from
    // Element::InlineStyle() with no CSSOM object (lane mem1).
    const held = try page.browser.evaluateScript(
        \\const host = document.body.appendChild(document.createElement('div'));
        \\host.contentEditable = 'true';
        \\host.focus();
        \\for (let i = 0; i < 10; i++) {
        \\  host.innerHTML = '<p><b>foo</b></p><p><span style="color:red">bar</span></p>';
        \\  const r = document.createRange();
        \\  r.setStart(host.lastChild.firstChild.firstChild, 0);
        \\  r.collapse(true);
        \\  getSelection().removeAllRanges();
        \\  getSelection().addRange(r);
        \\  document.execCommand('delete');
        \\}
        \\if (host.childNodes.length !== 1) throw new Error('no join: ' + host.innerHTML);
    );
    held.release();
    const census = Census.take(page);
    if (census.styles != 0) {
        std.debug.print("{d} CSSStyleProperties made by editing's reads\n", .{census.styles});
        return error.EditingReadMadeAStyleObject;
    }
}

test "editing's inline-style reads make no element.style object" {
    try native_read_page.onPage(editingStyleReadsMakeNoStyleObject);
}
