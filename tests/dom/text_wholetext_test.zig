const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const Document = dom.Document;
const Text = dom.Text;

test "Text.wholeText - single Text node returns own data" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const text = try doc.call_createTextNode("Hello");
    const div = try doc.call_createElement("div");
    _ = try div.call_appendChild(@ptrCast(text));

    const whole = try text.get_wholeText();
    defer allocator.free(whole);

    try std.testing.expectEqualStrings("Hello", whole);
}

test "Text.wholeText - concatenates contiguous Text nodes" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text1 = try doc.call_createTextNode("Hello");
    const text2 = try doc.call_createTextNode(" ");
    const text3 = try doc.call_createTextNode("World");

    _ = try div.call_appendChild((&text1));
    _ = try div.call_appendChild((&text2));
    _ = try div.call_appendChild((&text3));

    const whole = try text2.get_wholeText();
    defer allocator.free(whole);

    try std.testing.expectEqualStrings("Hello World", whole);
}

test "Text.wholeText - stops at element boundaries" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text1 = try doc.call_createTextNode("Hello");
    const span = try doc.call_createElement("span");
    const text2 = try doc.call_createTextNode("World");

    _ = try div.call_appendChild((&text1));
    _ = try div.call_appendChild((&span));
    _ = try div.call_appendChild((&text2));

    const whole1 = try text1.get_wholeText();
    defer allocator.free(whole1);
    try std.testing.expectEqualStrings("Hello", whole1);

    const whole2 = try text2.get_wholeText();
    defer allocator.free(whole2);
    try std.testing.expectEqualStrings("World", whole2);
}

test "Text.wholeText - handles empty Text nodes" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text1 = try doc.call_createTextNode("Hello");
    const text2 = try doc.call_createTextNode("");
    const text3 = try doc.call_createTextNode("World");

    _ = try div.call_appendChild((&text1));
    _ = try div.call_appendChild((&text2));
    _ = try div.call_appendChild((&text3));

    const whole = try text2.get_wholeText();
    defer allocator.free(whole);

    try std.testing.expectEqualStrings("HelloWorld", whole);
}

test "Text.wholeText - works from first node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text1 = try doc.call_createTextNode("A");
    const text2 = try doc.call_createTextNode("B");
    const text3 = try doc.call_createTextNode("C");

    _ = try div.call_appendChild((&text1));
    _ = try div.call_appendChild((&text2));
    _ = try div.call_appendChild((&text3));

    const whole = try text1.get_wholeText();
    defer allocator.free(whole);

    try std.testing.expectEqualStrings("ABC", whole);
}

test "Text.wholeText - works from last node" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text1 = try doc.call_createTextNode("A");
    const text2 = try doc.call_createTextNode("B");
    const text3 = try doc.call_createTextNode("C");

    _ = try div.call_appendChild((&text1));
    _ = try div.call_appendChild((&text2));
    _ = try div.call_appendChild((&text3));

    const whole = try text3.get_wholeText();
    defer allocator.free(whole);

    try std.testing.expectEqualStrings("ABC", whole);
}

test "Text.wholeText - preserves order" {
    const allocator = std.testing.allocator;

    var doc = try dom.Document.init(allocator);
    defer doc.deinit();

    const div = try doc.call_createElement("div");
    const text1 = try doc.call_createTextNode("First");
    const text2 = try doc.call_createTextNode("Second");
    const text3 = try doc.call_createTextNode("Third");

    _ = try div.call_appendChild((&text1));
    _ = try div.call_appendChild((&text2));
    _ = try div.call_appendChild((&text3));

    const whole = try text2.get_wholeText();
    defer allocator.free(whole);

    try std.testing.expectEqualStrings("FirstSecondThird", whole);
}
