const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;
const Node = dom.Node;
const Range = dom.Range;
const Text = dom.Text;

test "Range.toString - collapsed range returns empty string" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    _ = try doc.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, @ptrCast(doc));
    defer range.deinit();

    // Collapsed range
    try range.call_setStart(@ptrCast(div), 0);
    try range.call_setEnd(@ptrCast(div), 0);

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
    _ = try div.call_appendChild(@as(*dom.Node, @ptrCast(text)));
    _ = try doc.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, @ptrCast(doc));
    defer range.deinit();

    // Select "World" (offset 6 to 11)
    try range.call_setStart(@as(*dom.Node, @ptrCast(text)), 6);
    try range.call_setEnd(@as(*dom.Node, @ptrCast(text)), 11);

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
    _ = try div.call_appendChild(@as(*dom.Node, @ptrCast(text)));
    _ = try doc.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, @ptrCast(doc));
    defer range.deinit();

    // Select entire text node
    try range.call_setStart(@as(*dom.Node, @ptrCast(text)), 0);
    try range.call_setEnd(@as(*dom.Node, @ptrCast(text)), 5);

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

    _ = try div.call_appendChild((&text1).base);
    _ = try div.call_appendChild((&span));
    _ = try span.call_appendChild((&text2).base);
    _ = try div.call_appendChild((&text3).base);
    _ = try doc.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, @ptrCast(doc));
    defer range.deinit();

    // Select from start of div to end of div (all content)
    try range.call_setStart(@ptrCast(div), 0);
    try range.call_setEnd(@ptrCast(div), 3);

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

    _ = try div.call_appendChild((&text1).base);
    _ = try div.call_appendChild((&span));
    _ = try span.call_appendChild((&text2).base);
    _ = try doc.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, @ptrCast(doc));
    defer range.deinit();

    // Select from "lo" in "Hello" to end of "World"
    try range.call_setStart((&text1).base, 3);
    try range.call_setEnd((&text2).base, 5);

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

    _ = try div.call_appendChild((&text1).base);
    _ = try div.call_appendChild((&span));
    _ = try span.call_appendChild((&text2).base);
    _ = try doc.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, @ptrCast(doc));
    defer range.deinit();

    // Select from start of "Hello" to "Wor" in "World"
    try range.call_setStart((&text1).base, 0);
    try range.call_setEnd((&text2).base, 3);

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

    _ = try div.call_appendChild((&span1));
    _ = try div.call_appendChild((&span2));
    _ = try doc.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, @ptrCast(doc));
    defer range.deinit();

    // Select the entire div (no text content)
    try range.call_setStart(@ptrCast(div), 0);
    try range.call_setEnd(@ptrCast(div), 2);

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

    _ = try div.call_appendChild((&textA).base);
    _ = try div.call_appendChild((&span));
    _ = try span.call_appendChild((&textB).base);
    _ = try span.call_appendChild((&em));
    _ = try em.call_appendChild((&textC).base);
    _ = try span.call_appendChild((&textD).base);
    _ = try div.call_appendChild((&textE).base);
    _ = try doc.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, @ptrCast(doc));
    defer range.deinit();

    // Select entire div content
    try range.call_setStart(@ptrCast(div), 0);
    try range.call_setEnd(@ptrCast(div), 3);

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
    _ = try div.call_appendChild(@as(*dom.Node, @ptrCast(text)));
    _ = try doc.call_appendChild(@ptrCast(div));

    var range = try dom.Range.init(allocator, @ptrCast(doc));
    defer range.deinit();

    // Select the empty text node
    try range.call_setStart(@as(*dom.Node, @ptrCast(text)), 0);
    try range.call_setEnd(@as(*dom.Node, @ptrCast(text)), 0);

    const result = try range.toString(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}
