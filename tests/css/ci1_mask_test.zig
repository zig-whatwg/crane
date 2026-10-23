//! Masking §§7–8: owned layers, shorthand resets and computed lists.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectText(name: []const u8, input: []const u8, expected: ?[]const u8, computed: bool) !void {
    const p = css.properties.lookup(name) orelse return error.MaskNotImplemented;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, p, input, &assignments));
    if (expected) |text| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-size:20px");
        defer block.deinit();
        try block.entries.ensureUnusedCapacity(testing.allocator, assignments.items.len);
        for (assignments.items) |a| {
            a.value.retain();
            block.entries.appendAssumeCapacity(.{ .typed = .{ .longhand = a.longhand, .value = a.value, .important = false } });
        }
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        if (computed) {
            const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
            defer style.destroy();
            switch (p) {
                .longhand => |l| try style.serializeResolved(l, &out, testing.allocator),
                .shorthand => |s| {
                    var vs: [css.properties.max_assignments]css.properties.Assigned = undefined;
                    for (s.longhands(), 0..) |l, i| vs[i] = .{ .value = style.get(l) };
                    try testing.expect(try css.properties.serializeShorthand(s, vs[0..s.longhands().len], .computed, &out, testing.allocator));
                },
            }
        } else try block.getPropertyValue(name, &out);
        try testing.expectEqualStrings(text, out.items);
    }
}

test "mask shorthand canonicalizes independent layers and resets all mask border longhands" {
    try expectText("mask", "border-box border-box", "none", false);
    try expectText("mask", "border-box no-clip", "no-clip", false);
    try expectText("mask", "none alpha", "alpha", false);
    try expectText("mask", "intersect no-clip space round 1px 2px / contain view-box, stroke-box url(a.svg#m) luminance", "1px 2px / contain space round view-box no-clip intersect, url(\"a.svg#m\") stroke-box luminance", false);
    try expectText("mask", "url(a) right 1em bottom 2em / 3em auto no-repeat", "url(\"a\") calc(100% - 20px) calc(100% - 40px) / 60px auto no-repeat", true);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "mask-border-source:url(old);mask-border-slice:5 fill;mask-border-width:4;mask-border-outset:3;mask-border-repeat:round;mask:none,none");
    defer block.deinit();
    const names = .{ "mask-border-source", "mask-border-slice", "mask-border-width", "mask-border-outset", "mask-border-repeat" };
    const expected = .{ "none", "0", "auto", "0", "stretch" };
    inline for (names, expected) |name, value| {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.getPropertyValue(name, &out);
        try testing.expectEqualStrings(value, out.items);
    }
    for ([_][]const u8{ "", "none,", ",none", "none url(a)", "alpha luminance", "1px 2px 3px", "1px 2px / cover / contain", "repeat-x repeat-y", "no-clip content-box border-box", "margin-box", "add intersect" }) |bad| try expectText("mask", bad, null, false);
}

test "mask longhand grammar and computed lengths preserve independent authored lists" {
    if (comptime @hasDecl(css, "image_layers")) return layerChecks();
    return error.MaskNotImplemented;
}

fn layerChecks() !void {
    try expectText("mask-size", "1em, cover, auto 2em", "20px auto, cover, auto 40px", true);
    try expectText("mask-position", "right 1em bottom 10%, left", "calc(100% - 20px) 90%, 0% 50%", true);
    try expectText("mask-repeat", "repeat no-repeat, no-repeat repeat, round round", "repeat-x, repeat-y, round", false);
    try expectText("mask-border-slice", "1 2% 1 2% fill", "1 2% fill", false);
    try expectText("mask-border-width", "1em auto 2 3%", "20px auto 2 3%", true);
    try expectText("mask-border-outset", "2 1em", "2 20px", true);
    try expectText("mask-border-repeat", "space stretch", "space stretch", false);
    try expectText("mask-size", "-1px", null, false);
    try expectText("mask-border-slice", "-1", null, false);
    try expectText("mask-border-outset", "1%", null, false);
    try expectText("mask-origin", "no-clip", null, false);
    try expectText("mask-clip", "no-clip, content-box", "no-clip, content-box", false);
    // Values4 Appendix A, csswg-drafts#12791; WebKit 314242@main;
    // WPT 1203773547: computed lists never expand/truncate to image count.
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "mask-image:none,none;mask-size:100%;mask-repeat:space,round,no-repeat");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const image = style.get(css.properties.lookup("mask-image").?.longhand);
    const size = style.get(css.properties.lookup("mask-size").?.longhand);
    const repeat = style.get(css.properties.lookup("mask-repeat").?.longhand);
    try testing.expectEqual(@as(usize, 2), css.image_layers.count(image));
    try testing.expectEqual(@as(usize, 1), css.image_layers.count(size));
    try testing.expectEqual(@as(usize, 3), css.image_layers.count(repeat));
    try testing.expect(css.image_layers.atUsed(size, 0).eql(css.image_layers.atUsed(size, 1)));
    // Callers iterate only images: the third repeat entry creates no layer.
    for (0..css.image_layers.count(image)) |i| try testing.expect(!css.image_layers.atUsed(repeat, i).eql(css.image_layers.at(repeat, 2)));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue("mask", &out);
    try testing.expectEqualStrings("", out.items);
}
