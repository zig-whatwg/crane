//! Values4 Appendix C / Color4 Appendix B: quirks do not flow into components.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "SVG paint masks shapes and filters do not inherit another property's quirks" {
    const cases = .{
        .{ "fill", "fff" },
        .{ "stroke", "url(#paint) ffffff" },
        .{ "filter", "blur(3)" },
        .{ "filter", "drop-shadow(1 2)" },
        .{ "filter", "drop-shadow(1px 2px fff)" },
        .{ "clip-path", "circle(10)" },
        .{ "clip-path", "inset(1 2)" },
        .{ "clip-path", "circle(at 10 20)" },
        .{ "mask-position", "10 20" },
        .{ "mask-size", "10 20" },
        .{ "mask", "url(a) 10 20" },
    };
    inline for (cases) |case| {
        const property = css.properties.lookup(case[0]) orelse return error.ImagePropertyNotImplemented;
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (assignments.items) |item| item.value.release();
            assignments.deinit(testing.allocator);
        }
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator, .quirks = true }, property, case[1], &assignments));
    }
}
