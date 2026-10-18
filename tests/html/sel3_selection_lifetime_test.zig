//! Selection is an option's stored bit, including after its tree changes.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const expectInvariant = @import("sel3_selection_helpers.zig").expectInvariant;

fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

const Case = enum { remove_unread, append_unread, reset_unread, disable_selected, enable_option, enable_group };

fn exercise(comptime which: Case) !void {
    const fixture = try @import("sel3_selection_helpers.zig").DocumentPage.open();
    defer fixture.close();
    const document = fixture.document;
    const select = try element(document, "select");
    defer dom.node_creation.destroyUninserted(select);
    if (which == .enable_option or which == .enable_group) {
        const content = try element(document, "selectedcontent");
        _ = try interfaces.Node.call_appendChild(select, content);
        const option = try element(document, "option");
        try interfaces.Node.set_textContent(option, runtime.DOMString.initInterned("one"));
        const disabled = if (which == .enable_group) try element(document, "optgroup") else option;
        try interfaces.Element.call_setAttribute(disabled, runtime.DOMString.initInterned("disabled"), .{ .domstring = runtime.DOMString.initEmpty() });
        if (which == .enable_group) {
            _ = try interfaces.Node.call_appendChild(select, disabled);
            _ = try interfaces.Node.call_appendChild(disabled, option);
        } else _ = try interfaces.Node.call_appendChild(select, option);
        try std.testing.expect(!try interfaces.HTMLOptionElement.get_selected(option));
        try interfaces.Element.call_removeAttribute(disabled, runtime.DOMString.initInterned("disabled"));
        var text = (try interfaces.Node.get_textContent(content)) orelse return error.MissingText;
        defer text.deinit(std.testing.allocator);
        try std.testing.expectEqualStrings("one", text.asSlice());
        try expectInvariant(select);
        return;
    }
    const first = try element(document, "option");
    _ = try interfaces.Node.call_appendChild(select, first);
    if (which == .disable_selected) try interfaces.Element.call_setAttribute(first, runtime.DOMString.initInterned("disabled"), .{ .domstring = runtime.DOMString.initEmpty() });
    const second = try element(document, "option");
    _ = try interfaces.Node.call_appendChild(select, second);
    if (which == .disable_selected) {
        try std.testing.expect(try interfaces.HTMLOptionElement.get_selected(first));
        try std.testing.expect(!try interfaces.HTMLOptionElement.get_selected(second));
        try expectInvariant(select);
        return;
    }
    if (which == .append_unread) {
        // The paired creation benchmark separately enforces the linear,
        // no-list-scan append fast path without a timing assertion here.
        for (0..1000) |_| {
            const next = try element(document, "option");
            _ = try interfaces.Node.call_appendChild(select, next);
        }
    }
    if (which == .reset_unread) {
        try interfaces.HTMLSelectElement.set_selectedIndex(select, 1);
        dom.form_controls.reset(select);
    }
    // No selectedness getter has run since the initial insertion or reset.
    _ = try interfaces.Node.call_removeChild(select, first);
    defer dom.node_creation.destroyUninserted(first);
    try std.testing.expect(try interfaces.HTMLOptionElement.get_selected(first));
    try std.testing.expect(try interfaces.HTMLOptionElement.get_selected(second));
    try expectInvariant(select);
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

test "an unread implicit selection survives removal and the select resets" {
    try fresh(.remove_unread);
}
test "ordinary appends preserve an unread selection" {
    try fresh(.append_unread);
}
test "form reset restores default selection before an unread removal" {
    try fresh(.reset_unread);
}
test "disabling an implicitly selected option does not discard its selectedness" {
    try fresh(.disable_selected);
}
test "enabling an option updates selectedcontent when it becomes selected" {
    try fresh(.enable_option);
}
test "enabling an optgroup updates selectedcontent when an option becomes selected" {
    try fresh(.enable_group);
}
