//! Lane quick2: Window has no `item` member. Crane's indexed getter for its
//! child navigables (specs/supplementary/WindowIndexedGetter.idl) is
//! anonymous, as HTML's Window has no member of that name: a named one put a
//! `window.item()` method on every global, which no browser has, and hid an
//! element with id "item" from the Window's named properties
//! (css/css-cascade/scope-proximity.html calls getComputedStyle(item)).
const std = @import("std");
const helpers = @import("edges_node_holders_helpers.zig");

fn expectScript(page: helpers.Page, source: []const u8, expected: []const u8) !void {
    const actual = try page.evaluate(source);
    defer std.testing.allocator.free(actual);
    std.testing.expectEqualStrings(expected, actual) catch |err| {
        std.debug.print("{s}\n", .{source});
        return err;
    };
}

fn windowHasNoItem() !void {
    const page = try helpers.Page.open();
    defer page.close();
    try expectScript(page, "typeof window.item + ',' + ('item' in Window.prototype)", "undefined,false");
    try expectScript(page,
        \\document.body.innerHTML = '<span id=item></span>';
        \\String(window.item === document.getElementById('item'))
    , "true");
    try expectScript(page,
        \\document.body.append(document.createElement('iframe'));
        \\[window.length, window[0] === document.querySelector('iframe').contentWindow, window[1]].join()
    , "1,true,");
}

test "window.item is no member: an element with id item is a named property, and window[i] still answers" {
    try helpers.onFreshThread(windowHasNoItem);
}
