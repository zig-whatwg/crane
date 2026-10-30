//! CSS Nesting 1 sections 3.1 and 4: contextual parsing and owned resolution.
const std = @import("std");
const selector = @import("selector");
const a = std.testing.allocator;

fn checkText(allocator: std.mem.Allocator, source: []const u8, expected: []const u8) !void {
    const parsed = try selector.parser.parseCssomOwned(allocator, try allocator.dupe(u8, source), .{ .nesting = .style });
    var list = parsed.selectors;
    defer list.deinit();
    defer allocator.free(parsed.text);
    try std.testing.expectEqualStrings(expected, parsed.text);
}

fn syntax(allocator: std.mem.Allocator) !void {
    try checkText(allocator, ".child", "& .child");
    try checkText(allocator, "> & .child, .other", "& > & .child, & .other");
    try checkText(allocator, "div&.child", "div&.child");
    try checkText(allocator, ":is(.child, &)", ":is(.child, &)");
    // Section 3.1 counts the token even in a forgiven unknown function.
    try checkText(allocator, ":is(:unknown(&), .child)", ":is(:unknown(&), .child)");
    try checkText(allocator, ":is([title=\"&\"], .child)", "& :is([title=\"&\"], .child)");
    try checkText(allocator, ":nth-child(999999999999 of &)", ":nth-child(2147483647 of &)");
}

test "nested selector syntax supplies only the required implicit nesting selector" {
    if (comptime @hasDecl(selector, "nesting")) {
        try syntax(a);
        try std.testing.expectError(error.InvalidSelector, selector.parser.parseCssomOwned(a, try a.dupe(u8, "&div"), .{ .nesting = .style }));
    } else return error.MissingNesting;
}

fn ownedResolution(allocator: std.mem.Allocator) !void {
    const parent_text = try allocator.dupe(u8, "#parent, .other");
    var owns_parent_text = true;
    defer if (owns_parent_text) allocator.free(parent_text);
    var parent = try selector.parse(allocator, parent_text);
    var owns_parent = true;
    defer if (owns_parent) parent.deinit();
    const original = try selector.parser.parseCssomOwned(allocator, try allocator.dupe(u8, "& .child"), .{ .nesting = .style });
    var nested = original.selectors;
    var owns_nested = true;
    defer if (owns_nested) {
        nested.deinit();
        allocator.free(original.text);
    };
    var resolved = try selector.nesting.resolve(allocator, &nested, &parent);
    defer resolved.deinit();
    parent.deinit();
    owns_parent = false;
    allocator.free(parent_text);
    owns_parent_text = false;
    nested.deinit();
    allocator.free(original.text);
    owns_nested = false;
    const complex = &resolved.selectors[0];
    try std.testing.expectEqualStrings("child", complex.compound.simple_selectors[0].Class.class_name);
    const parents = complex.combinators[0].compound.simple_selectors[0].PseudoClass.kind.Is;
    try std.testing.expectEqualStrings("parent", parents.selectors[0].compound.simple_selectors[0].Id.id);
    try std.testing.expectEqualStrings("other", parents.selectors[1].compound.simple_selectors[0].Class.class_name);
    try std.testing.expectEqual(selector.Specificity{ .id = 1, .class = 1 }, complex.calculateSpecificity());
    try std.testing.expect(!selector.nesting.contains(&resolved));
}

test "resolved nested selectors own names after the parent and original rule are gone" {
    if (comptime @hasDecl(selector, "nesting")) {
        try ownedResolution(a);
    } else return error.MissingNesting;
}

fn recursiveResolution(allocator: std.mem.Allocator) !void {
    var parent = try selector.parse(allocator, "#parent, article");
    defer parent.deinit();
    const original = try selector.parser.parseCssomOwned(allocator, try allocator.dupe(u8, ":is(&, .fallback):nth-child(2n of :has(> &)):lang(en, \"fr\")::before"), .{ .nesting = .style });
    var list = original.selectors;
    defer list.deinit();
    defer allocator.free(original.text);
    var resolved = try selector.nesting.resolve(allocator, &list, &parent);
    defer resolved.deinit();
    try std.testing.expect(!selector.nesting.contains(&resolved));
    try std.testing.expectEqual(selector.Specificity{ .id = 2, .class = 2, .element = 1 }, resolved.selectors[0].calculateSpecificity());
}

