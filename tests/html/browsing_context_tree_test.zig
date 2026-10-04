//! A browsing context's place in the navigable tree: its parent link and its
//! parent's list of children (src/html/window/browsing_context.zig). The two
//! links are one fact, so every step that ends either ends both - leaving the
//! parent, discarding, freeing - whichever end goes first. html_core's own
//! test blocks run under no test target, so the cases live here.
//!
//! A context its parent still listed after it was freed was read by the next
//! walk of the list: "definitely close" (BrowsingContext.collectDescendants,
//! SIGSEGV at 0xaaaa...) and History's traversal, which made a joint session
//! history on the freed - and reused - block (a JointHistory leaked per
//! traversal, written into another object's memory).

const std = @import("std");
const html_core = @import("html_core");
const BrowsingContext = html_core.window.BrowsingContext;

test "a context freed while its parent lives leaves the parent's children" {
    const allocator = std.testing.allocator;
    const top = try BrowsingContext.initTopLevel(allocator);
    defer top.deinit();
    const first = try BrowsingContext.initChild(allocator, top);
    const second = try BrowsingContext.initChild(allocator, top);
    defer second.deinit();
    try std.testing.expectEqual(@as(u32, 2), top.getChildCount());

    first.deinit();
    try std.testing.expectEqual(@as(u32, 1), top.getChildCount());
    try std.testing.expect(top.getChildByIndex(0) == second);
}

test "a parent freed first takes its children's links to it" {
    const allocator = std.testing.allocator;
    const top = try BrowsingContext.initTopLevel(allocator);
    const child = try BrowsingContext.initChild(allocator, top);
    defer child.deinit();
    const grandchild = try BrowsingContext.initChild(allocator, child);
    defer grandchild.deinit();

    top.deinit();
    try std.testing.expect(child.parent == null);
    // The child is a context of its own now, and its own child still hangs
    // off it.
    try std.testing.expect(child.getTop() == child);
    try std.testing.expect(grandchild.getTop() == child);
}

test "a discarded context leaves its parent and lets go of the children it drops" {
    const allocator = std.testing.allocator;
    const top = try BrowsingContext.initTopLevel(allocator);
    defer top.deinit();
    const child = try BrowsingContext.initChild(allocator, top);
    const grandchild = try BrowsingContext.initChild(allocator, child);
    defer grandchild.deinit();

    // No Window was ever active in it: the caller frees it now.
    try std.testing.expect(child.discard());
    try std.testing.expectEqual(@as(u32, 0), top.getChildCount());
    try std.testing.expect(child.parent == null);
    try std.testing.expectEqual(@as(u32, 0), child.getChildCount());
    try std.testing.expect(grandchild.parent == null);
    // Closed with it: a discarded navigable's descendants are gone too.
    try std.testing.expect(grandchild.is_closed);
    child.deinit();
    try std.testing.expect(grandchild.getTop() == grandchild);
}

test "a closed parent still loses a child that is discarded" {
    const allocator = std.testing.allocator;
    const top = try BrowsingContext.initTopLevel(allocator);
    defer top.deinit();
    const child = try BrowsingContext.initChild(allocator, top);

    // Closing marks the whole tree; it frees none of it, so the parent's
    // list is still the parent's to keep right.
    top.close();
    try std.testing.expect(child.is_closed);
    try std.testing.expect(child.discard());
    try std.testing.expectEqual(@as(u32, 0), top.getChildCount());
    child.deinit();
}

test "every live descendant, parents first, and none that has left" {
    const allocator = std.testing.allocator;
    const top = try BrowsingContext.initTopLevel(allocator);
    defer top.deinit();
    const a = try BrowsingContext.initChild(allocator, top);
    defer a.deinit();
    const b = try BrowsingContext.initChild(allocator, a);
    defer b.deinit();
    const gone = try BrowsingContext.initChild(allocator, top);
    gone.deinit();

    var tree: std.ArrayListUnmanaged(*BrowsingContext) = .empty;
    defer tree.deinit(allocator);
    try top.collectDescendants(allocator, &tree);
    try std.testing.expectEqualSlices(*BrowsingContext, &.{ top, a, b }, tree.items);
}
