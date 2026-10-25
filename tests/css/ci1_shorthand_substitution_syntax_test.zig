//! Q211 item 1: declaration-value rejection precedes raw shorthand mutation.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Block = css.declarations.DeclarationBlock;

fn expectValue(allocator: std.mem.Allocator, block: *const Block, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

fn expectText(allocator: std.mem.Allocator, block: *const Block, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings(expected, out.items);
}

const margin_names = [_][]const u8{ "margin", "margin-top", "margin-right", "margin-bottom", "margin-left" };

// Every snapshot owns its values and cssText, including on partial OOM.
const Snapshot = struct {
    values: [margin_names.len][]u8,
    priorities: [margin_names.len]bool,
    text: []u8,
    length: usize,

    fn capture(allocator: std.mem.Allocator, block: *const Block) !Snapshot {
        var values: [margin_names.len][]u8 = undefined;
        var priorities: [margin_names.len]bool = undefined;
        var initialized: usize = 0;
        errdefer for (values[0..initialized]) |owned| allocator.free(owned);
        for (margin_names, 0..) |name, i| {
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(allocator);
            try block.getPropertyValue(name, &out);
            values[i] = try allocator.dupe(u8, out.items);
            initialized += 1;
            priorities[i] = block.getPropertyPriority(name);
        }
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(allocator);
        try block.serialize(&text);
        return .{ .values = values, .priorities = priorities, .text = try allocator.dupe(u8, text.items), .length = block.length() };
    }

    fn deinit(self: Snapshot, allocator: std.mem.Allocator) void {
        for (self.values) |owned| allocator.free(owned);
        allocator.free(self.text);
    }

    fn expectEqual(self: Snapshot, other: Snapshot) !void {
        for (self.values, other.values) |before, after| try testing.expectEqualStrings(before, after);
        try testing.expectEqualSlices(bool, &self.priorities, &other.priorities);
        try testing.expectEqualStrings(self.text, other.text);
        try testing.expectEqual(self.length, other.length);
    }
};

fn invalidSetter(allocator: std.mem.Allocator, invalid: []const u8, raw_prior: bool) !void {
    // Both prior priorities are covered within each separately named group.
    for ([_]bool{ false, true }) |important| {
        const old_value = if (raw_prior) "var(--old)" else "7px";
        const input = try std.fmt.allocPrint(allocator, "margin: {s}{s};", .{ old_value, if (important) " !important" else "" });
        defer allocator.free(input);
        var block = try Block.parse(.{ .allocator = allocator }, input);
        defer block.deinit();
        try expectValue(allocator, &block, "margin", old_value);
        try testing.expectEqual(important, block.getPropertyPriority("margin"));
        for (margin_names[1..]) |name| {
            try expectValue(allocator, &block, name, if (raw_prior) "" else "7px");
            try testing.expectEqual(!raw_prior and important, block.getPropertyPriority(name));
        }
        const before = try Snapshot.capture(allocator, &block);
        defer before.deinit(allocator);
        try testing.expect(!try block.setProperty(.{ .allocator = allocator }, "margin", invalid, ""));
        const after = try Snapshot.capture(allocator, &block);
        defer after.deinit(allocator);
        try before.expectEqual(after);
    }
}

fn invalidParsed(allocator: std.mem.Allocator, invalid: []const u8) !void {
    const input = try std.fmt.allocPrint(allocator, "margin-left: 7px; margin: {s};", .{invalid});
    defer allocator.free(input);
    var block = try Block.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    try expectValue(allocator, &block, "margin-left", "7px");
    for (margin_names[0..4]) |name| try expectValue(allocator, &block, name, "");
    for (margin_names) |name| try testing.expect(!block.getPropertyPriority(name));
    try testing.expectEqual(@as(usize, 1), block.length());
    try testing.expectEqualStrings("margin-left", block.item(0).?);
    try expectText(allocator, &block, "margin-left: 7px;");
}

fn nestedControl(allocator: std.mem.Allocator) !void {
    const raw = "calc(var(--x) + 1px) 2px";
    var parsed = try Block.parse(.{ .allocator = allocator }, "margin: calc(var(--x) + 1px) 2px;");
    defer parsed.deinit();
    var assigned = Block.init(allocator);
    defer assigned.deinit();
    try testing.expect(try assigned.setProperty(.{ .allocator = allocator }, "margin", raw, ""));
    for ([_]*const Block{ &parsed, &assigned }) |block| {
        try expectValue(allocator, block, "margin", raw);
        for (margin_names[1..]) |name| try expectValue(allocator, block, name, "");
        for (margin_names) |name| try testing.expect(!block.getPropertyPriority(name));
        try testing.expectEqual(@as(usize, 1), block.length());
        try testing.expectEqualStrings("margin", block.item(0).?);
        try expectText(allocator, block, "margin: calc(var(--x) + 1px) 2px;");
    }
}

test "Q211 top-level important preserves prior typed margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x) !important", false });
}

test "Q211 top-level important preserves prior raw margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x) !important", true });
}

test "Q211 top-level semicolon suffix preserves prior typed margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x); color: red", false });
}

test "Q211 top-level semicolon suffix preserves prior raw margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x); color: red", true });
}

test "Q211 unmatched parenthesis preserves prior typed margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x))", false });
}

test "Q211 unmatched parenthesis preserves prior raw margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x))", true });
}

test "Q211 unmatched square closer preserves prior typed margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x)]", false });
}

test "Q211 unmatched square closer preserves prior raw margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x)]", true });
}

test "Q211 unmatched curly closer preserves prior typed margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x)}", false });
}

test "Q211 unmatched curly closer preserves prior raw margin and priorities" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidSetter, .{ "var(--x)}", true });
}

test "Q211 parsed unmatched closer drops raw margin and preserves typed left" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidParsed, .{"var(--x) ]"});
}

test "Q211 parsed stray bang drops raw margin and preserves typed left" {
    try testing.checkAllAllocationFailures(testing.allocator, invalidParsed, .{"var(--x) ! foo"});
}

test "Q211 matched nested closer retains raw margin in parse and setter" {
    try testing.checkAllAllocationFailures(testing.allocator, nestedControl, .{});
}
