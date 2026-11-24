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
    try std.testing.expect(value == .boolean and value.boolean == false);
}

test "hidden recognizes until-found ASCII case insensitively" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    try interfaces.Element.call_setAttribute(page.element, str("hidden"), .{ .domstring = str("UnTiL-FoUnD") });
    const value = (try interfaces.HTMLElement.get_hidden(page.element)).?;
    try std.testing.expect(value == .domstring);
    try std.testing.expectEqualStrings("until-found", value.domstring.asSlice());
}

test "hidden setter handles every primitive union arm" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    // The setter takes the union the binding converted (WebIDL 3.2.25: null
    // and undefined are the nullable union's null, step 2).
    const Hidden = @typeInfo(@typeInfo(@TypeOf(interfaces.HTMLElement.set_hidden)).@"fn".param_types[1].?).optional.child;
    const cases = [_]struct { value: ?Hidden, attribute: ?[]const u8 }{
        .{ .value = null, .attribute = null },
        .{ .value = .{ .boolean = false }, .attribute = null },
        .{ .value = .{ .boolean = true }, .attribute = "" },
        .{ .value = .{ .double = 0 }, .attribute = null },
        .{ .value = .{ .double = -0.0 }, .attribute = null },
        .{ .value = .{ .double = std.math.nan(f64) }, .attribute = null },
        .{ .value = .{ .double = 1 }, .attribute = "" },
        .{ .value = .{ .double = std.math.inf(f64) }, .attribute = "" },
        .{ .value = .{ .domstring = str("") }, .attribute = null },
        .{ .value = .{ .domstring = str("UnTiL-FoUnD") }, .attribute = "until-found" },
        .{ .value = .{ .domstring = str("false") }, .attribute = "" },
        .{ .value = .{ .domstring = str("0") }, .attribute = "" },
    };
    for (cases) |case| {
        try interfaces.HTMLElement.set_hidden(page.element, .{ .boolean = true });
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
