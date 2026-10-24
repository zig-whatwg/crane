//! Q84: a Color aggregate forwards the optional random-input dependency.
const std = @import("std");
const css = @import("css");
const values = css.style_values;
const Color = values.Color;
const testing = std.testing;

test "Color random-input dependency defaults false for each existing scalar variant" {
    if (comptime !@hasDecl(Color, "needsRandomBase")) return error.ColorRandomDependencyApiNotImplemented;
    const named: Color = .{ .named = .{ .rgba = values.RgbaColor.black, .name = try values.SharedText.create(testing.allocator, "black") } };
    defer named.release();
    for ([_]Color{ Color.black, .current, named, .{ .system = .canvastext } }) |color| {
        try testing.expect(!color.needsRandomBase());
    }
}
