//! Lane edit3: Backspace at the editing host's start in the first item of a
//! nested list outdents it into the host list (src/html/execcommand/
//! delete.zig outdentsListItem) - editing/other/delete-in-last-list-item-
//! when-parent-list-is-editing-host.html, Chrome 157, Firefox 160 and Safari
//! 27.2 (wpt.fyi 2358bd4835) - while an item of the host list itself stays.
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");
const harness = @import("editing4_harness.zig");

fn pressBackspace(page: helpers.Page) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    const key: html.user_input.Key = .{ .key = "Backspace", .code = "Backspace", .key_code = 8 };
    html.user_input.keyDown(&keyboard, document, key, .{});
    html.user_input.keyUp(&keyboard, document, key, .{});
}

fn listOutdent() !void {
    const page = try helpers.Page.open();
    defer page.close();
    const Row = struct { list: []const u8, inner: []const u8, ok: []const []const u8 };
    const rows = [_]Row{
        .{ .list = "ol", .inner = "<ul><li></li></ul>", .ok = &.{ "<li></li>", "<li><br></li>" } },
        .{ .list = "ul", .inner = "<ol><li></li></ol>", .ok = &.{ "<li></li>", "<li><br></li>" } },
        .{ .list = "ul", .inner = "<li></li>", .ok = &.{ "<li></li>", "<li><br></li>" } },
    };
    var failures: usize = 0;
    for (rows) |row| {
        const setup = try std.fmt.allocPrint(std.testing.allocator,
            \\document.body.innerHTML = '<{s} contenteditable>{s}</{s}>';
            \\globalThis.host = document.body.firstChild;
            \\host.focus();
            \\getSelection().collapse(host.querySelector('li li') || host.querySelector('li'), 0);
        , .{ row.list, row.inner, row.list });
        defer std.testing.allocator.free(setup);
        try page.run(setup);
        pressBackspace(page);
        const actual = try page.evaluate("host.innerHTML + '|' + document.body.childNodes.length");
        defer std.testing.allocator.free(actual);
        var matched = false;
        for (row.ok) |ok| {
            const expected = try std.fmt.allocPrint(std.testing.allocator, "{s}|1", .{ok});
            defer std.testing.allocator.free(expected);
            if (std.mem.eql(u8, actual, expected)) matched = true;
        }
        if (!matched) {
            std.debug.print("<{s} contenteditable>{s}: got {s}\n", .{ row.list, row.inner, actual });
            failures += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "Backspace outdents the first item of a nested list at the editing host's start" {
    try helpers.onFreshThread(listOutdent);
}

fn rootEmptiedByExecCommand() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(harness.setup_script);
    // editing/run/delete.html (all three): execCommand("delete") empties a
    // root editable element with one caret position, as Backspace does.
    const Case = harness.Case;
    try harness.runCases(page, &[_]Case{
        .{ .input = "<div><div>{}<br></div></div>", .commands = &.{.{ "delete", "" }}, .expected = "<br>" },
        .{ .input = "<div><div contenteditable=false><div contenteditable><div>{}<br></div></div></div></div>", .commands = &.{.{ "delete", "" }}, .expected = "<div><div contenteditable=\"false\"><div contenteditable=\"\"><br></div></div></div>" },
    });
}

test "execCommand delete empties a root editable element with one caret position" {
    try helpers.onFreshThread(rootEmptiedByExecCommand);
}
