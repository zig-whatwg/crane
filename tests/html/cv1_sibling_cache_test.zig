//! Q45: only a lazy pointer grows ElementStyle; the record owns scalars.
const std = @import("std");
const dom = @import("dom");
const testing = std.testing;
const state = dom.style.element_style;

// The pre-cache layout, pinned before introducing sibling_counts.
const Before = struct {
    allocator: std.mem.Allocator,
    inline_block: @FieldType(state.ElementStyle, "inline_block"),
    inline_state: @FieldType(state.ElementStyle, "inline_state"),
    updating: bool,
    // Row117 MERGE-MAIN REQUIRED ruling (2026-10-24): this independent
    // field is present on both sides; the bound measures sibling_counts only.
    background_hint: @FieldType(state.ElementStyle, "background_hint"),
    // Lane editing3 (2026-10-26), by the same precedent: HTML 15.3.4's font
    // presentational hint cache is another independent field present on
    // both sides (integrator grant).
    font_hint: @FieldType(state.ElementStyle, "font_hint"),
    cached: @FieldType(state.ElementStyle, "cached"),
    pseudo: @FieldType(state.ElementStyle, "pseudo"),
};

test "a sibling cache costs at most one inline pointer and allocates lazily" {
    std.debug.print("CV1_ELEMENT_STYLE_SIZE before={d} current={d}\n", .{ @sizeOf(Before), @sizeOf(state.ElementStyle) });
    try testing.expect(@sizeOf(state.ElementStyle) <= @sizeOf(Before) + @sizeOf(?*anyopaque));
    if (comptime !@hasField(state.ElementStyle, "sibling_counts")) return error.SiblingCacheNotImplemented;
    const style = try state.ElementStyle.create(testing.allocator);
    defer style.destroy();
    try testing.expect(style.sibling_counts == null);
}

test "sibling scalar keys reject tree mutation adoption and address reuse" {
    if (comptime !@hasDecl(state, "SiblingCounts")) return error.SiblingCacheNotImplemented;
    const cache = state.SiblingCounts{ .value = .{ .index = 3, .count = 8 }, .document_address = 42, .document_generation = 7, .tree_version = 11 };
    try testing.expect(cache.matches(42, 7, 11));
    try testing.expect(!cache.matches(42, 7, 12));
    try testing.expect(!cache.matches(43, 7, 11));
    try testing.expect(!cache.matches(42, 8, 11));
}

test "a failed lazy sibling cache allocation leaves the count fallback usable" {
    if (comptime !@hasDecl(state, "SiblingCounts")) return error.SiblingCacheNotImplemented;
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    var style = state.ElementStyle{ .allocator = failing.allocator() };
    const counts = state.SiblingCounts{ .value = .{ .index = 3, .count = 8 }, .document_address = 42, .document_generation = 7, .tree_version = 11 };
    try testing.expect(!style.cacheSiblingCounts(counts));
    try testing.expect(style.sibling_counts == null);
    // The provider retains its computed pair on the stack even if caching
    // fails, so allocation failure cannot replace it with a default answer.
    try testing.expectEqual(@as(usize, 3), counts.value.index);
    try testing.expectEqual(@as(usize, 8), counts.value.count);
}

test "sibling cache replacement and teardown release every allocation" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(state, "SiblingCounts")) return error.SiblingCacheNotImplemented;
    const style = try state.ElementStyle.create(allocator);
    defer style.destroy();
    const counts = state.SiblingCounts{ .value = .{ .index = 3, .count = 8 }, .document_address = 42, .document_generation = 7, .tree_version = 11 };
    if (!style.cacheSiblingCounts(counts)) return error.OutOfMemory;
    var next = counts;
    next.tree_version += 1;
    next.value.count = 9;
    try testing.expect(style.cacheSiblingCounts(next));
    try testing.expectEqual(@as(usize, 9), style.sibling_counts.?.value.count);
}

test "style reads allocate sibling records only on demand and refill after mutation" {
    try @import("edges_node_holders_helpers.zig").onFreshThread(domCache);
}

fn domCache() !void {
    if (comptime !@hasField(state.ElementStyle, "sibling_counts")) return error.SiblingCacheNotImplemented;
    const interfaces = @import("interfaces");
    const runtime = @import("runtime");
    const page = try @import("edges_node_holders_helpers.zig").Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="parent"><i id="plain"></i>text<!--comment--><b id="target"></b><em id="last"></em></div>';
        \\getComputedStyle(document.getElementById('plain')).marginLeft;
    );
    const document = page.browser.current_context.?.document_instance.?;
    const plain = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("plain"))).?;
    try testing.expect(state.existingOf(plain).?.sibling_counts == null);
    try page.run(
        \\const target = document.getElementById('target');
        \\target.style.marginLeft = 'calc(1px * sibling-index())';
        \\target.style.marginTop = 'calc(1px * sibling-count())';
        \\getComputedStyle(target).marginLeft;
    );
    const target = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("target"))).?;
    const last = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("last"))).?;
    try testing.expectEqual(@as(usize, 1), state.existingOf(plain).?.sibling_counts.?.value.index);
    try testing.expectEqual(@as(usize, 2), state.existingOf(target).?.sibling_counts.?.value.index);
    try testing.expectEqual(@as(usize, 3), state.existingOf(last).?.sibling_counts.?.value.index);
    const old_version = state.existingOf(target).?.sibling_counts.?.tree_version;
    try page.run(
        \\document.getElementById('parent').prepend(document.createElement('strong'));
        \\getComputedStyle(target).marginLeft;
    );
    const now = state.existingOf(target).?.sibling_counts.?;
    try testing.expect(now.tree_version != old_version);
    try testing.expectEqual(@as(usize, 3), now.value.index);
    try testing.expectEqual(@as(usize, 4), now.value.count);
}
