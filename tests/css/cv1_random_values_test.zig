//! CSS Values 5 §9: fixed draws, scoped keys and computed inheritance.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn checkComputed(text: []const u8, expected: []const u8) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try style.serializeResolved(.left, &out, testing.allocator);
    try testing.expectEqualStrings(expected, out.items);
}

test "fixed random draws use inclusive step buckets and precise maximum snapping" {
    try checkComputed("left:random(fixed .5, 0px, 100px)", "50px");
    try checkComputed("left:random(fixed .5, 0px, 100px, 3px)", "51px");
    try checkComputed("left:random(fixed 1, 0px, 100px, 33.333px)", "100px");
    try checkComputed("left:random(fixed 1, 0px, 100px, 33.3px)", "99.9px");
    try checkComputed("left:random(fixed 0, 25px, -10px)", "25px");
}

test "random exceptional arguments follow the entire range algorithm" {
    try checkComputed("left:random(fixed .25, 0px, 100px, 0px)", "25px");
    try checkComputed("left:random(fixed .25, 0px, 100px, -2px)", "25px");
    try checkComputed("left:random(fixed .25, 0px, 100px, infinity * 1px)", "0px");
    try checkComputed("left:random(fixed .25, 0px, infinity * 1px)", "0px");
    try checkComputed("left:random(fixed .25, NaN * 1px, 100px)", "0px");
}

test "random key normalization happens before shorthand expansion" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin:random(1px,2px) random(property-scoped,3px,4px)");
    defer block.deinit();
    const cases = .{
        .{ "margin-top", "random(element-scoped ua-margin-1, 1px, 2px)" },
        .{ "margin-bottom", "random(element-scoped ua-margin-1, 1px, 2px)" },
        .{ "margin-left", "random(ua-margin, 3px, 4px)" },
        .{ "margin-right", "random(ua-margin, 3px, 4px)" },
    };
    inline for (cases) |c| {
        var actual: std.ArrayList(u8) = .empty;
        defer actual.deinit(testing.allocator);
        try block.getPropertyValue(c[0], &actual);
        try testing.expectEqualStrings(c[1], actual.items);
    }
}

test "random numbers share only their full nullable tuple and never draw for fixed values" {
    if (comptime !@hasField(css.cascade.Context, "random_base")) return error.RandomProviderNotImplemented;
    const random = css.random_values;
    const Probe = struct {
        calls: usize = 0,
        fn get(raw: *anyopaque, key: random.CacheKey) std.mem.Allocator.Error!f64 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return random.baseValue(.{17} ** 32, key, .{ .address = 91, .generation = 3, .pseudo = null });
        }
    };
    var probe = Probe{};
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:random(--shared,0px,100px);top:random(--shared,0px,100px);right:random(fixed .5,0px,100px)");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .random_base = .{ .context = &probe, .get = Probe.get } }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try testing.expectEqual(@as(usize, 2), probe.calls);
    try testing.expectEqual(style.get(.left).length.value, style.get(.top).length.value);
    try testing.expectEqual(@as(f64, 50), style.get(.right).length.value);
    try testing.expect(style.get(.left).length.value >= 0 and style.get(.left).length.value < 100);
}

test "random hashing separates nullable fields document seeds and reused element slots" {
    if (comptime !@hasDecl(css, "random_values")) return error.RandomValuesNotImplemented;
    const random = css.random_values;
    const key = random.CacheKey{ .name = "--a", .property = "ua-left-1", .element_scoped = true };
    const element = random.Identity{ .address = 91, .generation = 3, .pseudo = null };
    const value = random.baseValue(.{17} ** 32, key, element);
    try testing.expectEqual(value, random.baseValue(.{17} ** 32, key, element));
    try testing.expect(value != random.baseValue(.{18} ** 32, key, element));
    var reused = element;
    reused.generation += 1;
    try testing.expect(value != random.baseValue(.{17} ** 32, key, reused));
    reused = element;
    reused.pseudo = "before";
    try testing.expect(value != random.baseValue(.{17} ** 32, key, reused));
    const unscoped = random.CacheKey{ .name = "--a", .property = null, .element_scoped = false };
    try testing.expectEqual(random.baseValue(.{17} ** 32, unscoped, element), random.baseValue(.{17} ** 32, unscoped, reused));
    try testing.expect(random.baseValue(.{17} ** 32, .{ .name = "--a", .property = null }, element) != random.baseValue(.{17} ** 32, .{ .name = "--a", .property = "" }, element));
}

