//! Q91: preserve unbounded CSS data; the explicit physical adapter terminates.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

test "infinite chroma remains infinite in computed CSS color data" {
    inline for (.{ "lch(50 calc(infinity) 0)", "oklch(0.5 calc(infinity) 0)" }) |text| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "color", text, "");
        try testing.expectEqual(@as(usize, 1), block.entries.items.len);
        const color = block.entries.items[0].typed.value.value.color;
        const computed = try color.resolveComputed(testing.allocator, .{});
        defer computed.release();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(testing.allocator);
        try computed.serializeComputed(&output, testing.allocator);
        try testing.expectEqualStrings(text, output.items);
    }
}

test "physical gamut mapping terminates with finite bounded channels for nonfinite and extreme inputs" {
    if (comptime !@hasDecl(css, "color_spaces")) return error.TypedColorSpaceNotImplemented;
    const spaces = css.color_spaces;
    for ([_]f64{ std.math.inf(f64), -std.math.inf(f64), std.math.nan(f64), 1e300, -1e300 }) |extreme| {
        inline for (.{ spaces.Space.oklch, spaces.Space.lch, spaces.Space.srgb }) |space| {
            const origin = spaces.Components{ .space = space, .channels = .{ 0.5, extreme, 0 } };
            const result = spaces.gamutMapSrgb(origin);
            for (result) |channel| try testing.expect(std.math.isFinite(channel) and channel >= 0 and channel <= 1);
            // Q91: a lossy destination may not rewrite the CSS value itself.
            if (std.math.isNan(extreme)) try testing.expect(std.math.isNan(origin.channels[1])) else try testing.expectEqual(extreme, origin.channels[1]);
        }
    }
}

test "root currentcolor and nested currentcolor inherit the initial color in its own scheme" {
    inline for (.{ "currentcolor", "light-dark(red,currentcolor)" }) |input| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "color-scheme:dark;color:" ++ input);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .is_root = true }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(testing.allocator);
        try style.serializeResolved(.color, &output, testing.allocator);
        try testing.expectEqualStrings("rgb(255, 255, 255)", output.items);
    }
}
