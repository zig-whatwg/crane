//! Lane rendering3: a keyframe as the declaration block its computed values
//! are cascaded from (Web Animations 1 5.3.3 step 2.2's conflict rules).
const std = @import("std");
const dom = @import("dom");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const keyframes = dom.animations.keyframes;

fn frameOf(allocator: Allocator, pairs: []const [2][]const u8) !keyframes.Keyframe {
    var frame: keyframes.Keyframe = .{};
    errdefer freeFrame(allocator, &frame);
    for (pairs) |pair| {
        const name = try allocator.dupe(u8, pair[0]);
        errdefer allocator.free(name);
        const value = try allocator.dupe(u8, pair[1]);
        errdefer allocator.free(value);
        try frame.properties.append(allocator, .{ .name = name, .value = value });
    }
    return frame;
}

fn freeFrame(allocator: Allocator, frame: *keyframes.Keyframe) void {
    for (frame.properties.items) |p| {
        allocator.free(p.name);
        allocator.free(p.value);
    }
    frame.properties.deinit(allocator);
}

fn expectDeclared(block: anytype, allocator: Allocator, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn conflicts(allocator: Allocator) !void {
    // Rule 1: a longhand overrides a shorthand, whatever the order written.
    // Rule 2: border-top (4 longhands... 3) overrides border-color (4).
    // Rule 4: equal counts - the earlier IDL name wins.
    var frame = try frameOf(allocator, &.{
        .{ "border-top-color", "rgb(0, 0, 255)" },
        .{ "border-top", "1px solid rgb(0, 128, 0)" },
        .{ "border-color", "rgb(255, 0, 0)" },
        .{ "margin-left", "3px" },
        .{ "margin", "1px" },
    });
    defer freeFrame(allocator, &frame);
    var block = try keyframes.declarationBlock(allocator, &frame);
    defer block.deinit();
    try expectDeclared(&block, allocator, "border-top-color", "rgb(0, 0, 255)");
    try expectDeclared(&block, allocator, "border-top-width", "1px");
    try expectDeclared(&block, allocator, "border-right-color", "rgb(255, 0, 0)");
    try expectDeclared(&block, allocator, "margin-left", "3px");
    try expectDeclared(&block, allocator, "margin-right", "1px");
    // Every declaration is normal.
    for (block.entries.items) |*entry| try testing.expect(!entry.important());
}

test "r3: keyframe conflicts resolve by 5.3.3's rules" {
    try conflicts(testing.allocator);
}

test "r3: keyframe block under every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, conflicts, .{});
}

fn physicalAfterLogical(allocator: Allocator) !void {
    // Rule 3: physical overrides logical: margin-left is declared after
    // margin-inline-start even when the margin shorthand created it first.
    var frame = try frameOf(allocator, &.{
        .{ "margin-left", "3px" },
        .{ "margin-inline-start", "2px" },
        .{ "margin", "1px" },
    });
    defer freeFrame(allocator, &frame);
    var block = try keyframes.declarationBlock(allocator, &frame);
    defer block.deinit();
    var logical: ?usize = null;
    var physical: ?usize = null;
    for (block.entries.items, 0..) |*entry, i| {
        if (std.mem.eql(u8, entry.name(), "margin-inline-start")) logical = i;
        if (std.mem.eql(u8, entry.name(), "margin-left")) physical = i;
    }
    try testing.expect(physical.? > logical.?);
}

test "r3: a physical longhand is declared after the logical one it competes with" {
    try physicalAfterLogical(testing.allocator);
}

test "r3: !important in a keyframe value is rejected, never kept" {
    try testing.expectEqual(@as(?[]u8, null), try keyframes.parsedValue(testing.allocator, "width", "10px !important"));
    const ok = (try keyframes.parsedValue(testing.allocator, "width", "10px")).?;
    defer testing.allocator.free(ok);
    try testing.expectEqualStrings("10px", ok);
}
