//! Q74/Q75: immutable shared parent ownership, separate from matching.
const std = @import("std");
const selector = @import("selector");
const a = std.testing.allocator;

fn makeParent(allocator: std.mem.Allocator, text: []const u8) !*selector.nesting.SharedList {
    const owned = try allocator.dupe(u8, text);
    defer allocator.free(owned);
    var source = try selector.parse(allocator, owned);
    defer source.deinit();
    // The node must own its strings before this function frees the source.
    return selector.nesting.SharedList.create(allocator, &source, null);
}

fn nested(allocator: std.mem.Allocator, text: []const u8, parent: *selector.nesting.SharedList) !selector.SelectorList {
    const parsed = try selector.parser.parseCssomOwned(allocator, try allocator.dupe(u8, text), .{ .nesting = .style });
    var source = parsed.selectors;
    defer source.deinit();
    defer allocator.free(parsed.text);
    return selector.nesting.resolve(allocator, &source, parent.actualList());
}

fn exactCounts(allocator: std.mem.Allocator) !void {
    const parent = try makeParent(allocator, "#parent, .other");
    defer parent.unref();
    try std.testing.expectEqual(@as(u32, 1), parent.refs);
    try std.testing.expect(parent.isUnchanged());
    {
        var child = try nested(allocator, "&&", parent);
        defer child.deinit();
        try std.testing.expectEqual(@as(u32, 3), parent.refs);
        const simples = child.selectors[0].compound.simple_selectors;
        try std.testing.expectEqual(@as(usize, 2), simples.len);
        try std.testing.expect(simples[0].PseudoClass.kind.Is == simples[1].PseudoClass.kind.Is);
        try std.testing.expect(simples[0].PseudoClass.kind.Is.shared_owner == parent);
        try std.testing.expect(parent.isUnchanged());
    }
    try std.testing.expectEqual(@as(u32, 1), parent.refs);
    try std.testing.expect(parent.isUnchanged());
}

fn copyHolds(allocator: std.mem.Allocator) !void {
    const parent = try makeParent(allocator, "#parent");
    var owns_parent = true;
    defer if (owns_parent) parent.unref();
    var original = try nested(allocator, "&&", parent);
    var owns_original = true;
    defer if (owns_original) original.deinit();
    var copy = try selector.nesting.clone(allocator, &original);
    defer copy.deinit();
    try std.testing.expectEqual(@as(u32, 5), parent.refs);
    original.deinit();
    owns_original = false;
    try std.testing.expectEqual(@as(u32, 3), parent.refs);
    parent.unref();
    owns_parent = false;
    // Only the two copied components keep the parent node alive now.
    try std.testing.expectEqual(@as(u32, 2), parent.refs);
    const first = copy.selectors[0].compound.simple_selectors[0].PseudoClass.kind.Is;
    try std.testing.expectEqualStrings("parent", first.selectors[0].compound.simple_selectors[0].Id.id);
    try std.testing.expect(parent.isUnchanged());
    try std.testing.expectEqual(selector.Specificity{ .id = 2 }, copy.selectors[0].calculateSpecificity());
}

fn guardedViews(allocator: std.mem.Allocator) !void {
    const parent = try makeParent(allocator, ".a, .b::before");
    defer parent.unref();
    const actual = parent.actualList();
    try std.testing.expectEqual(@as(usize, 2), actual.selectors[1].compound.simple_selectors.len);
    try std.testing.expect(actual.selectors[1].compound.hasPseudoElement());
    var child = try nested(allocator, "& .child", parent);
    defer child.deinit();
    const guarded = child.selectors[0].combinators[0].compound.simple_selectors[0].PseudoClass.kind.Is;
    try std.testing.expect(guarded != actual);
    try std.testing.expect(guarded.shared_owner == parent);
    try std.testing.expectEqual(@as(usize, 3), guarded.selectors[1].compound.simple_selectors.len);
    const guard = guarded.selectors[1].compound.simple_selectors[2].PseudoClass.kind.Not;
    try std.testing.expect(guard.selectors[0].compound.simple_selectors[0] == .Universal);
    var declarations = try selector.nesting.clone(allocator, actual);
    defer declarations.deinit();
    try std.testing.expectEqual(@as(usize, 2), declarations.selectors[1].compound.simple_selectors.len);
    try std.testing.expect(declarations.selectors[1].compound.hasPseudoElement());
    try std.testing.expect(parent.isUnchanged());
    try std.testing.expectEqual(selector.Specificity{ .class = 2, .element = 1 }, child.selectors[0].calculateSpecificity());
}

test "parsed selector lists default to unique ownership" {
    if (comptime @hasField(selector.SelectorList, "shared_owner")) {
        var list = try selector.parse(a, ".ordinary:is(.child)");
        defer list.deinit();
        try std.testing.expect(list.shared_owner == null);
        const argument = list.selectors[0].compound.simple_selectors[1].PseudoClass.kind.Is;
        try std.testing.expect(argument.shared_owner == null);
    } else return error.MissingSharedNesting;
}

test "each resolved nesting component holds exactly one parent reference" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        try exactCounts(a);
    } else return error.MissingSharedNesting;
}

test "shared selector copies survive releasing the original and parent slot" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        try copyHolds(a);
    } else return error.MissingSharedNesting;
}

test "a shared parent has a guarded nesting view and unchanged actual selectors" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        try guardedViews(a);
    } else return error.MissingSharedNesting;
}

test "immutable selector nodes detect a structural write after freezing" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        const parent = try makeParent(a, ".original");
        defer parent.unref();
        try std.testing.expect(parent.isUnchanged());
        // Deliberate contract violation tests the predicate used by Debug
        // assertions. Restore it before any release or further operation.
        const first = &parent.actualList().selectors[0].compound.simple_selectors[0];
        const saved = first.*;
        first.* = .{ .Universal = .{} };
        const detected = !parent.isUnchanged();
        first.* = saved;
        try std.testing.expect(detected);
        try std.testing.expect(parent.isUnchanged());
    } else return error.MissingSharedNesting;
}

test "shared resolution copies and guarded views unwind every allocation failure" {
    if (comptime @hasDecl(selector.nesting, "SharedList")) {
        try std.testing.checkAllAllocationFailures(a, exactCounts, .{});
        try std.testing.checkAllAllocationFailures(a, copyHolds, .{});
        try std.testing.checkAllAllocationFailures(a, guardedViews, .{});
    } else return error.MissingSharedNesting;
}
