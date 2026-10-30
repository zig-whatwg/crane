//! Typed OM §5.3; Q36/Q40 Chrome 156 and Safari 27 probes, 2026-10-27.
//! The existing property grammar consumes native numeric trees. CSS text
//! never obtains the private stream marker or these declared range rules.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn assignment(allocator: std.mem.Allocator, name: []const u8, source: []const u8, is_unit: bool, expected: ?[]const u8, computed: ?[]const u8) anyerror!void {
    if (comptime !@hasDecl(css.properties, "parseTypedNumeric")) return std.testing.expect(false);
    const expression = (try css.math_values.parseNumeric(allocator, source)) orelse return error.TestUnexpectedResult;
    defer expression.deinit();
    const property = (css.properties.lookup(name) orelse return error.MissingProperty);
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    const ok = try css.properties.parseTypedNumeric(.{ .allocator = allocator }, property, .{ .expression = expression, .is_unit = is_unit }, &assignments);
    if (expected) |want| {
        try std.testing.expect(ok);
        for (assignments.items) |item| {
            var text: std.ArrayList(u8) = .empty;
            defer text.deinit(allocator);
            try css.properties.serializeAssigned(item.longhand, item.value, &text, allocator);
            try std.testing.expectEqualStrings(want, text.items);
            if (is_unit and expression.root.tag == .numeric) {
                try std.testing.expectEqual(expression.root.numeric.value, item.value.value.calculation.root.numeric.value);
                try std.testing.expectEqual(expression.root.numeric.unit, item.value.value.calculation.root.numeric.unit);
            }
            if (computed) |computed_want| {
                const value = item.value.value.calculation;
                const result = try value.compute(allocator, .{});
                defer result.unref();
                text.clearRetainingCapacity();
                try result.serialize(&text, allocator);
                try std.testing.expectEqualStrings(computed_want, text.items);
            }
        }
    } else {
        try std.testing.expect(!ok);
        try std.testing.expectEqual(@as(usize, 0), assignments.items.len);
    }
}

fn probeCases(allocator: std.mem.Allocator) anyerror!void {
    try assignment(allocator, "width", "-2px", true, "calc(-2px)", "0px");
    try assignment(allocator, "width", "-10%", true, "calc(-10%)", "0%");
    try assignment(allocator, "width", "0", true, null, null);
    try assignment(allocator, "width", "2px", true, "2px", "2px");
    try assignment(allocator, "width", "1cm", true, "1cm", null);
    try assignment(allocator, "width", "calc(1cm)", false, "calc(37.7953px)", null);
    try assignment(allocator, "opacity", "50%", true, "50%", "0.5");
    try assignment(allocator, "opacity", "200%", true, "200%", "1");
    try assignment(allocator, "opacity", "2", true, "2", "1");
    try assignment(allocator, "z-index", "1.5", true, "calc(1.5)", "2");
    try assignment(allocator, "z-index", "3", true, "3", "3");
    try assignment(allocator, "z-index", "2147483648", true, "2147483648", "2147483647");
    try assignment(allocator, "z-index", "-2147483649", true, "-2147483649", "-2147483648");
    try assignment(allocator, "z-index", "100000000000000000000", true, "100000000000000000000", "2147483647");
    // Q48 keeps the finite magnitude and the existing CSS-wide formatter.
    var large: std.ArrayList(u8) = .empty;
    defer large.deinit(allocator);
    try css.style_values.appendNumber(1e40, &large, allocator);
    try assignment(allocator, "z-index", "1e40", true, large.items, "2147483647");
    try large.appendSlice(allocator, "px");
    try assignment(allocator, "width", "1e40px", true, large.items, null);
    try assignment(allocator, "margin", "2px", true, "2px", "2px");
    try assignment(allocator, "color", "2px", true, null, null);
    try assignment(allocator, "width", "calc(1px * 1px)", false, null, null);
}

test "native numeric assignments preserve units and clamp only the owning grammar at computation" {
    try std.testing.checkAllAllocationFailures(a, probeCases, .{});
}

fn cssText(allocator: std.mem.Allocator, name: []const u8, source: []const u8, expected: ?[]const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    const changed = try block.setProperty(.{ .allocator = allocator }, name, source, "");
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try block.getPropertyValue(name, &text);
    if (expected) |want| {
        try std.testing.expect(changed);
        try std.testing.expectEqualStrings(want, text.items);
    } else try std.testing.expectEqualStrings("", text.items);
}