test "random item substitutes only its selected branch and invalidates the winning declaration" {
    try checkComputed("left:7px;left:random-item(fixed 0, random-item(fixed 1,1px,2px),3px)", "2px");
    try checkComputed("left:7px;left:random-item(fixed 1, invalid,3px)", "3px");
    try checkComputed("left:7px;left:random-item(fixed 0, invalid,3px)", "auto");
    try checkComputed("left:7px;left:random-item(fixed 0, ,3px)", "auto");
}

test "random pending shorthand shares substitution while preserving later longhands" {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "margin:random-item(fixed 0,1px 2px,3px 4px);margin-left:9px");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try testing.expectEqual(@as(f64, 1), style.get(.margin_top).length.value);
    try testing.expectEqual(@as(f64, 2), style.get(.margin_right).length.value);
    try testing.expectEqual(@as(f64, 1), style.get(.margin_bottom).length.value);
    try testing.expectEqual(@as(f64, 9), style.get(.margin_left).length.value);
}

test "random trees and pending substitutions release all allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}

fn allocationFailure(allocator: std.mem.Allocator) anyerror!void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "left:random(fixed .5,1em,100px);margin:random-item(fixed 0,random(fixed .25,1px,5px) 2px,3px);top:random-item(fixed 0,invalid,random(0px,100px));bottom:random-item(fixed 1,0px,random(10px,20px))");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try testing.expect(style.get(.left) == .length);
    try testing.expectEqual(@as(f64, 58), style.get(.left).length.value);
    try testing.expect(style.get(.top).isKeyword(.auto));
    try testing.expect(style.get(.bottom).isKeyword(.auto));
}

test "every random function advances its kind's ordinal before shorthand expansion" {
    if (comptime !@hasField(css.cascade.Context, "random_base")) return error.RandomProviderNotImplemented;
    const random = css.random_values;
    const Probe = struct {
        fn get(_: *anyopaque, key: random.CacheKey) std.mem.Allocator.Error!f64 {
            return random.baseValue(.{17} ** 32, key, .{ .address = 91, .generation = 3, .pseudo = null });
        }
    };
    var unused: u8 = 0;
    var top: [5]f64 = undefined;
    var left: [5]f64 = undefined;
    // Q82's Safari27 probe: B.top == D.top == E.left; A.left differs.
    // The two-auto control additionally pins A.left == C.left (index two).
    const cases = [_][]const u8{
        "margin:random(--k,0px,0px) random(0px,1000px)", // A
        "margin:random(0px,1000px)", // B
        "margin:random(0px,1000px) random(0px,1000px)", // C
        "margin:random(0px,1000px) 1px", // D
        "margin:1px random(0px,1000px)", // E
    };
    for (cases, 0..) |text, index| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, text);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .random_base = .{ .context = &unused, .get = Probe.get } }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        top[index] = style.get(.margin_top).length.value;
        left[index] = style.get(.margin_left).length.value;
    }
    try testing.expectEqual(top[1], top[3]);
    try testing.expectEqual(top[1], left[4]);
    try testing.expectEqual(top[1], top[2]);
    try testing.expectEqual(left[0], left[2]);
    try testing.expect(left[0] != top[1]);
}

test "missing random input skips to retained candidates and inherited or initial defaults" {
    if (comptime !@hasField(css.cascade.Context, "random_base")) return error.RandomProviderNotImplemented;
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:7px");
    defer low.deinit();
    var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "font-weight:600");
    defer parent_block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:random(10px,20px);top:random(10px,20px);font-weight:random(100,900);opacity:random(0,1);right:random(fixed .5,10px,20px)");
    defer high.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent }, &.{
        .{ .block = &low, .source = .{ .origin = .author, .order = 1 } },
        .{ .block = &high, .source = .{ .origin = .author, .order = 2 } },
    });
    defer style.destroy();
    try testing.expectEqual(@as(f64, 7), style.get(.left).length.value);
    try testing.expect(style.get(.top).isKeyword(.auto));
    try testing.expectEqual(@as(f64, 600), style.get(.font_weight).number);
    try testing.expectEqual(@as(f64, 1), style.get(.opacity).number);
    try testing.expectEqual(@as(f64, 15), style.get(.right).length.value);
}

