//! Properties and Values API registration validation and document-independent map.
const std = @import("std");
const css = @import("css");
const registry = css.property_registry;
const testing = std.testing;

fn registration(allocator: std.mem.Allocator, name: []const u8, initial: []const u8) !*registry.Registration {
    return registry.Registration.create(.{ .allocator = allocator }, .{
        .name = name,
        .syntax = "<length>",
        .inherits = false,
        .initial_value = initial,
    });
}

test "pr1 scripted registration validates names before duplicate and syntax checks" {
    var map = registry.Registry.init(testing.allocator);
    defer map.deinit();
    try map.register(.{ .allocator = testing.allocator }, .{ .name = "--x", .syntax = "<length>", .inherits = false, .initial_value = "1px" });
    try testing.expectError(error.InvalidModificationError, map.register(.{ .allocator = testing.allocator }, .{ .name = "--x", .syntax = "not valid", .inherits = false }));
    for ([_][]const u8{ "", "x", "--", "\\--x" }) |name| {
        try testing.expectError(error.SyntaxError, map.register(.{ .allocator = testing.allocator }, .{ .name = name, .inherits = false }));
    }
    // registerProperty takes a custom property name STRING, not an identifier token.
    try map.register(.{ .allocator = testing.allocator }, .{ .name = "--x, space", .inherits = true });
    try testing.expect(map.lookup("--x, space") != null);
    try testing.expect(map.lookup("--X") == null);
}

test "pr1 initial values require matching and independence with universal exception" {
    for ([_]registry.Definition{
        .{ .name = "--x", .syntax = "<length>", .inherits = false },
        .{ .name = "--x", .syntax = "<length>", .inherits = false, .initial_value = "1em" },
        .{ .name = "--x", .syntax = "<length>", .inherits = false, .initial_value = "red" },
        .{ .name = "--x", .syntax = "<number>", .inherits = false, .initial_value = "calc(1em / 1em)" },
        .{ .name = "--x", .inherits = false, .initial_value = "var(--y)" },
        .{ .name = "--x", .inherits = false, .initial_value = "env(x)" },
        .{ .name = "--x", .inherits = false, .initial_value = "attr(data-x)" },
        .{ .name = "--x", .inherits = false, .initial_value = "initial" },
    }) |definition| try testing.expectError(error.SyntaxError, registry.Registration.create(.{ .allocator = testing.allocator }, definition));
    const universal = try registry.Registration.create(.{ .allocator = testing.allocator }, .{ .name = "--empty", .inherits = false });
    defer universal.unref();
    try testing.expect(universal.initial_value == null);
    const independent = try registry.Registration.create(.{ .allocator = testing.allocator }, .{ .name = "--em", .inherits = false, .initial_value = "1em" });
    defer independent.unref();
    try testing.expect(independent.initial_value != null);
}

test "pr1 stylesheet order last valid registration wins and script takes precedence" {
    const allocator = testing.allocator;
    var map = registry.Registry.init(allocator);
    defer map.deinit();
    const first = try registration(allocator, "--x", "1px");
    defer first.unref();
    const last = try registration(allocator, "--x", "2px");
    defer last.unref();
    var declared = registry.Declared.init(allocator);
    defer declared.deinit();
    try declared.add(first);
    try declared.add(last);
    const empty_version = map.version;
    map.replaceDeclared(&declared);
    try testing.expect(map.lookup("--x").? == last);
    try testing.expect(map.version != empty_version);
    const declared_version = map.version;
    try declared.add(last);
    map.replaceDeclared(&declared);
    try testing.expectEqual(declared_version, map.version);
    try map.register(.{ .allocator = allocator }, .{ .name = "--x", .syntax = "<length>", .inherits = true, .initial_value = "3px" });
    const scripted = map.lookup("--x").?;
    try testing.expect(scripted != last);
    try testing.expect(scripted.inherits);
    const script_version = map.version;
    map.replaceDeclared(&declared);
    try testing.expect(map.lookup("--x").? == scripted);
    try testing.expectEqual(script_version, map.version);
}

