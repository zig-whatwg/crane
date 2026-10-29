//! A slot's assigned contents precede the content of a popover it invokes.
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn tab(page: helpers.Page, backward: bool) void {
    var keyboard: html.user_input.Keyboard = .{};
    const document = page.browser.current_context.?.document_instance.?;
    const modifiers = html.user_input.Modifiers{ .shift = backward };
    html.user_input.keyDown(&keyboard, document, .{ .key = "Tab" }, modifiers);
    html.user_input.keyUp(&keyboard, document, .{ .key = "Tab" }, modifiers);
}

fn expectActive(page: helpers.Page, id: []const u8) !void {
    const actual = try page.evaluate("document.activeElement.id");
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(id, actual);
}

fn exercise(comptime sentinels: bool, comptime backward: bool) !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<div id="host"><button id="invokerButton" slot="invoker">Click me</button><button id="inner">Click me next</button></div>';
        \\const root = host.attachShadow({mode:'open'});
        \\root.innerHTML = '<div><slot id="invoker" name="invoker"></slot><slot id="popover" popover="manual"></slot></div>';
        \\root.getElementById('popover').showPopover({source:root.getElementById('invoker')});
    );
    if (sentinels) try page.run(
        \\const before = document.createElement('button'); before.id = 'before'; host.before(before);
        \\const after = document.createElement('button'); after.id = 'after'; host.after(after);
    );
    const order = if (sentinels)
        &[_][]const u8{ "before", "invokerButton", "inner", "after" }
    else
        &[_][]const u8{ "invokerButton", "inner" };
    if (backward) {
        try page.run(if (sentinels) "document.getElementById('after').focus()" else "inner.focus()");
        var i = order.len - 1;
        while (i > 0) {
            i -= 1;
            tab(page, true);
            try expectActive(page, order[i]);
        }
    } else {
        try page.run(if (sentinels) "document.getElementById('before').focus()" else "invokerButton.focus()");
        for (order[1..]) |id| {
            tab(page, false);
            try expectActive(page, id);
        }
    }
}

fn exactForward() !void {
    try exercise(false, false);
}

fn exactBackward() !void {
    try exercise(false, true);
}

fn sentinelsForward() !void {
    try exercise(true, false);
}

fn sentinelsBackward() !void {
    try exercise(true, true);
}

test "sd1 a slot invoker's assigned button precedes its slotted popover" {
    try helpers.onFreshThread(exactForward);
}

test "sd1 Shift Tab from slotted popover content reaches the invoker button" {
    try helpers.onFreshThread(exactBackward);
}

test "sd1 slotted popover forward order with surrounding sentinels" {
    try helpers.onFreshThread(sentinelsForward);
}

test "sd1 slotted popover backward order with surrounding sentinels" {
    try helpers.onFreshThread(sentinelsBackward);
}
