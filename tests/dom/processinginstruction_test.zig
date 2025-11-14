//! ProcessingInstruction Tests (DOM Standard §4.13)
//! Tests for ProcessingInstruction interface

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const CharacterData = dom.CharacterData;
const ProcessingInstruction = dom.ProcessingInstruction;

const testing = std.testing;

test "ProcessingInstruction: createProcessingInstruction creates PI with target and data" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var pi = try doc.call_createProcessingInstruction("xml-stylesheet", "href=\"style.css\"");
    defer {
        pi.deinit();
        allocator.destroy(pi);
    }

    try testing.expectEqualStrings("xml-stylesheet", pi.get_target());
    try testing.expectEqualStrings("href=\"style.css\"", pi.get_data());
}

test "ProcessingInstruction: target is readonly" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var pi = try doc.call_createProcessingInstruction("target", "data");
    defer {
        pi.deinit();
        allocator.destroy(pi);
    }

    // Target should remain constant
    try testing.expectEqualStrings("target", pi.get_target());
}

test "ProcessingInstruction: inherits CharacterData methods" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var pi = try doc.call_createProcessingInstruction("xml-stylesheet", "type=\"text/css\"");
    defer {
        pi.deinit();
        allocator.destroy(pi);
    }

    // Can use CharacterData methods on data
    try testing.expectEqual(@as(u32, 14), pi.get_length());

    try pi.call_appendData(" href=\"style.css\"");
    try testing.expectEqualStrings("type=\"text/css\" href=\"style.css\"", pi.get_data());

    // Target unchanged
    try testing.expectEqualStrings("xml-stylesheet", pi.get_target());
}

test "ProcessingInstruction: data manipulation" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var pi = try doc.call_createProcessingInstruction("php", "echo 'hello';");
    defer {
        pi.deinit();
        allocator.destroy(pi);
    }

    try pi.call_replaceData(5, 7, "'world'");
    try testing.expectEqualStrings("echo 'world';", pi.get_data());

    // Target still unchanged
    try testing.expectEqualStrings("php", pi.get_target());
}

test "ProcessingInstruction: empty data" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var pi = try doc.call_createProcessingInstruction("target", "");
    defer {
        pi.deinit();
        allocator.destroy(pi);
    }

    try testing.expectEqualStrings("target", pi.get_target());
    try testing.expectEqualStrings("", pi.get_data());
    try testing.expectEqual(@as(u32, 0), pi.get_length());
}

test "ProcessingInstruction: substringData" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var pi = try doc.call_createProcessingInstruction("xml", "version=\"1.0\" encoding=\"UTF-8\"");
    defer {
        pi.deinit();
        allocator.destroy(pi);
    }

    const substr = try pi.call_substringData(0, 13);
    try testing.expectEqualStrings("version=\"1.0\"", substr);
}

test "ProcessingInstruction: multiple PIs with different targets" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var pi1 = try doc.call_createProcessingInstruction("xml", "version=\"1.0\"");
    defer {
        pi1.deinit();
        allocator.destroy(pi1);
    }

    var pi2 = try doc.call_createProcessingInstruction("xml-stylesheet", "href=\"style.css\"");
    defer {
        pi2.deinit();
        allocator.destroy(pi2);
    }

    var pi3 = try doc.call_createProcessingInstruction("php", "phpinfo();");
    defer {
        pi3.deinit();
        allocator.destroy(pi3);
    }

    try testing.expectEqualStrings("xml", pi1.get_target());
    try testing.expectEqualStrings("xml-stylesheet", pi2.get_target());
    try testing.expectEqualStrings("php", pi3.get_target());
}
