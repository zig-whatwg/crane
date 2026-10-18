//! Native focusability rules behind the select's shared focus integration.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const focus = @import("html").focus;
const helpers = @import("edges_node_holders_helpers.zig");

fn focusability(comptime id: []const u8, expected: bool) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = `
        \\  <input id="hidden" style="display:none">
        \\  <div style="display:none"><input id="ancestor-hidden"></div>
        \\  <div id="contents" tabindex="0" style="display:contents"><input></div>
        \\  <div style="display:none"><div id="hidden-contents" tabindex="0" style="display:contents"><input></div></div>
        \\  <select><button id="own"><span id="own-child" tabindex="0">label</span></button><option>one</option></select>
        \\  <button id="ordinary">ordinary</button>`;
    );
    const document = page.browser.current_context.?.document_instance.?;
    const element = (try interfaces.Document.call_getElementById(document, runtime.DOMString.initInterned(id))).?;
    try std.testing.expectEqual(expected, focus.isFocusableArea(element));
}

fn run(comptime id: []const u8, comptime expected: bool) !void {
    const Case = struct {
        fn exercise() !void {
            try focusability(id, expected);
        }
    };
    try helpers.onFreshThread(Case.exercise);
}

test "display none excludes an element from focusable areas" {
    try run("hidden", false);
}

test "display none on an ancestor excludes its input from focusable areas" {
    try run("ancestor-hidden", false);
}

test "display contents delegates rendering and remains a focusable area" {
    try run("contents", true);
}

test "display contents does not bypass a display none ancestor" {
    try run("hidden-contents", false);
}

test "an enabled select own button and its descendant are inert to focus" {
    try run("own", false);
    try run("own-child", false);
}

test "a button outside a select stays focusable" {
    try run("ordinary", true);
}
