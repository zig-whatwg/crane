//! The HTML parser sanitizes as it parses (HTML 13.2.6.1, the parser
//! sanitizer configuration): an element the configuration removes or
//! replaces with its children is never inserted ("insert an element at the
//! adjusted insertion location" step 3), and what would go into a replaced
//! one goes where it would have been (the insertion target redirection map,
//! "adjusted insertion location" step 5) - so the Text on either side of
//! what is kept out coalesces ("insert a character" step 6). The adoption
//! agency algorithm keeps the map (steps 12-13, 18.8-18.11, 21, 27-32).
//!
//! The cases are WPT's sanitizer-api .dat files' (sethtml-tree-construction,
//! sethtml-safety, sanitizer-in-adoption-agency at 2358bd4835), parsed here
//! as a document's body; Chrome 157 and Firefox 160 pass them, Safari 27.2
//! does not (lane maj2).
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#insert-an-element-at-the-adjusted-insertion-location
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#adoption-agency-algorithm

const std = @import("std");
const testing = std.testing;

const parser = @import("html").parser;
const Tokenizer = parser.Tokenizer;
const TreeBuilder = parser.TreeBuilder;
const TreeNode = parser.TreeNode;

/// A configuration that replaces the HTML elements named in `replace` with
/// their children and removes those named in `remove`; it allows every
/// attribute, no comment and every processing instruction.
const Config = struct {
    replace: []const []const u8 = &.{},
    remove: []const []const u8 = &.{},
    /// SVG and MathML elements removed, by local name.
    remove_foreign: []const []const u8 = &.{},

    fn parserSanitizer(self: *const Config) parser.ParserSanitizer {
        return .{
            .context = self,
            .element_action = &elementAction,
            .allows_attribute = &allowsAttribute,
            .allows_comments = &allowsComments,
            .allows_processing_instruction = &allowsProcessingInstruction,
        };
    }

    fn has(list: []const []const u8, name: []const u8) bool {
        for (list) |entry| if (std.mem.eql(u8, entry, name)) return true;
        return false;
    }

    fn elementAction(context: *const anyopaque, local: []const u8, namespace: parser.Namespace) parser.SanitizerAction {
        const self: *const Config = @ptrCast(@alignCast(context));
        if (namespace != .html) return if (has(self.remove_foreign, local)) .remove else .keep;
        if (has(self.replace, local)) return .replace_with_children;
        if (has(self.remove, local)) return .remove;
        return .keep;
    }

    fn allowsAttribute(_: *const anyopaque, _: []const u8, _: parser.Namespace, _: *const TreeNode.Attribute) bool {
        return true;
    }

    fn allowsComments(_: *const anyopaque) bool {
        return false;
    }

    fn allowsProcessingInstruction(_: *const anyopaque, _: []const u8) bool {
        return true;
    }
};

fn indent(output: *std.ArrayList(u8), depth: usize) !void {
    for (0..depth) |_| try output.appendSlice(testing.allocator, "  ");
}

/// html5lib's tree dump, one line per node, two spaces per level.
fn dumpNode(output: *std.ArrayList(u8), node: *TreeNode, depth: usize) !void {
    const allocator = testing.allocator;
    try indent(output, depth);
    switch (node.node_type) {
        .element => {
            try output.append(allocator, '<');
            if (node.namespace == .svg) try output.appendSlice(allocator, "svg ");
            if (node.namespace == .mathml) try output.appendSlice(allocator, "math ");
            try output.appendSlice(allocator, node.local_name orelse "");
            try output.appendSlice(allocator, ">\n");
        },
        .text => {
            try output.append(allocator, '"');
            try output.appendSlice(allocator, node.text_content.toSlice());
            try output.appendSlice(allocator, "\"\n");
        },
        .comment => {
            try output.appendSlice(allocator, "<!-- ");
            try output.appendSlice(allocator, node.text_content.toSlice());
            try output.appendSlice(allocator, " -->\n");
        },
        else => try output.appendSlice(allocator, "?\n"),
    }
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) try dumpNode(output, c, depth + 1);
}

/// The body element of the parser's tree.
fn bodyOf(builder: *TreeBuilder) ?*TreeNode {
    const html = builder.document.first_child orelse return null;
    var child = html.first_child;
    while (child) |c| : (child = c.next_sibling) {
        if (c.node_type == .element and c.hasTagName("body")) return c;
    }
    return null;
}

/// Parse "<body>" ++ `input` as a document with `config` as the parser's
/// sanitizer configuration (none when null), and compare the body's children with
/// `expected` (html5lib's dump, relative to the body).
fn expectBody(config: ?Config, input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    const markup = try std.mem.concat(allocator, u8, &.{ "<body>", input });
    defer allocator.free(markup);
    var tokenizer = Tokenizer.init(allocator, markup);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    if (config) |*given| builder.parser_sanitizer = given.parserSanitizer();
    try builder.parse();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    const body = bodyOf(&builder) orelse return error.NoBody;
    var child = body.first_child;
    while (child) |c| : (child = c.next_sibling) try dumpNode(&output, c, 0);
    testing.expectEqualStrings(expected, output.items) catch |err| {
        std.debug.print("input: {s}\n", .{input});
        return err;
    };
}

