//! CSS Lists 3 §§3.3–3.6,4.1–4.2; Counter Styles 3 §§2.1,4–5.
const std = @import("std");
const h = @import("bx1_helpers.zig");
const testing = std.testing;

test "counter declarations retain names order repeats and reversed automatic starts" {
    inline for (.{ "counter-reset", "counter-set", "counter-increment" }) |property| {
        const default_value = if (std.mem.eql(u8, property, "counter-increment")) "chapter 1" else "chapter 0";
        try h.check(testing.allocator, property, "chapter", default_value, false);
        try h.check(testing.allocator, property, "chapter", default_value, true);
        try h.check(testing.allocator, property, "a -1 b 0 a 9", "a -1 b 0 a 9", true);
        try h.check(testing.allocator, property, "chapter calc(2.5)", "chapter 3", true);
        try h.check(testing.allocator, property, "none", "none", true);
        inline for (.{ "none chapter", "3 chapter", "chapter 3.14", "chapter 2, other", "default 1", "inherit 1", "revert-layer 1" }) |input|
            try h.check(testing.allocator, property, input, "", false);
    }
    try h.check(testing.allocator, "counter-reset", "reversed(chapter)", "reversed(chapter)", true);
    try h.check(testing.allocator, "counter-reset", "reversed(chapter) -2 chapter", "reversed(chapter) -2 chapter 0", true);
    try h.check(testing.allocator, "counter-reset", "reversed(none)", "", false);
    try h.check(testing.allocator, "counter-increment", "reversed(chapter)", "", false);
    try h.check(testing.allocator, "counter-set", "reversed(chapter)", "", false);
    try h.check(testing.allocator, "counter-reset", "a\\ 8 9", "a\\ 8 9", true);
}

test "list style names strings symbols and images use their shared grammars" {
    inline for (.{ "disc", "decimal", "lower-roman", "CounterStyle", "inside", "\"Note: \"", "symbols(cyclic \"a\" \"b\")" }) |input| {
        try h.check(testing.allocator, "list-style-type", input, input, false);
        try h.check(testing.allocator, "list-style-type", input, input, true);
    }
    try h.check(testing.allocator, "list-style-type", "DiSc", "disc", false);
    try h.check(testing.allocator, "list-style-type", "symbols(symbolic \"a\")", "symbols(\"a\")", false);
    inline for (.{ "symbols()", "symbols(numeric \"a\")", "symbols(\"a\") extra", "symbols(url(a))", "symbols(image-set(url(a) 1x))", "default" }) |input|
        try h.check(testing.allocator, "list-style-type", input, "", false);
    try h.check(testing.allocator, "list-style-image", "url(\"https://example.com/marker.png\")", "url(\"https://example.com/marker.png\")", true);
}

test "shared symbols parsing preserves generated content image support" {
    // ANSWER Q6: list-style-type follows the shipping string-only grammar;
    // the pre-existing content owner continues to accept typed images.
    try h.check(testing.allocator, "content", "counter(name, symbols(image-set(url(a) 1x)))", "counter(name, symbols(image-set(url(\"a\") 1x)))", false);
    try h.check(testing.allocator, "content", "counter(name, symbols(numeric image-set(url(a) 1x)))", "", false);
}

test "list style shorthand disambiguates none and resets omitted longhands" {
    var block = h.Block.init(testing.allocator);
    defer block.deinit();
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "list-style", "inside disc url(\"https://example.com/marker.png\")", "");
    try h.specified(&block, "list-style-position", "inside", testing.allocator);
    try h.specified(&block, "list-style-type", "disc", testing.allocator);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "list-style", "none", "");
    try h.specified(&block, "list-style-position", "outside", testing.allocator);
    try h.specified(&block, "list-style-image", "none", testing.allocator);
    try h.specified(&block, "list-style-type", "none", testing.allocator);
    _ = try block.setProperty(.{ .allocator = testing.allocator }, "list-style", "none circle", "");
    try h.specified(&block, "list-style-type", "circle", testing.allocator);
    try h.check(testing.allocator, "list-style", "none disc url(\"https://example.com/marker.png\")", "", false);
    try h.check(testing.allocator, "list-style", "inside disc outside", "", false);
}

test "list shorthand position-spelled type names round trip without ambiguity" {
    // ANSWER Q32: once position is filled, its keyword spelling may name
    // a custom counter style. Keep an initial outside to disambiguate it.
    inline for (.{ "inside outside", "outside inside", "outside outside", "inside inside" }) |input| {
        inline for (.{ false, true }) |computed| try h.check(testing.allocator, "list-style", input, input, computed);
        var first = h.Block.init(testing.allocator);
        defer first.deinit();
        _ = try first.setProperty(.{ .allocator = testing.allocator }, "list-style", input, "");
        var text: std.ArrayList(u8) = .empty;
        defer text.deinit(testing.allocator);
        try first.getPropertyValue("list-style", &text);
        var second = h.Block.init(testing.allocator);
        defer second.deinit();
        _ = try second.setProperty(.{ .allocator = testing.allocator }, "list-style", text.items, "");
        const split = std.mem.indexOfScalar(u8, input, ' ').?;
        try h.specified(&second, "list-style-position", input[0..split], testing.allocator);
        try h.specified(&second, "list-style-type", input[split + 1 ..], testing.allocator);
        try h.specified(&second, "list-style-image", "none", testing.allocator);
    }
    try h.check(testing.allocator, "list-style", "none none none", "", false);
}

test "list style inherits while counter declarations do not" {
    var block = try h.Block.parse(.{ .allocator = testing.allocator }, "list-style:inside square;counter-reset:chapter 5;counter-increment:chapter 2;counter-set:other 4");
    defer block.deinit();
    const parent = try h.compute(testing.allocator, &block, null);
    defer parent.destroy();
    var empty = h.Block.init(testing.allocator);
    defer empty.deinit();
    const child = try h.compute(testing.allocator, &empty, parent);
    defer child.destroy();
    try h.expect(child, "list-style-position", "inside", testing.allocator);
    try h.expect(child, "list-style-type", "square", testing.allocator);
    inline for (.{ "counter-reset", "counter-set", "counter-increment" }) |property|
        try h.expect(child, property, "none", testing.allocator);
}

test "counter and list declarations release every allocation failure" {
    try testing.checkAllAllocationFailures(testing.allocator, allocationFailure, .{});
}
fn allocationFailure(allocator: h.Allocator) !void {
    try h.check(allocator, "counter-reset", "reversed(chapter) calc(-2.5) section", "reversed(chapter) -2 section 0", true);
    try h.check(allocator, "list-style-type", "symbols(numeric \"a\" \"b\")", "symbols(numeric \"a\" \"b\")", true);
    try h.check(allocator, "list-style-type", "symbols(numeric \"a\")", "", false);
}
