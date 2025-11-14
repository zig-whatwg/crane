//! CDATASection Tests (DOM Standard §4.12)
//! Tests for CDATASection interface

const std = @import("std");
const dom = @import("dom");
const Document = dom.Document;
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const CDATASection = dom.CDATASection;
const CharacterData = dom.CharacterData;
const Text = dom.Text;

const testing = std.testing;

test "CDATASection: createCDATASection creates node with data" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var cdata = try doc.call_createCDATASection("Some CDATA content");
    defer {
        cdata.deinit();
        allocator.destroy(cdata);
    }

    try testing.expectEqualStrings("Some CDATA content", cdata.get_data());
    try testing.expectEqual(@as(u32, 18), cdata.get_length());
}

test "CDATASection: empty data" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var cdata = try doc.call_createCDATASection("");
    defer {
        cdata.deinit();
        allocator.destroy(cdata);
    }

    try testing.expectEqualStrings("", cdata.get_data());
    try testing.expectEqual(@as(u32, 0), cdata.get_length());
}

test "CDATASection: inherits Text methods" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var cdata = try doc.call_createCDATASection("Hello World");
    defer {
        cdata.deinit();
        allocator.destroy(cdata);
    }

    // Can use Text methods (which inherit CharacterData)
    try cdata.call_appendData("!");
    try testing.expectEqualStrings("Hello World!", cdata.get_data());

    const substr = try cdata.call_substringData(0, 5);
    try testing.expectEqualStrings("Hello", substr);
}

test "CDATASection: splitText works" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var cdata = try doc.call_createCDATASection("HelloWorld");
    defer {
        cdata.deinit();
        allocator.destroy(cdata);
    }

    var cdata2 = try cdata.call_splitText(5);
    defer {
        cdata2.deinit();
        allocator.destroy(cdata2);
    }

    try testing.expectEqualStrings("Hello", cdata.get_data());
    try testing.expectEqualStrings("World", cdata2.get_data());
}

test "CDATASection: data manipulation" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var cdata = try doc.call_createCDATASection("abc");
    defer {
        cdata.deinit();
        allocator.destroy(cdata);
    }

    try cdata.call_insertData(3, "def");
    try testing.expectEqualStrings("abcdef", cdata.get_data());

    try cdata.call_deleteData(0, 3);
    try testing.expectEqualStrings("def", cdata.get_data());

    try cdata.call_replaceData(0, 3, "xyz");
    try testing.expectEqualStrings("xyz", cdata.get_data());
}

test "CDATASection: with special XML characters" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    // CDATA sections can contain characters that would otherwise need escaping
    var cdata = try doc.call_createCDATASection("<tag>value & \"quoted\"</tag>");
    defer {
        cdata.deinit();
        allocator.destroy(cdata);
    }

    try testing.expectEqualStrings("<tag>value & \"quoted\"</tag>", cdata.get_data());
}
