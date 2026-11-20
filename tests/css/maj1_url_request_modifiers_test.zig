//! Lane maj1: CSS Values 5 §4.1.1 request URL modifiers - cross-origin(),
//! integrity() and referrer-policy() after a url() or src() function's
//! string: each at most once, serialized in the grammar's order, kept on the
//! value's resource URL for the fetch (CSS Values 4 §4.5.4 step 5), and never
//! in an unquoted url() (Values 4 §4.5.3). Expectations: css/css-values/urls/
//! url-request-modifiers-{computed,serialize,invalid}.sub.html at wpt.fyi
//! aligned run 2358bd4835 - Chrome passes all, Safari cross-origin() and
//! referrer-policy() but not integrity(), Firefox none (golden rule 2: a
//! newer spec one browser ships).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

const Block = css.declarations.DeclarationBlock;
const Style = css.computed_style.ComputedStyle;

const image = "url(\"http://example.test/a.png\"";

fn specified(input: []const u8, out: *std.ArrayList(u8), block: *Block) !bool {
    out.clearRetainingCapacity();
    if (!try block.setProperty(.{ .allocator = testing.allocator }, "background-image", input, "")) return false;
    try block.getPropertyValue("background-image", out);
    return true;
}

fn valid(input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    if (!try specified(input, &out, &block)) {
        std.debug.print("\"{s}\" did not parse\n", .{input});
        return error.TestUnexpectedResult;
    }
    if (!std.mem.eql(u8, expected, out.items)) std.debug.print("\"{s}\" specified\n", .{input});
    try testing.expectEqualStrings(expected, out.items);
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    out.clearRetainingCapacity();
    try style.serializeResolved(.background_image, &out, allocator);
    if (!std.mem.eql(u8, expected, out.items)) std.debug.print("\"{s}\" computed\n", .{input});
    try testing.expectEqualStrings(expected, out.items);
}

fn invalid(input: []const u8) !void {
    var block = Block.init(testing.allocator);
    defer block.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);
    const parsed = try specified(input, &out, &block);
    if (parsed) std.debug.print("\"{s}\" should be invalid\n", .{input});
    try testing.expect(!parsed);
}

test "each request URL modifier parses and serializes" {
    try valid(image ++ ")", image ++ ")");
    try valid(image ++ " cross-origin(anonymous))", image ++ " cross-origin(anonymous))");
    try valid(image ++ " cross-origin(use-credentials))", image ++ " cross-origin(use-credentials))");
    try valid(image ++ " integrity(\"sha384-foobar\"))", image ++ " integrity(\"sha384-foobar\"))");
    try valid(image ++ " integrity(\"\"))", image ++ " integrity(\"\"))");
    for ([_][]const u8{ "no-referrer", "no-referrer-when-downgrade", "same-origin", "origin", "strict-origin", "origin-when-cross-origin", "strict-origin-when-cross-origin", "unsafe-url" }) |policy| {
        var buffer: [160]u8 = undefined;
        const text = try std.fmt.bufPrint(&buffer, image ++ " referrer-policy({s}))", .{policy});
        try valid(text, text);
    }
    // Keywords are ASCII case-insensitive and serialize in lowercase.
    try valid(image ++ " CROSS-ORIGIN(Anonymous))", image ++ " cross-origin(anonymous))");
}

test "modifiers serialize in the grammar's order" {
    const canonical = image ++ " cross-origin(anonymous) integrity(\"sha384-foobar\") referrer-policy(no-referrer))";
    try valid(image ++ " integrity(\"sha384-foobar\") referrer-policy(no-referrer) cross-origin(anonymous))", canonical);
    try valid(image ++ " referrer-policy(no-referrer) cross-origin(anonymous) integrity(\"sha384-foobar\"))", canonical);
    try valid(image ++ " referrer-policy(no-referrer) integrity(\"sha384-foobar\") cross-origin(anonymous))", canonical);
    try valid(image ++ " referrer-policy(no-referrer) cross-origin(anonymous))", image ++ " cross-origin(anonymous) referrer-policy(no-referrer))");
}

test "malformed, repeated, unknown or misplaced modifiers are invalid" {
    for ([_][]const u8{
        image ++ " cross-origin())",
        image ++ " cross-origin(,))",
        image ++ " cross-origin(anonymous,))",
        image ++ " cross-origin(anonymous foobar))",
        image ++ " cross-origin(anonymous) cross-origin(use-credentials))",
        image ++ " integrity())",
        image ++ " integrity(sha384-foobar))",
        image ++ " integrity(\"a\" foobar))",
        image ++ " integrity(\"a\") integrity(\"a\"))",
        image ++ " referrer-policy(no-referrer same-origin))",
        image ++ " referrer-policy(foobar))",
        image ++ " referrer-policy(no-referrer) referrer-policy(no-referrer))",
        image ++ " crossorigin(anonymous))",
        image ++ " referrerpolicy(no-referrer))",
        image ++ " foobar(baz))",
        image ++ " anonymous)",
        "url(cross-origin(anonymous) \"http://example.test/a.png\")",
        // Values 4 §4.5.3: an unquoted URL takes no modifier.
        "url(http://example.test/a.png cross-origin(anonymous))",
        "\"http://example.test/a.png\" cross-origin(anonymous)",
    }) |input| try invalid(input);
}

test "the value's resource URL carries the parsed modifiers" {
    const allocator = testing.allocator;
    var block = Block.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-image", image ++ " referrer-policy(same-origin) integrity(\"sha256-x\") cross-origin(use-credentials))", ""));
    const style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &block, .source = .{ .origin = .author } }});
    defer style.destroy();
    const urls = style.get(.background_image).resourceUrls();
    try testing.expectEqual(@as(usize, 1), urls.len);
    const modifiers = urls[0].modifiers;
    try testing.expectEqual(css.style_values.RequestModifiers.CrossOrigin.use_credentials, modifiers.cross_origin.?);
    try testing.expectEqualStrings("sha256-x", modifiers.integrity.?);
    try testing.expectEqual(css.style_values.RequestModifiers.ReferrerPolicy.same_origin, modifiers.referrer_policy.?);
    try testing.expectEqualStrings("same-origin", modifiers.referrer_policy.?.name());
    // No modifier: nothing changes the request.
    var plain = Block.init(allocator);
    defer plain.deinit();
    try testing.expect(try plain.setProperty(.{ .allocator = allocator }, "background-image", image ++ ")", ""));
    const plain_style = try css.cascade.cascade(.{ .allocator = allocator, .parent = null }, &.{.{ .block = &plain, .source = .{ .origin = .author } }});
    defer plain_style.destroy();
    const none = plain_style.get(.background_image).resourceUrls()[0].modifiers;
    try testing.expect(none.cross_origin == null and none.integrity == null and none.referrer_policy == null);
}
