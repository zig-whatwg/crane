//! HTML 8.6.5 "built-in safe default configuration": the MathML and SVG
//! table lists MathML `a` (with href, hreflang and type) before `math`. WPT
//! sanitizer-api/sanitizer-default-config.html (2358bd4835) expects it; the
//! cached HTML Standard (16 October 2026) has the row.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const fixture = @import("rf_fixture.zig");

const mathml = "http://www.w3.org/1998/Math/MathML";

test "the default Sanitizer configuration keeps MathML a with href, hreflang and type, before math" {
    var page: fixture.Page = undefined;
    try page.open();
    defer page.close();
    const sanitizer = try interfaces.Sanitizer.call_constructor(&page.ctx, .notPassed());
    defer runtime.Instance.deinit(sanitizer);
    const config = try interfaces.Sanitizer.call_get(sanitizer);
    var a_index: ?usize = null;
    var math_index: ?usize = null;
    var attributes: []const []const u8 = &.{};
    var names: [8][]const u8 = undefined;
    for (config.elements.?, 0..) |element, i| {
        const entry = switch (element) {
            .sanitizer_element_namespace_with_attributes => |value| value,
            .domstring => continue,
        };
        const namespace = entry.base.namespace.getOrDefault(null) orelse continue;
        if (!std.mem.eql(u8, namespace.asSlice(), mathml)) continue;
        const name = entry.base.name.asSlice();
        if (std.mem.eql(u8, name, "math")) math_index = i;
        if (!std.mem.eql(u8, name, "a")) continue;
        a_index = i;
        var n: usize = 0;
        for (entry.attributes orelse &.{}) |attribute| {
            names[n] = switch (attribute) {
                .domstring => |value| value.asSlice(),
                .sanitizer_attribute_namespace => |value| value.name.asSlice(),
            };
            n += 1;
        }
        attributes = names[0..n];
    }
    try std.testing.expect(a_index != null);
    try std.testing.expect(math_index != null);
    try std.testing.expect(a_index.? < math_index.?);
    try std.testing.expectEqual(@as(usize, 3), attributes.len);
    try std.testing.expectEqualStrings("href", attributes[0]);
    try std.testing.expectEqualStrings("hreflang", attributes[1]);
    try std.testing.expectEqualStrings("type", attributes[2]);
}
