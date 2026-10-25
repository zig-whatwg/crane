//! Q205 draft: original declaration random scope reaches typed content images.
//! Values5 §§9.1, 9.4–9.4.1; production declaration parsing, public queries only.
//! UNRUN: install and record RED on d2's actual typed-parser parent before fixing.
const std = @import("std");
const css = @import("css");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Value = css.style_values.Value;

fn parseContent(options: css.properties.ParseOptions, text: []const u8) !Value {
    // ArrayList is required by the production parser's public signature.
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(options.allocator);
    }
    try testing.expect(try css.properties.parseDeclaration(options, .{ .longhand = .content }, text, &assignments));
    try testing.expectEqual(@as(usize, 1), assignments.items.len);
    try testing.expectEqual(css.properties.Longhand.content, assignments.items[0].longhand);
    const assigned = assignments.items[0].value;
    try testing.expect(assigned == .value);
    try testing.expect(assigned.value == .content);
    assigned.value.retain();
    return assigned.value;
}

fn expectText(allocator: Allocator, value: Value, expected: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try css.properties.serializeValue(.content, value, &out, allocator);
    try testing.expectEqualStrings(expected, out.items);
}

fn specified(allocator: Allocator, input: []const u8, expected: []const u8, needs_random: bool) !void {
    // parseDeclaration constructs and destroys its real scope; this helper
    // neither fabricates a key nor supplies its own context.
    const value = try parseContent(.{ .allocator = allocator }, input);
    defer value.release();
    try expectText(allocator, value, expected);
    try testing.expectEqual(needs_random, value.needsRandomBase());
    try testing.expect(!value.needsTreeCounts());
    try testing.expect(!value.needsUnavailableMetrics(false));
}

test "Q205 content omitted and auto random keys use the original declaration identity" {
    for ([_][]const u8{
        "linear-gradient(red random(1px, 2px), blue)",
        "linear-gradient(red random(auto, 1px, 2px), blue)",
    }) |input| try specified(testing.allocator, input, "linear-gradient(red random(element-scoped ua-content-1, 1px, 2px), blue)", true);
}

test "Q205 content property-dependent keys normalize through the existing math owner" {
    const Case = struct { input: []const u8, expected: []const u8 };
    for ([_]Case{
        .{ .input = "linear-gradient(red random(property-scoped, 1px, 2px), blue)", .expected = "linear-gradient(red random(ua-content, 1px, 2px), blue)" },
        .{ .input = "linear-gradient(red random(property-index-scoped, 1px, 2px), blue)", .expected = "linear-gradient(red random(ua-content-1, 1px, 2px), blue)" },
        .{ .input = "linear-gradient(red random(--shared element-scoped property-index-scoped, 1px, 2px), blue)", .expected = "linear-gradient(red random(--shared element-scoped ua-content-1, 1px, 2px), blue)" },
    }) |case| try specified(testing.allocator, case.input, case.expected, true);
}

test "Q205 content fixed named and source-independent cache keys are positive controls" {
    const Case = struct { input: []const u8, expected: []const u8, needs_random: bool = true };
    for ([_]Case{
        // Mixed length/percentage prevents fixed-value constant folding.
        .{ .input = "linear-gradient(red random(fixed .5, 1px, 2%), blue)", .expected = "linear-gradient(red random(fixed 0.5, 1px, 2%), blue)", .needs_random = false },
        .{ .input = "linear-gradient(red random(--named, 1px, 2px), blue)", .expected = "linear-gradient(red random(--named, 1px, 2px), blue)" },
        .{ .input = "linear-gradient(red random(element-scoped, 1px, 2px), blue)", .expected = "linear-gradient(red random(element-scoped, 1px, 2px), blue)" },
        .{ .input = "linear-gradient(red random(ua-explicit, 1px, 2px), blue)", .expected = "linear-gradient(red random(ua-explicit, 1px, 2px), blue)" },
    }) |case| try specified(testing.allocator, case.input, case.expected, case.needs_random);
}

const multiple_input = "  /* random(99px, 100px) */ \"random(7px, 8px)\" " ++
    "linear-gradient(red random(--named, 1px, 2px), blue) " ++
    "linear-gradient(red random(fixed .5, 1px, 2%), blue) " ++
    "linear-gradient(red random(auto, 3px, 4px), blue random(5px, 6px))";
const multiple_expected = "\"random(7px, 8px)\" " ++
    "linear-gradient(red random(--named, 1px, 2px), blue) " ++
    "linear-gradient(red random(fixed 0.5, 1px, 2%), blue) " ++
    "linear-gradient(red random(element-scoped ua-content-3, 3px, 4px), blue random(element-scoped ua-content-4, 5px, 6px))";

test "Q205 content ordinals span images count fixed and named functions and ignore strings and comments" {
    try specified(testing.allocator, multiple_input, multiple_expected, true);
}

const nested_input = "linear-gradient(red random(random(1px, 2px), 3px), blue random(auto, 4px, 5px))";
const nested_expected = "linear-gradient(red random(element-scoped ua-content-1, random(element-scoped ua-content-2, 1px, 2px), 3px), blue random(element-scoped ua-content-3, 4px, 5px))";

