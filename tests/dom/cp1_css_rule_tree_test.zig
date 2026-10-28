//! CSS Conditional 5: an owned, inert container rule tree.
const std = @import("std");
const dom = @import("dom");
const a = std.testing.allocator;

fn containers(allocator: std.mem.Allocator) !void {
    const record = try dom.style.SheetRecord.create(allocator, "@container Name (widTH>=10PX), style(--flag) { .child { color: green } }", .{});
    defer record.unref();
    const list = try record.rulesWith(.{ .allocator = allocator });
    try std.testing.expectEqual(@as(usize, 1), list.items.len);
    const rule = list.items[0];
    try std.testing.expectEqualStrings("container", @tagName(rule.kind()));
    try std.testing.expectEqual(@as(usize, 1), rule.children().?.items.len);
    try std.testing.expectEqualStrings("Name (width >= 10px), style(--flag)", rule.prelude);
    const compiled = try record.contentsOf(.{ .allocator = allocator });
    // Preservation pin: no layout-backed container evaluator is installed.
    // Parsing the rule must not make its conditional children unconditional.
    try std.testing.expectEqual(@as(usize, 0), compiled.rules.items.len);
}

test "container rules preserve conditions and keep unevaluated children inert" {
    errdefer std.debug.print("CP1_CONTAINER_MODEL_CASE FAIL: container rules preserve conditions and keep unevaluated children inert\n", .{});
    try containers(a);
    std.debug.print("CP1_CONTAINER_MODEL_CASE PASS: container rules preserve conditions and keep unevaluated children inert\n", .{});
}

test "container payload fits the existing font-rule payload budget" {
    errdefer std.debug.print("CP1_CONTAINER_MODEL_CASE FAIL: container payload fits the existing font-rule payload budget\n", .{});
    const Data = dom.style.rules.Data;
    if (comptime @hasField(Data, "container")) {
        try std.testing.expect(@sizeOf(@FieldType(Data, "container")) <= @sizeOf(@FieldType(Data, "font_face")));
    } else return error.MissingContainerRule;
    std.debug.print("CP1_CONTAINER_MODEL_CASE PASS: container payload fits the existing font-rule payload budget\n", .{});
}

fn groups(allocator: std.mem.Allocator) !void {
    const pairs = .{
        .{ "@media all {}", "@media all {\n}" },
        .{ "@supports (color: red) {}", "@supports (color: red) {\n}" },
        .{ "@layer named {}", "@layer named {\n}" },
        .{ "@container (width>10px) {}", "@container (width > 10px) {\n}" },
        .{ "@media all { .a { color: red } }", "@media all {\n  .a { color: red; }\n}" },
        .{ "@container FUTURE( URL(\"x\") ,  [a]) {}", "@container FUTURE( URL(\"x\") ,  [a]) {\n}" },
    };
    inline for (pairs) |pair| {
        const record = try dom.style.SheetRecord.create(allocator, pair[0], .{});
        defer record.unref();
        const list = try record.rulesWith(.{ .allocator = allocator });
        try std.testing.expectEqual(@as(usize, 1), list.items.len);
        const text = try list.items[0].serialize(allocator);
        defer allocator.free(text);
        try std.testing.expectEqualStrings(pair[1], text);
    }
}

test "empty group serialization follows browsers and nonempty indentation stays intact" {
    errdefer std.debug.print("CP1_CONTAINER_MODEL_CASE FAIL: empty group serialization follows browsers and nonempty indentation stays intact\n", .{});
    try groups(a);
    std.debug.print("CP1_CONTAINER_MODEL_CASE PASS: empty group serialization follows browsers and nonempty indentation stays intact\n", .{});
}

test "container rule construction compilation and serialization unwind every OOM" {
    errdefer std.debug.print("CP1_CONTAINER_MODEL_CASE FAIL: container rule construction compilation and serialization unwind every OOM\n", .{});
    try std.testing.checkAllAllocationFailures(a, containers, .{});
    try std.testing.checkAllAllocationFailures(a, groups, .{});
    std.debug.print("CP1_CONTAINER_MODEL_CASE PASS: container rule construction compilation and serialization unwind every OOM\n", .{});
}
