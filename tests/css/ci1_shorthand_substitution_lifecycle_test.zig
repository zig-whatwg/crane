//! Q206 raw shorthand lifecycle and tokenizer controls; interim seam only.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn propertyValue(allocator: std.mem.Allocator, block: *const css.declarations.DeclarationBlock, name: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue(name, &out);
    return try allocator.dupe(u8, out.items);
}

fn serialized(allocator: std.mem.Allocator, block: *const css.declarations.DeclarationBlock) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.serialize(&out);
    return try allocator.dupe(u8, out.items);
}

fn rawRawParsed(allocator: std.mem.Allocator, old_value: []const u8, new_value: []const u8, old_important: bool, new_important: bool) !void {
    const input = try std.fmt.allocPrint(allocator, "margin: {s}{s}; margin: {s}{s};", .{
        old_value,
        if (old_important) " !important" else "",
        new_value,
        if (new_important) " !important" else "",
    });
    defer allocator.free(input);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    const should_keep_old = old_important and !new_important;
    const expected = if (should_keep_old) old_value else new_value;
    const got = try propertyValue(allocator, &block, "margin");
    defer allocator.free(got);
    try testing.expectEqualStrings(expected, got);
    try testing.expectEqual(if (should_keep_old) old_important else new_important, block.getPropertyPriority("margin"));
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    try testing.expect(try block.removeProperty("margin", &removed));
    try testing.expectEqualStrings(expected, removed.items);
    try testing.expectEqual(@as(usize, 0), block.length());
}

fn rawRawSetter(allocator: std.mem.Allocator, old_value: []const u8, new_value: []const u8, old_important: bool, new_important: bool) !void {
    const input = try std.fmt.allocPrint(allocator, "margin: {s}{s};", .{ old_value, if (old_important) " !important" else "" });
    defer allocator.free(input);
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "margin", new_value, if (new_important) "important" else ""));
    const got = try propertyValue(allocator, &block, "margin");
    defer allocator.free(got);
    try testing.expectEqualStrings(new_value, got);
    try testing.expectEqual(new_important, block.getPropertyPriority("margin"));
    var removed: std.ArrayList(u8) = .empty;
    defer removed.deinit(allocator);
    try testing.expect(try block.removeProperty("margin", &removed));
    try testing.expectEqualStrings(new_value, removed.items);
    try testing.expectEqual(@as(usize, 0), block.length());
}

fn setCssTextTransfersAndReuses(allocator: std.mem.Allocator, function: []const u8) !void {
    const options: css.properties.ParseOptions = .{ .allocator = allocator };
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try block.setCssText(options, "color: red;");
    const authored = try std.fmt.allocPrint(allocator, "margin:   {s}   !important;", .{function});
    defer allocator.free(authored);
    try block.setCssText(options, authored);
    {
        const initial = try propertyValue(allocator, &block, "margin");
        defer allocator.free(initial);
        try testing.expectEqualStrings(function, initial);
    }
    try testing.expect(block.getPropertyPriority("margin"));
    try testing.expectEqual(@as(usize, 1), block.length());

    try testing.expect(try block.setProperty(options, "margin-left", "7px", ""));
    {
        const margin = try propertyValue(allocator, &block, "margin");
        defer allocator.free(margin);
        try testing.expectEqualStrings("", margin);
        const left = try propertyValue(allocator, &block, "margin-left");
        defer allocator.free(left);
        try testing.expectEqualStrings("7px", left);
        const after_longhand = try serialized(allocator, &block);
        defer allocator.free(after_longhand);
        try testing.expect(std.mem.indexOf(u8, after_longhand, function) == null);
    }

    try block.setCssText(options, "margin: 1px;");
    {
        const margin = try propertyValue(allocator, &block, "margin");
        defer allocator.free(margin);
        try testing.expectEqualStrings("1px", margin);
    }
    try testing.expectEqual(@as(usize, 4), block.length());
    try block.setCssText(options, "color: blue;");
    try testing.expectEqual(@as(usize, 1), block.length());
    try testing.expectEqualStrings("color", block.item(0).?);
    block.clear();
    try testing.expectEqual(@as(usize, 0), block.length());
    const reintroduced = try std.fmt.allocPrint(allocator, "margin: {s};", .{function});
    defer allocator.free(reintroduced);
    try block.setCssText(options, reintroduced);
    {
        const margin = try propertyValue(allocator, &block, "margin");
        defer allocator.free(margin);
        try testing.expectEqualStrings(function, margin);
    }
    try testing.expectEqual(@as(usize, 1), block.length());
}

