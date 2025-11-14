//! DocumentType Tests (DOM Standard §4.7)
//! Tests for DocumentType interface

const std = @import("std");
const dom = @import("dom");
const infra = @import("infra");
const webidl = @import("webidl");
// Type aliases
const DocumentType = dom.DocumentType;

const testing = std.testing;

test "DocumentType: createDocumentType with all parameters" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var doctype = try doc.call_createDocumentType(
        "html",
        "-//W3C//DTD HTML 4.01//EN",
        "http://www.w3.org/TR/html4/strict.dtd",
    );
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    try testing.expectEqualStrings("html", doctype.get_name());
    try testing.expectEqualStrings("-//W3C//DTD HTML 4.01//EN", doctype.get_publicId());
    try testing.expectEqualStrings("http://www.w3.org/TR/html4/strict.dtd", doctype.get_systemId());
}

test "DocumentType: HTML5 doctype (empty publicId and systemId)" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var doctype = try doc.call_createDocumentType("html", "", "");
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    try testing.expectEqualStrings("html", doctype.get_name());
    try testing.expectEqualStrings("", doctype.get_publicId());
    try testing.expectEqualStrings("", doctype.get_systemId());
}

test "DocumentType: XML doctype with systemId only" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var doctype = try doc.call_createDocumentType(
        "root",
        "",
        "http://example.com/dtd/example.dtd",
    );
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    try testing.expectEqualStrings("root", doctype.get_name());
    try testing.expectEqualStrings("", doctype.get_publicId());
    try testing.expectEqualStrings("http://example.com/dtd/example.dtd", doctype.get_systemId());
}

test "DocumentType: XHTML doctype" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var doctype = try doc.call_createDocumentType(
        "html",
        "-//W3C//DTD XHTML 1.0 Strict//EN",
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd",
    );
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    try testing.expectEqualStrings("html", doctype.get_name());
    try testing.expectEqualStrings("-//W3C//DTD XHTML 1.0 Strict//EN", doctype.get_publicId());
    try testing.expectEqualStrings("http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd", doctype.get_systemId());
}

test "DocumentType: custom XML doctype" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var doctype = try doc.call_createDocumentType("custom", "public-id", "system-id");
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    try testing.expectEqualStrings("custom", doctype.get_name());
    try testing.expectEqualStrings("public-id", doctype.get_publicId());
    try testing.expectEqualStrings("system-id", doctype.get_systemId());
}

test "DocumentType: readonly properties" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var doctype = try doc.call_createDocumentType("test", "pub", "sys");
    defer {
        doctype.deinit();
        allocator.destroy(doctype);
    }

    // Properties should be constant throughout lifetime
    try testing.expectEqualStrings("test", doctype.get_name());
    try testing.expectEqualStrings("pub", doctype.get_publicId());
    try testing.expectEqualStrings("sys", doctype.get_systemId());

    // Re-check to ensure they haven't changed
    try testing.expectEqualStrings("test", doctype.get_name());
    try testing.expectEqualStrings("pub", doctype.get_publicId());
    try testing.expectEqualStrings("sys", doctype.get_systemId());
}

test "DocumentType: multiple doctypes" {
    const allocator = testing.allocator;

    var doc = try Document.init(allocator);
    defer doc.deinit();

    var doctype1 = try doc.call_createDocumentType("html", "", "");
    defer {
        doctype1.deinit();
        allocator.destroy(doctype1);
    }

    var doctype2 = try doc.call_createDocumentType("xml", "public", "system");
    defer {
        doctype2.deinit();
        allocator.destroy(doctype2);
    }

    // Each doctype maintains its own properties
    try testing.expectEqualStrings("html", doctype1.get_name());
    try testing.expectEqualStrings("xml", doctype2.get_name());

    try testing.expectEqualStrings("", doctype1.get_publicId());
    try testing.expectEqualStrings("public", doctype2.get_publicId());
}