fn registryOom(allocator: std.mem.Allocator) !void {
    var map = registry.Registry.init(allocator);
    defer map.deinit();
    const record = try registration(allocator, "--length", "1px");
    var owns_record = true;
    defer if (owns_record) record.unref();
    var declared = registry.Declared.init(allocator);
    defer declared.deinit();
    try declared.add(record);
    map.replaceDeclared(&declared);
    record.unref();
    owns_record = false;
    try testing.expectEqualStrings("--length", map.lookup("--length").?.name);
    try map.register(.{ .allocator = allocator }, .{ .name = "--script", .syntax = "<string>+", .inherits = false, .initial_value = "'a' 'b'" });
    try testing.expect(map.lookup("--script") != null);
}

test "pr1 registry owns registrations and unwinds every allocation failure" {
    try registryOom(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, registryOom, .{});
}

fn parseDeclared(allocator: std.mem.Allocator, text: []const u8) !?*registry.Registration {
    var parsed = (try css.rules.parseRule(allocator, text)) orelse return null;
    defer parsed.deinitOwned(allocator);
    return registry.Registration.fromRule(.{ .allocator = allocator }, &parsed);
}

test "pr1 property descriptors preserve source syntax but validate complete rule" {
    const valid = (try parseDeclared(testing.allocator, "@property --x { unknown: value; initial-value: 1px; syntax: ' <length> '; inherits: false; }")) orelse return error.TestExpectedValue;
    defer valid.unref();
    try testing.expectEqualStrings("--x", valid.name);
    try testing.expectEqualStrings(" <length> ", valid.syntax_text);
    try testing.expect(!valid.inherits);
    try testing.expectEqualStrings("1px", valid.initial_text.?);
    for ([_][]const u8{
        "@property --x {}",
        "@property --x { syntax: '*'; }",
        "@property --x { inherits: false; }",
        "@property --x { syntax: '<length>'; inherits: false; }",
        "@property --x { syntax: '<length>'; inherits: false; initial-value: 1em; }",
        "@property --x, --y { syntax: '*'; inherits: false; }",
        "@property x { syntax: '*'; inherits: false; }",
        "@property --x;",
        "@property (",
    }) |text| {
        const invalid = try parseDeclared(testing.allocator, text);
        defer if (invalid) |r| r.unref();
        try testing.expect(invalid == null);
    }
}

test "pr1 ignored descriptors and invalid duplicates do not erase valid descriptors" {
    const rule = (try parseDeclared(testing.allocator, "@property --x { syntax: '<length>'; syntax: 'bad grammar'; inherits: true; inherits: maybe; initial-value: 2px; color: red; }")) orelse return error.TestExpectedValue;
    defer rule.unref();
    try testing.expectEqualStrings("<length>", rule.syntax_text);
    try testing.expect(rule.inherits);
    const important = try parseDeclared(testing.allocator, "@property --x { syntax: '*' !important; inherits: false; }");
    defer if (important) |r| r.unref();
    try testing.expect(important == null);
}

// All six cases from the Chrome/Firefox/Safari descriptor probe (Q10).
test "pr1 duplicate descriptor validation follows the browser majority" {
    for ([_]struct { text: []const u8, initial: ?[]const u8 }{
        .{ .text = "syntax: '<length>'; syntax: 'bad grammar'; inherits: false; initial-value: 1px", .initial = "1px" },
        .{ .text = "syntax: '<length>'; syntax: invalid; inherits: false; initial-value: 1px", .initial = "1px" },
        .{ .text = "syntax: '<length>'; inherits: false; inherits: invalid; initial-value: 1px", .initial = "1px" },
        .{ .text = "syntax: '<length>'; inherits: false; initial-value: 1px; initial-value: red", .initial = null },
        .{ .text = "syntax: '<length>'; inherits: false; initial-value: 1px; initial-value: var(--x)", .initial = null },
        .{ .text = "syntax: '*'; inherits: false; initial-value:", .initial = "" },
    }) |case| {
        const text = try std.fmt.allocPrint(testing.allocator, "@property --x {{ {s}; }}", .{case.text});
        defer testing.allocator.free(text);
        const record = try parseDeclared(testing.allocator, text);
        defer if (record) |r| r.unref();
        if (case.initial) |initial| {
            try testing.expect(record != null);
            try testing.expectEqualStrings(initial, record.?.initial_text.?);
            try testing.expect(!record.?.inherits);
        } else try testing.expect(record == null);
    }
}

