//! Font Loading3 §3.1: shorthand input, ordered families and Unicode coverage.
const std = @import("std");
const dom = @import("dom");
const fonts = dom.style.engine.resource_loading.font_loading;
const testing = std.testing;

fn match(allocator: std.mem.Allocator, font: []const u8, text: []const u8) anyerror!?fonts.FamilyMatch {
    return fonts.matchFontForText(.{ .allocator = allocator }, &faces, font, text);
}

const faces = [_]fonts.FamilyFace{
    .{ .family = "Second" },
    .{ .family = "First", .matching = .{ .weight = .{ .first = 700, .last = 700 } }, .ranges = &.{.{ .first = 'A', .last = 'A' }} },
    .{ .family = "First", .ranges = &.{.{ .first = 'A', .last = 'A' }} },
    .{ .family = "First", .ranges = &.{.{ .first = 'B', .last = 'B' }} },
    .{ .family = "serif" },
};

fn check(allocator: std.mem.Allocator, font: []const u8, text: []const u8, indices: []const usize, found: bool) !void {
    const result = (try match(allocator, font, text)) orelse return error.ExpectedFont;
    defer allocator.free(result.indices);
    try testing.expectEqualSlices(usize, indices, result.indices);
    try testing.expectEqual(found, result.found_faces);
}

test "font loading matches every named family in order and excludes CSS generics" {
    try check(testing.allocator, "16px First, Second", "AB", &.{ 2, 3, 0 }, true);
    try check(testing.allocator, "16px Second, First", "AB", &.{ 0, 2, 3 }, true);
    // Loading 3 §3.1 steps 6/8 and Blink's FontFaceSet::load: append each
    // requested family, even a repeated one (liaison ANSWER Q24).
    try check(testing.allocator, "16px First, Second, First", "AB", &.{ 2, 3, 0, 2, 3 }, true);
    try check(testing.allocator, "bolder 2em First", "A", &.{1}, true);
    try check(testing.allocator, "16px serif", "A", &.{}, false);
    try check(testing.allocator, "16px 'serif'", "A", &.{4}, true);
    try check(testing.allocator, "16px Missing", "A", &.{}, false);
}

test "font loading selects style before filtering ranges and retains found faces for empty text" {
    try check(testing.allocator, "bold 16px First", "B", &.{}, true);
    try check(testing.allocator, "16px First", "B", &.{3}, true);
    try check(testing.allocator, "16px First", "", &.{}, true);
}

test "font loading initial matching fallback does not change unknown request values" {
    try check(testing.allocator, "calc(1cap / 1px) 16px First", "AB", &.{ 2, 3 }, true);
    try check(testing.allocator, "oblique calc(1cap / 1px * 1deg) 16px First", "AB", &.{ 2, 3 }, true);
    try check(testing.allocator, "calc(1cap) First", "AB", &.{ 2, 3 }, true);
    try check(testing.allocator, "16px/calc(1cap) First", "AB", &.{ 2, 3 }, true);
}

fn unknownStretch(allocator: std.mem.Allocator) anyerror!void {
    const css = dom.style.css;
    const families = try css.font_family.Families.create(allocator, &.{.{ .named = .{ .name = "Width" } }});
    var request: css.font_request.FontLoadingResult = .{ .accepted_unavailable = .{
        .families = families.items,
        .owned_families = families,
        .style = .normal,
        .weight = 400,
        .stretch_pct = null,
        .size_px = 16,
        .line_height = .normal,
    } };
    defer request.deinit();
    const candidates = [_]fonts.FamilyFace{
        .{ .family = "Width", .matching = .{ .width = .{ .first = 75, .last = 75 } } },
        .{ .family = "Width" },
    };
    const selected = try fonts.matchParsedFontForText(allocator, &candidates, &request, "A");
    defer allocator.free(selected.indices);
    try testing.expectEqualSlices(usize, &.{1}, selected.indices);
    try testing.expect(selected.found_faces);
    try testing.expect(request.accepted_unavailable.stretch_pct == null);
}

test "unknown stretch uses initial width only in matching and stays unknown in the request" {
    try unknownStretch(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, unknownStretch, .{});
}

test "font loading rejects bad shorthand syntax and CSS-wide keywords" {
    for ([_][]const u8{ "", "not a font", "16px", "inherit", "initial", "unset", "revert", "revert-layer", "revert-rule" }) |font| {
        const result = try match(testing.allocator, font, "A");
        defer if (result) |matched| testing.allocator.free(matched.indices);
        try testing.expect(result == null);
    }
}

test "font matching releases every partially built request and result under OOM" {
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn exercise(allocator: std.mem.Allocator) !void {
            try check(allocator, "16px First, Second", "AB", &.{ 2, 3, 0 }, true);
            try check(allocator, "calc(1cap / 1px) 16px First", "AB", &.{ 2, 3 }, true);
        }
    }.exercise, .{});
}