test "nesting resolution recurses through logical nth and relative selector lists" {
    if (comptime @hasDecl(selector, "nesting")) {
        try recursiveResolution(a);
    } else return error.MissingNesting;
}

fn pseudoParents(allocator: std.mem.Allocator) !void {
    var parent = try selector.parse(allocator, ".a, .b::before");
    defer parent.deinit();
    const original = try selector.parser.parseCssomOwned(allocator, try allocator.dupe(u8, "& .c"), .{ .nesting = .style });
    var list = original.selectors;
    defer list.deinit();
    defer allocator.free(original.text);
    var resolved = try selector.nesting.resolve(allocator, &list, &parent);
    defer resolved.deinit();
    const complex = &resolved.selectors[0];
    try std.testing.expectEqual(selector.Specificity{ .class = 2, .element = 1 }, complex.calculateSpecificity());
    const parents = complex.combinators[0].compound.simple_selectors[0].PseudoClass.kind.Is;
    try std.testing.expectEqual(@as(usize, 1), parents.selectors[0].compound.simple_selectors.len);
    const guarded = parents.selectors[1].compound.simple_selectors;
    try std.testing.expectEqual(@as(usize, 3), guarded.len);
    const guard = guarded[2].PseudoClass.kind.Not;
    try std.testing.expect(guard.selectors[0].compound.simple_selectors[0] == .Universal);
    var direct = try selector.nesting.clone(allocator, &parent);
    defer direct.deinit();
    // CSSNestedDeclarations preserves the parent's actual pseudo-element;
    // it does not pass through the synthesized :is() parent-copy path.
    try std.testing.expectEqual(@as(usize, 2), direct.selectors[1].compound.simple_selectors.len);
    try std.testing.expect(direct.selectors[1].compound.hasPseudoElement());
}

test "nesting pseudo-element parents cannot match but retain their specificity" {
    if (comptime @hasDecl(selector, "nesting")) {
        try pseudoParents(a);
    } else return error.MissingNesting;
}

test "top-level ampersand is scope with zero specificity and CSSOM keeps ampersand" {
    if (comptime @hasDecl(selector, "nesting")) {
        var ordinary = try selector.parse(a, "&");
        defer ordinary.deinit();
        try std.testing.expectEqual(selector.Specificity{}, ordinary.selectors[0].calculateSpecificity());
        try std.testing.expect(ordinary.selectors[0].compound.simple_selectors[0].PseudoClass.kind == .Where);
        const original = try selector.parser.parseCssomOwned(a, try a.dupe(u8, "&"), .{});
        var list = original.selectors;
        defer list.deinit();
        defer a.free(original.text);
        try std.testing.expectEqualStrings("&", original.text);
        try std.testing.expect(selector.nesting.contains(&list));
        var resolved = try selector.nesting.resolve(a, &list, null);
        defer resolved.deinit();
        try std.testing.expectEqual(selector.Specificity{}, resolved.selectors[0].calculateSpecificity());
        const scoped = try selector.parser.parseCssomOwned(a, try a.dupe(u8, "&"), .{ .nesting = .scope });
        var scoped_list = scoped.selectors;
        defer scoped_list.deinit();
        defer a.free(scoped.text);
        var scope_resolved = try selector.nesting.resolve(a, &scoped_list, null);
        defer scope_resolved.deinit();
        try std.testing.expectEqual(selector.Specificity{}, scope_resolved.selectors[0].calculateSpecificity());
    } else return error.MissingNesting;
}

test "nesting selectors unwind every allocation failure" {
    if (comptime @hasDecl(selector, "nesting")) {
        try std.testing.checkAllAllocationFailures(a, syntax, .{});
        try std.testing.checkAllAllocationFailures(a, ownedResolution, .{});
        try std.testing.checkAllAllocationFailures(a, recursiveResolution, .{});
        try std.testing.checkAllAllocationFailures(a, pseudoParents, .{});
    } else return error.MissingNesting;
}
