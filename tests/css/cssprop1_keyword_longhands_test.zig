//! Lane cssprop1 batch 1 (cluster C01a): the keyword-only longhands each
//! definition table names - Compositing 1/2 §§3.2-3.4, Page Floats 3 / CSS
//! 2.1 §9.5.2 (clear), Color Adjustment 1 §§3.1, 4, Masking 1 §6.2
//! (clip-rule), Overscroll 1 §§2-3, Position 4 §3.4 (overlay), Ruby 1
//! §§3.1, 4.1, 5.1, Scroll Anchoring 1 §2.2, Overflow 3 §5 (scroll-behavior),
//! Filter Effects 1 §17.7 (color-interpolation-filters), Sizing 4 §5
//! (frame-sizing) and Writing Modes 4 §9.1 (text-combine-upright): grammar,
//! specified and computed serialization, initial value, inheritance and
//! animation type.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;
const Style = css.computed_style.ComputedStyle;

fn longhandOf(name: []const u8) !css.properties.Longhand {
    const property = css.properties.lookup(name) orelse return error.UnsupportedProperty;
    if (property != .longhand) return error.NotALonghand;
    return property.longhand;
}

fn resolved(style: *const Style, name: []const u8, out: *std.ArrayList(u8)) !void {
    out.clearRetainingCapacity();
    try style.serializeResolved(try longhandOf(name), out, testing.allocator);
}

/// `input` is valid: it reads back as `specified` and computes to `computed`.
fn valid(name: []const u8, input: []const u8, specified: []const u8, computed: []const u8) !void {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, name, input, ""));
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    try testing.expectEqualStrings(specified, text.items);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try resolved(style, name, &text);
    try testing.expectEqualStrings(computed, text.items);
}

fn invalid(name: []const u8, input: []const u8) !void {
    _ = try longhandOrShorthand(name);
    var block = Block.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, name, input, "");
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try block.getPropertyValue(name, &text);
    try testing.expectEqualStrings("", text.items);
}

fn longhandOrShorthand(name: []const u8) !css.properties.Property {
    return css.properties.lookup(name) orelse error.UnsupportedProperty;
}

const blend_modes = [_][]const u8{
    "normal",      "multiply",   "screen",     "overlay",    "darken",       "lighten",
    "color-dodge", "color-burn", "hard-light", "soft-light", "difference",   "exclusion",
    "hue",         "saturation", "color",      "luminosity", "plus-lighter",
};

test "keyword longhands accept exactly their grammars and compute as specified" {
    const groups = .{
        .{ "isolation", &[_][]const u8{ "auto", "isolate" } },
        .{ "clear", &[_][]const u8{ "none", "left", "right", "both", "inline-start", "inline-end" } },
        .{ "print-color-adjust", &[_][]const u8{ "economy", "exact" } },
        .{ "forced-color-adjust", &[_][]const u8{ "auto", "none", "preserve-parent-color" } },
        .{ "clip-rule", &[_][]const u8{ "nonzero", "evenodd" } },
        .{ "overscroll-behavior-x", &[_][]const u8{ "contain", "none", "auto", "chain" } },
        .{ "overscroll-behavior-y", &[_][]const u8{ "contain", "none", "auto", "chain" } },
        .{ "overscroll-behavior-inline", &[_][]const u8{ "contain", "none", "auto", "chain" } },
        .{ "overscroll-behavior-block", &[_][]const u8{ "contain", "none", "auto", "chain" } },
        .{ "ruby-align", &[_][]const u8{ "start", "center", "space-between", "space-around" } },
        .{ "ruby-overhang", &[_][]const u8{ "auto", "spaces" } },
        .{ "overflow-anchor", &[_][]const u8{ "auto", "none" } },
        .{ "scroll-behavior", &[_][]const u8{ "auto", "smooth" } },
        .{ "color-interpolation-filters", &[_][]const u8{ "auto", "srgb", "linearrgb" } },
        .{ "frame-sizing", &[_][]const u8{ "auto", "content-width", "content-height", "content-inline-size", "content-block-size" } },
        .{ "text-combine-upright", &[_][]const u8{ "none", "all" } },
    };
    inline for (groups) |group| {
        for (group[1]) |keyword| try valid(group[0], keyword, keyword, keyword);
        try invalid(group[0], "unknown-keyword");
        try invalid(group[0], "1");
        try invalid(group[0], group[1][0] ++ " " ++ group[1][1]);
    }
    for (blend_modes) |mode| try valid("mix-blend-mode", mode, mode, mode);
    try invalid("mix-blend-mode", "auto");
    try invalid("mix-blend-mode", "normal luminosity");
    try invalid("mix-blend-mode", "normal, luminosity");
    // Compositing 2 lists plus-lighter only; Safari's plus-darker is in no
    // spec and no other browser.
    try invalid("mix-blend-mode", "plus-darker");
    try invalid("isolation", "none");
    try invalid("clear", "block-start");
    try invalid("overflow-anchor", "all");
    try invalid("scroll-behavior", "normal");
    try invalid("clip-rule", "auto");
    try invalid("forced-color-adjust", "default");
}