test "random key normalization owns names and keeps function buckets separate only for indexed keys" {
    if (comptime !@hasDecl(css, "random_values")) return error.RandomValuesNotImplemented;
    const random = css.random_values;
    const source = random.KeySource{ .property = "margin", .index = 2, .function = .numeric };
    var item_source = source;
    item_source.function = .item;
    inline for (.{ @as(?[]const u8, null), "auto", "element-scoped property-index-scoped" }) |input| {
        const numeric = (try random.parseCacheKey(testing.allocator, input, source)).?;
        defer numeric.deinit(testing.allocator);
        const item = (try random.parseCacheKey(testing.allocator, input, item_source)).?;
        defer item.deinit(testing.allocator);
        try testing.expect(!numeric.eql(item));
        try testing.expectEqualStrings("ua-margin-2", numeric.property.?);
        try testing.expect(numeric.element_scoped);
    }
    inline for (.{ "--shared", "element-scoped", "property-scoped", "--shared property-scoped element-scoped", "ua-explicit" }) |input| {
        const numeric = (try random.parseCacheKey(testing.allocator, input, source)).?;
        defer numeric.deinit(testing.allocator);
        const item = (try random.parseCacheKey(testing.allocator, input, item_source)).?;
        defer item.deinit(testing.allocator);
        try testing.expect(numeric.eql(item));
    }
    var early = source;
    early.early = true;
    const early_key = (try random.parseCacheKey(testing.allocator, null, early)).?;
    defer early_key.deinit(testing.allocator);
    try testing.expectEqualStrings("ua-early-margin-2", early_key.property.?);
    inline for (.{ "", "fixed", "auto --x", "--x --y", "element-scoped element-scoped", "property-scoped property-index-scoped", "ua-a ua-b", "not-a-key" }) |invalid| {
        const result = try random.parseCacheKey(testing.allocator, invalid, source);
        defer if (result) |key| key.deinit(testing.allocator);
        try testing.expect(result == null);
    }
    try testing.checkAllAllocationFailures(testing.allocator, keyAllocationFailure, .{});
}

fn keyAllocationFailure(allocator: std.mem.Allocator) !void {
    const random = css.random_values;
    const original = (try random.parseCacheKey(allocator, "element-scoped --owned property-index-scoped", .{ .property = "left", .index = 3, .function = .numeric })).?;
    defer original.deinit(allocator);
    const copied = try original.clone(allocator);
    defer copied.deinit(allocator);
    try testing.expect(original.eql(copied));
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try copied.serialize(&text, allocator);
    try testing.expectEqualStrings("--owned element-scoped ua-left-3", text.items);
}

test "random substitution preflight evaluates only its selected branch" {
    // Q88: unused random tokens are not provider dependencies; a selected
    // missing provider skips, whereas invalid selected syntax wins as unset.
    if (comptime !@hasField(css.cascade.Context, "random_base")) return error.RandomProviderNotImplemented;
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:7px;top:8px;right:9px");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:random-item(fixed 0,1px,random(0px,100px));top:random-item(fixed 1,1px,random(0px,100px));right:random-item(fixed 0,invalid,random(0px,100px))");
    defer high.deinit();
    var it = high.typed();
    var count: usize = 0;
    while (it.next() != null) count += 1;
    try testing.expectEqual(@as(usize, 3), count);
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
        .{ .block = &low, .source = .{ .origin = .author, .order = 1 } },
        .{ .block = &high, .source = .{ .origin = .author, .order = 2 } },
    });
    defer style.destroy();
    try testing.expectEqual(@as(f64, 1), style.get(.left).length.value);
    try testing.expectEqual(@as(f64, 8), style.get(.top).length.value);
    try testing.expect(style.get(.right).isKeyword(.auto));
}

