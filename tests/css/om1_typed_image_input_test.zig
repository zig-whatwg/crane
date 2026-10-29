//! Q66: native images use the existing grammar and preserve URL provenance.
const std = @import("std");
const css = @import("css");
const a = std.testing.allocator;
const Resolver = struct {
    calls: usize = 0,
    oom: bool = false,
    prefix: []const u8,
    fn resolve(context: *const anyopaque, allocator: std.mem.Allocator, raw: []const u8) ?[]u8 {
        const self: *@This() = @ptrCast(@alignCast(@constCast(context)));
        self.calls += 1;
        return std.mem.concat(allocator, u8, &.{ self.prefix, raw }) catch {
            self.oom = true;
            return null;
        };
    }
};

fn imageAssignment(allocator: std.mem.Allocator, target_name: []const u8) anyerror!void {
    if (comptime !@hasDecl(css.properties, "parseTypedImage")) return std.testing.expect(false);
    const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://old.test/style.css", .referrer_policy = "no-referrer", .origin_clean = false });
    var source_owned = true;
    defer if (source_owned) source.unref();
    var original = Resolver{ .prefix = "https://old.test/" };
    var later = Resolver{ .prefix = "https://new.test/" };
    var parsed: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (parsed.items) |assignment| assignment.value.release();
        parsed.deinit(allocator);
    }
    const okay = try css.properties.parseDeclaration(.{
        .allocator = allocator,
        .resource_source = source,
        .url_resolver = .{ .context = &original, .resolve = Resolver.resolve },
    }, (css.properties.lookup("background-image") orelse return error.MissingProperty), "url(picture.svg)", &parsed);
    if (original.oom) return error.OutOfMemory;
    try std.testing.expect(okay);
    const native = parsed.items[0].value.value;
    const property = (css.properties.lookup(target_name) orelse return error.MissingProperty);
    var output: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (output.items) |assignment| assignment.value.release();
        output.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseTypedImage(.{
        .allocator = allocator,
        .url_resolver = .{ .context = &later, .resolve = Resolver.resolve },
    }, property, native, &output));
    try std.testing.expectEqual(@as(usize, 0), later.calls);
    try std.testing.expectEqual(@as(usize, 1), original.calls);
    for (parsed.items) |assignment| assignment.value.release();
    parsed.clearRetainingCapacity();
    source.unref();
    source_owned = false;
    var seen: usize = 0;
    for (output.items) |assignment| {
        for (assignment.value.value.resourceUrls()) |url| {
            seen += 1;
            try std.testing.expectEqualStrings("https://old.test/picture.svg", url.url);
            try std.testing.expect(url.source.? == source);
            try std.testing.expectEqualStrings("https://old.test/style.css", url.source.?.base_url);
            try std.testing.expectEqualStrings("no-referrer", url.source.?.referrer_policy);
            try std.testing.expect(!url.source.?.origin_clean);
        }
    }
    try std.testing.expectEqual(@as(usize, 1), seen);
}

test "native images match existing image longhands and shorthand without resolving URLs again" {
    for ([_][]const u8{ "background-image", "list-style-image", "background" }) |name| try imageAssignment(a, name);
}

test "native image ownership and shorthand expansion unwind every allocation failure" {
    for ([_][]const u8{ "background-image", "list-style-image", "background" }) |name|
        try std.testing.checkAllAllocationFailures(a, imageAssignment, .{name});
}

fn reject(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css.properties, "parseTypedImage")) return std.testing.expect(false);
    var parsed: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (parsed.items) |assignment| assignment.value.release();
        parsed.deinit(allocator);
    }
    try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, (css.properties.lookup("background-image") orelse return error.MissingProperty), "url(a)", &parsed));
    var output: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (output.items) |assignment| assignment.value.release();
        output.deinit(allocator);
    }
    for ([_][]const u8{ "width", "color", "font-family", "animation-name" }) |name| {
        try std.testing.expect(!try css.properties.parseTypedImage(.{ .allocator = allocator }, (css.properties.lookup(name) orelse return error.MissingProperty), parsed.items[0].value.value, &output));
        try std.testing.expectEqual(@as(usize, 0), output.items.len);
    }
    try std.testing.expect(!try css.properties.parseTypedImage(.{ .allocator = allocator }, (css.properties.lookup("background-image") orelse return error.MissingProperty), .{ .keyword = .none }, &output));
    // There is no CSS-text argument to the native entry. Ordinary lookalikes
    // and trailing text are parsed entirely by the unchanged CSS tokenizer.
    for ([_][]const u8{ "__crane_typed_image__()", "url(a) junk", "url(a) 1px" }) |text|
        try std.testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator }, (css.properties.lookup("background-image") orelse return error.MissingProperty), text, &output));
}

test "native image marker is private and wrong grammars reject without partial assignments" {
    try std.testing.checkAllAllocationFailures(a, reject, .{});
}

fn layers(allocator: std.mem.Allocator) anyerror!void {
    if (comptime !@hasDecl(css.typed_om, "property_lists")) return std.testing.expect(false);
    var parsed: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (parsed.items) |assignment| assignment.value.release();
        parsed.deinit(allocator);
    }
    const property = (css.properties.lookup("background-image") orelse return error.MissingProperty);
    for ([_][]const u8{ "url(a)", "url(b), none" }) |text|
        try std.testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, property, text, &parsed));
    const joined = try css.typed_om.property_lists.concat(allocator, .background_image, &.{ parsed.items[0].value.value, parsed.items[1].value.value });
    defer joined.release();
    for (parsed.items) |assignment| assignment.value.release();
    parsed.clearRetainingCapacity();
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try css.properties.serializeValue(.background_image, joined, &text, allocator);
    try std.testing.expectEqualStrings("url(\"a\"), url(\"b\"), none", text.items);
}

test "native image list joining keeps all components after their source owners are released" {
    try std.testing.checkAllAllocationFailures(a, layers, .{});
}
