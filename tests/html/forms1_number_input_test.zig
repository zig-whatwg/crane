//! Lane forms1 (C7a): a number input inserts typed text at its caret and
//! refuses the keys that would break scientific notation (Blink
//! NumberInputType::FilterBeforeTextInserted, WebKit
//! NumberInputType::handleBeforeTextInsertedEvent; HTML 4.10.5.1.12 "user
//! agents must not allow the user to set the value to a non-empty string that
//! is not a valid floating-point number");
//! the-input-element/number-invalid-scientific-key-events.html (Chrome and
//! Safari 4/4). ArrowLeft moves an input's caret one grapheme cluster.
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

/// Type "1e+1" into a cleared, focused number input, move the caret
/// `left` code points left, then type `key`.
fn numberCase(left: usize, key: []const u8, expected: []const u8) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<input type=number id=n>'; document.getElementById('n').focus();");
    try typeText(page, "1e+1");
    try expectScript(page, "document.getElementById('n').value", "1e+1");
    for (0..left) |_| try press(page, "ArrowLeft", null);
    try typeText(page, key);
    try expectScript(page, "const n = document.getElementById('n'); n.value + '|' + n.validity.valid + '|' + n.valueAsNumber", expected);
}

fn numberSignAfterE() !void {
    try numberCase(2, "-", "1e+1|true|10");
    try numberCase(2, "+", "1e+1|true|10");
}

test "a number input refuses a second sign after its e" {
    try helpers.onFreshThread(numberSignAfterE);
}

fn numberLeadingSign() !void {
    // A leading '+' is refused once there is an 'e'; a leading '-' is not.
    try numberCase(4, "+", "1e+1|true|10");
    try numberCase(4, "-", "-1e+1|true|-10");
}

test "a number input inserts at its caret, refusing a leading plus with an e" {
    try helpers.onFreshThread(numberLeadingSign);
}
