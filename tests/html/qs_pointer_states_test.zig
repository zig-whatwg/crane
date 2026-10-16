//! The elements a Document's :hover and :active rest on (dom.pointer_states):
//! set by user input, read by the selector matcher, and never a dangling
//! pointer - an element that leaves its document hands its state to the
//! parent it left, and one that is freed reads as nothing.
const std = @import("std");
const html = @import("html");
const dom = @import("dom");
const runtime = @import("runtime");
const helpers = @import("edges_node_holders_helpers.zig");

const user_input = html.user_input;

fn documentOf(page: helpers.Page) !*runtime.Instance {
    const context = page.browser.current_context orelse return error.NoPage;
    return context.document_instance orelse error.NoDocument;
}

fn element(document: *runtime.Instance, selector: []const u8) !*runtime.Instance {
    return (try dom.selector_matching.querySelector(document, selector)) orelse error.NoElement;
}

fn pressRemoveCollect() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<div id=d><span id=s></span></div><p id=other></p>';");
    const document = try documentOf(page);
    const span = try element(document, "#s");
    const div = try element(document, "#d");

    var pointer = user_input.Pointer{};
    user_input.pointerMove(&pointer, span, .{});
    try std.testing.expect(dom.pointer_states.get(document, .hovered) == span);
    try std.testing.expect(try dom.selector_matching.matches(div, ":hover"));
    try std.testing.expect(!try dom.selector_matching.matches(div, ":active"));

    user_input.pointerDown(&pointer, 0, .{});
    try std.testing.expect(dom.pointer_states.get(document, .pointed) == span);
    try std.testing.expect(try dom.selector_matching.matches(span, ":active"));
    try std.testing.expect(try dom.selector_matching.matches(div, ":active"));

    // Removing the span hands both states to the div it left.
    try page.run("document.getElementById('s').remove();");
    try std.testing.expect(dom.pointer_states.get(document, .pointed) == div);
    try std.testing.expect(dom.pointer_states.get(document, .hovered) == div);

    // Removing the div too, then collecting it with its span: the document
    // holds them weakly, so nothing reads freed memory, and the state has
    // passed on to the body.
    try page.run("document.getElementById('d').remove();");
    try page.run("collectNow();");
    try page.turn();
    try page.run("collectNow();");
    try page.turn();
    const body = try element(document, "body");
    try std.testing.expect(dom.pointer_states.get(document, .pointed) == body);
    try std.testing.expect(try dom.selector_matching.matches(body, ":active"));
    const other = try element(document, "#other");
    try std.testing.expect(!try dom.selector_matching.matches(other, ":active"));

    user_input.pointerUp(&pointer, 0, .{});
    try std.testing.expect(dom.pointer_states.get(document, .pointed) == null);
    try std.testing.expect(!try dom.selector_matching.matches(body, ":active"));
}

test "a pressed element that is removed and collected hands :active and :hover to its parent" {
    try helpers.onFreshThread(pressRemoveCollect);
}

fn spaceActivation() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run("document.body.innerHTML = '<button id=b>b</button><button id=n>n</button>'; document.getElementById('b').focus();");
    const document = try documentOf(page);
    const button = try element(document, "#b");
    var keyboard = user_input.Keyboard{};
    const space = user_input.Key{ .key = " ", .code = "Space", .key_code = 32, .text = " " };
    user_input.keyDown(&keyboard, document, space, .{});
    try std.testing.expect(dom.pointer_states.get(document, .activated) == button);
    try std.testing.expect(try dom.selector_matching.matches(button, ":active"));
    user_input.keyUp(&keyboard, document, space, .{});
    try std.testing.expect(dom.pointer_states.get(document, .activated) == null);
    try std.testing.expect(!try dom.selector_matching.matches(button, ":active"));
}

test "Space holds a focused button in a formal activation state until its keyup" {
    try helpers.onFreshThread(spaceActivation);
}