test "ordinary CSS retains its range and parser behavior including marker lookalikes" {
    try cssText(a, "width", "-2px", null);
    try cssText(a, "width", "0", "0px");
    try cssText(a, "opacity", "200%", "2");
    try cssText(a, "z-index", "2147483648", "2147483647");
    try cssText(a, "z-index", "-2147483649", "-2147483648");
    for ([_][]const u8{ "calc", "calc()", "native_numeric_marker", "calc(native_numeric_marker)", "-crane-typed-numeric()" }) |text| try cssText(a, "width", text, null);
    try cssText(a, "width", "calc(2px)", "calc(2px)");
}

// D38/Q38/Q40: parser bound tags describe the owning grammar; they must
// not change CSS text. The pre-existing two tests above remain byte-exact.
test "native numeric range classification defaults to grammar" {
    if (comptime !@hasField(css.math_values.Grammar, "minimum_kind")) return std.testing.expect(false);
    const grammar: css.math_values.Grammar = .{ .kind = .number };
    try std.testing.expectEqual(css.math_values.Grammar.BoundKind.grammar, grammar.minimum_kind);
    try std.testing.expectEqual(css.math_values.Grammar.BoundKind.grammar, grammar.maximum_kind);
}

test "each exceptional numeric bound carries its owning clamp metadata without changing CSS text" {
    if (comptime !@hasField(css.math_values.Grammar, "minimum_kind")) return std.testing.expect(false);
    const Bound = css.math_values.Grammar.BoundKind;
    const Shape = enum { direct, filter, image, grid, second_component, first_component };
    const Case = struct { property: []const u8, source: []const u8, expected: ?[]const u8 = null, shape: Shape = .direct, minimum: Bound, maximum: Bound };
    const cases = [_]Case{
        .{ .property = "width", .source = "calc(2px)", .minimum = .grammar, .maximum = .grammar },
        .{ .property = "font-weight", .source = "calc(400)", .minimum = .grammar, .maximum = .grammar },
        .{ .property = "opacity", .source = "calc(2)", .minimum = .computation, .maximum = .computation },
        .{ .property = "z-index", .source = "calc(2)", .minimum = .representation, .maximum = .representation },
        .{ .property = "list-style-image", .source = "-webkit-cross-fade(url(a.png), url(b.png), calc(2))", .expected = "-webkit-cross-fade(url(\"a.png\"), url(\"b.png\"), calc(2))", .shape = .image, .minimum = .computation, .maximum = .computation },
        .{ .property = "filter", .source = "grayscale(calc(2))", .shape = .filter, .minimum = .grammar, .maximum = .computation },
        .{ .property = "filter", .source = "brightness(calc(2))", .shape = .filter, .minimum = .grammar, .maximum = .grammar },
        .{ .property = "grid-column-start", .source = "calc(2)", .shape = .grid, .minimum = .representation, .maximum = .representation },
        .{ .property = "grid-column-start", .source = "span calc(2)", .shape = .grid, .minimum = .grammar, .maximum = .representation },
        .{ .property = "initial-letter", .source = "2 calc(3)", .shape = .second_component, .minimum = .grammar, .maximum = .representation },
        .{ .property = "hyphenate-limit-lines", .source = "calc(3)", .minimum = .grammar, .maximum = .representation },
        .{ .property = "hyphenate-limit-chars", .source = "calc(3)", .shape = .first_component, .minimum = .grammar, .maximum = .representation },
    };
    for (cases) |case| {
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (assignments.items) |item| item.value.release();
            assignments.deinit(a);
        }
        try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = a }, (css.properties.lookup(case.property) orelse return error.MissingProperty), case.source, &assignments));
        try std.testing.expectEqual(@as(usize, 1), assignments.items.len);
        const value = assignments.items[0].value.value;
        const expression = switch (case.shape) {
            .direct => value.calculation,
            .filter => value.filter.items[0].function.argument.scalar.calculation,
            .image => value.image.data.cross_fade.weight_value.?.calculation,
            .grid => value.grid_line.count.?.calculation,
            .second_component => value.text_values.items[1].calculation,
            .first_component => value.text_values.items[0].calculation,
        };
        try std.testing.expectEqual(case.minimum, expression.grammar.minimum_kind);
        try std.testing.expectEqual(case.maximum, expression.grammar.maximum_kind);
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(a);
        try css.properties.serializeAssigned(assignments.items[0].longhand, assignments.items[0].value, &text, a);
        // Tags must not affect the pre-existing specified serialization.
        try std.testing.expectEqualStrings(case.expected orelse case.source, text.items);
        var roundtrip = css.declarations.DeclarationBlock.init(a);
        defer roundtrip.deinit();
        try std.testing.expect(try roundtrip.setProperty(.{ .allocator = a }, case.property, text.items, ""));
        var again: std.ArrayList(u8) = .empty;
        defer again.deinit(a);
        try roundtrip.getPropertyValue(case.property, &again);
        try std.testing.expectEqualStrings(text.items, again.items);
    }
}
