//! HTML 4.10.7/4.10.10/4.10.17 regression cases through generated interfaces.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const testing = std.testing;

fn child(document: *runtime.Instance, parent: *runtime.Instance, name: []const u8) !*runtime.Instance {
    const element = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned(name), .notPassed());
    errdefer dom.node_creation.destroyUninserted(element);
    _ = try interfaces.Node.call_appendChild(parent, element);
    return element;
}

fn attribute(element: *runtime.Instance, name: []const u8, value: []const u8) !void {
    try interfaces.Element.call_setAttribute(element, runtime.DOMString.initInterned(name), .{ .domstring = runtime.DOMString.initInterned(value) });
}

const Case = enum { disabled_wrapper, placeholder_wrapper, selectedcontent, selection_order };

fn exercise(comptime which: Case) !void {
    const fixture = try @import("sel3_selection_helpers.zig").DocumentPage.open();
    defer fixture.close();
    const document = fixture.document;
    const select = try interfaces.Document.call_createElementNS(document, runtime.DOMString.initInterned("http://www.w3.org/1999/xhtml"), runtime.DOMString.initInterned("select"), .notPassed());
    defer dom.node_creation.destroyUninserted(select);

    switch (which) {
        .disabled_wrapper => {
            const group = try child(document, select, "optgroup");
            try attribute(group, "disabled", "");
            const wrapper = try child(document, group, "div");
            const disabled = try child(document, wrapper, "option");
            try attribute(disabled, "value", "disabled");
            const enabled = try child(document, select, "option");
            try attribute(enabled, "value", "enabled");
            try testing.expectEqual(@as(i32, 1), try interfaces.HTMLSelectElement.get_selectedIndex(select));
            try interfaces.HTMLOptionElement.set_selected(disabled, true);
            try testing.expectEqual(@as(i32, 0), try interfaces.HTMLSelectElement.get_selectedIndex(select));
        },
        .placeholder_wrapper => {
            try attribute(select, "required", "");
            const wrapper = try child(document, select, "div");
            const option = try child(document, wrapper, "option");
            try attribute(option, "value", "");
            try testing.expect(!try interfaces.HTMLSelectElement.call_checkValidity(select));
            const group = try child(document, wrapper, "optgroup");
            _ = try interfaces.Node.call_appendChild(group, option);
            try testing.expect(try interfaces.HTMLSelectElement.call_checkValidity(select));
        },
        .selectedcontent => {
            const button = try child(document, select, "button");
            const content = try child(document, button, "selectedcontent");
            const option = try child(document, select, "option");
            try attribute(option, "value", "chosen");
            const label = try child(document, option, "b");
            try interfaces.Node.set_textContent(label, runtime.DOMString.initInterned("one"));
            try interfaces.HTMLSelectElement.set_value(select, runtime.DOMString.initInterned("chosen"));
            const clone = (try interfaces.Node.get_firstChild(content)) orelse return error.MissingSelectedContent;
            try testing.expect(clone != label);
            var text = (try interfaces.Node.get_textContent(content)) orelse return error.MissingText;
            defer text.deinit(testing.allocator);
            try testing.expectEqualStrings("one", text.asSlice());
            try interfaces.HTMLSelectElement.set_selectedIndex(select, -1);
            try testing.expectEqual(@as(?*runtime.Instance, null), try interfaces.Node.get_firstChild(content));
        },
        .selection_order => {
            const first = try child(document, select, "option");
            const second = try child(document, select, "option");
            try interfaces.HTMLOptionElement.set_selected(second, true);
            try interfaces.HTMLOptionElement.set_selected(first, true);
            try testing.expect(try interfaces.HTMLOptionElement.get_selected(first));
            try testing.expect(!try interfaces.HTMLOptionElement.get_selected(second));
        },
    }
}

fn runOnThread(comptime which: Case) !void {
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

test "select default selection skips an option wrapped in a disabled optgroup" {
    try runOnThread(.disabled_wrapper);
}

test "select placeholder excludes optgroups but permits wrappers" {
    try runOnThread(.placeholder_wrapper);
}

test "selectedcontent clones the selected option and clears an empty selection" {
    try runOnThread(.selectedcontent);
}

test "the most recently selected option wins irrespective of tree order" {
    try runOnThread(.selection_order);
}