test "substituted revert and revert-layer select the original lower origin or layer" {
    if (comptime !@hasField(css.cascade.Context, "random_base")) return error.RandomProviderNotImplemented;
    var ua = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:3px;top:2px");
    defer ua.deinit();
    var low = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:7px;top:9px");
    defer low.deinit();
    var high = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:random-item(fixed 0,revert-layer,100px);top:random-item(fixed 0,revert,100px)");
    defer high.deinit();
    var it = high.typed();
    var count: usize = 0;
    while (it.next() != null) count += 1;
    try testing.expectEqual(@as(usize, 2), count);
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{
        .{ .block = &ua, .source = .{ .origin = .user_agent } },
        .{ .block = &low, .source = .{ .origin = .author, .layer = 0 } },
        .{ .block = &high, .source = .{ .origin = .author, .layer = 1 } },
    });
    defer style.destroy();
    try testing.expectEqual(@as(f64, 7), style.get(.left).length.value);
    try testing.expectEqual(@as(f64, 2), style.get(.top).length.value);
}

test "unresolved computed random fixes its base before inheritance" {
    if (comptime !@hasField(css.cascade.Context, "random_base")) return error.RandomProviderNotImplemented;
    const Probe = struct {
        calls: usize = 0,
        fn get(raw: *anyopaque, _: css.random_values.CacheKey) std.mem.Allocator.Error!f64 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            return if (self.calls == 1) 0.25 else 0.75;
        }
    };
    var probe = Probe{};
    var parent_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:random(element-scoped,1px,50%)");
    defer parent_block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .random_base = .{ .context = &probe, .get = Probe.get } }, &.{.{ .block = &parent_block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    try testing.expectEqual(@as(usize, 1), probe.calls);
    try testing.expect(!parent.get(.left).needsRandomBase());
    var child_block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:inherit");
    defer child_block.deinit();
    const child = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = parent, .random_base = .{ .context = &probe, .get = Probe.get } }, &.{.{ .block = &child_block, .source = .{ .origin = .author } }});
    defer child.destroy();
    try testing.expectEqual(@as(usize, 1), probe.calls);
    try testing.expectEqual(parent.get(.left).calculation, child.get(.left).calculation);
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(testing.allocator);
    try child.serializeResolved(.left, &text, testing.allocator);
    try testing.expectEqualStrings("random(fixed 0.25, 1px, 50%)", text.items);
}

test "fixed random simplifies known dimensions but preserves unresolved percentage and fixed calc syntax" {
    inline for (.{
        .{ "random(fixed .5,0px,100px)", "calc(50px)" },
        .{ "random(fixed .5,0px,100px,3px)", "calc(51px)" },
        .{ "random(fixed calc(2 / 4),0%,100%)", "random(fixed calc(0.5), 0%, 100%)" },
    }) |c| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        _ = try block.setProperty(.{ .allocator = testing.allocator }, "width", c[0], "");
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try block.getPropertyValue("width", &out);
        try testing.expectEqualStrings(c[1], out.items);
    }
}

// Append to cv1_random_values_test.zig and remove "--" from that file's
// invalid-key table before the RED. Values4§4.3 does not require a tail.
test "bare double dash is a dashed ident random key in both function kinds" {
    const random = css.random_values;
    inline for (.{ "--", "\\2d \\2d" }) |input| {
        const key = (try random.parseCacheKey(testing.allocator, input, .{ .property = "left", .index = 1, .function = .numeric })) orelse return error.BareDashedIdentRejected;
        defer key.deinit(testing.allocator);
        try testing.expectEqualStrings("--", key.name.?);
        try testing.expect(key.property == null);
    }
    const Probe = struct {
        calls: usize = 0,
        wrong_key: bool = false,
        fn get(raw: *anyopaque, key: random.CacheKey) std.mem.Allocator.Error!f64 {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.calls += 1;
            if (key.name == null or !std.mem.eql(u8, key.name.?, "--")) self.wrong_key = true;
            return 0.75;
        }
    };
    var probe = Probe{};
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, "left:random(--,0px,100px);top:random-item(--,1px,2px)");
    defer block.deinit();
    const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null, .random_base = .{ .context = &probe, .get = Probe.get } }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try testing.expectEqual(@as(f64, 75), style.get(.left).length.value);
    try testing.expectEqual(@as(f64, 2), style.get(.top).length.value);
    try testing.expectEqual(@as(usize, 2), probe.calls);
    try testing.expect(!probe.wrong_key);
}