test "keyword spellings serialize lowercase and legacy aliases as their target" {
    // Filter Effects 1 §17.7: sRGB and linearRGB match ASCII
    // case-insensitively and serialize lowercase in all three browsers
    // (color-interpolation-filters-parsing-valid.html).
    try valid("color-interpolation-filters", "sRGB", "srgb", "srgb");
    try valid("color-interpolation-filters", "LiNeArRgB", "linearrgb", "linearrgb");
    try invalid("color-interpolation-filters", "linearRGB sRGB");
    // Ruby 1 §5.1: none is a legacy value alias of spaces.
    try valid("ruby-overhang", "none", "spaces", "spaces");
    try invalid("ruby-overhang", "auto spaces");
    try invalid("ruby-overhang", "none none");
}

test "ruby-position: alternate || over | under, or inter-character" {
    try valid("ruby-position", "over", "over", "over");
    try valid("ruby-position", "under", "under", "under");
    try valid("ruby-position", "inter-character", "inter-character", "inter-character");
    try valid("ruby-position", "alternate", "alternate", "alternate");
    // "alternate, either on its own or in combination with over, behaves
    // the same as over" for the first level: alternate over is alternate.
    try valid("ruby-position", "alternate over", "alternate", "alternate");
    try valid("ruby-position", "over alternate", "alternate", "alternate");
    try valid("ruby-position", "alternate under", "alternate under", "alternate under");
    try valid("ruby-position", "under alternate", "alternate under", "alternate under");
    try invalid("ruby-position", "over under");
    try invalid("ruby-position", "alternate alternate");
    try invalid("ruby-position", "alternate inter-character");
    try invalid("ruby-position", "auto");
    try invalid("ruby-position", "10px 20px");
}

test "background-blend-mode is a list of mix-blend-mode values, computed as specified" {
    for (blend_modes) |mode| try valid("background-blend-mode", mode, mode, mode);
    try valid("background-blend-mode", "normal, luminosity", "normal, luminosity", "normal, luminosity");
    try valid("background-blend-mode", "screen, overlay, screen", "screen, overlay, screen", "screen, overlay, screen");
    try invalid("background-blend-mode", "normal luminosity");
    try invalid("background-blend-mode", "normal,");
    try invalid("background-blend-mode", "auto");
}

