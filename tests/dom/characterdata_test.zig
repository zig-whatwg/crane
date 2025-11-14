//! CharacterData Tests (DOM Standard §4.11)
//! Tests for CharacterData interface and data manipulation methods

const std = @import("std");
const dom = @import("dom");
const Document = dom.Document;
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const CharacterData = dom.CharacterData;

const testing = std.testing;

test "CharacterData: data getter returns data" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try testing.expectEqualStrings("Hello World", text.get_data());
}

test "CharacterData: data setter replaces data" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Original");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.set_data("Modified");
    try testing.expectEqualStrings("Modified", text.get_data());
}

test "CharacterData: length returns code unit count" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("12345");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try testing.expectEqual(@as(u32, 5), text.get_length());
}

test "CharacterData: length for empty data" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try testing.expectEqual(@as(u32, 0), text.get_length());
}

test "CharacterData: substringData extracts substring" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    const substr = try text.call_substringData(0, 5);
    try testing.expectEqualStrings("Hello", substr);

    const substr2 = try text.call_substringData(6, 5);
    try testing.expectEqualStrings("World", substr2);
}

test "CharacterData: substringData with count overflow" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Count extends past end - should return to end
    const substr = try text.call_substringData(2, 100);
    try testing.expectEqualStrings("llo", substr);
}

test "CharacterData: substringData throws on invalid offset" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Offset > length should throw
    const result = text.call_substringData(10, 5);
    try testing.expectError(error.IndexSizeError, result);
}

test "CharacterData: appendData adds to end" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_appendData(" World");
    try testing.expectEqualStrings("Hello World", text.get_data());
    try testing.expectEqual(@as(u32, 11), text.get_length());
}

test "CharacterData: appendData to empty string" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_appendData("First");
    try testing.expectEqualStrings("First", text.get_data());
}

test "CharacterData: insertData at beginning" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_insertData(0, "Hello ");
    try testing.expectEqualStrings("Hello World", text.get_data());
}

test "CharacterData: insertData in middle" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Heo");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_insertData(2, "ll");
    try testing.expectEqualStrings("Hello", text.get_data());
}

test "CharacterData: insertData at end" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_insertData(5, " World");
    try testing.expectEqualStrings("Hello World", text.get_data());
}

test "CharacterData: insertData throws on invalid offset" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    const result = text.call_insertData(10, "X");
    try testing.expectError(error.IndexSizeError, result);
}

test "CharacterData: deleteData from beginning" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_deleteData(0, 6);
    try testing.expectEqualStrings("World", text.get_data());
}

test "CharacterData: deleteData from middle" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_deleteData(5, 6);
    try testing.expectEqualStrings("Hello", text.get_data());
}

test "CharacterData: deleteData with count overflow" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Delete from offset 6 to end (count > remaining)
    try text.call_deleteData(6, 100);
    try testing.expectEqualStrings("Hello ", text.get_data());
}

test "CharacterData: deleteData entire string" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_deleteData(0, 5);
    try testing.expectEqualStrings("", text.get_data());
    try testing.expectEqual(@as(u32, 0), text.get_length());
}

test "CharacterData: replaceData in middle" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_replaceData(6, 5, "Zig");
    try testing.expectEqualStrings("Hello Zig", text.get_data());
}

test "CharacterData: replaceData with longer string" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hi");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_replaceData(0, 2, "Hello");
    try testing.expectEqualStrings("Hello", text.get_data());
}

test "CharacterData: replaceData with shorter string" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_replaceData(0, 5, "Hi");
    try testing.expectEqualStrings("Hi", text.get_data());
}

test "CharacterData: replaceData with count overflow" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello World");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    // Replace from offset 6 to end
    try text.call_replaceData(6, 100, "Zig");
    try testing.expectEqualStrings("Hello Zig", text.get_data());
}

test "CharacterData: replaceData throws on invalid offset" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("Hello");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    const result = text.call_replaceData(10, 1, "X");
    try testing.expectError(error.IndexSizeError, result);
}

test "CharacterData: works with Comment nodes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var comment = try doc.call_createComment("Original comment");
    defer {
        comment.deinit();
        allocator.destroy(comment);
    }

    try testing.expectEqualStrings("Original comment", comment.get_data());
    try testing.expectEqual(@as(u32, 16), comment.get_length());

    try comment.call_appendData(" - modified");
    try testing.expectEqualStrings("Original comment - modified", comment.get_data());
}

test "CharacterData: multiple operations in sequence" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var text = try doc.call_createTextNode("abc");
    defer {
        text.deinit();
        allocator.destroy(text);
    }

    try text.call_appendData("def");
    try testing.expectEqualStrings("abcdef", text.get_data());

    try text.call_insertData(3, "123");
    try testing.expectEqualStrings("abc123def", text.get_data());

    try text.call_deleteData(3, 3);
    try testing.expectEqualStrings("abcdef", text.get_data());

    try text.call_replaceData(0, 3, "xyz");
    try testing.expectEqualStrings("xyzdef", text.get_data());
}
