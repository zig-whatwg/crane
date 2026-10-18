//! <template for> (HTML "prepare content patching") on the tree-then-convert
//! path, where the tree builder patches its own tree: DOMParser, innerHTML
//! and the other fragment parsers. The live parser's patching is covered by
//! the template-for WPT files and crane/p1-template-for-*.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inhead
//! ("A start tag whose tag name is "template"", "Keep" step 2) and
//! https://html.spec.whatwg.org/multipage/scripting.html#prepare-content-patching

const std = @import("std");
const testing = std.testing;

const html = @import("html");
const parser = html.parser;
const Tokenizer = parser.Tokenizer;
const TreeBuilder = parser.TreeBuilder;
const TreeNode = parser.TreeNode;

/// The body's children, as compact markup: elements, text, `<?target data?>`.
fn serializeChildren(allocator: std.mem.Allocator, out: *std.ArrayList(u8), node: *TreeNode) !void {
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) {
        switch (c.node_type) {
            .element => {
                try out.print(allocator, "<{s}>", .{c.local_name orelse ""});
                try serializeChildren(allocator, out, c);
                try out.print(allocator, "</{s}>", .{c.local_name orelse ""});
            },
            .text => try out.appendSlice(allocator, c.text_content.toSlice()),
            .processing_instruction => try out.print(allocator, "<?{s} {s}?>", .{ c.pi_target orelse "", c.text_content.toSlice() }),
            .comment => try out.print(allocator, "<!--{s}-->", .{c.text_content.toSlice()}),
            else => {},
        }
    }
}

fn expectBody(input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    const html_node = builder.document.first_child orelse return error.NoHtml;
    var child = html_node.first_child;
    while (child) |c| : (child = c.next_sibling) {
        if (c.hasTagName("head")) {
            try out.appendSlice(allocator, "[head]");
            try serializeChildren(allocator, &out, c);
        }
        if (c.hasTagName("body")) {
            try out.appendSlice(allocator, "[body]");
            try serializeChildren(allocator, &out, c);
        }
    }
    try testing.expectEqualStrings(expected, out.items);
}

test "a <template for> replaces the range between <?start> and <?end> and is not inserted" {
    try expectBody("<div><?start name=\"p\">Old<?end></div><template for=\"p\">New</template>", "[head][body]<div>New</div>");
}

test "a <template for> inserts at a <?marker>, which goes" {
    try expectBody("<div>a<?marker name=\"m\">b</div><template for=\"m\"><i>x</i></template>", "[head][body]<div>a<i>x</i>b</div>");
}

test "a <template for> in body patches head" {
    try expectBody("<head><?marker name=\"h\"></head><body><template for=\"h\"><meta></template>", "[head]<meta></meta>[body]");
}

test "a <template for> naming no marker is an ordinary template" {
    try expectBody("<div><?start name=\"p\">Old<?end></div><template for=\"q\">New</template>", "[head][body]<div><?start name=\"p\"?>Old<?end ?></div><template>New</template>");
}

test "an empty for attribute is an ordinary template" {
    try expectBody("<template for=\"\">x</template>", "[head]<template>x</template>[body]");
}

test "without an end marker the range runs to the end of the start marker's parent" {
    try expectBody("<div><?start name=\"p\">a<b>b</b></div><template for=\"p\">c</template>", "[head][body]<div>c</div>");
}

test "nested start and end markers pair up" {
    try expectBody("<div><?start name=\"p\">a<?start name=\"q\">b<?end>c<?end>d</div><template for=\"p\">x</template>", "[head][body]<div>xd</div>");
}

test "markers are matched by their name pseudo-attribute, case-sensitively" {
    try expectBody("<div><?marker Name=\"p\">1</div><div><?marker name=\"p\">2</div><template for=\"p\">x</template>", "[head][body]<div><?marker Name=\"p\"?>1</div><div>x2</div>");
}

test "a patching template left open at the end of the input still removes its markers" {
    try expectBody("<div><?start name=\"p\">Old<?end> content</div><template for=\"p\">New</template", "[head][body]<div>New content</div>");
}
