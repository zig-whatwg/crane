//! Tree construction: the elements the insertion modes name are HTML elements,
//! and "after head" resets the frameset-ok flag.
//!
//! HTML 13.2.4.2: "the stack of open elements is said to have a particular
//! element in table scope" - the element types of the list are HTML ones
//! (html, table, template), and "a tr element", "a tbody element" in the
//! in-table-body and in-row steps is an HTML element. So are the elements the
//! parser pops until ("pop elements until a template element has been
//! popped") and the ones "clear the stack back to a table ... context" stops
//! at. A MathML tbody, an SVG td or an SVG template in foreign content is none
//! of them. And the "after head" insertion mode's "anything else" inserts the
//! implied body and sets the frameset-ok flag to "ok" (HTML, 2026), so a
//! template in head does not keep a later frameset out.
//!
//! The cases are html5lib's (tests/wpt/html/syntax/parsing/resources/math.dat,
//! svg.dat, template.dat, namespace-sensitivity.dat), which Chrome, Firefox
//! and Safari all pass (wpt.fyi 2358bd4835, html5lib_url.html and
//! html5lib_write.html).

const std = @import("std");
const testing = std.testing;

const html = @import("html");
const parser = html.parser;
const Tokenizer = parser.Tokenizer;
const TreeBuilder = parser.TreeBuilder;
const TreeNode = parser.TreeNode;

/// `node`'s subtree, html5lib style: two spaces per level, `<svg td>` for an
/// element in the SVG namespace. A template's contents are its children here
/// (the tree builder alone keeps them there).
fn serialize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), node: *TreeNode, depth: usize) !void {
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
        },
        .text => {
            try out.append(allocator, '"');
            try out.appendSlice(allocator, node.text_content.toSlice());
            try out.appendSlice(allocator, "\"\n");
        },
        else => return,
    }
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) try serialize(allocator, out, c, depth + 1);
}

fn expectDocument(input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var child = builder.document.first_child;
    while (child) |c| : (child = c.next_sibling) try serialize(allocator, &out, c, 0);
    try testing.expectEqualStrings(expected, out.items);
}

fn expectFragment(context_name: []const u8, input: []const u8, expected: []const u8) !void {
    const allocator = testing.allocator;
    const context = try TreeNode.initElement(allocator, context_name, .html);
    defer context.deinit();
    var result = try parser.parseFragment(allocator, context, input, .{});
    defer result.deinit();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    for (result.children) |c| try serialize(allocator, &out, c, 0);
    try testing.expectEqualStrings(expected, out.items);
}

test "a MathML tbody is no tbody in table scope: a tfoot in a tbody fragment is ignored" {
    try expectFragment("tbody", "<math><tbody><mo><tfoot>",
        \\<math math>
        \\  <math tbody>
        \\    <math mo>
        \\
    );
    try expectFragment("tfoot", "<math><tfoot><mo><tbody>",
        \\<math math>
        \\  <math tfoot>
        \\    <math mo>
        \\
    );
    try expectFragment("thead", "<math><thead><mo><tbody>",
        \\<math math>
        \\  <math thead>
        \\    <math mo>
        \\
    );
}

test "an SVG tr is no tr in table scope: a tr in a tr fragment is ignored" {
    try expectFragment("tr", "<svg><tr><td><title><tr>",
        \\<svg svg>
        \\  <svg tr>
        \\    <svg td>
        \\      <svg title>
        \\
    );
    try expectFragment("tr", "<math><tr><td><mo><tr>",
        \\<math math>
        \\  <math tr>
        \\    <math td>
        \\      <math mo>
        \\
    );
}

test "an SVG template is not the template the in-template end of file pops to" {
    try expectDocument("<template><svg><template>",
        \\<html>
        \\  <head>
        \\    <template>
        \\      <svg svg>
        \\        <svg template>
        \\  <body>
        \\
    );
}

test "an SVG td is not the cell a td end tag closes" {
    try expectDocument("<body><table><tr><td><svg><td><foreignObject><span></td>Foo",
        \\<html>
        \\  <head>
        \\  <body>
        \\    "Foo"
        \\    <table>
        \\      <tbody>
        \\        <tr>
        \\          <td>
        \\            <svg svg>
        \\              <svg td>
        \\                <svg foreignObject>
        \\                  <span>
        \\
    );
}