fn descriptorOom(allocator: std.mem.Allocator) !void {
    const record = (try parseDeclared(allocator, "@property --x { syntax: '<length>'; syntax: 'bad grammar'; syntax: '<string>+'; inherits: false; initial-value: 'a' 'b'; }")) orelse return error.TestExpectedValue;
    defer record.unref();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try record.serializeRule(&out, allocator);
    try testing.expectEqualStrings("@property --x { syntax: \"<string>+\"; inherits: false; initial-value: 'a' 'b'; }", out.items);
}

test "pr1 rule descriptors serialize and unwind every allocation failure" {
    try descriptorOom(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, descriptorOom, .{});
}

// Chrome 155, Firefox 158 and Safari 27 agree in
// tmp/analysis/integrator-probes-1025l/RULINGS.md (Q16).
test "pr1 universal initial descriptor admits braces without changing ordinary declarations" {
    for ([_][]const u8{ "foo(){}", "{}", "{} foo()", "foo {} bar", "[foo] {}", "foo() {}", "url(a){}" }) |initial| {
        const text = try std.fmt.allocPrint(testing.allocator, "@property --x {{ syntax: '*'; inherits: false; initial-value: {s}; }}", .{initial});
        defer testing.allocator.free(text);
        const record = (try parseDeclared(testing.allocator, text)) orelse return error.TestExpectedValue;
        defer record.unref();
        try testing.expectEqualStrings(initial, record.initial_text orelse return error.TestExpectedValue);
    }
    // A real property still follows CSS Syntax §5.5.6 step 8; using an
    // unknown property would not distinguish that rule from property lookup.
    const ordinary = try css.rules.parseDeclarationList(testing.allocator, "color: red{}; background-color: blue");
    defer css.rules.freeDeclarationList(testing.allocator, ordinary);
    try testing.expectEqual(@as(usize, 1), ordinary.len);
    try testing.expectEqualStrings("background-color", ordinary[0].name);
}

// Q17: Chrome/Firefox preserve the source for typed and universal syntax;
// Safari re-spells strings/whitespace (probe 1025m/RULINGS.md).
test "pr1 initial descriptors retain authored text across typed validation" {
    for ([_]struct { syntax: []const u8, source: []const u8, expected: []const u8 }{
        .{ .syntax = "*", .source = "a  b", .expected = "a  b" },
        .{ .syntax = "*", .source = "a/**/b", .expected = "a/**/b" },
        .{ .syntax = "<string>+", .source = "'a' 'b'", .expected = "'a' 'b'" },
        .{ .syntax = "<length>", .source = "01PX", .expected = "01PX" },
        .{ .syntax = "<length>", .source = "calc(1px + 2px)", .expected = "calc(1px + 2px)" },
        .{ .syntax = "<color>", .source = "RED", .expected = "RED" },
        .{ .syntax = "<url>", .source = "url(a)", .expected = "url(a)" },
        .{ .syntax = "*", .source = "  a \t b  ", .expected = "a \t b" },
    }) |case| {
        const text = try std.fmt.allocPrint(testing.allocator, "@property --x {{ syntax: \"{s}\"; inherits: false; initial-value: {s}; }}", .{ case.syntax, case.source });
        defer testing.allocator.free(text);
        const record = (try parseDeclared(testing.allocator, text)) orelse return error.TestExpectedValue;
        defer record.unref();
        try testing.expectEqualStrings(case.expected, record.initial_text.?);
    }
}
