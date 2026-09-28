//! Tree construction: foreign content (SVG and MathML) and attributes added to elements already made.
//!
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inbody
//!       ("A start tag whose tag name is "math"" / ""svg"")
//! Spec: https://html.spec.whatwg.org/multipage/parsing.html#parsing-main-inforeign
//!
//! Each case parses a document and serializes the body the way html5lib's
//! tree-construction tests do - one line per node, `<svg script>` for an
//! element in the SVG namespace, `xlink href="..."` for a namespaced
//! attribute - so a failure prints the tree that was built.

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
            switch (node.namespace) {
                .html => {},
                .svg => try out.appendSlice(allocator, "svg "),
                .mathml => try out.appendSlice(allocator, "math "),
            }
            try out.appendSlice(allocator, node.local_name orelse "");
            try out.appendSlice(allocator, ">\n");
            for (node.attributes.toSlice()) |attr| {
                for (0..depth + 1) |_| try out.appendSlice(allocator, "  ");
                if (attr.prefix) |p| {
                    try out.appendSlice(allocator, p);
                    try out.append(allocator, ' ');
                }
                try out.appendSlice(allocator, attr.name);
                try out.appendSlice(allocator, "=\"");
                try out.appendSlice(allocator, attr.value);
                try out.appendSlice(allocator, "\"\n");
            }
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

test "an svg start tag in body inserts an element in the SVG namespace, and its children follow" {
    try expectBody("<svg><script>a</script><path></path></svg>",
        \\<svg svg>
        \\  <svg script>
        \\    "a"
        \\  <svg path>
        \\
    );
}

test "a math start tag in body inserts an element in the MathML namespace" {
    try expectBody("<math><mi>x</mi></math>",
        \\<math math>
        \\  <math mi>
        \\    "x"
        \\
    );
}

test "an SVG element's tag name and attributes are case-adjusted" {
    try expectBody("<svg viewbox=\"0 0 1 1\"><clippath></clippath><foreignobject></foreignobject></svg>",
        \\<svg svg>
        \\  viewBox="0 0 1 1"
        \\  <svg clipPath>
        \\  <svg foreignObject>
        \\
    );
}

test "a MathML element's definitionurl is adjusted" {
    try expectBody("<math definitionurl=\"u\"></math>",
        \\<math math>
        \\  definitionURL="u"
        \\
    );
}

test "the attributes in the foreign attributes table get their prefix and namespace, and only those" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<svg xlink:href=\"#a\" xml:lang=\"en\" xmlns=\"n\" xmlns:xlink=\"x\" xlink:foo=\"f\"></svg>");
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();

    const body = builder.document.first_child.?.last_child.?;
    const svg = body.first_child.?;
    const attrs = svg.attributes.toSlice();
    try testing.expectEqual(@as(usize, 5), attrs.len);

    try testing.expectEqualStrings("href", attrs[0].name);
    try testing.expectEqualStrings("xlink", attrs[0].prefix.?);
    try testing.expectEqualStrings("http://www.w3.org/1999/xlink", attrs[0].namespace.?.uri());

    try testing.expectEqualStrings("lang", attrs[1].name);
    try testing.expectEqualStrings("xml", attrs[1].prefix.?);
    try testing.expectEqualStrings("http://www.w3.org/XML/1998/namespace", attrs[1].namespace.?.uri());

    // "xmlns": no prefix, local name xmlns, the XMLNS namespace.
    try testing.expectEqualStrings("xmlns", attrs[2].name);
    try testing.expect(attrs[2].prefix == null);
    try testing.expectEqualStrings("http://www.w3.org/2000/xmlns/", attrs[2].namespace.?.uri());

    try testing.expectEqualStrings("xlink", attrs[3].name);
    try testing.expectEqualStrings("xmlns", attrs[3].prefix.?);

    // Not in the table: an ordinary attribute whose name has a colon.
    try testing.expectEqualStrings("xlink:foo", attrs[4].name);
    try testing.expect(attrs[4].prefix == null);
    try testing.expect(attrs[4].namespace == null);
}

test "an HTML breakout tag leaves foreign content" {
    try expectBody("<svg><g><p>x</p></g></svg>",
        \\<svg svg>
        \\  <svg g>
        \\<p>
        \\  "x"
        \\
    );
}

test "foreignObject is an HTML integration point" {
    try expectBody("<svg><foreignObject><div>x</div></foreignObject></svg>",
        \\<svg svg>
        \\  <svg foreignObject>
        \\    <div>
        \\      "x"
        \\
    );
}

test "annotation-xml is an HTML integration point only with an HTML encoding" {
    try expectBody("<math><annotation-xml encoding=\"Text/HTML\"><foo></foo></annotation-xml></math>",
        \\<math math>
        \\  <math annotation-xml>
        \\    encoding="Text/HTML"
        \\    <foo>
        \\
    );
    try expectBody("<math><annotation-xml><foo></foo></annotation-xml></math>",
        \\<math math>
        \\  <math annotation-xml>
        \\    <math foo>
        \\
    );
}

test "an svg start tag inside annotation-xml is SVG" {
    try expectBody("<math><annotation-xml><svg></svg></annotation-xml></math>",
        \\<math math>
        \\  <math annotation-xml>
        \\    <svg svg>
        \\
    );
}

test "a MathML text integration point parses HTML start tags as HTML, except mglyph and malignmark" {
    try expectBody("<math><mi><b>x</b><mglyph></mglyph></mi></math>",
        \\<math math>
        \\  <math mi>
        \\    <b>
        \\      "x"
        \\    <math mglyph>
        \\
    );
}

