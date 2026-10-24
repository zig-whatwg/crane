//! Q80 final browser ruling, per case; Q86 user decision for the reset.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Case = struct { input: []const u8, specified: []const u8, computed: []const u8 };

// Probe evidence: integrator-probes-1023s/results/bgshort-chrome.json and
// integrator-probes-1023q/results/bgshort-{firefox,safari}.json.
const cases = [_]Case{
    // Cases 0-3: Chrome/Safari full expansion; Firefox minimal is outvoted.
    .{ .input = "background:red", .specified = "red", .computed = "rgb(255, 0, 0) none repeat scroll 0% 0% / auto padding-box border-box" },
    .{ .input = "background:url(\"https://example.test/a.png\")", .specified = "url(\"https://example.test/a.png\")", .computed = "rgba(0, 0, 0, 0) url(\"https://example.test/a.png\") repeat scroll 0% 0% / auto padding-box border-box" },
    .{
        .input = "background:url(\"https://example.test/a.png\") top left no-repeat, url(\"https://example.test/b.png\") center / 100% 100% fixed content-box padding-box white",
        .specified = "url(\"https://example.test/a.png\") left top no-repeat, url(\"https://example.test/b.png\") center center / 100% 100% fixed content-box padding-box white",
        .computed = "url(\"https://example.test/a.png\") no-repeat scroll 0% 0% / auto padding-box border-box, rgb(255, 255, 255) url(\"https://example.test/b.png\") repeat fixed 50% 50% / 100% 100% content-box padding-box",
    },
    .{ .input = "background:none", .specified = "none", .computed = "rgba(0, 0, 0, 0) none repeat scroll 0% 0% / auto padding-box border-box" },
    // Case 4: Firefox/Safari specified padding-box text; Chrome/Safari full
    // computed expansion. The two decisions use their respective majorities.
    .{ .input = "background:text", .specified = "padding-box text", .computed = "rgba(0, 0, 0, 0) none repeat scroll 0% 0% / auto padding-box text" },
    // Case 5 amended by Q109: wpt.fyi Chrome 156 passes the two
    // background-computed border-area/text tests; Safari 27 drops text
    // incorrectly, and Firefox does not ship border-area. Backgrounds4
    // computes the clip as specified; expand the correct longhand intact.
    .{ .input = "background:border-area text", .specified = "border-area text", .computed = "rgba(0, 0, 0, 0) none repeat scroll 0% 0% / auto border-box border-area text" },
    // Case 6: Chrome/Safari repeat the short size list in the shorthand;
    // Q119: the resolved size longhand repeats short lists to image count.
    .{ .input = "background-image:none,none;background-size:cover", .specified = "", .computed = "none repeat scroll 0% 0% / cover padding-box border-box, rgba(0, 0, 0, 0) none repeat scroll 0% 0% / cover padding-box border-box" },
    // Q119-C7 amends Q80: Chrome's image-count matching wins by mechanism;
    // Safari's comma inside one layer is a formatting defect. Longhands keep
    // both x entries (Firefox/Safari), independently of shorthand matching.
    .{ .input = "background-position-x:10px,20px;background-position-y:30px", .specified = "", .computed = "rgba(0, 0, 0, 0) none repeat scroll 10px 30px / auto padding-box border-box" },
};

fn check(allocator: Allocator, case: Case) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, case.input);
    var owned = true;
    defer if (owned) block.deinit();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue("background", &text);
    try testing.expectEqualStrings(case.specified, text.items);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    block.deinit();
    owned = false;
    const shorthand = css.properties.Shorthand.background;
    var assigned: [css.properties.Longhand.count]css.properties.Assigned = undefined;
    for (shorthand.longhands(), 0..) |longhand, i| assigned[i] = .{ .value = style.get(longhand) };
    text.clearRetainingCapacity();
    if (!try css.properties.serializeShorthand(shorthand, assigned[0..shorthand.longhands().len], .computed, &text, allocator)) text.clearRetainingCapacity();
    try testing.expectEqualStrings(case.computed, text.items);
}

test "background Q80 case 0: red expands all computed components" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[0]});
}

test "background Q80 case 1: URL expands all computed components" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[1]});
}

test "background Q80 case 2: last layer puts its color before the image" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[2]});
}

test "background Q80 case 3: none expands all computed components" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[3]});
}

test "background Q80 case 4: text uses the per-form browser majority" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[4]});
}

test "background Q80 case 5: border-area text expands the correct computed clip" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[5]});
}

test "background Q80 case 6: short size list repeats to the image count" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[6]});
}

test "background Q119 case 7: shorthand matches image count and preserves the longhands" {
    try testing.checkAllAllocationFailures(testing.allocator, check, .{cases[7]});
}

test "background computed shorthand preserves unequal underlying longhand lists" {
    for ([_]struct { input: []const u8, name: []const u8, expected: []const u8 }{
        .{ .input = cases[6].input, .name = "background-size", .expected = "cover, cover" },
        .{ .input = cases[7].input, .name = "background-position-x", .expected = "10px, 20px" },
        .{ .input = cases[5].input, .name = "background-clip", .expected = "border-area text" },
    }) |case| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, case.input);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        const longhand = (css.properties.lookup(case.name) orelse return error.BackgroundComponentNotImplemented).longhand;
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(testing.allocator);
        try style.serializeResolved(longhand, &text, testing.allocator);
        try testing.expectEqualStrings(case.expected, text.items);
    }
}

test "background omitted declared color is transparent while authored spellings stay distinct" {
    for ([_]struct { input: []const u8, expected: []const u8 }{
        .{ .input = "background:none", .expected = "transparent" },
        .{ .input = "background:border-box content-box", .expected = "transparent" },
        .{ .input = "background:border-area", .expected = "transparent" },
        .{ .input = "background:border-area text", .expected = "transparent" },
        .{ .input = "background:transparent", .expected = "transparent" },
        .{ .input = "background:rgba(0,0,0,0)", .expected = "rgba(0, 0, 0, 0)" },
    }) |case| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, case.input);
        defer block.deinit();
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(testing.allocator);
        try block.getPropertyValue("background-color", &text);
        try testing.expectEqualStrings(case.expected, text.items);
        const style = try css.cascade.cascade(.{ .allocator = testing.allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        text.clearRetainingCapacity();
        try style.serializeResolved(.background_color, &text, testing.allocator);
        try testing.expectEqualStrings("rgba(0, 0, 0, 0)", text.items);
    }
}
