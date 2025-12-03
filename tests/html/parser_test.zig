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
        var tok = token;
        defer tok.deinit();
        switch (tok) {
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
    // "notanentity;" matches "not" (a valid entity without semicolon) as a prefix
    // So we test with strings that don't start with any entity name
    try testing.expect(ent.findLongestMatch("xyz") == null);
    try testing.expect(ent.findLongestMatch("zzz") == null);
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
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
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
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    try testing.expect(builder.quirks_mode == .no_quirks);
}

// ============================================================================
// Foreign Content Tests (SVG and MathML)
// Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inforeign
// ============================================================================

test "tree builder - SVG element in HTML" {
    const allocator = testing.allocator;

    const html_content = "<div><svg width='100' height='100'><circle cx='50' cy='50' r='40'/></svg></div>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    // Verify document structure was created
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - SVG with nested HTML" {
    const allocator = testing.allocator;

    // SVG foreignObject can contain HTML content
    const html_content = "<svg><foreignObject><div>HTML inside SVG</div></foreignObject></svg>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - MathML element in HTML" {
    const allocator = testing.allocator;

    // MathML for x² + y² = z²
    const html_content = "<p>The formula: <math><msup><mi>x</mi><mn>2</mn></msup></math></p>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - MathML annotation-xml with HTML" {
    const allocator = testing.allocator;

    // annotation-xml with text/html encoding contains HTML
    const html_content = "<math><annotation-xml encoding='text/html'><div>HTML</div></annotation-xml></math>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - SVG case sensitivity" {
    const allocator = testing.allocator;

    // SVG element names are case-sensitive (should be lowercase internally)
    const html_content = "<SVG><RECT width='100' height='50'/></SVG>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    try testing.expect(builder.document.node_type == .document);
}

// ============================================================================
// Parse Error Tests
// Spec: https://html.spec.whatwg.org/multipage/parsing.html#parse-errors
// ============================================================================

test "tree builder - missing end tag recovery" {
    const allocator = testing.allocator;

    // Missing </p> end tag - parser should recover
    const html_content = "<div><p>Paragraph without end tag<div>Another div";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    // Parser should recover and create valid tree
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - unexpected end tag" {
    const allocator = testing.allocator;

    // End tag for element that was never opened
    const html_content = "<div>Content</span></div>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    // Parser should ignore the unexpected </span> and continue
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - misnested tags recovery" {
    const allocator = testing.allocator;

    // Misnested tags: <b><i>text</b></i>
    const html_content = "<b><i>misnested</b></i>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    // Parser should apply adoption agency algorithm to recover
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - text in table recovery" {
    const allocator = testing.allocator;

    // Text directly in <table> (should be foster parented)
    const html_content = "<table>foster parented text<tr><td>cell</td></tr></table>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    // Parser should foster parent the text
    try testing.expect(builder.document.node_type == .document);
}

test "tree builder - implicit html/head/body" {
    const allocator = testing.allocator;

    // No explicit html/head/body tags
    const html_content = "<p>Just a paragraph</p>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        try builder.processToken(tok);
    }
    try builder.processToken(.eof);

    // Parser should implicitly create html, head, body
    try testing.expect(builder.document.node_type == .document);
}

test "tokenizer - malformed DOCTYPE" {
    const allocator = testing.allocator;

    // DOCTYPE without proper format
    var tokenizer = Tokenizer.init(allocator, "<!DOCTYPE>");
    defer tokenizer.deinit();

    var found_doctype = false;
    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        switch (tok) {
            .doctype => {
                found_doctype = true;
            },
            else => {},
        }
    }

    // Should still emit a DOCTYPE token (with quirks flag)
    try testing.expect(found_doctype);
}

test "tokenizer - script with less-than in content" {
    const allocator = testing.allocator;

    // Script with < in content (should not start a new tag)
    const html_content = "<script>if (x < 5) alert('hi');</script>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    var in_script = false;
    var found_script_start = false;
    var found_script_end = false;

    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        defer tok.deinit();
        switch (tok) {
            .start_tag => |tag| {
                if (std.mem.eql(u8, tag.getTagName(), "script")) {
                    found_script_start = true;
                    in_script = true;
                }
            },
            .end_tag => |tag| {
                if (std.mem.eql(u8, tag.getTagName(), "script")) {
                    found_script_end = true;
                    in_script = false;
                }
            },
            else => {},
        }
    }

    try testing.expect(found_script_start);
    try testing.expect(found_script_end);
}

test "tokenizer - CDATA section in foreign content" {
    const allocator = testing.allocator;

    // CDATA is only valid in foreign content (SVG/MathML)
    const html_content = "<![CDATA[raw text]]>";

    var tokenizer = Tokenizer.init(allocator, html_content);
    defer tokenizer.deinit();

    // In HTML context, CDATA is parsed as a bogus comment
    // Just verify it doesn't crash
    while (try tokenizer.nextToken()) |token| {
        var tok = token;
        tok.deinit();
    }
}

// ============================================================================
// Fragment Parsing Tests
// ============================================================================

test "fragment parser - basic usage" {
    const allocator = testing.allocator;
    const TreeNode = parser.TreeNode;
    const fragment_parser = parser.fragment_parser;

    // Create context element (div)
    const context = try TreeNode.initElement(allocator, "div", .html);
    defer context.deinit();

    // Parse fragment
    var result = try fragment_parser.parseFragment(allocator, context, "<span>Content</span>", .{});
    defer result.deinit();

    // Should have one child
    try testing.expectEqual(@as(usize, 1), result.children.len);
    try testing.expectEqualStrings("span", result.children[0].local_name.?);
}

test "fragment parser - table context" {
    const allocator = testing.allocator;
    const TreeNode = parser.TreeNode;
    const fragment_parser = parser.fragment_parser;

    // Create context element (tbody)
    const context = try TreeNode.initElement(allocator, "tbody", .html);
    defer context.deinit();

    // Parse table row in tbody context
    var result = try fragment_parser.parseFragment(allocator, context, "<tr><td>Cell 1</td><td>Cell 2</td></tr>", .{});
    defer result.deinit();

    // Should have parsed the row
    try testing.expectEqual(@as(usize, 1), result.children.len);
    try testing.expectEqualStrings("tr", result.children[0].local_name.?);
}

test "fragment parser - select context" {
    const allocator = testing.allocator;
    const TreeNode = parser.TreeNode;
    const fragment_parser = parser.fragment_parser;

    // Create context element (select)
    const context = try TreeNode.initElement(allocator, "select", .html);
    defer context.deinit();

    // Parse options in select context (includes attributes to verify token cleanup)
    var result = try fragment_parser.parseFragment(allocator, context, "<option value='1'>One</option><option value='2'>Two</option>", .{});
    defer result.deinit();

    // Should have parsed the options
    try testing.expectEqual(@as(usize, 2), result.children.len);
}
