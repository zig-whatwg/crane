//! Node's childNodes list is kept in the node's rare block (lane nm2 batch 2,
//! step a; node-memory plan v2 section 6 item 5), at run time:
//!
//! - A node whose childNodes was never read has no block; the first read
//!   costs a 16-byte block (one slot).
//! - [SameObject]: the same list every read, on an element, a Text and a
//!   Document alike, and beside an element's own rare fields.
//! - The node's cache is raw (the list holds the node, never the reverse):
//!   when the list is freed before its node the slot is cleared and the next
//!   read makes a new list (dom.refcount's childNodesFreed).
//!
//! What Node's State and the block's field are is pinned at comptime in
//! tests/dom/nm2_child_nodes_rare_test.zig, where these three tests were
//! too. Lane mp1 moved them here: a childNodes list is its WRAPPER's to free
//! (native_read_page.zig), and tests/dom's realm has no engine, so each test
//! freed its lists by hand (runtime.Instance.deinit). Here each test has a
//! page of a real Browser over a poisoning allocator: the generated getter
//! wraps the list it makes and ties it to its node (dom.same_object_cache ->
//! engine.traceChild), and the list is freed as production frees it - by its
//! wrapper's collection, once its node no longer keeps it, or at the page's
//! end. The page's allocator reports whatever a test leaves.
//!
//! These name generated interfaces, the engine protocol and src/dom types
//! only (AGENTS.md "The impls boundary").
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dom = @import("dom");
const native_read_page = @import("native_read_page.zig");

const rare_data = dom.node_rare_data;
const Page = native_read_page.Page;
const str = native_read_page.str;

/// The traced slot the generated childNodes getter keeps its list in
/// (dom.same_object_cache, "SameObject:" ++ the attribute's name).
const child_nodes_slot: engine.TracedSlot = .{ .name = "SameObject:childNodes" };

/// `node`'s rare block's bytes as its allocator was asked for them; 0 for none.
fn blockBytes(node: *runtime.Instance) usize {
    return dom.instance_bridge.getNodeBase(node).?.rare.blockBytes();
}

fn cached(node: *runtime.Instance) ?*runtime.Instance {
    return rare_data.get(dom.instance_bridge.getNodeBase(node).?.rare, .child_nodes);
}

/// Collect until the wrappers nothing reaches are gone and what their
/// collection left to free is freed (as cg1_element_same_object_test does).
fn collectAll(page: Page) !void {
    for (0..4) |_| try page.collect();
}

fn firstReadMakesTheBlock() !void {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    const page = try Page.open(debug.allocator());
    defer page.close();

    // An element and a Text made natively, in the page's tree; and a
    // Document of the page's own that script keeps, with one child.
    const div = try page.element("div");
    const text = try interfaces.Document.call_createTextNode(page.document, str("t"));
    _ = try interfaces.Node.call_appendChild(div, text);
    const other = try page.object("globalThis.other = new Document()");
    const root = try interfaces.Document.call_createElement(other, str("root"), .{ .was_passed = false, .value = undefined });
    _ = try interfaces.Node.call_appendChild(other, root);

    var lists: [3]*runtime.Instance = undefined;
    for ([_]*runtime.Instance{ div, text, other }, 0..) |node, i| {
        try testing.expectEqual(@as(usize, 0), blockBytes(node));
        const list = try interfaces.Node.get_childNodes(node);
        try testing.expect((try interfaces.Node.get_childNodes(node)) == list);
        try testing.expect(cached(node).? == list);
        try testing.expectEqual(@as(usize, 16), blockBytes(node));
        lists[i] = list;
    }
    // The lists are live over their nodes' children.
    try testing.expectEqual(@as(u32, 1), try interfaces.NodeList.get_length(lists[0]));
    try testing.expectEqual(@as(u32, 0), try interfaces.NodeList.get_length(lists[1]));
    try testing.expectEqual(@as(u32, 1), try interfaces.NodeList.get_length(lists[2]));
    // The lists are their wrappers' to free: at the latest when the page
    // ends, each letting go of its node's cache as it goes.
}

test "childNodes: no block until it is read, a 16-byte block after, the same list every read - on an element, a Text and a Document" {
    try native_read_page.onFreshThread(firstReadMakesTheBlock);
}

fn freedListLetsTheCacheGo() !void {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    const page = try Page.open(debug.allocator());
    defer page.close();
    const div = try page.element("div");

    const first = try interfaces.Node.get_childNodes(div);
    const block = dom.instance_bridge.getNodeBase(div).?.rare.block;
    const generation = runtime.SlabAllocator.generationOf(first);
    // The list before its node: with the node's edge to it gone, nothing
    // reaches the list's wrapper, and the collector frees the list while
    // the node stays in the page's tree.
    engine.forgetTracedChild(div, child_nodes_slot);
    try collectAll(page);
    try testing.expect(runtime.SlabAllocator.generationOf(first) != generation);
    // Cleared, not dangling: the freed list's slot reads as no list.
    try testing.expect(cached(div) == null);

    const second = try interfaces.Node.get_childNodes(div);
    try testing.expect(cached(div).? == second);
    try testing.expect((try interfaces.Node.get_childNodes(div)) == second);
    // The field kept its bit: the same block, no new allocation for it.
    try testing.expect(dom.instance_bridge.getNodeBase(div).?.rare.block == block);
    try testing.expectEqual(@as(usize, 16), blockBytes(div));
}

test "a childNodes list freed before its node clears the node's cache; the next read makes a new list in the same slot" {
    try native_read_page.onFreshThread(freedListLetsTheCacheGo);
}

fn sharesTheBlockWithElementFields() !void {
    var debug: @import("root").poisoning.DebugAllocator(.{}) = .init;
    defer testing.expect(debug.deinit() == .ok) catch @panic("the page leaked");
    const page = try Page.open(debug.allocator());
    defer page.close();
    const div = try page.element("div");

    const class_list = try interfaces.Element.get_classList(div);
    const list = try interfaces.Node.get_childNodes(div);
    // classList's slot and childNodes': 2 fields, 3 slots, 32 bytes.
    try testing.expectEqual(@as(usize, 32), blockBytes(div));
    _ = try interfaces.Element.get_attributes(div);
    try interfaces.Element.call_setAttribute(div, str("title"), .{ .domstring = str("t") });
    _ = (try interfaces.Element.call_getAttributeNode(div, str("title"))).?;
    // 5 fields now: the block grew and moved (a freed one reads 0xdd).
    try testing.expectEqual(@as(usize, 64), blockBytes(div));
    try testing.expect((try interfaces.Node.get_childNodes(div)) == list);
    try testing.expect((try interfaces.Element.get_classList(div)) == class_list);

    // An orphan with its list made: freed by its creator, unwrapped - the
    // chain ends the list's edge at Node's level, then Node frees the block.
    // The edge was all that kept the list's wrapper: the collector takes
    // it, and the wrapper's end frees the list.
    const orphan = try page.uninserted("p");
    const orphan_list = try interfaces.Node.get_childNodes(orphan);
    const generation = runtime.SlabAllocator.generationOf(orphan_list);
    dom.node_creation.destroyUninserted(orphan);
    try collectAll(page);
    try testing.expect(runtime.SlabAllocator.generationOf(orphan_list) != generation);
    // The div's two objects are their wrappers' to free, at the page's end.
}

test "childNodes shares the block with an element's own rare fields, and both survive each other's grow" {
    try native_read_page.onFreshThread(sharesTheBlockWithElementFields);
}
