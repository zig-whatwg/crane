//! CSS Values 5 §4.1.1 request URL modifiers inside image-set(): the request
//! URL modifiers row (lane maj1) replaced Q81's interim opaque path - a
//! candidate url() with modifiers is a typed value carrying them, and an
//! unknown modifier makes the whole value invalid, as in Chrome, Firefox and
//! Safari (css/css-values/urls/url-request-modifiers-invalid.sub.html).
const std = @import("std");
const css = @import("css");
const testing = std.testing;

fn checkTyped(allocator: std.mem.Allocator) !void {
    const text = "image-set(url(\"a.png\" cross-origin(anonymous)) 1x, \"b.png\" 2x)";
    var block = css.declarations.DeclarationBlock.init(allocator);
    defer block.deinit();
    try testing.expect(try block.setProperty(.{ .allocator = allocator }, "background-image", text, ""));
    const value = block.get(.background_image).?.value.value;
    try testing.expect(value == .image);
    const urls = value.resourceUrls();
    try testing.expectEqual(@as(usize, 2), urls.len);
    try testing.expectEqualStrings("a.png", urls[0].url);
    try testing.expectEqual(css.style_values.RequestModifiers.CrossOrigin.anonymous, urls[0].modifiers.cross_origin.?);
    try testing.expectEqualStrings("b.png", urls[1].url);
    try testing.expect(urls[1].modifiers.isEmpty());
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try block.getPropertyValue("background-image", &out);
    try testing.expectEqualStrings("image-set(url(\"a.png\" cross-origin(anonymous)) 1x, url(\"b.png\") 2x)", out.items);
}

test "a candidate url() with request modifiers is a typed image-set value" {
    try testing.checkAllAllocationFailures(testing.allocator, checkTyped, .{});
}

test "plain image-set stays typed and unrelated invalid forms never take the fallback" {
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    const options = css.properties.ParseOptions{ .allocator = testing.allocator };
    try testing.expect(try block.setProperty(options, "background-image", "image-set(url(\"a.png\") 1x, \"b.png\" 2x)", ""));
    try testing.expect(block.get(.background_image).?.value.value == .image);
    for ([_][]const u8{
        "url(\"a\" b)",          "src(\"a\" b)",            "image-set()",        "image-set(none)",
        "image-set(url(a) -1x)", "image-set(url(a) 1x 2x)", "image-set(url(a),)", "image-set(image-set(url(a)))",
        "image-set(\"bad\n\")",
    }) |input| try testing.expect(!try block.setProperty(options, "background-image", input, ""));
}

test "an unknown URL modifier inside image-set() is invalid" {
    // Q82, done: no opaque acceptance survives the modifier row.
    var block = css.declarations.DeclarationBlock.init(testing.allocator);
    defer block.deinit();
    const options = css.properties.ParseOptions{ .allocator = testing.allocator };
    for ([_][]const u8{
        "image-set(url('a' junk",
        "image-set(url('a' junk) 1x)",
        "image-set(url(\"a.png\" cross-origin(anonymous) cross-origin(anonymous)) 1x)",
        "image-set(url(\"a.png\" referrer-policy(nope)) 1x)",
    }) |input| try testing.expect(!try block.setProperty(options, "background-image", input, ""));
}
