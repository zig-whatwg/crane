//! Selected options entering one select in a batch retain their insertion order.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const expectInvariant = @import("sel3_selection_helpers.zig").expectInvariant;

fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

const Case = enum { group, fragment, before_existing, batch_before_existing, multiple, reinsert_select, reinsert_wrapper, reinsert_form, reinsert_content, adopted_wrapper, parsed_select };

fn exercise(comptime which: Case) !void {
    const fixture = try @import("sel3_selection_helpers.zig").DocumentPage.open();
    defer fixture.close();
    const document = fixture.document;
    if (which == .parsed_select) {
        try dom.document_internals.setDocumentType(document, .html);
        const container = try element(document, "div");
        defer dom.node_creation.destroyUninserted(container);
        try interfaces.Element.set_innerHTML(container, .{ .domstring = runtime.DOMString.initInterned("<select><option>one</option><option selected>two</option></select>") });
        const parsed_select = (try interfaces.Node.get_firstChild(container)).?;
        try expectInvariant(parsed_select);
        try std.testing.expectEqual(@as(i32, 1), try interfaces.HTMLSelectElement.get_selectedIndex(parsed_select));
        _ = try interfaces.Node.call_appendChild(document, container);
        const after_connect = try interfaces.HTMLSelectElement.get_selectedIndex(parsed_select);
        _ = try interfaces.Node.call_removeChild(document, container);
        try expectInvariant(parsed_select);
        try std.testing.expectEqual(@as(i32, 1), after_connect);
        return;
    }
    const other_document: ?*runtime.Instance = if (which == .adopted_wrapper) try interfaces.Document.init(std.testing.allocator, document.ctx) else null;
    defer if (other_document) |other| interfaces.Document.deinit(other);
    const select = try element(document, "select");
    const root = switch (which) {
        .reinsert_wrapper, .adopted_wrapper => try element(document, "div"),
        .reinsert_form => try element(document, "form"),
        else => select,
    };
    defer dom.node_creation.destroyUninserted(root);
    if (root != select) _ = try interfaces.Node.call_appendChild(root, select);
    if (which == .reinsert_content) {
        const button = try element(document, "button");
        _ = try interfaces.Node.call_appendChild(select, button);
        _ = try interfaces.Node.call_appendChild(button, try element(document, "selectedcontent"));
    }
    if (which == .multiple) try interfaces.Element.call_setAttribute(select, runtime.DOMString.initInterned("multiple"), .{ .domstring = runtime.DOMString.initEmpty() });
    const first = try element(document, "option");
    const last = try element(document, "option");
    const preserve_clear = switch (which) {
        .reinsert_select, .reinsert_wrapper, .reinsert_form, .reinsert_content, .adopted_wrapper => true,
        else => false,
    };
    if (!preserve_clear) {
        try interfaces.Element.call_setAttribute(first, runtime.DOMString.initInterned("selected"), .{ .domstring = runtime.DOMString.initEmpty() });
        try interfaces.Element.call_setAttribute(last, runtime.DOMString.initInterned("selected"), .{ .domstring = runtime.DOMString.initEmpty() });
    }
    if (preserve_clear) {
        _ = try interfaces.Node.call_appendChild(select, first);
        _ = try interfaces.Node.call_appendChild(select, last);
        try interfaces.HTMLSelectElement.set_selectedIndex(select, -1);
        try expectInvariant(select);
        if (other_document) |other| {
            _ = try interfaces.Document.call_adoptNode(other, root);
            _ = try interfaces.Node.call_appendChild(select, try element(other, "option"));
            try expectInvariant(select);
            try std.testing.expectEqual(@as(i32, 0), try interfaces.HTMLSelectElement.get_selectedIndex(select));
            return;
        }
        _ = try interfaces.Node.call_appendChild(document, root);
        // Remove before any assertion so the deferred detached-tree cleanup
        // always owns root, even when the first connection changed selection.
        const after_connect = try interfaces.HTMLSelectElement.get_selectedIndex(select);
        _ = try interfaces.Node.call_removeChild(document, root);
        try expectInvariant(select);
        try std.testing.expectEqual(@as(i32, -1), after_connect);
        _ = try interfaces.Node.call_appendChild(document, root);
        const after_reconnect = try interfaces.HTMLSelectElement.get_selectedIndex(select);
        _ = try interfaces.Node.call_removeChild(document, root);
        try expectInvariant(select);
        try std.testing.expectEqual(@as(i32, -1), after_reconnect);
    } else if (which == .before_existing) {
        _ = try interfaces.Node.call_appendChild(select, last);
        try expectInvariant(select);
        _ = try interfaces.Node.call_insertBefore(select, first, last);
        try expectInvariant(select);
        try std.testing.expect(try interfaces.HTMLOptionElement.get_selected(first));
        try std.testing.expect(!try interfaces.HTMLOptionElement.get_selected(last));
    } else {
        const container = if (which == .group) try element(document, "optgroup") else try interfaces.Document.call_createDocumentFragment(document);
        defer if (which != .group) dom.node_creation.destroyUninserted(container);
        _ = try interfaces.Node.call_appendChild(container, first);
        _ = try interfaces.Node.call_appendChild(container, last);
        if (which == .batch_before_existing) {
            const existing = try element(document, "option");
            _ = try interfaces.Node.call_appendChild(select, existing);
            _ = try interfaces.Node.call_insertBefore(select, container, existing);
            try std.testing.expect(!try interfaces.HTMLOptionElement.get_selected(existing));
        } else _ = try interfaces.Node.call_appendChild(select, container);
        try expectInvariant(select);
        try std.testing.expectEqual(which == .multiple, try interfaces.HTMLOptionElement.get_selected(first));
        try std.testing.expect(try interfaces.HTMLOptionElement.get_selected(last));
    }
}

fn fresh(comptime which: Case) !void {
    const Run = struct {
        fn run(result: *?anyerror) void {
            exercise(which) catch |err| {
                result.* = err;
            };
        }
    };
    var result: ?anyerror = null;
    const thread = try std.Thread.spawn(.{}, Run.run, .{&result});
    thread.join();
    if (result) |err| return err;
}

test "the last selected option in an inserted optgroup wins" {
    try fresh(.group);
}
test "the last selected option in an inserted fragment wins" {
    try fresh(.fragment);
}
test "a selected option inserted before an existing selection wins" {
    try fresh(.before_existing);
}
test "the last selected member of a batch inserted before an existing selection wins" {
    try fresh(.batch_before_existing);
}
test "a multiple select preserves both selections in an inserted batch" {
    try fresh(.multiple);
}
test "connecting and reinserting a whole select preserves its cleared selection" {
    try fresh(.reinsert_select);
}
test "connecting and reinserting a select's wrapper preserves its cleared selection" {
    try fresh(.reinsert_wrapper);
}
test "connecting a form preserves its descendant select's cleared selection" {
    try fresh(.reinsert_form);
}
test "connecting a select with selectedcontent preserves its cleared selection" {
    try fresh(.reinsert_content);
}
test "an option appended after adopting a parentless wrapper still resets selection" {
    try fresh(.adopted_wrapper);
}
test "connecting a container preserves the selection produced by innerHTML parsing" {
    try fresh(.parsed_select);
}
