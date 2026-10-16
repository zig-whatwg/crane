//! HTML 6.1: hidden's union is not an ordinary boolean reflector.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const fixture = @import("rf_fixture.zig");
const str = fixture.str;

test "hidden without a content attribute is false rather than null" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const value = (try interfaces.HTMLElement.get_hidden(page.element)) orelse return error.UnexpectedNull;
    try std.testing.expectEqual(false, value.asBoolean().?);
}

test "hidden recognizes until-found ASCII case insensitively" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try interfaces.Element.call_setAttribute(page.element, str("hidden"), .{ .domstring = str("UnTiL-FoUnD") });
    const value = (try interfaces.HTMLElement.get_hidden(page.element)).?;
    try std.testing.expect(value == .string);
    try std.testing.expectEqualStrings("until-found", value.string.data);
}

test "hidden setter handles every primitive union arm" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const cases = [_]struct { value: ?runtime.JSValue, attribute: ?[]const u8 }{
        .{ .value = null, .attribute = null },
        .{ .value = runtime.JSValue.jsNull, .attribute = null },
        .{ .value = runtime.JSValue.jsUndefined, .attribute = null },
        .{ .value = runtime.JSValue.fromBoolean(false), .attribute = null },
        .{ .value = runtime.JSValue.fromBoolean(true), .attribute = "" },
        .{ .value = runtime.JSValue.fromNumber(0), .attribute = null },
        .{ .value = runtime.JSValue.fromNumber(-0.0), .attribute = null },
        .{ .value = runtime.JSValue.fromNumber(std.math.nan(f64)), .attribute = null },
        .{ .value = runtime.JSValue.fromNumber(1), .attribute = "" },
        .{ .value = runtime.JSValue.fromNumber(std.math.inf(f64)), .attribute = "" },
        .{ .value = runtime.JSValue.fromStringRef(""), .attribute = null },
        .{ .value = runtime.JSValue.fromStringRef("UnTiL-FoUnD"), .attribute = "until-found" },
        .{ .value = runtime.JSValue.fromStringRef("false"), .attribute = "" },
        .{ .value = runtime.JSValue.fromStringRef("0"), .attribute = "" },
    };
    for (cases) |case| {
        try interfaces.HTMLElement.set_hidden(page.element, runtime.JSValue.fromBoolean(true));
        try interfaces.HTMLElement.set_hidden(page.element, case.value);
        var attribute = try interfaces.Element.call_getAttribute(page.element, str("hidden"));
        defer if (attribute) |*value| value.deinit(std.testing.allocator);
        if (case.attribute) |expected| {
            try std.testing.expectEqualStrings(expected, (attribute orelse return error.MissingAttribute).asSlice());
        } else {
            try std.testing.expect(attribute == null);
        }
    }
}
