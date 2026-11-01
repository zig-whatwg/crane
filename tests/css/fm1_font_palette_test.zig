//! Fonts 4 §9.1 and Color 5 mixing serialization; no palette rendering here.
const std = @import("std");
const h = @import("bx1_helpers.zig");

test "font palettes preserve names and canonicalize predefined keywords" {
    inline for (.{ "normal", "light", "dark", "--", "--Custom" }) |value| {
        try h.check(std.testing.allocator, "font-palette", value, value, false);
        try h.check(std.testing.allocator, "font-palette", value, value, true);
    }
    try h.check(std.testing.allocator, "font-palette", "LIGHT", "light", false);
    inline for (.{ "foo", "none", "light dark", "\"--foo\"", "1" }) |input|
        try h.check(std.testing.allocator, "font-palette", input, "", false);
}

const specified = .{
    .{ "palette-mix(in oklab, light 30%, dark)", "palette-mix(light 30%, dark 70%)" },
    .{ "palette-mix(in xyz, 30% --Foo, dark)", "palette-mix(in xyz-d65, --Foo 30%, dark 70%)" },
    .{ "palette-mix(in hsl shorter hue, light, dark)", "palette-mix(in hsl, light, dark)" },
    .{ "palette-mix(in oklch longer hue, light, dark)", "palette-mix(in oklch longer hue, light, dark)" },
    .{ "palette-mix(light 50%, dark 50%)", "palette-mix(light, dark)" },
    .{ "palette-mix(light calc(50%), dark)", "palette-mix(light calc(50%), dark)" },
    .{ "palette-mix(light 50%, dark, --foo)", "palette-mix(light 50%, dark 25%, --foo 25%)" },
    .{ "palette-mix(light, dark, --foo)", "palette-mix(light, dark, --foo)" },
    .{ "palette-mix(dark 100%)", "palette-mix(dark)" },
    .{ "palette-mix(dark 0%)", "palette-mix(dark 0%)" },
    .{ "palette-mix(light 0%, dark 0%)", "palette-mix(light 0%, dark 0%)" },
};

test "palette mix serializes arbitrary component counts and weights" {
    inline for (specified) |case|
        try h.check(std.testing.allocator, "font-palette", case[0], case[1], false);
}

test "palette mix computes weights and simplifies equivalent palettes" {
    inline for (.{
        .{ "palette-mix(light calc(50%), dark)", "palette-mix(light, dark)" },
        .{ "palette-mix(light calc(sign(1em - 1px) * 10%), dark)", "palette-mix(light 10%, dark 90%)" },
        .{ "palette-mix(light 30%, light)", "light" },
        .{ "palette-mix(--Foo)", "--Foo" },
        .{ "palette-mix(dark 50%)", "palette-mix(dark 50%)" },
        .{ "palette-mix(dark 0%)", "palette-mix(dark 0%)" },
        .{ "palette-mix(light 0%, dark 0%)", "palette-mix(light 0%, dark 0%)" },
        .{ "palette-mix(light 0%, dark 100%)", "dark" },
        .{ "palette-mix(light 75%, light 75%)", "light" },
        .{ "palette-mix(light 30%, light 40%)", "palette-mix(light 30%, light 40%)" },
    }) |case| try h.check(std.testing.allocator, "font-palette", case[0], case[1], true);
}

test "palette equivalence respects longer hue and endpoint alpha" {
    // ANSWER Q33 / Color4 §13.5.2: equal polar hues take a full circle
    // under longer hue. An endpoint with zero weight contributes nothing.
    inline for (.{
        .{ "palette-mix(in oklch longer hue, --Foo 50%, --Foo 50%)", "palette-mix(in oklch longer hue, --Foo, --Foo)" },
        .{ "palette-mix(in oklch shorter hue, --Foo 50%, --Foo 50%)", "--Foo" },
        .{ "palette-mix(light 100%, dark 0%)", "light" },
        .{ "palette-mix(light 50%)", "palette-mix(light 50%)" },
    }) |case| try h.check(std.testing.allocator, "font-palette", case[0], case[1], true);
}

test "palette omitted oversum weights clamp to zero and round trip" {
    // Liaison Q22: Color 5 serialization uses Values 5 §6.1's specified
    // sum, which is clamped to 100% before distributing omitted weights.
    const source = "palette-mix(light 80%, dark 70%, --Other)";
    const canonical = "palette-mix(light 80%, dark 70%, --Other 0%)";
    inline for (.{ false, true }) |computed| {
        try h.check(std.testing.allocator, "font-palette", source, canonical, computed);
        try h.check(std.testing.allocator, "font-palette", canonical, canonical, computed);
    }
}

test "palette mix rejects malformed methods components and literal ranges" {
    inline for (.{
        "palette-mix()",                                "palette-mix(in srgb)",                 "palette-mix(light,)",
        "palette-mix(in srgb longer hue, light, dark)", "palette-mix(in made-up, light, dark)", "palette-mix(regular, dark)",
        "palette-mix(light -1%, dark)",                 "palette-mix(light 101%, dark)",        "palette-mix(light 20% 30%, dark)",
        "palette-mix(light, initial)",
    }) |input| try h.check(std.testing.allocator, "font-palette", input, "", false);
}

test "nested palette ownership survives every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationFailure, .{});
}

test "palette mix accepts 128 composite levels and rejects the 129th" {
    // Q29's engine safety bound matches the existing color/image owners.
    for ([_]usize{ 128, 129 }) |depth| {
        var input: std.ArrayList(u8) = .empty;
        defer input.deinit(std.testing.allocator);
        for (0..depth) |_| try input.appendSlice(std.testing.allocator, "palette-mix(");
        try input.appendSlice(std.testing.allocator, "dark");
        try input.appendNTimes(std.testing.allocator, ')', depth);
        try h.check(std.testing.allocator, "font-palette", input.items, if (depth == 128) input.items else "", false);
    }
}

test "font palette inherits its computed mix and starts at normal" {
    var empty = h.Block.init(std.testing.allocator);
    defer empty.deinit();
    const initial = try h.compute(std.testing.allocator, &empty, null);
    defer initial.destroy();
    try h.expect(initial, "font-palette", "normal", std.testing.allocator);
    var block = try h.Block.parse(.{ .allocator = std.testing.allocator }, "font-palette:palette-mix(--Custom calc(30%), dark)");
    defer block.deinit();
    const parent = try h.compute(std.testing.allocator, &block, initial);
    defer parent.destroy();
    const child = try h.compute(std.testing.allocator, &empty, parent);
    defer child.destroy();
    try h.expect(child, "font-palette", "palette-mix(--Custom 30%, dark 70%)", std.testing.allocator);
}

fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "font-palette", "palette-mix(palette-mix(in srgb, light 30%, normal) 20%, dark)", "palette-mix(palette-mix(in srgb, light 30%, normal 70%) 20%, dark 80%)", true);
    try h.check(allocator, "font-palette", "palette-mix(--Foo calc(50%), --Foo)", "--Foo", true);
    try h.check(allocator, "font-palette", "palette-mix(light 50%, dark, --foo)", "palette-mix(light 50%, dark 25%, --foo 25%)", false);
}
