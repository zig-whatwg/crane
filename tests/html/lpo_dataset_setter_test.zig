//! DOMStringMap rejects invalid names before mutating its element.
//!
//! On a page of a real Browser (native_read_page.zig, lane mp1): the dataset
//! is its wrapper's to end, and the engine-less context this test had freed
//! it by hand.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const native_read_page = @import("native_read_page.zig");
const testing = std.testing;

fn exercise(page: native_read_page.Page) !void {
    const element = try page.elementNS("http://www.w3.org/1999/xhtml", "div");
    const dataset = try interfaces.HTMLElement.get_dataset(element);
    const value = runtime.DOMString.initInterned("value");
    for ([_][]const u8{ "-a", "foo-bar", "--a", "bad-a/", "bad-a " }) |name| {
        try testing.expectError(error.SyntaxError, interfaces.DOMStringMap.call_setter(dataset, runtime.DOMString.initInterned(name), value));
    }
    for ([_][]const u8{ "bad name", "bad\tname", "bad\nname", "bad\rname", "bad\x0cname", "bad\x00name", "bad/name", "bad=name", "bad>name" }) |name| {
        try testing.expectError(error.InvalidCharacterError, interfaces.DOMStringMap.call_setter(dataset, runtime.DOMString.initInterned(name), value));
    }
    try testing.expect(!try interfaces.Element.call_hasAttributes(element));

    const cases = [_]struct { property: []const u8, attribute: []const u8 }{
        .{ .property = "", .attribute = "data-" },
        .{ .property = "fooBar", .attribute = "data-foo-bar" },
        .{ .property = "foo-Bar", .attribute = "data-foo--bar" },
        .{ .property = "-", .attribute = "data--" },
        .{ .property = "foo-9", .attribute = "data-foo-9" },
        .{ .property = "é-É", .attribute = "data-é-É" },
    };
    for (cases) |case| {
        try interfaces.DOMStringMap.call_setter(dataset, runtime.DOMString.initInterned(case.property), value);
        var actual = (try interfaces.Element.call_getAttribute(element, runtime.DOMString.initInterned(case.attribute))).?;
        defer actual.deinit(testing.allocator);
        try testing.expectEqualStrings("value", actual.asSlice());
    }
}

test "dataset setter validates hyphen-lowercase before attribute names and converts only ASCII capitals" {
    try native_read_page.onPage(exercise);
}
