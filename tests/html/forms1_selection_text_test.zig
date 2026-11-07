//! Lane forms1 (C7b): Selection's stringifier returns a focused text
//! control's selected text (Selection API: "If the selection is within a
//! textarea or input element, it must return the selected substring in its
//! value") - the text the user sees, unsanitized;
//! the-input-element/email-set-value.html (all three browsers).
const std = @import("std");
const html = @import("html");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const user_input = html.user_input;

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn press(page: helpers.Page, key: []const u8, text: ?[]const u8) !void {
    var keyboard: user_input.Keyboard = .{};
    const document = try documentOf(page);
    user_input.keyDown(&keyboard, document, .{ .key = key, .text = text }, .{});
    user_input.keyUp(&keyboard, document, .{ .key = key, .text = text }, .{});
}

fn typeText(page: helpers.Page, text: []const u8) !void {
    var it = (try std.unicode.Utf8View.init(text)).iterator();
    while (it.nextCodepointSlice()) |character| try press(page, character, character);
}

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

fn selectionText() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<input type=email id=e><input id=t value=abcdef><p>outside</p>'; document.getElementById('e').focus();");
    try typeText(page, " foo@bar   ");
    try expectScript(page, "const e = document.getElementById('e'); e.select(); e.value + '|' + getSelection().toString() + '|'", "foo@bar| foo@bar   |");
    try expectScript(page, "const e2 = document.getElementById('e'); e2.value = 'foo@bar'; e2.select(); getSelection().toString()", "foo@bar");
    try expectScript(page, "const t = document.getElementById('t'); t.focus(); t.setSelectionRange(1, 3); getSelection().toString()", "bc");
    // A document selection outside any control is unchanged.
    try expectScript(page, "document.activeElement.blur(); getSelection().selectAllChildren(document.querySelector('p')); getSelection().toString()", "outside");
}

test "Selection's stringifier returns a focused text control's selected text" {
    try helpers.onFreshThread(selectionText);
}