test "overscroll-behavior is the x and y longhands, one value for both" {
    const allocator = testing.allocator;
    const cases = .{
        .{ "contain", "contain", "contain", "contain" },
        .{ "contain none", "contain none", "contain", "none" },
        .{ "chain auto", "chain auto", "chain", "auto" },
        .{ "none none", "none", "none", "none" },
    };
    inline for (cases) |case| {
        var block = Block.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "overscroll-behavior", case[0], ""));
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        try block.getPropertyValue("overscroll-behavior", &text);
        try testing.expectEqualStrings(case[1], text.items);
        text.clearRetainingCapacity();
        try block.getPropertyValue("overscroll-behavior-x", &text);
        try testing.expectEqualStrings(case[2], text.items);
        text.clearRetainingCapacity();
        try block.getPropertyValue("overscroll-behavior-y", &text);
        try testing.expectEqualStrings(case[3], text.items);
    }
    try invalid("overscroll-behavior", "contain contain contain");
    try invalid("overscroll-behavior", "normal");
    try invalid("overscroll-behavior", "0");
}

test "overscroll-behavior-inline and -block map onto x and y by writing mode" {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = allocator }, "overscroll-behavior-inline", "contain", "");
    _ = try block.setProperty(.{ .allocator = allocator }, "overscroll-behavior-block", "none", "");
    const horizontal = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer horizontal.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try resolved(horizontal, "overscroll-behavior-x", &text);
    try testing.expectEqualStrings("contain", text.items);
    try resolved(horizontal, "overscroll-behavior-y", &text);
    try testing.expectEqualStrings("none", text.items);

    _ = try block.setProperty(.{ .allocator = allocator }, "writing-mode", "vertical-rl", "");
    const vertical = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer vertical.destroy();
    try resolved(vertical, "overscroll-behavior-x", &text);
    try testing.expectEqualStrings("none", text.items);
    try resolved(vertical, "overscroll-behavior-y", &text);
    try testing.expectEqualStrings("contain", text.items);
    try resolved(vertical, "overscroll-behavior-inline", &text);
    try testing.expectEqualStrings("contain", text.items);
}

test "color-adjust is a shorthand of print-color-adjust" {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "color-adjust", "exact", ""));
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue("print-color-adjust", &text);
    try testing.expectEqualStrings("exact", text.items);
    text.clearRetainingCapacity();
    try block.getPropertyValue("color-adjust", &text);
    try testing.expectEqualStrings("exact", text.items);
    try invalid("color-adjust", "exact economy");
    try testing.expect((try longhandOrShorthand("color-adjust")) == .shorthand);
}

test "initial values and inheritance follow each definition table" {
    const allocator = testing.allocator;
    const root = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{});
    defer root.destroy();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    const initials = .{
        .{ "isolation", "auto" },               .{ "mix-blend-mode", "normal" },
        .{ "background-blend-mode", "normal" }, .{ "clear", "none" },
        .{ "print-color-adjust", "economy" },   .{ "forced-color-adjust", "auto" },
        .{ "clip-rule", "nonzero" },            .{ "overscroll-behavior-x", "auto" },
        .{ "overscroll-behavior-y", "auto" },   .{ "overlay", "none" },
        .{ "ruby-position", "alternate" },      .{ "ruby-align", "space-around" },
        .{ "ruby-overhang", "auto" },           .{ "overflow-anchor", "auto" },
        .{ "scroll-behavior", "auto" },         .{ "color-interpolation-filters", "linearrgb" },
        .{ "frame-sizing", "auto" },            .{ "text-combine-upright", "none" },
    };
    inline for (initials) |case| {
        try resolved(root, case[0], &text);
        try testing.expectEqualStrings(case[1], text.items);
    }

    // A parent sets every one; the child inherits exactly the inherited ones.
    const settings = .{
        .{ "isolation", "isolate", false },            .{ "mix-blend-mode", "multiply", false },
        .{ "background-blend-mode", "screen", false }, .{ "clear", "both", false },
        .{ "print-color-adjust", "exact", true },      .{ "forced-color-adjust", "none", true },
        .{ "clip-rule", "evenodd", true },             .{ "overscroll-behavior-x", "contain", false },
        .{ "ruby-position", "under", true },           .{ "ruby-align", "center", true },
        .{ "ruby-overhang", "spaces", true },          .{ "overflow-anchor", "none", false },
        .{ "scroll-behavior", "smooth", false },       .{ "color-interpolation-filters", "srgb", true },
        .{ "frame-sizing", "content-width", false },   .{ "text-combine-upright", "all", true },
    };
    var block = Block.init(allocator);
    defer block.deinit();
    inline for (settings) |case| try testing.expect(try block.setProperty(.{ .allocator = allocator }, case[0], case[1], ""));
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    inline for (settings) |case| {
        try testing.expectEqual(case[2], (try longhandOf(case[0])).inherited());
        try resolved(parent, case[0], &text);
        try testing.expectEqualStrings(case[1], text.items);
        try resolved(child, case[0], &text);
        if (case[2]) try testing.expectEqualStrings(case[1], text.items) else try testing.expect(!std.mem.eql(u8, case[1], text.items));
    }
}

