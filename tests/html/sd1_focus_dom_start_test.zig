//! Disabled positive-tabindex start: Blink/WebKit keep rank, Gecko uses DOM.
//! The three-engine source audit (row129 D24/Q19, 2026-10-27) rules this
//! deliberate HTML 6.6.5 step 4 deviation. Revisions are in focus_navigation.
const std = @import("std");
const html = @import("html");
const helpers = @import("edges_node_holders_helpers.zig");

fn disabledStartingPoint() !void {
    const page = try helpers.Page.open();
    defer page.close();
    for ([_]bool{ false, true }) |backward| {
        try page.run(
            \\document.body.innerHTML = '<button id="before" tabindex="3"></button><button id="start" tabindex="2"></button><button id="next" tabindex="1"></button><button id="last"></button>';
            \\document.getElementById('start').focus();
            \\document.getElementById('start').disabled = true;
        );
        var keyboard: html.user_input.Keyboard = .{};
        const document = page.browser.current_context.?.document_instance.?;
        html.user_input.keyDown(&keyboard, document, .{ .key = "Tab" }, .{ .shift = backward });
        html.user_input.keyUp(&keyboard, document, .{ .key = "Tab" }, .{ .shift = backward });
        const active = try page.evaluate("document.activeElement.id");
        defer std.testing.allocator.free(active);
        try std.testing.expectEqualStrings(if (backward) "next" else "before", active);
    }
}

test "sd1 a disabled positive-tabindex starting point keeps its rank in both directions" {
    try helpers.onFreshThread(disabledStartingPoint);
}
