//! Tree construction: the text the tokenizer's character tokens build.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#tokenization
//!
//! Each case parses a document and serializes the body the way html5lib's
//! tree-construction tests do - one line per node - so a failure prints the
//! tree that was built.

const std = @import("std");
const testing = std.testing;

const html = @import("html");
const parser = html.parser;
const Tokenizer = parser.Tokenizer;
const TreeBuilder = parser.TreeBuilder;
const TreeNode = parser.TreeNode;

/// The body's subtree, html5lib style: two spaces per level below body.
fn serializeBody(allocator: std.mem.Allocator, builder: *TreeBuilder) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    const html_node = builder.document.first_child orelse return out.toOwnedSlice(allocator);
    var child = html_node.first_child;
    while (child) |c| : (child = c.next_sibling) {
        if (c.hasTagName("body")) {
            var body_child = c.first_child;
            while (body_child) |b| : (body_child = b.next_sibling) try serializeNode(allocator, &out, b, 0);
        }
    }
    return out.toOwnedSlice(allocator);
}

fn serializeNode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), node: *TreeNode, depth: usize) !void {
    for (0..depth) |_| try out.appendSlice(allocator, "  ");
    switch (node.node_type) {
        .element => {
            try out.append(allocator, '<');
            try out.appendSlice(allocator, node.local_name orelse "");
            try out.appendSlice(allocator, ">\n");
        },
        .text => {
            try out.append(allocator, '"');
            try out.appendSlice(allocator, node.text_content.toSlice());
            try out.appendSlice(allocator, "\"\n");
        },
        .comment => {
            try out.appendSlice(allocator, "<!-- ");
            try out.appendSlice(allocator, node.text_content.toSlice());
            try out.appendSlice(allocator, " -->\n");
        },
        else => {},
    }
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) try serializeNode(allocator, out, c, depth + 1);
}

fn expectBody(input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    const actual = try serializeBody(allocator, &builder);
    defer allocator.free(actual);
    try testing.expectEqualStrings(expected, actual);
}

test "an ampersand that begins no character reference stays where it was" {
    // "Flush code points consumed as a character reference" emits the "&" (or
    // "&#", "&#x") there and then; the text after it comes after it. The
    // tokenizer queued the flushed characters and handed back the next text
    // run first: "a && b" became "a  b&&".
    try expectBody("<p>a && b</p><p>1 &# 2</p><p>&#x; x</p>",
        \\<p>
        \\  "a && b"
        \\<p>
        \\  "1 &# 2"
        \\<p>
        \\  "&#x; x"
        \\
    );
}

test "an ampersand at the end of the input is text, not lost" {
    // "a &" ends in the character reference state: the flushed "&" is queued
    // as the input ends, and it still comes before end-of-file.
    try expectBody("<p>a &",
        \\<p>
        \\  "a &"
        \\
    );
}