fn tokenizerControls(allocator: std.mem.Allocator) !void {
    const options: css.properties.ParseOptions = .{ .allocator = allocator };
    for ([_][]const u8{ "VAR(--x)", "v\\61 r(--x)", "ENV(x)", "e\\6e v(x)" }) |function| {
        const input = try std.fmt.allocPrint(allocator, "margin: {s};", .{function});
        defer allocator.free(input);
        var block = try css.declarations.DeclarationBlock.parse(options, input);
        defer block.deinit();
        const got = try propertyValue(allocator, &block, "margin");
        defer allocator.free(got);
        try testing.expect(got.len != 0);
        try testing.expectEqual(@as(usize, 1), block.length());
        try testing.expectEqualStrings("margin", block.item(0).?);
    }

    for ([_][]const u8{ "/* var(--x) */ 1px", "/* env(x) */ 1px" }) |value| {
        const input = try std.fmt.allocPrint(allocator, "margin: {s};", .{value});
        defer allocator.free(input);
        var block = try css.declarations.DeclarationBlock.parse(options, input);
        defer block.deinit();
        const got = try propertyValue(allocator, &block, "margin");
        defer allocator.free(got);
        try testing.expectEqualStrings("1px", got);
        try testing.expectEqual(@as(usize, 4), block.length());
    }

    for ([_][]const u8{ "\"var(--x)\"", "\"env(x)\"" }) |value| {
        const input = try std.fmt.allocPrint(allocator, "margin: {s};", .{value});
        defer allocator.free(input);
        var block = try css.declarations.DeclarationBlock.parse(options, input);
        defer block.deinit();
        try testing.expectEqual(@as(usize, 0), block.length());
    }
}

fn badTokensPreserveExisting(allocator: std.mem.Allocator) !void {
    for ([_][]const u8{
        "margin-left: 7px; margin: var(--x) url(a b);",
        "margin-left: 7px; margin: env(x) url(a b);",
        "margin-left: 7px; margin: var(--x) f(\"bad\n);",
        "margin-left: 7px; margin: env(x) f(\"bad\n);",
    }) |input| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, input);
        defer block.deinit();
        const left = try propertyValue(allocator, &block, "margin-left");
        defer allocator.free(left);
        try testing.expectEqualStrings("7px", left);
        try testing.expectEqual(@as(usize, 1), block.length());
        try testing.expectEqualStrings("margin-left", block.item(0).?);
        const raw = try propertyValue(allocator, &block, "margin");
        defer allocator.free(raw);
        try testing.expectEqualStrings("", raw);
    }
}

test "parsed raw shorthand replacement obeys importance and returns the live trimmed text" {
    try testing.checkAllAllocationFailures(testing.allocator, rawRawParsed, .{ "var(--x)", "env(x)", false, false });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawParsed, .{ "var(--x)", "env(x)", false, true });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawParsed, .{ "var(--x)", "env(x)", true, false });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawParsed, .{ "var(--x)", "env(x)", true, true });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawParsed, .{ "env(x)", "var(--x)", false, false });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawParsed, .{ "env(x)", "var(--x)", false, true });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawParsed, .{ "env(x)", "var(--x)", true, false });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawParsed, .{ "env(x)", "var(--x)", true, true });
}

test "setProperty raw shorthand replacement always uses the requested importance" {
    try testing.checkAllAllocationFailures(testing.allocator, rawRawSetter, .{ "var(--x)", "env(x)", false, false });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawSetter, .{ "var(--x)", "env(x)", false, true });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawSetter, .{ "var(--x)", "env(x)", true, false });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawSetter, .{ "var(--x)", "env(x)", true, true });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawSetter, .{ "env(x)", "var(--x)", false, false });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawSetter, .{ "env(x)", "var(--x)", false, true });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawSetter, .{ "env(x)", "var(--x)", true, false });
    try testing.checkAllAllocationFailures(testing.allocator, rawRawSetter, .{ "env(x)", "var(--x)", true, true });
}

test "setCssText transfers raw storage and supports later typed mutation and reuse" {
    try testing.checkAllAllocationFailures(testing.allocator, setCssTextTransfersAndReuses, .{"var(--x)"});
    try testing.checkAllAllocationFailures(testing.allocator, setCssTextTransfersAndReuses, .{"env(x)"});
}

test "tokenizer recognizes actual var and env names without matching comments or strings" {
    try testing.checkAllAllocationFailures(testing.allocator, tokenizerControls, .{});
}

test "bad url and bad string tokens do not replace earlier typed declarations" {
    try testing.checkAllAllocationFailures(testing.allocator, badTokensPreserveExisting, .{});
}
