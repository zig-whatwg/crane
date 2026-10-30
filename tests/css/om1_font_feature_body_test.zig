//! Fonts 4 §6.9: preserve mixed descriptors/feature blocks through the
//! existing Syntax parser, before the descriptor grammar validates them.
const std = @import("std");
const css = @import("css");

fn mixedBody(allocator: std.mem.Allocator) anyerror!void {
    var parsed = try css.rules.parseStyleSheetContents(allocator,
        \\@font-feature-values Example {
        \\  FONT-DISPLAY: swap;
        \\  @swash { foo: 1; FOO: 2; f\6f o: 3; bad: -1; }
        \\  @styleset { repeated: 1 2; } @styleset { repeated: 3; }
        \\  not-a-feature { skipped: 4; }
        \\  @annotation { upper: 5; @swash { dropped: 6; } lower: 7; }
        \\  @unknown { dropped: 8; }
        \\  font-display: optional;
        \\}
        \\@swash { outside: 9; }
        \\p { COLOR: red; }
    );
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 3), parsed.items.len);
    const rule = &parsed.items[0];
    try std.testing.expectEqualStrings("font-feature-values", rule.name);
    try std.testing.expectEqualStrings("Example", rule.prelude);
    try std.testing.expectEqual(@as(usize, 2), rule.declarations.len);
    try std.testing.expectEqualStrings("font-display", rule.declarations[0].name);
    try std.testing.expectEqualStrings("swap", rule.declarations[0].value);
    try std.testing.expectEqualStrings("optional", rule.declarations[1].value);
    try std.testing.expectEqual(@as(usize, 5), rule.children.len);
    const first = &rule.children[0];
    try std.testing.expectEqualStrings("swash", first.name);
    try std.testing.expectEqual(@as(usize, 4), first.declarations.len);
    try std.testing.expectEqualStrings("foo", first.declarations[0].name);
    try std.testing.expectEqualStrings("FOO", first.declarations[1].name);
    try std.testing.expectEqualStrings("foo", first.declarations[2].name);
    // Syntax preserves even a grammar-invalid value; Fonts validates later.
    try std.testing.expectEqualStrings("-1", first.declarations[3].value);
    try std.testing.expectEqualStrings("1 2", rule.children[1].declarations[0].value);
    try std.testing.expectEqualStrings("3", rule.children[2].declarations[0].value);
    try std.testing.expectEqual(@as(usize, 2), rule.children[3].declarations.len);
    try std.testing.expectEqual(@as(usize, 0), rule.children[4].declarations.len);
    try std.testing.expectEqual(@as(usize, 0), parsed.items[1].declarations.len);
    try std.testing.expectEqualStrings("color", parsed.items[2].declarations[0].name);
}

test "font feature mixed bodies preserve case and recover without leaking" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, mixedBody, .{});
}

fn dumpRule(out: *std.ArrayList(u8), rule: css.rules.Rule) !void {
    const allocator = std.testing.allocator;
    try out.appendSlice(allocator, rule.name);
    try out.append(allocator, '|');
    try out.appendSlice(allocator, rule.prelude);
    try out.append(allocator, '{');
    for (rule.declarations) |declaration| {
        try out.appendSlice(allocator, declaration.name);
        try out.append(allocator, ':');
        try out.appendSlice(allocator, declaration.value);
        if (declaration.important) try out.appendSlice(allocator, "!important");
        try out.append(allocator, ';');
    }
    for (rule.children) |child| try dumpRule(out, child);
    try out.append(allocator, '}');
}

test "other rule trees retain byte-identical names preludes and declaration values" {
    const allocator = std.testing.allocator;
    var parsed = try css.rules.parseStyleSheetContents(allocator,
        \\@font-face { FONT-FAMILY: "Example"; src: url(font.woff2); }
        \\@property --Mixed { syntax: "*"; inherits: false; initial-value: { A } B; }
        \\@counter-style Mixed { system: cyclic; symbols: "a" B; }
        \\@media SCREEN { P { COLOR: RED !important; --Mixed:  A /*x*/ B ; } }
        \\@keyframes Mixed { FROM { opacity: 0; } to { opacity: 1; } }
    );
    defer parsed.deinit();
    var serialized: std.ArrayList(u8) = .empty;
    defer serialized.deinit(allocator);
    for (parsed.items) |rule| try dumpRule(&serialized, rule);
    try std.testing.expectEqualStrings(
        "font-face|{font-family:\"Example\";src:url(\"font.woff2\");}" ++
            "property|--Mixed{syntax:\"*\";inherits:false;initial-value:{ A } B;}" ++
            "counter-style|Mixed{system:cyclic;symbols:\"a\" B;}" ++
            "media|SCREEN{|P{color:RED!important;--Mixed:A /*x*/ B;}}" ++
            "keyframes|Mixed{|FROM{opacity:0;}|to{opacity:1;}}",
        serialized.items,
    );
}
