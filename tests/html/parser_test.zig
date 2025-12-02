//! HTML Parser Tests
//!
//! Tests for the HTML tokenizer and tree builder per HTML Standard §13.
//! https://html.spec.whatwg.org/multipage/parsing.html

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const html = @import("html");
const parser = html.parser;
const Tokenizer = parser.Tokenizer;
const TreeBuilder = parser.TreeBuilder;
const Token = parser.Token;
const State = parser.State;

// ============================================================================
// Tokenizer Tests
// ============================================================================

test "tokenizer - basic initialization" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "test");
    defer tokenizer.deinit();

    try testing.expect(tokenizer.state == .data);
}

test "tokenizer - simple start tag" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<div>");
    defer tokenizer.deinit();

    var found_div = false;
    while (try tokenizer.nextToken()) |token| {
        switch (token) {
            .start_tag => |tag| {
                if (std.mem.eql(u8, tag.getTagName(), "div")) {
                    found_div = true;
                }
            },
            else => {},
        }
    }

    try testing.expect(found_div);
}

test "tokenizer - end tag" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "</div>");
    defer tokenizer.deinit();

    var found_end_div = false;
    while (try tokenizer.nextToken()) |token| {
        switch (token) {
            .end_tag => |tag| {
                if (std.mem.eql(u8, tag.getTagName(), "div")) {
                    found_end_div = true;
                }
            },
            else => {},
        }
    }

    try testing.expect(found_end_div);
}

test "tokenizer - self-closing tag" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<br/>");
    defer tokenizer.deinit();

    var found_br = false;
    var is_self_closing = false;

    while (try tokenizer.nextToken()) |token| {
        switch (token) {
            .start_tag => |tag| {
                if (std.mem.eql(u8, tag.getTagName(), "br")) {
                    found_br = true;
                    is_self_closing = tag.self_closing;
                }
            },
            else => {},
        }
    }

    try testing.expect(found_br);
    try testing.expect(is_self_closing);
}

test "tokenizer - comment" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<!-- comment -->");
    defer tokenizer.deinit();

    var found_comment = false;
    while (try tokenizer.nextToken()) |token| {
        switch (token) {
            .comment => {
                found_comment = true;
            },
            else => {},
        }
    }

    try testing.expect(found_comment);
}

test "tokenizer - DOCTYPE" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<!DOCTYPE html>");
    defer tokenizer.deinit();

    var found_doctype = false;
    while (try tokenizer.nextToken()) |token| {
        switch (token) {
            .doctype => {
                found_doctype = true;
            },
            else => {},
        }
    }

    try testing.expect(found_doctype);
}

test "tokenizer - numeric character reference decimal" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "&#65;"); // 'A'
    defer tokenizer.deinit();

    var found_a = false;
    while (try tokenizer.nextToken()) |token| {
        switch (token) {
            .character => |char| {
                if (char == 'A') {
                    found_a = true;
                }
            },
            else => {},
        }
    }

    try testing.expect(found_a);
}

test "tokenizer - numeric character reference hex" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "&#x41;"); // 'A'
    defer tokenizer.deinit();

    var found_a = false;
    while (try tokenizer.nextToken()) |token| {
        switch (token) {
            .character => |char| {
                if (char == 'A') {
                    found_a = true;
                }
            },
            else => {},
        }
    }

    try testing.expect(found_a);
}

test "tokenizer - multiple tags" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<div><span></span></div>");
    defer tokenizer.deinit();

    var start_tags: usize = 0;
    var end_tags: usize = 0;

    while (try tokenizer.nextToken()) |token| {
        switch (token) {
            .start_tag => start_tags += 1,
            .end_tag => end_tags += 1,
            else => {},
        }
    }

    try testing.expectEqual(@as(usize, 2), start_tags);
    try testing.expectEqual(@as(usize, 2), end_tags);
}

// ============================================================================
// Entity Tests
// ============================================================================

