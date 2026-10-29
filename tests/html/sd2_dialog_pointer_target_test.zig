//! Closing ends open-list membership; removal and pointerup end the down target.
const helpers = @import("edges_node_holders_helpers.zig");
const dom = @import("dom");
const html = @import("html");
const std = @import("std");

fn closingKeepsTarget() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<button id=outside>Outside</button><dialog id=other closedby=any></dialog><dialog id=clicked closedby=any><button id=inside>Inside</button></dialog>';
        \\globalThis.other = document.getElementById('other');
        \\globalThis.clicked = document.getElementById('clicked');
        \\other.show();
    );
    const document = page.browser.current_context.?.document_instance.?;
    const outside = (try dom.selector_matching.querySelector(document, "#outside")).?;
    const inside = (try dom.selector_matching.querySelector(document, "#inside")).?;
    const clicked = (try dom.selector_matching.querySelector(document, "#clicked")).?;
    var pointer: html.user_input.Pointer = .{};
    for ([_][]const u8{ "clicked.close()", "clicked.open = false" }) |close| {
        try page.run("clicked.show()");
        html.user_input.pointerMove(&pointer, inside, .{});
        html.user_input.pointerDown(&pointer, 0, .{});
        const state = (try dom.top_layer.ofDocument(document, false)).?;
        try std.testing.expect(state.dialog_pointerdown_target.get() == clicked);
        try page.run(close);
        // HTML light dismiss 6.1 compares against the remembered down target,
        // even when that dialog has since left the open dialogs list.
        html.user_input.pointerMove(&pointer, outside, .{});
        html.user_input.pointerUp(&pointer, 0, .{});
        try page.run("if (!other.open) throw new Error('closing the down target dismissed another dialog')");
        try std.testing.expect(state.dialog_pointerdown_target.get() == null);
    }
}

fn removingClosedTarget() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try page.run(
        \\document.body.innerHTML = '<dialog id=clicked closedby=any><button id=inside>Inside</button></dialog>';
        \\globalThis.clicked = document.getElementById('clicked');
        \\clicked.show();
    );
    const document = page.browser.current_context.?.document_instance.?;
    const inside = (try dom.selector_matching.querySelector(document, "#inside")).?;
    const clicked = (try dom.selector_matching.querySelector(document, "#clicked")).?;
    var pointer: html.user_input.Pointer = .{};
    html.user_input.pointerMove(&pointer, inside, .{});
    html.user_input.pointerDown(&pointer, 0, .{});
    const state = (try dom.top_layer.ofDocument(document, false)).?;
    try page.run("clicked.close()");
    try std.testing.expect(state.lastOpenDialog() == null);
    try std.testing.expect(state.dialog_pointerdown_target.get() == clicked);
    // The removal exit applies even without an open attribute.
    try page.run("clicked.remove()");
    try std.testing.expect(state.dialog_pointerdown_target.get() == null);
}

test "closing a pointerdown dialog does not dismiss another dialog on pointerup" {
    try helpers.onFreshThread(closingKeepsTarget);
}

test "removal clears a dialog pointerdown target that was already closed" {
    try helpers.onFreshThread(removingClosedTarget);
}
