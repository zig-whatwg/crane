//! HTML 6.6.3: tabIndex parsing and defaults, through public interfaces.
const std = @import("std");
const interfaces = @import("interfaces");
const fixture = @import("rf_fixture.zig");
const str = fixture.str;

test "tabIndex uses the HTML integer prefix and long range" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const cases = [_]struct { text: []const u8, value: i32 }{
        .{ .text = "\t7trailing", .value = 7 },
        .{ .text = "\n\r\x0c +7", .value = 7 },
        .{ .text = "7\x0b", .value = 7 },
        .{ .text = "1.5", .value = 1 },
        .{ .text = "-2147483648x", .value = std.math.minInt(i32) },
        .{ .text = "2147483647x", .value = std.math.maxInt(i32) },
        .{ .text = "2147483648", .value = -1 },
        .{ .text = "-2147483649", .value = -1 },
        .{ .text = "999999999999999999999999999999999999", .value = -1 },
        .{ .text = "\x0b7", .value = -1 },
        .{ .text = "\xc2\xa0" ++ "7", .value = -1 },
        .{ .text = "", .value = -1 },
    };
    for (cases) |case| {
        try interfaces.Element.call_setAttribute(page.element, str("tabindex"), .{ .domstring = str(case.text) });
        try std.testing.expectEqual(case.value, try interfaces.HTMLElement.get_tabIndex(page.element));
    }
}

test "tabIndex defaults depend on the element even for an invalid attribute" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    for ([_][]const u8{ "a", "area", "button", "frame", "iframe", "input", "object", "select", "textarea" }) |tag| {
        const element = try page.append(page.element, tag);
        try std.testing.expectEqual(@as(i32, 0), try interfaces.HTMLElement.get_tabIndex(element));
        try interfaces.Element.call_setAttribute(element, str("tabindex"), .{ .domstring = str("invalid") });
        try std.testing.expectEqual(@as(i32, 0), try interfaces.HTMLElement.get_tabIndex(element));
    }
    for ([_][]const u8{ "div", "span", "audio", "video", "details", "summary" }) |tag| {
        const element = try page.append(page.element, tag);
        try std.testing.expectEqual(@as(i32, -1), try interfaces.HTMLElement.get_tabIndex(element));
    }
}

test "only the first summary child of details defaults to tabIndex zero" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const details = try page.append(page.element, "details");
    _ = try page.append(details, "div");
    const first = try page.append(details, "summary");
    const second = try page.append(details, "summary");
    try std.testing.expectEqual(@as(i32, 0), try interfaces.HTMLElement.get_tabIndex(first));
    try std.testing.expectEqual(@as(i32, -1), try interfaces.HTMLElement.get_tabIndex(second));
    _ = try interfaces.Node.call_removeChild(details, first);
    defer interfaces.HTMLElement.deinit(first);
    try std.testing.expectEqual(@as(i32, 0), try interfaces.HTMLElement.get_tabIndex(second));
}
