//! Values 5 §3.3.1 and resolving in properties: match first, then consume.
//! Registration's CSS-wide initial-value restriction belongs to registration.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const keywords = [_][]const u8{ "inherit", "initial", "unset", "revert", "revert-layer", " /**/InHeRiT/**/ ", "\\69 nherit" };

test "pr1 universal matching preserves CSS-wide keywords uncomputed" {
    var definition = try css.syntax_definitions.parse(testing.allocator, "*");
    defer definition.deinit();
    for (keywords) |text| {
        var value = (try definition.parseValue(.{ .allocator = testing.allocator }, text)) orelse return error.TestExpectedValue;
        defer value.deinit();
        try testing.expect(value.data == .universal);
        try testing.expectEqualStrings(text, value.data.universal);
    }
}

test "pr1 typed and custom-ident syntax still reject CSS-wide values" {
    for ([_][]const u8{ "<custom-ident>", "<color>", "<length>", "<image>", "<string>" }) |syntax| {
        var definition = try css.syntax_definitions.parse(testing.allocator, syntax);
        defer definition.deinit();
        for (keywords) |text| {
            var value = try definition.parseValue(.{ .allocator = testing.allocator }, text);
            defer if (value) |*owned| owned.deinit();
            try testing.expect(value == null);
        }
    }
}

test "pr1 registration alone rejects universal CSS-wide initial values" {
    var registry = css.property_registry.Registry.init(testing.allocator);
    defer registry.deinit();
    for (keywords) |text| {
        try testing.expectError(error.SyntaxError, registry.register(.{ .allocator = testing.allocator }, .{
            .name = "--wide",
            .inherits = false,
            .initial_value = text,
        }));
        try testing.expect(registry.lookup("--wide") == null);
        try testing.expectEqual(@as(u64, 0), registry.version);
        const source = try std.fmt.allocPrint(testing.allocator, "@property --wide {{ syntax: '*'; inherits: false; initial-value: {s}; }}", .{text});
        defer testing.allocator.free(source);
        var rule = (try css.rules.parseRule(testing.allocator, source)).?;
        defer rule.deinitOwned(testing.allocator);
        const record = try css.property_registry.Registration.fromRule(.{ .allocator = testing.allocator }, &rule);
        defer if (record) |owned| owned.unref();
        try testing.expect(record == null);
    }
}
