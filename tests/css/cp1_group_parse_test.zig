//! CSS Syntax 3 §5.5.5: failed declaration attempts must stop early.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;

fn allocatedForRules(count: usize, rule: []const u8) !usize {
    var source: std.ArrayList(u8) = .empty;
    defer source.deinit(a);
    try source.appendSlice(a, "@media all {");
    for (0..count) |_| try source.appendSlice(a, rule);
    try source.append(a, '}');
    var measured = std.testing.FailingAllocator.init(a, .{});
    {
        var sheet = try css.rules.parseStyleSheetContents(measured.allocator(), source.items);
        defer sheet.deinit();
        try std.testing.expectEqual(count, sheet.items[0].children.len);
    }
    try std.testing.expectEqual(measured.allocated_bytes, measured.freed_bytes);
    return measured.allocated_bytes;
}

fn expectLinear(rule: []const u8) !void {
    // Allocation work is deterministic; the separate Crane fixture records
    // wall-clock scaling. Pin both the missing-colon and block early exits.
    const small = try allocatedForRules(64, rule);
    const large = try allocatedForRules(128, rule);
    try std.testing.expect(large < 3 * small);
}

test "group parsing allocates linearly for type-led rules" {
    try expectLinear("div{a:b}");
}

test "group parsing allocates linearly for descendant rules" {
    try expectLinear("li a{a:b}");
}

test "group parsing allocates linearly for pseudo-class led rules" {
    try expectLinear("a:hover{a:b}");
}

test "group parsing preserves independent child trees and custom declaration runs" {
    const children = [_][]const u8{
        "div{a:b}",                                      "a:hover{a:b}", "li a{a:b}",
        "@supports (display:block) { p { color:red } }",
    };
    var source: std.ArrayList(u8) = .empty;
    defer source.deinit(a);
    try source.appendSlice(a, "@media all {");
    for (children) |text| try source.appendSlice(a, text);
    try source.appendSlice(a, "--x:{y} }");
    var grouped = try css.rules.parseStyleSheetContents(a, source.items);
    defer grouped.deinit();
    const rules = grouped.items[0].children;
    try std.testing.expectEqual(children.len + 1, rules.len);
    for (children, 0..) |text, i| {
        var independent = (try css.rules.parseRule(a, text)).?;
        defer independent.deinitOwned(a);
        try std.testing.expectEqualDeep(independent, rules[i]);
    }
    const tail = rules[children.len];
    try std.testing.expectEqual(css.rules.Rule.Kind.declarations, tail.kind);
    const expected = try css.rules.parseDeclarationList(a, "--x:{y}");
    defer css.rules.freeDeclarationList(a, expected);
    try std.testing.expectEqualDeep(expected, tail.declarations);
}

test "declaration early exits preserve blocks important escapes and descriptor exemptions" {
    const cases = [_][]const u8{
        "x:{} !important",           "x:{} ! important",          "x:{} !IMPORTANT",
        "x: {} {}",                  "x: ({a:b})",                "--x: before {} after",
        "\\2d -x: before {} after",  "x: {} !important trailing", "x: before {}; y:after",
        "x: {} !important; y:after",
    };
    for (cases) |text| {
        const wrapped = try std.mem.concat(a, u8, &.{ "a{", text, "}" });
        defer a.free(wrapped);
        var sheet = try css.rules.parseStyleSheetContents(a, wrapped);
        defer sheet.deinit();
        const flat = try css.rules.parseDeclarationList(a, text);
        defer css.rules.freeDeclarationList(a, flat);
        var declarations: std.ArrayList(css.rules.Declaration) = .empty;
        defer declarations.deinit(a);
        try declarations.appendSlice(a, sheet.items[0].declarations);
        for (sheet.items[0].children) |child| if (child.kind == .declarations) {
            try declarations.appendSlice(a, child.declarations);
        };
        try std.testing.expectEqualDeep(flat, declarations.items);
    }
    var property = try css.rules.parseStyleSheetContents(a, "@property --x { syntax: '*'; inherits: false; initial-value: before {} after; }");
    defer property.deinit();
    try std.testing.expectEqual(@as(usize, 3), property.items[0].declarations.len);
    try std.testing.expectEqualStrings("before {} after", property.items[0].declarations[2].value);
}