test "Q205 content nested numeric random assigns the outer ordinal before its children" {
    try specified(testing.allocator, nested_input, nested_expected, true);
    // The outer fixed function still consumes ordinal #1. Its numeric base
    // needs #2 even though the outer function itself has no cache key.
    try specified(testing.allocator, "linear-gradient(red random(fixed random(0, 1), 1px, 2px), blue)", "linear-gradient(red random(fixed random(element-scoped ua-content-2, 0, 1), 1px, 2px), blue)", true);
}

test "Q205 content radial retry and conic position keep declaration token ordinals" {
    try specified(testing.allocator, "radial-gradient(circle random(1px, 2px), red random(auto, 3px, 4px), blue)", "radial-gradient(random(element-scoped ua-content-1, 1px, 2px), red random(element-scoped ua-content-2, 3px, 4px), blue)", true);
    try specified(testing.allocator, "conic-gradient(at random(1px, 2px) random(auto, 3px, 4px), red, blue)", "conic-gradient(at random(element-scoped ua-content-1, 1px, 2px) random(element-scoped ua-content-2, 3px, 4px), red, blue)", true);
}

const composite_input = "image-set(linear-gradient(red random(1px, 2px), blue) 1x, linear-gradient(red random(auto, 3px, 4px), blue) 2x)";
const composite_expected = "image-set(linear-gradient(red random(element-scoped ua-content-1, 1px, 2px), blue) 1x, linear-gradient(red random(element-scoped ua-content-2, 3px, 4px), blue) 2x)";

test "Q205 content image-set children share the enclosing declaration scope" {
    try specified(testing.allocator, composite_input, composite_expected, true);
}

const KeyProbe = struct {
    named_seen: bool = false,
    auto_seen: bool = false,
    wrong_key: bool = false,

    fn get(raw: *anyopaque, key: css.random_values.CacheKey) Allocator.Error!f64 {
        const self: *KeyProbe = @ptrCast(@alignCast(raw));
        const property = key.property orelse {
            self.wrong_key = true;
            return 0.25;
        };
        if (std.mem.eql(u8, property, "ua-content-9")) {
            self.named_seen = true;
            if (key.name == null or !std.mem.eql(u8, key.name.?, "--owned") or key.element_scoped or key.indexed_function != .numeric) self.wrong_key = true;
        } else if (std.mem.eql(u8, property, "ua-content-10")) {
            self.auto_seen = true;
            if (key.name != null or !key.element_scoped or key.indexed_function != .numeric) self.wrong_key = true;
        } else self.wrong_key = true;
        return 0.25;
    }
};

fn callerScopeLifetime(allocator: Allocator) !void {
    var block = blk: {
        var owned = css.declarations.DeclarationBlock.init(allocator);
        errdefer owned.deinit();
        // An independent temporary allocator owns ALL scope storage and input.
        // The returned declaration block must use its own backing allocator.
        var temporary = std.heap.ArenaAllocator.init(allocator);
        defer temporary.deinit();
        const a = temporary.allocator();
        const input = try a.dupe(u8, "linear-gradient(red random(--prior, 0px, 1px), blue) " ++
            "linear-gradient(red random(--owned property-index-scoped, 1px, 2px), blue random(auto, 3px, 4px))");
        const property = try a.dupe(u8, "content");
        var scope = try css.random_values.ParseScope.init(a, input, property, .{ .numeric_offset = 7 });
        defer scope.deinit();
        const second = std.mem.indexOf(u8, input, ") linear-gradient(") orelse return error.ExpectedSecondImage;
        // A supported original-buffer substring: prior numeric token is #8.
        try testing.expect(try owned.setProperty(.{ .allocator = allocator, .random_scope = &scope }, "content", input[second + 2 ..], ""));
        @memset(input, '?');
        @memset(property, 'x');
        break :blk owned;
    };
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("content", &out);
    try testing.expectEqualStrings("linear-gradient(red random(--owned ua-content-9, 1px, 2px), blue random(element-scoped ua-content-10, 3px, 4px))", out.items);
    const value = (block.get(.content) orelse return error.ExpectedContent).value.value;
    try testing.expect(value.needsRandomBase());
    // Exercise the retained math graph's owned strings, not only cached text.
    var probe = KeyProbe{};
    const computed = try css.cascade.cascade(.{ .allocator = allocator, .parent = null, .random_base = .{ .context = &probe, .get = KeyProbe.get } }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer computed.destroy();
    try testing.expect(probe.named_seen and probe.auto_seen and !probe.wrong_key);
    out.clearRetainingCapacity();
    try computed.serializeResolved(.content, &out, allocator);
    try testing.expectEqualStrings("linear-gradient(rgb(255, 0, 0) 1.25px, rgb(0, 0, 255) 3.25px)", out.items);
}

test "Q205 content borrows caller scope only while parsing an original-buffer substring" {
    try callerScopeLifetime(testing.allocator);
}

fn retainedImageLifetime(allocator: Allocator) !void {
    const survivor = blk: {
        const source = try css.style_values.ResourceSource.create(allocator, .{ .base_url = "https://scope.test/style.css", .referrer_policy = "no-referrer", .origin_clean = false });
        defer source.unref();
        const input = try allocator.dupe(u8, "image-set(linear-gradient(red random(1px, 2px), blue) 1x, url(\"retained.png\") 2x)");
        defer allocator.free(input);
        const content = try parseContent(.{ .allocator = allocator, .resource_source = source }, input);
        defer content.release();
        // Independently retain the typed child before Content and source end.
        const image = content.content.items[0].image orelse return error.ExpectedTypedImage;
        image.retain();
        @memset(input, '?');
        break :blk image;
    };
    defer survivor.release();
    try testing.expect(survivor.needsRandomBase());
    try testing.expect(!survivor.needsTreeCounts());
    var text: std.ArrayList(u8) = .empty;
    defer text.deinit(allocator);
    try css.properties.serializeValue(.list_style_image, survivor, &text, allocator);
    try testing.expectEqualStrings("image-set(linear-gradient(red random(element-scoped ua-content-1, 1px, 2px), blue) 1x, url(\"retained.png\") 2x)", text.items);
    const urls = survivor.resourceUrls();
    try testing.expectEqual(@as(usize, 1), urls.len);
    try testing.expectEqualStrings("retained.png", urls[0].url);
    const source = urls[0].source orelse return error.ExpectedResourceSource;
    try testing.expectEqualStrings("https://scope.test/style.css", source.base_url);
    try testing.expectEqualStrings("no-referrer", source.referrer_policy);
    try testing.expect(!source.origin_clean);
}

test "Q205 retained content image survives input scope content and resource-source owners" {
    try retainedImageLifetime(testing.allocator);
}

fn storedDeclaration(allocator: Allocator, input: []const u8, expected: []const u8) !void {
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    // Includes parser output transfer and destination storage allocations.
    // Injected OutOfMemory propagates through try, never becomes rejection.
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "content", input, ""));
    const value = (block.get(.content) orelse return error.ExpectedStoredContent).value.value;
    try testing.expect(value == .content);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("content", &out);
    try testing.expectEqualStrings(expected, out.items);
}

