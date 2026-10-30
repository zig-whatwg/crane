//! Q173: computedStyleMap's weak identity storage is lazy and style-owned.
const std = @import("std");
const dom = @import("dom");
const interfaces = @import("interfaces");
const runtime = @import("runtime");
const testing = std.testing;
const style = dom.style.element_style;
const Field = @FieldType(style.ElementStyle, "computed_map");
const page_helpers = @import("edges_node_holders_helpers.zig");

test "computed map identity costs one pointer and defaults to null" {
    try testing.expectEqual(@sizeOf(?*anyopaque), @sizeOf(Field));
    // The pre-fix inline ObjectLink must produce an assertion failure, not a
    // type error, so this test can run before the lazy representation exists.
    if (comptime @typeInfo(Field) != .optional) return testing.expect(false);
    const state = try style.ElementStyle.create(testing.allocator);
    defer state.destroy();
    try testing.expect(state.computed_map == null);
    const Record = @typeInfo(@typeInfo(Field).optional.child).pointer.child;
    state.computed_map = try testing.allocator.create(Record);
    state.computed_map.?.* = .{};
    // destroy must release this allocation, even without a live map object.
}

test "the first computedStyleMap allocates identity storage and subsequent calls reuse it" {
    try page_helpers.onFreshThread(firstMap);
}

fn firstMap() !void {
    if (comptime @typeInfo(Field) != .optional) return testing.expect(false);
    const page = try page_helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="target" style="color:red"></div>';
        \\document.getElementById('target').style.color;
    );
    const document = page.browser.current_context.?.document_instance.?;
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("target"))).?;
    const state = style.existingOf(element) orelse return error.MissingElementStyle;
    try testing.expect(state.computed_map == null);
    const first = try interfaces.Element.call_computedStyleMap(element);
    const record = state.computed_map orelse return error.MissingComputedMapLink;
    const second = try interfaces.Element.call_computedStyleMap(element);
    try testing.expect(first == second);
    try testing.expect(record == state.computed_map.?);
    try page.run(
        \\const target = document.getElementById('target');
        \\if (target.computedStyleMap() !== target.computedStyleMap()) throw new Error('map identity');
    );
    // Page.close tears down ElementStyle under std.testing.allocator.
}

test "a failed lazy computed map allocation leaves no link and permits a retry" {
    try page_helpers.onFreshThread(allocationFailure);
}

fn allocationFailure() !void {
    if (comptime @typeInfo(Field) != .optional) return testing.expect(false);
    const page = try page_helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="target" style="color:red"></div>';
        \\document.getElementById('target').style.color;
    );
    const document = page.browser.current_context.?.document_instance.?;
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned("target"))).?;
    const state = style.existingOf(element) orelse return error.MissingElementStyle;
    try testing.expect(state.computed_map == null);
    const allocator = state.allocator;
    defer state.allocator = allocator;
    var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });
    state.allocator = failing.allocator();
    try testing.expectError(error.OutOfMemory, interfaces.Element.call_computedStyleMap(element));
    try testing.expect(state.computed_map == null);
    state.allocator = allocator;
    const first = try interfaces.Element.call_computedStyleMap(element);
    try testing.expect(state.computed_map != null);
    try testing.expect(first == try interfaces.Element.call_computedStyleMap(element));
}
