//! CSS UI4 §5.1.1 number hotspots; f extends the earlier scalar-only stage.
//! Q113 grants the pending specified payload and preserves the computed view.
//! Real declarations exercise all three dependency queries and both views.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn dependencies(allocator: std.mem.Allocator, input: []const u8, tree: bool, random: bool, metrics: bool) !void {
    const value = blk: {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "cursor", input, ""));
        const value = (block.get(.cursor) orelse return error.ExpectedCursor).value.value;
        value.retain();
        break :blk value;
    };
    defer value.release();
    try testing.expectEqual(tree, value.needsTreeCounts());
    try testing.expectEqual(random, value.needsRandomBase());
    try testing.expectEqual(metrics, value.needsUnavailableMetrics(false));
    // A number-valued hotspot is not geometry, even on a geometry property.
    try testing.expectEqual(metrics, value.needsUnavailableMetrics(true));
}

test "actual typed hotspot declarations retain every numeric dependency" {
    for ([_][]const u8{ "url(a) calc(1) 2, pointer", "url(a) 1 calc(2 + 0), pointer", "url(a) random(fixed 0.5, 0, 2) 2, pointer" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ input, false, false, false });
    for ([_][]const u8{ "url(a) calc(sibling-index()) 2, pointer", "url(a) 1 calc(sibling-count()), pointer" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ input, true, false, false });
    for ([_][]const u8{ "url(a) random(0, 2) 2, pointer", "url(a) 1 random(0, 2), pointer" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ input, false, true, false });
    for ([_][]const u8{ "url(a) calc(1cap / 1px) 2, pointer", "url(a) 1 calc(1cap / 1px), pointer" }) |input|
        try testing.checkAllAllocationFailures(testing.allocator, dependencies, .{ input, false, false, true });
}

const Counts = struct {
    calls: usize = 0,
    fn get(raw: *anyopaque) css.math_values.TreeCounts {
        const self: *Counts = @ptrCast(@alignCast(raw));
        self.calls += 1;
        return .{ .index = 3, .count = 7 };
    }
};

fn winningSource(allocator: std.mem.Allocator, allowed: bool) !void {
    var counts: Counts = .{};
    const child = blk: {
        var user = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "cursor:url(a) calc(sibling-index()) calc(sibling-count()), pointer");
        defer user.deinit();
        try testing.expect(user.get(.cursor) != null);
        var author = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "cursor:revert");
        defer author.deinit();
        const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .tree_counts = .{ .context = &counts, .get = Counts.get } }, &.{
            .{ .block = &user, .source = .{ .origin = .user, .tree_scope = .{ .serial = 71 }, .tree_count_allowed = allowed } },
            .{ .block = &author, .source = .{ .origin = .author, .tree_scope = .{ .serial = 999 }, .tree_count_allowed = !allowed } },
        });
        defer parent.destroy();
        var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "cursor:inherit");
        defer inherited.deinit();
        break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherited, .source = .{ .origin = .author, .tree_scope = .{ .serial = 1234 }, .tree_count_allowed = !allowed } }});
    };
    defer child.destroy();
    try testing.expectEqual(@as(usize, if (allowed) 1 else 0), counts.calls);
    const value = child.get(.cursor);
    try testing.expect(value == .cursor);
    const Candidate = @TypeOf(value.cursor.candidates[0]);
    if (comptime !@hasField(Candidate, "hotspot_values")) return error.TypedHotspotNotImplemented;
    try testing.expect(value.cursor.candidates[0].hotspot_values == null);
    // Row117's computed numeric contract remains usable after all owners die.
    const hotspot = value.cursor.candidates[0].hotspot orelse return error.ExpectedComputedHotspot;
    try testing.expectEqual(@as(f64, if (allowed) 3 else 0), hotspot[0]);
    try testing.expectEqual(@as(f64, if (allowed) 7 else 0), hotspot[1]);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try child.serializeResolved(.cursor, &out, allocator);
    try testing.expectEqualStrings(if (allowed) "url(\"a\") 3 7, pointer" else "url(\"a\") 0 0, pointer", out.items);
}

