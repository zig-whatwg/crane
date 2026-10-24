//! CSS Backgrounds3 §5.1: border-image-source is one image, with provenance.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn expectImage(input: []const u8, expected: ?[]const u8) !void {
    const property = css.properties.lookup("border-image-source") orelse return error.BorderImageSourceNotImplemented;
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |a| a.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expectEqual(expected != null, try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, property, input, &assignments));
    if (expected) |text| {
        try testing.expectEqual(@as(usize, 1), assignments.items.len);
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try css.properties.serializeAssigned(property.longhand, assignments.items[0].value, &out, testing.allocator);
        try testing.expectEqualStrings(text, out.items);
    }
}

test "border-image-source accepts one image and rejects malformed alternatives" {
    try expectImage("none", "none");
    try expectImage("url(frame.png)", "url(\"frame.png\")");
    try expectImage("url('#frame')", "url(\"#frame\")");
    for ([_][]const u8{ "", "auto", "url(a) url(b)", "url(a), url(b)", "none none", "red", "url(a) 2x" }) |bad| try expectImage(bad, null);
}

fn allocationCase(allocator: std.mem.Allocator) !void {
    const property = css.properties.lookup("border-image-source") orelse return error.BorderImageSourceNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "border-image-source:url(#frame)");
    defer block.deinit();
    const parent = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer parent.destroy();
    try testing.expectEqual(@as(usize, 1), parent.get(property.longhand).resourceUrls().len);
    const child = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{});
    defer child.destroy();
    try testing.expect(child.get(property.longhand).isKeyword(.none));
    var inherited = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, "border-image-source:inherit");
    defer inherited.deinit();
    const inheriting = try css.cascade.cascade(.{ .allocator = allocator, .parent = parent }, &.{.{ .block = &inherited, .source = .{ .origin = .author } }});
    defer inheriting.destroy();
    try testing.expect(inheriting.get(property.longhand).eql(parent.get(property.longhand)));
    try testing.expectEqual(@as(usize, 1), inheriting.get(property.longhand).resourceUrls().len);
}

test "border-image-source initial inheritance and ownership survive allocation failures" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationCase, .{});
}

fn expectBlock(input: []const u8, name: []const u8, expected: []const u8) !void {
    if (css.properties.lookup("border-image-source") == null) return error.BorderImageSourceNotImplemented;
    var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = testing.allocator }, input);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    try block.getPropertyValue(name, &out);
    try testing.expectEqualStrings(expected, out.items);
}

test "border resets its image source but a side shorthand preserves it" {
    try expectBlock("border-image-source:url(frame);border:1px solid", "border-image-source", "none");
    try expectBlock("border-image-source:url(frame);border-top:1px solid", "border-image-source", "url(\"frame\")");
    try expectBlock("border-image-source:url(frame);border-right:1px solid", "border-image-source", "url(\"frame\")");
    try expectBlock("border-image-source:url(frame);border-bottom:1px solid", "border-image-source", "url(\"frame\")");
    try expectBlock("border-image-source:url(frame);border-left:1px solid", "border-image-source", "url(\"frame\")");
    try expectBlock("border:1px solid;border-image-source:url(frame)", "border", "");
    try expectBlock("border:1px solid;border-image-source:none", "border", "1px solid");
    try expectBlock("border:inherit", "border-image-source", "inherit");
    try expectBlock("border:initial", "border-image-source", "initial");
}

const UrlResolver = struct {
    base: []const u8 = "https://old.test/css/",
    calls: usize = 0,
    oom: bool = false,
    fn resolve(context: *const anyopaque, allocator: std.mem.Allocator, raw: []const u8) ?[]u8 {
        const self: *UrlResolver = @ptrCast(@alignCast(@constCast(context)));
        self.calls += 1;
        return std.mem.concat(allocator, u8, &.{ self.base, raw }) catch {
            self.oom = true;
            return null;
        };
    }
};

fn frozenUrlCase(allocator: std.mem.Allocator) !void {
    const property = css.properties.lookup("border-image-source") orelse return error.BorderImageSourceNotImplemented;
    for ([_]struct { input: []const u8, specified: []const u8, computed: []const u8, raw: []const u8 }{
        .{ .input = "url(frame.svg)", .specified = "url(\"frame.svg\")", .computed = "url(\"https://old.test/css/frame.svg\")", .raw = "frame.svg" },
        .{ .input = "url('#frame')", .specified = "url(\"#frame\")", .computed = "url(\"#frame\")", .raw = "#frame" },
        .{ .input = "url('')", .specified = "url(\"\")", .computed = "url(\"\")", .raw = "" },
    }) |case| {
        var resolver = UrlResolver{};
        const style = blk: {
            const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://old.test/css/style.css", .referrer_policy = "no-referrer" });
            defer source.unref();
            var block = css.declarations.DeclarationBlock.init(allocator);
            defer block.deinit();
            try testing.expect(try block.setProperty(.{ .allocator = allocator, .resource_source = source, .url_resolver = .{ .context = &resolver, .resolve = UrlResolver.resolve } }, "border-image-source", case.input, ""));
            if (resolver.oom) return error.OutOfMemory;
            var specified: std.ArrayList(u8) = .empty;
            defer specified.deinit(allocator);
            try block.getPropertyValue("border-image-source", &specified);
            try testing.expectEqualStrings(case.specified, specified.items);
            resolver.base = "https://changed.test/";
            break :blk try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        };
        defer style.destroy();
        const calls = resolver.calls;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try style.serializeResolved(property.longhand, &out, allocator);
        try testing.expectEqualStrings(case.computed, out.items);
        try testing.expectEqual(calls, resolver.calls);
        const urls = style.get(property.longhand).resourceUrls();
        try testing.expectEqual(@as(usize, 1), urls.len);
        try testing.expectEqual(case.raw.len != 0, urls[0].valid);
        try testing.expectEqual(std.mem.startsWith(u8, case.raw, "#"), urls[0].local_fragment);
        try testing.expectEqualStrings("https://old.test/css/style.css", urls[0].source.?.base_url);
        try testing.expectEqualStrings("no-referrer", urls[0].source.?.referrer_policy);
        if (case.raw.len == 0) {
            try testing.expectEqualStrings("", urls[0].url);
        } else {
            const absolute = try std.mem.concat(allocator, u8, &.{ "https://old.test/css/", case.raw });
            defer allocator.free(absolute);
            try testing.expectEqualStrings(absolute, urls[0].url);
        }
    }
}

test "border-image-source preserves authored local and empty URLs with frozen owned resolution" {
    try testing.checkAllAllocationFailures(testing.allocator, frozenUrlCase, .{});
}
