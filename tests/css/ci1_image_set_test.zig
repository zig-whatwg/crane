//! CSS Images4 §2.4: typed candidates, deterministic filtering and provenance.
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn parse(allocator: std.mem.Allocator, input: []const u8) !css.style_values.Value {
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(.{ .allocator = allocator }, .{ .longhand = .list_style_image }, input, &assignments));
    try testing.expectEqual(@as(usize, 1), assignments.items.len);
    const result = assignments.items[0].value.value;
    result.retain();
    return result;
}

const Checks = if (@hasDecl(css, "image_values")) struct {
    const images = css.image_values;
    const context: u8 = 0;

    fn supported(_: *const anyopaque, mime: []const u8) bool {
        return std.ascii.eqlIgnoreCase(mime, "image/png");
    }

    fn selection() !void {
        const value = try parse(testing.allocator, "image-set(url(unsupported) type('image/unknown') 1x, url(first) 1x type('image/png'), url(duplicate) 1x, url(high) 3x, url(middle) 2x)");
        defer value.release();
        const set = images.view(value).?.image_set;
        try testing.expectEqual(@as(usize, 5), set.candidates.len);
        const support = images.TypeSupport{ .context = &context, .supports = supported };
        // Images4 selection steps 1–3: type filtering precedes deduplication.
        try testing.expectEqual(@as(?usize, 1), images.select(set.candidates, 1, support));
        // Blink/WebKit UA choice: first resolution >= DPR, else largest.
        try testing.expectEqual(@as(?usize, 4), images.select(set.candidates, 1.5, support));
        try testing.expectEqual(@as(?usize, 3), images.select(set.candidates, 4, support));
        try testing.expectEqual(@as(usize, 5), set.candidates.len);
        try testing.expectEqualStrings("first", images.view(set.candidates[1].image).?.url.url);
    }

    fn noSupportedCandidate() !void {
        const value = try parse(testing.allocator, "image-set(url(a) type('image/unknown'), url(b) 2x type('text/plain'))");
        defer value.release();
        const set = images.view(value).?.image_set;
        try testing.expectEqual(@as(?usize, null), images.select(set.candidates, 1, .{ .context = &context, .supports = supported }));
        try testing.expectEqual(@as(f64, 1), set.candidates[0].resolution_dppx);
        try testing.expect(!set.candidates[0].resolution_explicit);
    }

    fn crossFade(allocator: std.mem.Allocator) !void {
        const value = try parse(allocator, "image-set(-webkit-cross-fade(url(a), image-set(url(b) 1x), 50%) 1x)");
        defer value.release();
        const set = images.view(value).?.image_set;
        const cross = images.view(set.candidates[0].image).?.cross_fade;
        try testing.expectEqual(@as(f64, 0.5), cross.weight);
        try testing.expectEqualStrings("a", images.view(cross.inputs[0]).?.url.url);
        try testing.expectEqual(@as(usize, 1), images.view(cross.inputs[1]).?.image_set.candidates.len);
        const urls = value.resourceUrls();
        try testing.expectEqual(@as(usize, 2), urls.len);
        try testing.expectEqualStrings("a", urls[0].url);
        try testing.expectEqualStrings("b", urls[1].url);
    }

    fn zeroResolution() !void {
        const zero = try parse(testing.allocator, "image-set(url(zero) 0x)");
        defer zero.release();
        const support = images.TypeSupport{ .context = &context, .supports = supported };
        try testing.expectEqual(@as(?usize, null), images.select(images.view(zero).?.image_set.candidates, 1, support));
        const mixed = try parse(testing.allocator, "image-set(url(zero) 0x, url(usable) 0.5x)");
        defer mixed.release();
        try testing.expectEqual(@as(?usize, 1), images.select(images.view(mixed).?.image_set.candidates, 1, support));
    }
} else struct {};

test "image-set filters types before duplicates and selects without mutating candidates" {
    if (comptime !@hasDecl(css, "image_values")) return error.TypedImagesNotImplemented;
    try Checks.selection();
}

