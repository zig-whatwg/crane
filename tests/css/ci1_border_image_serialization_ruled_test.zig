//! UNRUN NEW Q174 PART2 supplement. Existing public APIs; no production patch.
//! Golden rule2 evidence: main/tmp/analysis/integrator-probes-1024c/.
//! Q173 permits only minimal parser extraction; mask serialization stays unchanged.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const family = [_][]const u8{ "border-image-source", "border-image-slice", "border-image-width", "border-image-outset", "border-image-repeat" };
fn shorthand() !css.properties.Shorthand {
    for (family) |name| _ = css.properties.lookup(name) orelse return error.BorderImageFamilyNotImplemented;
    return (css.properties.lookup("border-image") orelse return error.BorderImageFamilyNotImplemented).shorthand;
}
fn expectProperty(block: *const css.declarations.DeclarationBlock, name: []const u8, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(block.allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}
fn expectComputedShorthand(style: *const css.computed_style.ComputedStyle, expected: []const u8, allocator: Allocator) !void {
    const sh = try shorthand();
    var assigned: [5]css.properties.Assigned = undefined;
    for (sh.longhands(), &assigned) |l, *v| v.* = .{ .value = style.get(l) };
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try testing.expect(try css.properties.serializeShorthand(sh, &assigned, .computed, &out, allocator));
    try testing.expectEqualStrings(expected, out.items);
}
fn specifiedCase(allocator: Allocator) !void {
    _ = try shorthand();
    // Literal expected strings independently pin the ruled mode, not its formatter.
    const Case = struct { input: []const u8, expected: []const u8 };
    for ([_]Case{
        .{ .input = "none", .expected = "none" },
        .{ .input = "none 20", .expected = "20" },
        .{ .input = "none repeat", .expected = "repeat" },
        .{ .input = "20 / / 2", .expected = "20 / / 2" },
        .{ .input = "100% / 2", .expected = "100% / 2" },
        .{ .input = "100% / / 2", .expected = "100% / / 2" },
        .{ .input = "url(a) 100% / 2", .expected = "url(\"a\") 100% / 2" },
        .{ .input = "url(a)", .expected = "url(\"a\")" },
        .{ .input = "100% / 1 / 0 stretch", .expected = "none" },
    }) |c| {
        var block = css.declarations.DeclarationBlock.init(allocator);
        defer block.deinit();
        try testing.expect(try block.setProperty(.{ .allocator = allocator }, "border-image", c.input, ""));
        try testing.expectEqual(@as(usize, 5), block.length());
        try expectProperty(&block, "border-image", c.expected);
        var serialized: std.ArrayList(u8) = .empty;
        defer serialized.deinit(allocator);
        try block.serialize(&serialized);
        const expected_css_text = try std.mem.concat(allocator, u8, &.{ "border-image: ", c.expected, ";" });
        defer allocator.free(expected_css_text);
        try testing.expectEqualStrings(expected_css_text, serialized.items);
    }
}
test "ci1 Q174 specified shortest border image preserves required slice and slash context all OOM" {
    try specifiedCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, specifiedCase, .{});
}
fn noneCase(allocator: Allocator) !void {
    _ = try shorthand();
    for ([_][]const u8{
        "border-image:none",     "border-image:none 20",  "border-image:none repeat",
        "border-image:20 / / 2", "border-image:100% / 2", "border-image:100% / / 2",
        "border-image-width:2",  "border-image-outset:2",
    }) |text| {
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, text);
        defer block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        try expectComputedShorthand(style, "none", allocator);
    }
}
test "ci1 Q174 computed none source hides other shorthand values all OOM" {
    try noneCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, noneCase, .{});
}
const Resolver = struct {
    absolute: []const u8 = "https://frozen.test/css/a",
    calls: usize = 0,
    oom: bool = false,
    fn resolve(context: *const anyopaque, allocator: Allocator, raw: []const u8) ?[]u8 {
        const self: *Resolver = @ptrCast(@alignCast(@constCast(context)));
        self.calls += 1;
        if (!std.mem.eql(u8, raw, "a")) return null;
        return allocator.dupe(u8, self.absolute) catch {
            self.oom = true;
            return null;
        };
    }
};
fn frozenComputedCase(allocator: Allocator) !void {
    _ = try shorthand();
    const Case = struct { property: []const u8 = "border-image", input: []const u8, specified: []const u8, computed: []const u8 };
    for ([_]Case{
        .{ .input = "url(a)", .specified = "url(\"a\")", .computed = "url(\"https://frozen.test/css/a\") 100% / 1 / 0 stretch" },
        .{ .property = "border-image-source", .input = "url(a)", .specified = "url(\"a\")", .computed = "url(\"https://frozen.test/css/a\") 100% / 1 / 0 stretch" },
        .{ .input = "url(a) 100% / 2", .specified = "url(\"a\") 100% / 2", .computed = "url(\"https://frozen.test/css/a\") 100% / 2 / 0 stretch" },
        .{ .input = "url(a) 20 / 2 / 3 round", .specified = "url(\"a\") 20 / 2 / 3 round", .computed = "url(\"https://frozen.test/css/a\") 20 / 2 / 3 round" },
    }) |c| {
        var resolver = Resolver{};
        const style = blk: {
            const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://frozen.test/css/style.css", .referrer_policy = "no-referrer" });
            defer source.unref();
            var block = css.declarations.DeclarationBlock.init(allocator);
            defer block.deinit();
            try testing.expect(try block.setProperty(.{ .allocator = allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = Resolver.resolve } }, c.property, c.input, ""));
            if (resolver.oom) return error.OutOfMemory;
            try expectProperty(&block, c.property, c.specified);
            resolver.absolute = "https://changed.test/a";
            break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        };
        defer style.destroy();
        const calls = resolver.calls;
        try expectComputedShorthand(style, c.computed, allocator);
        try testing.expectEqual(calls, resolver.calls);
        const image = style.get(css.properties.lookup(family[0]).?.longhand);
        try testing.expectEqualStrings("https://frozen.test/css/a", image.resourceUrls()[0].url);
        try testing.expectEqualStrings("no-referrer", image.resourceUrls()[0].source.?.referrer_policy);
    }
}
test "ci1 Q174 computed nonnone source fully expands frozen absolute URL after owners release all OOM" {
    try frozenComputedCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, frozenComputedCase, .{});
}
fn mixedResetCase(allocator: Allocator) !void {
    _ = try shorthand();
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "border-image:none 20 / 2 / 3; border-image-repeat:stretch!important");
    defer block.deinit();
    try expectProperty(&block, "border-image", "");
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.serialize(&out);
    try testing.expectEqualStrings("border-image-source: none; border-image-slice: 20; border-image-width: 2; border-image-outset: 3; border-image-repeat: stretch !important;", out.items);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    try expectComputedShorthand(style, "none", allocator);
    // No removeProperty return-value assertion: explicitly outside Q174.
    var reset = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "border-image:url(a) 20 / 2 / 3 round;border:5px dotted blue");
    defer reset.deinit();
    try expectProperty(&reset, "border-image", "none");
    try expectProperty(&reset, "border", "5px dotted blue");
    const reset_style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &reset, .source = .{ .origin = .author } }});
    defer reset_style.destroy();
    try expectComputedShorthand(reset_style, "none", allocator);
}
test "ci1 Q174 mixed priority cssText uses five longhand order and border resets image all OOM" {
    try mixedResetCase(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, mixedResetCase, .{});
}