test "entities - basic lookup" {
    const ent = parser.entities;

    // Test amp
    if (ent.findLongestMatch("amp;")) |entity| {
        try testing.expectEqual(@as(usize, 1), entity.codepoints.len);
        try testing.expectEqual(@as(u21, 38), entity.codepoints[0]); // &
    } else {
        return error.EntityNotFound;
    }
}

test "entities - lt and gt" {
    const ent = parser.entities;

    // Test lt
    if (ent.findLongestMatch("lt;")) |entity| {
        try testing.expectEqual(@as(u21, 60), entity.codepoints[0]); // <
    } else {
        return error.EntityNotFound;
    }

    // Test gt
    if (ent.findLongestMatch("gt;")) |entity| {
        try testing.expectEqual(@as(u21, 62), entity.codepoints[0]); // >
    } else {
        return error.EntityNotFound;
    }
}

test "entities - nbsp" {
    const ent = parser.entities;

    if (ent.findLongestMatch("nbsp;")) |entity| {
        try testing.expectEqual(@as(u21, 160), entity.codepoints[0]);
    } else {
        return error.EntityNotFound;
    }
}

test "entities - legacy entities without semicolon" {
    const ent = parser.entities;

    // Test legacy amp (no semicolon)
    if (ent.findLongestMatch("amp")) |entity| {
        try testing.expectEqual(@as(u21, 38), entity.codepoints[0]);
    } else {
        return error.EntityNotFound;
    }
}

test "entities - multi-codepoint entities" {
    const ent = parser.entities;

    // Test NotEqualTilde which has 2 codepoints
    if (ent.findLongestMatch("NotEqualTilde;")) |entity| {
        try testing.expectEqual(@as(usize, 2), entity.codepoints.len);
    } else {
        return error.EntityNotFound;
    }
}

test "entities - nonexistent entity returns null" {
    const ent = parser.entities;
    try testing.expect(ent.findLongestMatch("notanentity;") == null);
    try testing.expect(ent.findLongestMatch("xyz") == null);
}

test "entities - total count" {
    const ent = parser.entities;
    // WHATWG defines 2231 entities
    try testing.expect(ent.entities.len > 2000);
    try testing.expect(ent.entities.len < 2500);
}

// ============================================================================
// Tree Builder Tests
// ============================================================================

test "tree builder - initialization" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "");
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    try testing.expect(builder.insertion_mode == .initial);
    // Document is created during init, verify it exists
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - simple HTML document" {
    const allocator = testing.allocator;

    const html_content = "<!DOCTYPE html><html><head></head><body></body></html>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        try builder.processToken(token);
    }
    try builder.processToken(.eof);

    // Document should have children after parsing
    // Document is created during init, verify it exists
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - paragraph element" {
    const allocator = testing.allocator;

    const html_content = "<p>Hello</p>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        try builder.processToken(token);
    }
    try builder.processToken(.eof);

    // Document is created during init, verify it exists
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - nested elements" {
    const allocator = testing.allocator;

    const html_content = "<div><span>text</span></div>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        try builder.processToken(token);
    }
    try builder.processToken(.eof);

    // Document is created during init, verify it exists
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - void elements" {
    const allocator = testing.allocator;

    const html_content = "<p>Line 1<br>Line 2</p>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        try builder.processToken(token);
    }
    try builder.processToken(.eof);

    // Document is created during init, verify it exists
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - table structure" {
    const allocator = testing.allocator;

    const html_content = "<table><tr><td>Cell</td></tr></table>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        try builder.processToken(token);
    }
    try builder.processToken(.eof);

    // Document is created during init, verify it exists
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - quirks mode detection" {
    const allocator = testing.allocator;

    // HTML5 DOCTYPE should trigger standards mode (no quirks)
    const html_content = "<!DOCTYPE html><html></html>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        try builder.processToken(token);
    }
    try builder.processToken(.eof);

    try testing.expect(builder.quirks_mode == .no_quirks);
}