test "after head's implied body sets frameset-ok to ok: a template in head does not keep a frameset out" {
    try expectDocument("<template>x</template><p><frameset>",
        \\<html>
        \\  <head>
        \\    <template>
        \\      "x"
        \\  <frameset>
        \\
    );
    try expectDocument("<head></head><template></template><p><frameset>",
        \\<html>
        \\  <head>
        \\    <template>
        \\  <frameset>
        \\
    );
    // A template in body still sets it to "not ok".
    try expectDocument("<p><template></template><frameset>",
        \\<html>
        \\  <head>
        \\  <body>
        \\    <p>
        \\      <template>
        \\
    );
}

/// The first element named `name` under `node`, in tree order.
fn find(node: *TreeNode, name: []const u8) ?*TreeNode {
    var child = node.first_child;
    while (child) |c| : (child = c.next_sibling) {
        if (c.node_type == .element and c.hasTagName(name)) return c;
        if (find(c, name)) |found| return found;
    }
    return null;
}

fn attributeOfFirstInput(input: []const u8) ![]u8 {
    const allocator = testing.allocator;
    var tokenizer = Tokenizer.init(allocator, input);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    const element = find(builder.document, "input") orelse return error.NoInput;
    return allocator.dupe(u8, element.getAttribute("value") orelse return error.NoValue);
}

test "a CR in an attribute value is a newline, and a later LF that does not follow it is one too" {
    // HTML 13.2.3.5: a CR not followed by an LF becomes an LF; only "a U+000D
    // CARRIAGE RETURN (CR) code point followed by a U+000A LINE FEED (LF)"
    // pair is one newline. Characters between them break the pair.
    // (html/syntax/parsing/newline-normalization-cr-then-lf.html: Chrome,
    // Firefox and Safari PASS at wpt.fyi 2358bd4835.)
    for ([_][]const u8{ "<body><input value='before\rABCDEF\nafter'>", "<body><input value=\"before\rABCDEF\nafter\">" }) |input| {
        const value = try attributeOfFirstInput(input);
        defer testing.allocator.free(value);
        try testing.expectEqualStrings("before\nABCDEF\nafter", value);
    }
    // A CR LF pair is still one newline.
    const pair = try attributeOfFirstInput("<body><input value='before\r\nafter'>");
    defer testing.allocator.free(pair);
    try testing.expectEqualStrings("before\nafter", pair);
}

fn documentMode(input: []const u8) !parser.QuirksMode {
    var tokenizer = Tokenizer.init(testing.allocator, input);
    defer tokenizer.deinit();
    var builder = try TreeBuilder.init(testing.allocator, &tokenizer);
    defer builder.deinit();
    try builder.parse();
    return builder.quirks_mode;
}

test "an HTML 4.01 Frameset or Transitional DOCTYPE with an empty system identifier is quirks, as with none" {
    // HTML 13.2.6.4.1 (whatwg/html#12023): "The system identifier is missing
    // or the empty string, and the public identifier starts with:
    // "-//W3C//DTD HTML 4.01 Frameset//"" - and Transitional - sets quirks
    // mode; a system identifier that is "neither missing nor the empty
    // string" sets limited-quirks. Chrome and Safari ship it
    // (html/syntax/parsing/doctype-system-identifier-distinction.html,
    // wpt.fyi 2358bd4835; Firefox not yet): golden rule 2, the newer spec.
    try testing.expectEqual(parser.QuirksMode.quirks, try documentMode("<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Frameset//EN\" \"\"><p>"));
    try testing.expectEqual(parser.QuirksMode.quirks, try documentMode("<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" ''><p>"));
    try testing.expectEqual(parser.QuirksMode.quirks, try documentMode("<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Frameset//EN\"><p>"));
    try testing.expectEqual(parser.QuirksMode.limited_quirks, try documentMode("<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Frameset//EN\" \"http://www.w3.org/TR/html4/frameset.dtd\"><p>"));
}