test "cursor hotspots compute with the actual winning source and inherit after source release" {
    try testing.checkAllAllocationFailures(testing.allocator, winningSource, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, winningSource, .{true});
}

fn missingRandom(allocator: std.mem.Allocator, fixed: bool) !void {
    var lower = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "cursor:crosshair");
    defer lower.deinit();
    var higher = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, if (fixed) "cursor:url(a) random(fixed 0.5, 0, 2) 2, pointer" else "cursor:url(a) random(0, 2) 2, pointer");
    defer higher.deinit();
    try testing.expect(higher.get(.cursor) != null);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{
        .{ .block = &lower, .source = .{ .origin = .user } },
        .{ .block = &higher, .source = .{ .origin = .author } },
    });
    defer style.destroy();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try style.serializeResolved(.cursor, &out, allocator);
    try testing.expectEqualStrings(if (fixed) "url(\"a\") 1 2, pointer" else "crosshair", out.items);
}

test "unavailable random hotspot skips the candidate while fixed random computes" {
    try testing.checkAllAllocationFailures(testing.allocator, missingRandom, .{false});
    try testing.checkAllAllocationFailures(testing.allocator, missingRandom, .{true});
}

test "cursor hotspot math does not admit dimensions percentages or a single coordinate" {
    for ([_][]const u8{ "url(a) calc(1px) 2, pointer", "url(a) calc(1%) 2, pointer", "url(a) calc(1deg) 2, pointer", "url(a) calc(1), pointer" }) |input| {
        var block = css.declarations.DeclarationBlock.init(testing.allocator);
        defer block.deinit();
        try testing.expect(!try block.setProperty(.{ .allocator = testing.allocator }, "cursor", input, ""));
        try testing.expect(block.get(.cursor) == null);
    }
}

fn viewStates(allocator: std.mem.Allocator) !void {
    for ([_][]const u8{ "url(a), copy", "url(a) 1.5 -2.9, copy", "url(a) 1 calc(2 + 0), copy" }, 0..) |input, index| {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "cursor", input, ""));
        const value = (block.get(.cursor) orelse return error.ExpectedCursor).value.value;
        const candidate = value.cursor.candidates[0];
        if (comptime !@hasDecl(@TypeOf(candidate), "hotspotView")) return error.HotspotViewNotImplemented;
        const view = candidate.hotspotView();
        switch (index) {
            0 => {
                try testing.expect(view == .none);
                try testing.expect(candidate.hotspot == null and candidate.hotspot_values == null);
            },
            1 => {
                try testing.expect(view == .numeric);
                try testing.expectEqual([2]f64{ 1.5, -2.9 }, view.numeric);
                try testing.expect(candidate.hotspot_values == null);
            },
            2 => {
                try testing.expect(view == .pending);
                try testing.expect(candidate.hotspot == null and candidate.hotspot_values != null);
                var output: std.ArrayList(u8) = .empty;
                defer output.deinit(allocator);
                try block.getPropertyValue("cursor", &output);
                // One of cursor-valid.html's explicit specified forms.
                try testing.expectEqualStrings("url(\"a\") 1 calc(2), copy", output.items);
            },
            else => unreachable,
        }
    }
}

test "one hotspot accessor distinguishes absent literal and pending specified values" {
    try testing.checkAllAllocationFailures(testing.allocator, viewStates, .{});
}

fn stageComputed(allocator: std.mem.Allocator) !void {
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "cursor:url(a.cur) calc(1) 2, pointer");
    defer block.deinit();
    try testing.expect(block.get(.cursor) != null);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try style.serializeResolved(.cursor, &output, allocator);
    try testing.expectEqualStrings("url(\"a.cur\") 1 2, pointer", output.items);
}

test "Q113 former scalar-stage rejection computes its exact numeric hotspot" {
    try testing.checkAllAllocationFailures(testing.allocator, stageComputed, .{});
}
