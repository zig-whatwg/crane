//! A node is its slab slot and ONE state block (lane perf2, batch 5: Z7;
//! tmp/plans/perf2b5-design.md 3.2-3.3).
//!
//! At d1ee79a9386 `document.createElement('div')` made five arena requests -
//! the generated State, then the EventTarget, Node, Element and HTMLElement
//! InternalStates, one each in its level's init - and malloc'd the NodeBase.
//! Now each level's InternalState is a field of its own State by value and the
//! NodeBase one of Node's, so the State block IS the node: one request, the
//! NodeBase inside it, and what the engine is told the node holds is that block
//! and the slot - counted once at the node's registration and returned whole
//! at its teardown (perf2b4_dom_memory_test.zig keeps the zero-delta half).
const std = @import("std");
const testing = std.testing;
const runtime = @import("runtime");
const engine = @import("engine");
const dom = @import("dom");
const interfaces = @import("interfaces");
const h = @import("refcount_holders_helpers.zig");
const onFreshThread = h.onFreshThread;

fn arenaRequests(page: h.Page) usize {
    return page.browser.scope.arena.stats().total_allocations;
}

/// The arena requests `source` makes, less those of a script that makes
/// nothing (`0;`).
fn requestsOf(page: h.Page, source: []const u8) !usize {
    try page.run("0;");
    const control_before = arenaRequests(page);
    try page.run("0;");
    const control = arenaRequests(page) - control_before;
    const before = arenaRequests(page);
    try page.run(source);
    return arenaRequests(page) - before - control;
}

fn oneRequestPerNode() !void {
    const page = try h.Page.open();
    defer page.close();
    for (0..2) |_| try page.collect();
    const div = try requestsOf(page, "globalThis.d = document.createElement('div'); 0;");
    const text = try requestsOf(page, "globalThis.t = document.createTextNode('x'); 0;");
    if (div != 1 or text != 1) {
        std.debug.print("arena requests: a div {d}, a text node {d} (one block each expected)\n", .{ div, text });
        return error.NotOneBlock;
    }
}

test "createElement and createTextNode each make ONE arena request: the node's State block" {
    try onFreshThread(oneRequestPerNode);
}

fn instanceOf(page: h.Page, source: []const u8) !*runtime.Instance {
    const held = try page.browser.evaluateScript(source);
    defer held.release();
    const realm = page.browser.getRealm() orelse return error.NoRealm;
    return engine.convertToPlatformObject(realm, held.borrow()) orelse error.NotAPlatformObject;
}

fn nodeBaseInsideItsBlock() !void {
    const page = try h.Page.open();
    defer page.close();
    for (0..2) |_| try page.collect();
    const before = page.browser.scope.dom_memory.live;
    const instance = try instanceOf(page, "globalThis.d = document.createElement('div'); d");
    const node_base = dom.instance_bridge.getNodeBase(@ptrCast(instance)) orelse return error.NotANode;
    const block = @intFromPtr(instance.state);
    const end = block + instance.vtable.state_size;
    const at = @intFromPtr(node_base);
    if (at < block or at + @sizeOf(dom.NodeBase) > end) {
        std.debug.print("NodeBase at {x}, the div's State block {x}..{x}\n", .{ at, block, end });
        return error.NodeBaseOutsideItsBlock;
    }
    // Reported once: the slot and the block's class, nothing per level.
    const expected = runtime.SlabAllocator.slot_bytes +
        runtime.ArenaAllocator.heldBytes(instance.vtable.state_size, instance.vtable.state_align);
    const delta = page.browser.scope.dom_memory.live - before;
    if (delta != expected) {
        std.debug.print("a div is reported as {d} B; its slot and block are {d} B\n", .{ delta, expected });
        return error.NotCountedOnce;
    }
}

test "a div's NodeBase lies inside its State block, and the engine is told the slot and the block, once" {
    try onFreshThread(nodeBaseInsideItsBlock);
}
