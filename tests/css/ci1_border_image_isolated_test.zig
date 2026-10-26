//! UNRUN isolated RED candidate; install/run only on the actual accepted parent.
const std = @import("std");
const css = @import("css");
test "ci1 isolated border image omitted width slash expands five typed longhands" {
    const p = css.properties.lookup("border-image") orelse return error.BorderImageFamilyNotImplemented;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(std.testing.allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = std.testing.allocator }, p, "20 / / 2 round", &assignments));
    try std.testing.expectEqual(@as(usize, 5), assignments.items.len);
    const names = [_][]const u8{ "border-image-source", "border-image-slice", "border-image-width", "border-image-outset", "border-image-repeat" };
    const expected = [_][]const u8{ "none", "20", "1", "2", "round" };
    for (names, expected, assignments.items) |name, text, a| {
        const longhand = (css.properties.lookup(name) orelse return error.BorderImageFamilyNotImplemented).longhand;
        try std.testing.expectEqual(longhand, a.longhand);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(std.testing.allocator);
        try css.properties.serializeAssigned(longhand, a.value, &out, std.testing.allocator);
        try std.testing.expectEqualStrings(text, out.items);
    }
}
