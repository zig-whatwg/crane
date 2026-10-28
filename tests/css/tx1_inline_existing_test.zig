//! Existing specified readbacks from generation183's passing-name manifest.
//! These do not assume the old unparsed representation or longhand count.
const std = @import("std");
const css = @import("css");

test "existing inline specified values survive property registration" {
    const allocator = std.testing.allocator;
    const cases = .{
        .{ "alignment-baseline", "alphabetic" },
        .{ "alignment-baseline", "baseline" },
        .{ "alignment-baseline", "central" },
        .{ "alignment-baseline", "ideographic" },
        .{ "alignment-baseline", "inherit" },
        .{ "alignment-baseline", "mathematical" },
        .{ "alignment-baseline", "middle" },
        .{ "alignment-baseline", "text-bottom" },
        .{ "alignment-baseline", "text-top" },
        .{ "baseline-shift", "0px" },
        .{ "baseline-shift", "1px" },
        .{ "baseline-shift", "5%" },
        .{ "baseline-shift", "bottom" },
        .{ "baseline-shift", "center" },
        .{ "baseline-shift", "inherit" },
        .{ "baseline-shift", "sub" },
        .{ "baseline-shift", "super" },
        .{ "baseline-shift", "top" },
        .{ "baseline-source", "auto" },
        .{ "baseline-source", "first" },
        .{ "baseline-source", "inherit" },
        .{ "baseline-source", "last" },
        .{ "vertical-align", "baseline" },
        .{ "vertical-align", "sub" },
        .{ "vertical-align", "super" },
    };
    inline for (cases) |entry| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, entry[0] ++ ":" ++ entry[1]);
        defer block.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try block.getPropertyValue(entry[0], &out);
        try std.testing.expectEqualStrings(entry[1], out.items);
    }
}
