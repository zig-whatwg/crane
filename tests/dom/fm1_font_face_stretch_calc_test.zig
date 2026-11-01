//! Fonts 4 §4.4/§4.4.1 and Values 4 §10.12–§10.13: specified stretch math.
const std = @import("std");
const fonts = @import("dom").style.engine.resource_loading.font_loading;
const Allocator = std.mem.Allocator;
const testing = std.testing;

fn descriptor(allocator: Allocator, kind: fonts.Descriptor, input: []const u8, expected: ?[]const u8) !void {
    const actual = try fonts.parseDescriptor(allocator, kind, input);
    defer if (actual) |text| allocator.free(text);
    if (expected) |text| {
        try testing.expect(actual != null);
        try testing.expectEqualStrings(text, actual.?);
    } else try testing.expect(actual == null);
}

const Case = struct { input: []const u8, expected: []const u8 };
const calculations = [_]Case{
    .{ .input = "calc(0% - 10%)", .expected = "calc(-10%)" },
    .{ .input = "calc(-10%) calc(80%)", .expected = "calc(-10%) calc(80%)" },
    .{ .input = "calc(80%) calc(-10%)", .expected = "calc(80%) calc(-10%)" },
    .{ .input = "calc(50%) 50%", .expected = "calc(50%) 50%" },
    .{ .input = "50% calc(50%)", .expected = "50% calc(50%)" },
    .{ .input = "calc(50%) calc(50%)", .expected = "calc(50%)" },
    .{ .input = "calc(25% + 25%) calc(50%)", .expected = "calc(50%)" },
    .{ .input = "calc(100%) normal", .expected = "calc(100%) normal" },
    .{ .input = "CALC(0% - 10%)/**/calc(80%)", .expected = "calc(-10%) calc(80%)" },
    .{ .input = "calc(50% + 25% * sign(100em - 1px))", .expected = "calc(50% + (25% * sign(100em - 1px)))" },
};

fn specifiedCalculations(allocator: Allocator) !void {
    // Q62: Gecko font_face.rs impl_range!/FontWidthRange serializes the
    // second endpoint only when specified endpoints differ. Percentage's
    // NumericUnion PartialEq keeps literal and calculation arms distinct;
    // parse_with_clamping_mode records math bounds, while sort_range is
    // compute-only. Use native coverage for this engine-source ruling.
    for (calculations) |case| try descriptor(allocator, .stretch, case.input, case.expected);
}

test "FontFace stretch math keeps specified bounds and compares simplified endpoints" {
    try testing.checkAllAllocationFailures(testing.allocator, specifiedCalculations, .{});
}

fn existingControls(allocator: Allocator) !void {
    try descriptor(allocator, .stretch, "50% 50%", "50%");
    try descriptor(allocator, .stretch, "80% 50%", "80% 50%");
    try descriptor(allocator, .stretch, "normal 100%", "normal");
    try descriptor(allocator, .stretch, "0%", "0%");
    try descriptor(allocator, .stretch, "auto", "auto");
    for ([_][]const u8{
        "-0.5%",                         "-1%",                "-60% 80%",  "50% -1%",       "calc(50%) -1%",
        "calc(50%) calc(60%) calc(70%)", "calc(50%) trailing", "calc(1px)", "calc(50% + 1)", "calc()",
        "50%, 80%",                      "auto calc(50%)",
    }) |input| try descriptor(allocator, .stretch, input, null);
    // Q62 explicitly keeps the other shared numeric-descriptor branches
    // unchanged. Their literal forms still work and these math forms reject.
    try descriptor(allocator, .weight, "500", "500");
    try descriptor(allocator, .weight, "calc(500)", null);
    try descriptor(allocator, .style, "oblique 10deg", "oblique 10deg");
    try descriptor(allocator, .style, "oblique calc(10deg)", null);
}

test "FontFace stretch literal bounds and other numeric descriptors stay unchanged" {
    try testing.checkAllAllocationFailures(testing.allocator, existingControls, .{});
}

fn descriptorMutation(allocator: Allocator) !void {
    var block = blk: {
        const source = try allocator.dupe(u8, "font-family: Calc Face; font-stretch: calc(0% - 10%) calc(80%); font-weight: 400");
        defer allocator.free(source);
        break :blk try fonts.descriptorBlock(allocator, source);
    };
    defer block.deinit();
    try testing.expectEqualStrings("calc(-10%) calc(80%)", fonts.descriptorValue(&block, "font-stretch"));
    try testing.expectEqualStrings("calc(-10%) calc(80%)", fonts.descriptorValue(&block, "font-width"));
    try testing.expect(try fonts.setDescriptor(&block, "font-width", "calc(25% + 25%) calc(50%)", ""));
    try testing.expectEqualStrings("calc(50%)", fonts.descriptorValue(&block, "font-stretch"));
    try testing.expect(!try fonts.setDescriptor(&block, "font-stretch", "calc(50%) -1%", ""));
    try testing.expectEqualStrings("calc(50%)", fonts.descriptorValue(&block, "font-stretch"));
    try testing.expect(!try fonts.setDescriptor(&block, "font-stretch", "calc(80%)", "important"));
    try testing.expectEqualStrings("calc(50%)", fonts.descriptorValue(&block, "font-stretch"));
    try testing.expect(try fonts.setDescriptor(&block, "font-stretch", "calc(50%) 50%", ""));
    try testing.expectEqualStrings("calc(50%) 50%", fonts.descriptorValue(&block, "font-stretch"));
    try testing.expect(try fonts.setDescriptor(&block, "font-stretch", "", ""));
    try testing.expectEqualStrings("", fonts.descriptorValue(&block, "font-width"));
    try testing.expectEqualStrings("400", fonts.descriptorValue(&block, "font-weight"));
}

test "FontFace stretch descriptor blocks own math strings and preserve rejected mutations" {
    try testing.checkAllAllocationFailures(testing.allocator, descriptorMutation, .{});
}
