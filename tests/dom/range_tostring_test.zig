const std = @import("std");
const dom = @import("dom");

test "Range.toString - collapsed range returns empty string" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Collapsed range
    try range.call_setStart(&div.base, 0);
    try range.call_setEnd(&div.base, 0);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "Range.toString - single Text node substring" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello World");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(&text.base.base);
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Select "World" (offset 6 to 11)
    try range.call_setStart(&text.base.base, 6);
    try range.call_setEnd(&text.base.base, 11);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("World", result);
}

test "Range.toString - entire Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(&text.base.base);
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Select entire text node
    try range.call_setStart(&text.base.base, 0);
    try range.call_setEnd(&text.base.base, 5);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello", result);
}

test "Range.toString - multiple Text nodes" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create: <div>Hello<span>World</span>!</div>
    const div = try doc.call_createElement("div");
    const text1 = try doc.call_createTextNode("Hello");
    const span = try doc.call_createElement("span");
    const text2 = try doc.call_createTextNode("World");
    const text3 = try doc.call_createTextNode("!");

    _ = try div.call_appendChild(&text1.base.base);
    _ = try div.call_appendChild(&span.base);
    _ = try span.call_appendChild(&text2.base.base);
    _ = try div.call_appendChild(&text3.base.base);
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Select from start of div to end of div (all content)
    try range.call_setStart(&div.base, 0);
    try range.call_setEnd(&div.base, 3);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("HelloWorld!", result);
}

test "Range.toString - partial Text node at start" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create: <div>Hello<span>World</span></div>
    const div = try doc.call_createElement("div");
    const text1 = try doc.call_createTextNode("Hello");
    const span = try doc.call_createElement("span");
    const text2 = try doc.call_createTextNode("World");

    _ = try div.call_appendChild(&text1.base.base);
    _ = try div.call_appendChild(&span.base);
    _ = try span.call_appendChild(&text2.base.base);
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Select from "lo" in "Hello" to end of "World"
    try range.call_setStart(&text1.base.base, 3);
    try range.call_setEnd(&text2.base.base, 5);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("loWorld", result);
}

test "Range.toString - partial Text node at end" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create: <div>Hello<span>World</span></div>
    const div = try doc.call_createElement("div");
    const text1 = try doc.call_createTextNode("Hello");
    const span = try doc.call_createElement("span");
    const text2 = try doc.call_createTextNode("World");

    _ = try div.call_appendChild(&text1.base.base);
    _ = try div.call_appendChild(&span.base);
    _ = try span.call_appendChild(&text2.base.base);
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Select from start of "Hello" to "Wor" in "World"
    try range.call_setStart(&text1.base.base, 0);
    try range.call_setEnd(&text2.base.base, 3);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("HelloWor", result);
}

test "Range.toString - no Text nodes" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create: <div><span></span><span></span></div>
    const div = try doc.call_createElement("div");
    const span1 = try doc.call_createElement("span");
    const span2 = try doc.call_createElement("span");

    _ = try div.call_appendChild(&span1.base);
    _ = try div.call_appendChild(&span2.base);
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Select the entire div (no text content)
    try range.call_setStart(&div.base, 0);
    try range.call_setEnd(&div.base, 2);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "Range.toString - nested elements with text" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    // Create: <div>A<span>B<em>C</em>D</span>E</div>
    const div = try doc.call_createElement("div");
    const textA = try doc.call_createTextNode("A");
    const span = try doc.call_createElement("span");
    const textB = try doc.call_createTextNode("B");
    const em = try doc.call_createElement("em");
    const textC = try doc.call_createTextNode("C");
    const textD = try doc.call_createTextNode("D");
    const textE = try doc.call_createTextNode("E");

    _ = try div.call_appendChild(&textA.base.base);
    _ = try div.call_appendChild(&span.base);
    _ = try span.call_appendChild(&textB.base.base);
    _ = try span.call_appendChild(&em.base);
    _ = try em.call_appendChild(&textC.base.base);
    _ = try span.call_appendChild(&textD.base.base);
    _ = try div.call_appendChild(&textE.base.base);
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Select entire div content
    try range.call_setStart(&div.base, 0);
    try range.call_setEnd(&div.base, 3);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("ABCDE", result);
}

test "Range.toString - empty Text node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(&text.base.base);
    _ = try doc.base.call_appendChild(&div.base);

    var range = try dom.Range.init(allocator, &doc.base);
    defer range.deinit();

    // Select the empty text node
    try range.call_setStart(&text.base.base, 0);
    try range.call_setEnd(&text.base.base, 0);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}