test "a CDATA section is text in foreign content and a bogus comment in HTML" {
    try expectBody("<svg><![CDATA[a<b]]></svg><div><![CDATA[c]]></div>",
        \\<svg svg>
        \\  "a<b"
        \\<div>
        \\  <!-- [CDATA[c]] -->
        \\
    );
}

test "a script inside svg is not script data: its markup is parsed" {
    try expectBody("<svg><script>x<g></g>y</script></svg>",
        \\<svg svg>
        \\  <svg script>
        \\    "x"
        \\    <svg g>
        \\    "y"
        \\
    );
}

const ScriptRecorder = struct {
    var names: [8]u8 = undefined;
    var count: usize = 0;
    fn callback(node: *TreeNode, _: ?*anyopaque) void {
        names[count] = switch (node.namespace) {
            .svg => 's',
            .html => 'h',
            .mathml => 'm',
        };
        count += 1;
    }
};

test "an SVG script's end tag, or its self-closing start tag, hands it to the script callback" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<svg><script>a</script><script/></svg><script>b</script>");
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    builder.scripting_enabled = true;
    ScriptRecorder.count = 0;
    builder.setScriptExecutionCallback(&ScriptRecorder.callback, null);
    try builder.parse();
    try testing.expectEqualStrings("ssh", ScriptRecorder.names[0..ScriptRecorder.count]);
}

const AttributeRecorder = struct {
    var seen: [4][]const u8 = undefined;
    var count: usize = 0;
    fn callback(node: *TreeNode, attr: *const TreeNode.Attribute, _: ?*anyopaque) void {
        _ = node;
        seen[count] = attr.name;
        count += 1;
    }
};

test "a second body start tag adds its missing attributes to the body, and tells the adapter" {
    // "in body", a start tag whose tag name is "body": "for each attribute on
    // the token, check to see if the attribute is already present on the body
    // element (the second element) on the stack of open elements, and if it
    // is not, add the attribute and its corresponding value to that element."
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<body class=a><p>x</p><body class=b onload=f()>");
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    AttributeRecorder.count = 0;
    builder.setDomAdapterAttributeCallback(&AttributeRecorder.callback);
    try builder.parse();

    const body = builder.document.first_child.?.last_child.?;
    try testing.expectEqualStrings("a", body.getAttribute("class").?);
    try testing.expectEqualStrings("f()", body.getAttribute("onload").?);
    try testing.expectEqual(@as(usize, 1), AttributeRecorder.count);
    try testing.expectEqualStrings("onload", AttributeRecorder.seen[0]);
}

test "a fragment parsed with an svg context element is SVG: the context is the adjusted current node" {
    // "The adjusted current node is the context element if the parser was
    // created as part of the HTML fragment parsing algorithm and the stack of
    // open elements has only one element in it" (innerHTML on an svg element).
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<g></g><clippath></clippath><div></div>");
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    const root = try TreeNode.initElement(allocator, "html", .html);
    builder.document.appendChild(root);
    try builder.open_elements.append(root);
    builder.insertion_mode = .in_body;
    const context = try TreeNode.initElement(allocator, "svg", .svg);
    defer context.deinit();
    builder.fragment_context = context;
    try builder.parse();

    const g = root.first_child.?;
    try testing.expectEqual(parser.Namespace.svg, g.namespace);
    const clip = g.next_sibling.?;
    try testing.expectEqualStrings("clipPath", clip.local_name.?);
    // A breakout tag leaves foreign content even in a fragment.
    const div = clip.next_sibling.?;
    try testing.expectEqual(parser.Namespace.html, div.namespace);
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

test "a named character reference in text consumes exactly the name it matched" {
    // "Consume the maximum number of characters possible, where the consumed
    // characters are one of the identifiers in the named character references
    // table." A name that matches nothing consumes nothing: the ambiguous
    // ampersand state emits its characters. After a shorter match ("not" of
    // "notit;"), the rest is the return state's. The tokenizer consumed the
    // whole run of name characters and dropped what it did not match: "x &c y"
    // read "x & y", "AT&T" read "AT&".
    try expectBody("<p>x &c y</p><p>AT&T</p><p>&notit;</p>",
        \\<p>
        \\  "x &c y"
        \\<p>
        \\  "AT&T"
        \\<p>
        \\  "¬it;"
        \\
    );
}

test "a named character reference emits every code point it stands for" {
    // &NotEqualTilde; is U+2242 U+0338: the second code point was dropped.
    try expectBody("<p>&NotEqualTilde;&amp;</p>",
        \\<p>
        \\  "≂̸&"
        \\
    );
}

test "in an attribute value, a legacy name followed by an alphanumeric or = is left as written" {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, "<p title=\"&notit; &not;x &amp=1 &c\">");
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();

    const body = builder.document.first_child.?.last_child.?;
    const p = body.first_child.?;
    try testing.expectEqualStrings("&notit; ¬x &amp=1 &c", p.attributes.toSlice()[0].value);
}

test "the character after a numeric character reference is kept" {
    // The numeric character reference end state consumes nothing: entered
    // after the ";", or reconsuming the character that ended the digits, it
    // hands that character to the return state. The tokenizer consumed one
    // more character to run the state, and dropped it: "&#65;x" read "A".
    try expectBody("<p>&#65;x &#66x &#x43;y &#x44y</p>",
        \\<p>
        \\  "Ax Bx Cy Dy"
        \\
    );
}