test "image-set without a supported candidate is invalid and omitted resolution is 1x" {
    if (comptime !@hasDecl(css, "image_values")) return error.TypedImagesNotImplemented;
    try Checks.noSupportedCandidate();
}

test "legacy cross-fade preserves both inputs and allows an indirect image-set" {
    if (comptime !@hasDecl(css, "image_values")) return error.TypedImagesNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, Checks.crossFade, .{});
}

test "a zero-resolution candidate remains specified but never becomes a usable image" {
    if (comptime !@hasDecl(css, "image_values")) return error.TypedImagesNotImplemented;
    try Checks.zeroResolution();
}

test "image-set nested directly or in an opaque image function is invalid" {
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(testing.allocator);
    }
    try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = .list_style_image }, "image-set(image-set(url(a) 1x) 1x)", &assignments));
    try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = .list_style_image }, "image-set(image(image-set(url(a)) 2x) 2x)", &assignments));
}

// Q36, integrator-probes-1022k/results/ldnest-{chrome,firefox,safari}.json:
// Firefox/Safari reject indirect nesting through either light-dark branch;
// Chrome accepts it. All three accept light-dark outside image-set.
test "light-dark preserves image-set nesting restrictions in both branches" {
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |item| item.value.release();
        assignments.deinit(testing.allocator);
    }
    for ([_][]const u8{
        "image-set(light-dark(image-set(url(a) 1x), url(b)) 1x)",
        "image-set(light-dark(url(a), image-set(url(b) 1x)) 1x)",
    }) |input| try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = testing.allocator }, .{ .longhand = .list_style_image }, input, &assignments));
    for ([_][]const u8{
        "light-dark(image-set(url(a) 1x), url(b))",
        "light-dark(url(a), url(b))",
    }) |input| {
        const value = try parse(testing.allocator, input);
        defer value.release();
    }
}

fn nested(allocator: std.mem.Allocator, depth: usize) ![]u8 {
    var text: std.ArrayList(u8) = .empty;
    errdefer text.deinit(allocator);
    for (0..depth) |_| try text.appendSlice(allocator, "light-dark(");
    try text.appendSlice(allocator, "url(at-depth)");
    for (0..depth) |_| try text.appendSlice(allocator, ", none)");
    return text.toOwnedSlice(allocator);
}

const DepthChecks = if (@hasDecl(css, "image_values")) struct {
    fn accepted(allocator: std.mem.Allocator) !void {
        const input = try nested(allocator, 128);
        defer allocator.free(input);
        const declaration = try std.fmt.allocPrint(allocator, "list-style-image:{s}", .{input});
        defer allocator.free(declaration);
        var block = try css.declarations.DeclarationBlock.parse(.{ .allocator = allocator }, declaration);
        var block_owned = true;
        defer if (block_owned) block.deinit();
        const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
        defer style.destroy();
        block.deinit();
        block_owned = false;
        // The computed selected leaf must outlive every specified wrapper.
        const image = css.image_values.view(style.get(.list_style_image)) orelse return error.ExpectedImage;
        try testing.expect(image == .url);
        try testing.expectEqualStrings("at-depth", image.url.url);
    }

    fn rejected(allocator: std.mem.Allocator) !void {
        const input = try nested(allocator, 129);
        defer allocator.free(input);
        var assignments: std.ArrayList(css.properties.Assignment) = .empty;
        defer {
            for (assignments.items) |item| item.value.release();
            assignments.deinit(allocator);
        }
        try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator }, .{ .longhand = .list_style_image }, input, &assignments));
        try testing.expectEqual(@as(usize, 0), assignments.items.len);
    }
} else struct {};

test "128 composite image levels parse compute and release at every allocation failure" {
    if (comptime !@hasDecl(css, "image_values")) return error.TypedImagesNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, DepthChecks.accepted, .{});
}

test "129 composite image levels reject without a partial value or leaked reference" {
    if (comptime !@hasDecl(css, "image_values")) return error.TypedImagesNotImplemented;
    try testing.checkAllAllocationFailures(testing.allocator, DepthChecks.rejected, .{});
}
