//! Typed OM 1 §§3, 4.1, 6.1; liaison Q10/Q16 browser rulings.
const std = @import("std");
const css = @import("css");

test "custom property name strings are not parsed CSS identifiers" {
    if (comptime !@hasDecl(css.typed_om, "unparsed")) return std.testing.expect(false);
    for ([_][]const u8{ "--", "--a", "--a b", "--\\x", "--\n" }) |name|
        try std.testing.expect(css.typed_om.unparsed.isCustomPropertyName(name));
    for ([_][]const u8{ "", "-", "a", " --a", "-a", "\\2d-a" }) |name|
        try std.testing.expect(!css.typed_om.unparsed.isCustomPropertyName(name));
}

fn serializeGraphs(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "unparsed")) return std.testing.expect(false);
    const unparsed = css.typed_om.unparsed;
    const Reader = struct {
        nodes: []const []const unparsed.Segment,
        pub fn length(self: @This(), id: usize) !usize {
            return self.nodes[id].len;
        }
        pub fn segment(self: @This(), id: usize, index: usize) !unparsed.Segment {
            return self.nodes[id][index];
        }
        pub fn release(_: @This(), _: unparsed.Segment) void {}
    };
    const strings = [_]unparsed.Segment{ .{ .string = "lem" }, .{ .string = "on" }, .{ .string = "ade" } };
    const leaf = [_]unparsed.Segment{.{ .variable = .{ .name = "--B", .fallback = null } }};
    const variables = [_]unparsed.Segment{
        .{ .variable = .{ .name = "--a b", .fallback = 1 } },
        .{ .variable = .{ .name = "--a b", .fallback = 1 } },
    };
    const cycle = [_]unparsed.Segment{ .{ .string = "discarded" }, .{ .variable = .{ .name = "--A", .fallback = 0 } } };
    const cases = .{
        .{ Reader{ .nodes = &.{&strings} }, "lemonade" },
        .{ Reader{ .nodes = &.{ &variables, &leaf } }, "var(--a b,var(--B))var(--a b,var(--B))" },
        .{ Reader{ .nodes = &.{&cycle} }, "" },
        .{ Reader{ .nodes = &.{&.{}} }, "" },
    };
    inline for (cases) |case| {
        const text = try unparsed.serialize(allocator, 0, case[0]);
        defer allocator.free(text);
        try std.testing.expectEqualStrings(case[1], text);
    }
}

test "unparsed graph serialization releases every allocation including cyclic paths" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, serializeGraphs, .{});
}

test "deep unparsed graphs use a call-local traversal stack" {
    if (comptime !@hasDecl(css.typed_om, "unparsed")) return std.testing.expect(false);
    const unparsed = css.typed_om.unparsed;
    const Reader = struct {
        pub fn length(_: @This(), _: usize) !usize {
            return 1;
        }
        pub fn segment(_: @This(), id: usize, _: usize) !unparsed.Segment {
            return if (id == 10000) .{ .string = "leaf" } else .{ .variable = .{ .name = "--A", .fallback = id + 1 } };
        }
        pub fn release(_: @This(), _: unparsed.Segment) void {}
    };
    const text = try unparsed.serialize(std.testing.allocator, 0, Reader{});
    defer std.testing.allocator.free(text);
    try std.testing.expectEqual(@as(usize, 90004), text.len);
    try std.testing.expect(std.mem.startsWith(u8, text, "var(--A,var(--A,"));
    try std.testing.expectEqualStrings("leaf", text[80000..80004]);
}