test "text around a replaced element coalesces into one Text node" {
    // sethtml-tree-construction #20.
    try expectBody(.{ .replace = &.{"div"} }, "<div>test<div>p</div>tt<p>div</p></div>",
        \\"testptt"
        \\<p>
        \\  "div"
        \\
    );
    // #68.
    try expectBody(.{ .replace = &.{"div"} }, "test<div>p</div>tt<p>div</p>",
        \\"testptt"
        \\<p>
        \\  "div"
        \\
    );
    // #110: the title's RCDATA text goes where the title would have been.
    try expectBody(.{ .replace = &.{"title"} }, "<title>a&amp;b<b></title>c",
        \\"a&b<b>c"
        \\
    );
}

test "text around a removed element or comment coalesces" {
    // sethtml-safety #2: a removed script and its contents.
    try expectBody(.{ .remove = &.{"script"} }, "<div>Hello<script>World</script>xxx",
        \\<div>
        \\  "Helloxxx"
        \\
    );
    // basic-filtering comments/1: a comment the configuration drops.
    try expectBody(.{}, "a <!-- comment --> b",
        \\"a  b"
        \\
    );
}

test "a replaced table's children and foster-parented text go where it would have been" {
    // sethtml-tree-construction #88: the table is never inserted, so the
    // foster parent is the element above it on the stack - the body here.
    try expectBody(.{ .replace = &.{"table"} }, "<table><tr><td>y</td></tr>x</table>",
        \\<tbody>
        \\  <tr>
        \\    <td>
        \\      "y"
        \\"x"
        \\
    );
    // #90.
    try expectBody(.{ .replace = &.{"table"} }, "a<table><tr><td>y</td></tr>b</table>c",
        \\"a"
        \\<tbody>
        \\  <tr>
        \\    <td>
        \\      "y"
        \\"bc"
        \\
    );
    // #96: a removed table; foster-parented text joins the text before it.
    try expectBody(.{ .remove = &.{"table"} }, "a<table>b<tr><td>c</table>d",
        \\"abd"
        \\
    );
}

test "the adoption agency algorithm keeps the insertion target redirection map" {
    // sanitizer-in-adoption-agency #5.
    try expectBody(.{ .replace = &.{"b"} }, "<b>1<p>foo</b>bar",
        \\"1"
        \\<p>
        \\  "foobar"
        \\
    );
    // #6: the formatting element's clone goes where the replaced div
    // would have been - after the first b.
    try expectBody(.{ .replace = &.{"div"} }, "<b><div>Text</b>",
        \\<b>
        \\  "Text"
        \\<b>
        \\
    );
    // #37.
    try expectBody(.{ .replace = &.{ "b", "div" } }, "<b><div>Text</b>after",
        \\"Textafter"
        \\
    );
}

/// Parse `markup` as a document with `config` as the parser's sanitizer
/// configuration, and compare the whole tree (html5lib's dump, relative to
/// the Document) with `expected`. std.testing.allocator fails the test when
/// a node the configuration kept out of the tree is not freed with the
/// builder.
fn expectDocument(config: Config, markup: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, markup);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    builder.parser_sanitizer = config.parserSanitizer();
    try builder.parse();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    var child = builder.document.first_child;
    while (child) |c| : (child = c.next_sibling) try dumpNode(&output, c, 0);
    testing.expectEqualStrings(expected, output.items) catch |err| {
        std.debug.print("markup: {s}\n", .{markup});
        return err;
    };
}

test "an element the parser makes itself and the configuration keeps out is freed with the builder" {
    // The implied head (before head, "anything else"): removed. Lane maj2's
    // bug-finding sweep leaked one 624-byte TreeNode per parse of
    // sanitizer-duplicate-html-body.html's html/body-only configurations.
    try expectDocument(.{ .remove = &.{"head"} }, "<p>x",
        \\<html>
        \\  <body>
        \\    <p>
        \\      "x"
        \\
    );
    // The implied body (after head, "anything else"): replaced, so the p
    // goes where the body would have been.
    try expectDocument(.{ .replace = &.{"body"} }, "<p>x",
        \\<html>
        \\  <head>
        \\  <p>
        \\    "x"
        \\
    );
    // The implied tbody and tr (in table and in table body, a td start
    // tag): replaced, so the td goes into the table.
    try expectDocument(.{ .replace = &.{ "tbody", "tr" } }, "<table><td>x",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <table>
        \\      <td>
        \\        "x"
        \\
    );
    // The implied colgroup (in table, a col start tag): removed with the col
    // inserted into it.
    try expectDocument(.{ .remove = &.{"colgroup"} }, "<table><col>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <table>
        \\
    );
    // The implied p of a p end tag with no p in button scope: replaced.
    try expectDocument(.{ .replace = &.{"p"} }, "</p>x",
        \\<html>
        \\  <head>
        \\  <body>
        \\    "x"
        \\
    );
    // A foreign element ("insert a foreign element"), removed with its child.
    try expectDocument(.{ .remove_foreign = &.{"svg"} }, "<svg><circle/></svg>y",
        \\<html>
        \\  <head>
        \\  <body>
        \\    "y"
        \\
    );
    // The implied html (before html, "anything else"): removed, so the
    // Document has no element.
    try expectDocument(.{ .remove = &.{"html"} }, "x", "");
}

test "a parse with no sanitizer configuration builds the tree it always did" {
    try expectBody(null, "<b>1<p>foo</b>bar",
        \\<b>
        \\  "1"
        \\<p>
        \\  <b>
        \\    "foo"
        \\  "bar"
        \\
    );
}
