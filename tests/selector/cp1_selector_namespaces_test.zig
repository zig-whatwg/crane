//! CSS Namespaces 3 and Selectors 4: namespaces are resolved while parsing.
const std = @import("std");
const selector = @import("selector");

fn resolve(_: ?*const anyopaque, prefix: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, prefix, "svg")) return "http://www.w3.org/2000/svg";
    if (std.mem.eql(u8, prefix, "x")) return "urn:x";
    if (std.mem.eql(u8, prefix, "empty")) return "";
    return null;
}

const options: selector.parser.ParseOptions = .{
    .namespaces = .{ .resolve = resolve, .default = "urn:default" },
};

fn parsedCases(a: std.mem.Allocator) !void {
    var names = try selector.parseWithOptions(a, "svg|a[x|href='yes']", options);
    defer names.deinit();
    const subject = names.selectors[0].compound.simple_selectors;
    try std.testing.expectEqualStrings("a", subject[0].Type.tag_name);
    try std.testing.expectEqualStrings("http://www.w3.org/2000/svg", subject[1].NamespaceURI.uri);
    try std.testing.expectEqualStrings("urn:x", subject[2].NamespacedAttribute.uri);
    try std.testing.expectEqualDeep(selector.Specificity{ .element = 1, .class = 1 }, names.selectors[0].calculateSpecificity());

    var defaults = try selector.parseWithOptions(a, ".x, *|*.x, |*.x, [href]", options);
    defer defaults.deinit();
    try std.testing.expectEqualStrings("urn:default", defaults.selectors[0].compound.simple_selectors[0].NamespaceURI.uri);
    try std.testing.expectEqual(.any, defaults.selectors[1].compound.simple_selectors[0].Universal.namespace);
    try std.testing.expectEqual(.none, defaults.selectors[2].compound.simple_selectors[0].Universal.namespace);
    try std.testing.expectEqual(.none, defaults.selectors[3].compound.simple_selectors[1].Attribute.namespace);
}

test "declared prefixes and default namespaces resolve to owned constraints" {
    try parsedCases(std.testing.allocator);
}

test "namespace selector parsing unwinds every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, parsedCases, .{});
}

test "undeclared and incorrectly cased prefixes are invalid" {
    const a = std.testing.allocator;
    try std.testing.expectError(error.InvalidSelector, selector.parseWithOptions(a, "missing|a", options));
    try std.testing.expectError(error.InvalidSelector, selector.parseWithOptions(a, "[missing|a]", options));
    try std.testing.expectError(error.InvalidSelector, selector.parseWithOptions(a, "SVG|a", options));
}

test "DOM parsing does not acquire a stylesheet namespace resolver" {
    try std.testing.expectError(error.InvalidSelector, selector.parse(std.testing.allocator, "svg|a"));
    try std.testing.expectError(error.InvalidSelector, selector.parse(std.testing.allocator, "[x|href]"));
    var old = try selector.parse(std.testing.allocator, "*|a, |a, [*|href], [|href]");
    defer old.deinit();
    try std.testing.expectEqual(@as(usize, 4), old.selectors.len);
}

test "logical combination subjects ignore implicit default namespaces only" {
    const a = std.testing.allocator;
    var list = try selector.parseWithOptions(a, "*|*:is(.ancestor .subject, *.explicit):not(.n):where(.w)", options);
    defer list.deinit();
    const simples = list.selectors[0].compound.simple_selectors;
    const logical = simples[1].PseudoClass.kind.Is;
    try std.testing.expectEqual(.Class, std.meta.activeTag(logical.selectors[0].compound.simple_selectors[0]));
    try std.testing.expectEqualStrings("urn:default", logical.selectors[0].combinators[0].compound.simple_selectors[0].NamespaceURI.uri);
    try std.testing.expectEqualStrings("urn:default", logical.selectors[1].compound.simple_selectors[1].NamespaceURI.uri);
    try std.testing.expectEqual(.Class, std.meta.activeTag(simples[2].PseudoClass.kind.Not.selectors[0].compound.simple_selectors[0]));
    try std.testing.expectEqual(.Class, std.meta.activeTag(simples[3].PseudoClass.kind.Where.selectors[0].compound.simple_selectors[0]));
}