test "Q205 content allocation walks cover omitted auto fixed named multiple and nested declaration storage" {
    const Case = struct { input: []const u8, expected: []const u8 };
    for ([_]Case{
        .{ .input = "linear-gradient(red random(1px, 2px), blue)", .expected = "linear-gradient(red random(element-scoped ua-content-1, 1px, 2px), blue)" },
        .{ .input = "linear-gradient(red random(auto, 1px, 2px), blue)", .expected = "linear-gradient(red random(element-scoped ua-content-1, 1px, 2px), blue)" },
        .{ .input = "linear-gradient(red random(fixed .5, 1px, 2%), blue)", .expected = "linear-gradient(red random(fixed 0.5, 1px, 2%), blue)" },
        .{ .input = "linear-gradient(red random(--named, 1px, 2px), blue)", .expected = "linear-gradient(red random(--named, 1px, 2px), blue)" },
        .{ .input = "linear-gradient(red random(property-scoped, 1px, 2px), blue)", .expected = "linear-gradient(red random(ua-content, 1px, 2px), blue)" },
        .{ .input = "linear-gradient(red random(property-index-scoped, 1px, 2px), blue)", .expected = "linear-gradient(red random(ua-content-1, 1px, 2px), blue)" },
        .{ .input = "linear-gradient(red random(fixed random(0, 1), 1px, 2px), blue)", .expected = "linear-gradient(red random(fixed random(element-scoped ua-content-2, 0, 1), 1px, 2px), blue)" },
        .{ .input = multiple_input, .expected = multiple_expected },
        .{ .input = nested_input, .expected = nested_expected },
        .{ .input = composite_input, .expected = composite_expected },
    }) |case| try testing.checkAllAllocationFailures(testing.allocator, storedDeclaration, .{ case.input, case.expected });
}

test "Q205 content allocation walks release borrowed-scope and retained-image lifetime paths" {
    try testing.checkAllAllocationFailures(testing.allocator, callerScopeLifetime, .{});
    try testing.checkAllAllocationFailures(testing.allocator, retainedImageLifetime, .{});
}

fn rejectedSuffix(allocator: Allocator) !void {
    var assignments: std.ArrayList(css.properties.Assignment) = .empty;
    defer {
        for (assignments.items) |assignment| assignment.value.release();
        assignments.deinit(allocator);
    }
    // Following successful scope-aware image parsing, an invalid content item
    // must discard that image. An injected allocation error remains an error.
    try testing.expect(!try css.properties.parseDeclaration(.{ .allocator = allocator }, .{ .longhand = .content }, "linear-gradient(red random(1px, 2px), blue) not-a-content-item", &assignments));
    try testing.expectEqual(@as(usize, 0), assignments.items.len);
}

test "Q205 content rejects invalid suffix without retaining a partial typed image at every allocation failure" {
    try rejectedSuffix(testing.allocator);
    try testing.checkAllAllocationFailures(testing.allocator, rejectedSuffix, .{});
}