fn overlayWith(declaration: []const u8, origin: css.cascade.Origin, important: bool, out: *std.ArrayList(u8)) !void {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    // overlay is a valid declaration for every origin (overlay-valid.html):
    // only the cascade keeps it from applying.
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "overlay", declaration, if (important) "important" else ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = origin } }});
    defer style.destroy();
    try resolved(style, "overlay", out);
}

test "overlay: only the UA's important declarations and transitions set it" {
    // Position 4 §3.4: "User agents must have the following rule in their UA
    // stylesheet: * { overlay: none !important; }" - so no author, user or
    // animation declaration ever wins, and only a UA !important rule (the
    // top layer's `overlay: auto`) or the transition origin above it does.
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try overlayWith("auto", .author, false, &text);
    try testing.expectEqualStrings("none", text.items);
    try overlayWith("auto", .author, true, &text);
    try testing.expectEqualStrings("none", text.items);
    try overlayWith("auto", .user, true, &text);
    try testing.expectEqualStrings("none", text.items);
    try overlayWith("auto", .animation, false, &text);
    try testing.expectEqualStrings("none", text.items);
    try overlayWith("auto", .user_agent, false, &text);
    try testing.expectEqualStrings("none", text.items);
    try overlayWith("auto", .user_agent, true, &text);
    try testing.expectEqualStrings("auto", text.items);
    try overlayWith("auto", .transition, false, &text);
    try testing.expectEqualStrings("auto", text.items);
    try overlayWith("inherit", .author, false, &text);
    try testing.expectEqualStrings("none", text.items);
}

test "animation types: overlay steps like visibility; three are not animatable" {
    const interpolation = css.interpolation;
    const Value = css.style_values.Value;
    const allocator = testing.allocator;
    const none = Value.kw(.none);
    const auto = Value.kw(.auto);
    // Position 4 §3.4: "auto is interpolated as a discrete step where values
    // of p such that 0 < p < 1 map to auto and other values of p map to the
    // closer endpoint".
    try testing.expectEqual(interpolation.AnimationType.visibility, interpolation.animationType(try longhandOf("overlay")));
    const cases = .{ .{ none, auto, 0.1, auto }, .{ auto, none, 0.9, auto }, .{ none, auto, 0, none }, .{ auto, none, 1, none } };
    inline for (cases) |case| {
        const v = try interpolation.interpolate(allocator, try longhandOf("overlay"), case[0], case[1], case[2]);
        defer v.release();
        try testing.expect(v.eql(case[3]));
    }
    try testing.expect(try interpolation.transitionable(allocator, try longhandOf("overlay"), none, auto));
    // Color Adjust 1 §4, Overflow 3 §5 and Writing Modes 4 §9.1.
    for ([_][]const u8{ "forced-color-adjust", "scroll-behavior", "text-combine-upright" }) |name|
        try testing.expectEqual(interpolation.AnimationType.not_animatable, interpolation.animationType(try longhandOf(name)));
    for ([_][]const u8{ "isolation", "mix-blend-mode", "clear", "clip-rule", "ruby-position", "frame-sizing" }) |name|
        try testing.expect(!try interpolation.transitionable(allocator, try longhandOf(name), Value.kw(.auto), Value.kw(.none)));
}
