//! Sparse option selectedness across append, reset and attribute reads.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const expectInvariant = @import("sel3_selection_helpers.zig").expectInvariant;

fn element(document: *runtime.Instance, name: []const u8) !*runtime.Instance {
    return interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
}

fn attr(node: *runtime.Instance, name: []const u8) !void {
    try interfaces.Element.call_setAttribute(node, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initEmpty() });
}

fn expectText(node: *runtime.Instance, expected: []const u8) !void {
    var text = (try interfaces.Node.get_textContent(node)) orelse return error.MissingText;
    defer text.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(expected, text.asSlice());
}

const Case = enum { append_after_clear, append_first_enabled, enable_then_reset, default_read, all_write_paths };

fn exercise(comptime which: Case) !void {
    const fixture = try @import("sel3_selection_helpers.zig").DocumentPage.open();
    defer fixture.close();
    const document = fixture.document;
    const root = try element(document, "div");
    _ = try interfaces.Node.call_appendChild(document, root);
    const select = try element(document, "select");
    _ = try interfaces.Node.call_appendChild(root, select);
    const content = try element(document, "selectedcontent");
    _ = try interfaces.Node.call_appendChild(select, content);
    const first = try element(document, "option");
    try interfaces.Node.set_textContent(first, runtime.DOMString.initInterned("one"));
    if (which == .enable_then_reset or which == .append_first_enabled) try attr(first, "disabled");
    if (which == .default_read) try attr(first, "selected");
    _ = try interfaces.Node.call_appendChild(select, first);
    try expectInvariant(select);

    switch (which) {
        .append_after_clear => {
            try interfaces.HTMLSelectElement.set_selectedIndex(select, -1);
            try expectInvariant(select);
            try std.testing.expect(!try interfaces.HTMLOptionElement.get_selected(first));
            const second = try element(document, "option");
            _ = try interfaces.Node.call_appendChild(select, second);
            try expectInvariant(select);
            try std.testing.expect(try interfaces.HTMLOptionElement.get_selected(first));
            try std.testing.expectEqual(@as(i32, 0), try interfaces.HTMLSelectElement.get_selectedIndex(select));
            // HTML option insertion ignores its returned selects. Only the
            // inserted option's post-connection step can clone, and it is
            // unselected here (cached HTML :82870-82880, row61 Q22).
            try expectText(content, "");
        },
        .append_first_enabled => {
            try interfaces.HTMLSelectElement.set_selectedIndex(select, -1);
            try expectInvariant(select);
            const second = try element(document, "option");
            try interfaces.Node.set_textContent(second, runtime.DOMString.initInterned("two"));
            _ = try interfaces.Node.call_appendChild(select, second);
            try expectInvariant(select);
            try std.testing.expect(!try interfaces.HTMLOptionElement.get_selected(first));
            try std.testing.expect(try interfaces.HTMLOptionElement.get_selected(second));
            try expectText(content, "two");
        },
        .enable_then_reset => {
            const second = try element(document, "option");
            try interfaces.Node.set_textContent(second, runtime.DOMString.initInterned("two"));
            _ = try interfaces.Node.call_appendChild(select, second);
            try expectInvariant(select);
            try interfaces.Element.call_removeAttribute(first, runtime.DOMString.initInterned("disabled"));
            try expectInvariant(select);
            // Enabling does not replace an existing selection. Reset chooses
            // the now-enabled first option and updates selectedcontent.
            try std.testing.expect(!try interfaces.HTMLOptionElement.get_selected(first));
            try std.testing.expect(try interfaces.HTMLOptionElement.get_selected(second));
            dom.form_controls.reset(select);
            try expectInvariant(select);
            try std.testing.expect(try interfaces.HTMLOptionElement.get_selected(first));
            try std.testing.expect(!try interfaces.HTMLOptionElement.get_selected(second));
            try expectText(content, "one");
        },
        .default_read => {
            try interfaces.HTMLSelectElement.set_selectedIndex(select, -1);
            try expectInvariant(select);
            try std.testing.expect(try interfaces.Element.call_hasAttribute(first, runtime.DOMString.initInterned("selected")));
            try std.testing.expect(try interfaces.HTMLOptionElement.get_defaultSelected(first));
            try std.testing.expect(!try interfaces.HTMLOptionElement.get_selected(first));
            try std.testing.expectEqual(@as(i32, -1), try interfaces.HTMLSelectElement.get_selectedIndex(select));
        },
        .all_write_paths => {
            const second = try element(document, "option");
            try interfaces.Node.set_textContent(second, runtime.DOMString.initInterned("two"));
            _ = try interfaces.Node.call_appendChild(select, second);
            try expectInvariant(select);
            try interfaces.HTMLOptionElement.set_selected(second, true);
            try expectInvariant(select);
            try interfaces.HTMLSelectElement.set_selectedIndex(select, -1);
            try expectInvariant(select);
            try interfaces.HTMLSelectElement.set_value(select, runtime.DOMString.initInterned("one"));
            try expectInvariant(select);
            try attr(second, "selected");
            try expectInvariant(select);
            dom.form_controls.reset(select);
            try expectInvariant(select);
            try interfaces.Element.call_removeAttribute(second, runtime.DOMString.initInterned("selected"));
            try expectInvariant(select);
            _ = try interfaces.Node.call_removeChild(select, first);
            defer dom.node_creation.destroyUninserted(first);
            try expectInvariant(select);

            const other = try element(document, "select");
            _ = try interfaces.Node.call_appendChild(root, other);
            const wrapper = try element(document, "div");
            _ = try interfaces.Node.call_appendChild(wrapper, second);
            try expectInvariant(select);
            _ = try interfaces.Node.call_appendChild(other, wrapper);
            try expectInvariant(other);
            try interfaces.Element.call_moveBefore(select, wrapper, null);
            try expectInvariant(select);
            try expectInvariant(other);

            try attr(select, "multiple");
            try expectInvariant(select);
            const third = try element(document, "option");
            _ = try interfaces.Node.call_appendChild(select, third);
            try expectInvariant(select);
            try dom.form_controls.pickOption(select, second, true);
            try expectInvariant(select);
            try dom.form_controls.pickOption(select, third, true);
            try expectInvariant(select);
            try interfaces.Element.call_removeAttribute(select, runtime.DOMString.initInterned("multiple"));
            try expectInvariant(select);
            try interfaces.Element.call_setAttribute(select, runtime.DOMString.initInterned("size"), .{ .domstring = runtime.DOMString.initInterned("2") });
            try expectInvariant(select);
            try interfaces.HTMLSelectElement.set_selectedIndex(select, -1);
            try expectInvariant(select);
            dom.form_controls.reset(select);
            try expectInvariant(select);
            try interfaces.Element.call_removeAttribute(select, runtime.DOMString.initInterned("size"));
            try expectInvariant(select);
        },
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

test "appending after selectedIndex minus one selects the first option without cloning it" {
    try fresh(.append_after_clear);
}
test "an appended first enabled option clones in its post-connection step" {
    try fresh(.append_first_enabled);
}
test "reset selects a newly enabled first option without preselecting it" {
    try fresh(.enable_then_reset);
}
test "default-selected attribute reads preserve an explicit false selectedness" {
    try fresh(.default_read);
}
test "the select summary bit agrees after every selection and owner change" {
    try fresh(.all_write_paths);
}
