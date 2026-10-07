//! HTML 13.2.6.4.7 adoption agency: real moves and saved formatting tokens.
const std = @import("std");
const parser = @import("html").parser;
const TreeNode = parser.TreeNode;

fn writeTree(node: *TreeNode, out: *std.ArrayList(u8)) !void {
    const allocator = std.testing.allocator;
    if (node.node_type == .text) {
        try out.appendSlice(allocator, node.text_content.toSlice());
        return;
    }
    try out.appendSlice(allocator, node.local_name orelse "#");
    if (node.getAttribute("data-copy")) |value| {
        try out.append(allocator, '=');
        try out.appendSlice(allocator, value);
    }
    try out.append(allocator, '[');
    var child = node.first_child;
    while (child) |value| : (child = value.next_sibling) try writeTree(value, out);
    try out.append(allocator, ']');
}

fn expectFragment(input: []const u8, expected: []const u8) !void {
    const allocator = std.testing.allocator;
    const context = try TreeNode.initElement(allocator, "div", .html);
    defer context.deinit();
    var result = try parser.parseFragment(allocator, context, input, .{});
    defer result.deinit();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    for (result.children) |child| try writeTree(child, &output);
    try std.testing.expectEqualStrings(expected, output.items);
}

test "adoption agency moves a furthest block and retains token attributes" {
    try expectFragment("<b data-copy=yes>1<p>2</b>3</p>", "b=yes[1]p[b=yes[2]3]");
}

test "adoption agency clones inner formatting elements" {
    try expectFragment("<b><i data-copy=inner>1<p>2</b>3</i>4</p>", "b[i=inner[1]]i=inner[]p[i=inner[b[2]3]4]");
}

test "reconstruction includes the first unopened entry and its attributes" {
    try expectFragment("<p><b data-copy=b><i data-copy=i>x</p>y", "p[b=b[i=i[x]]]b=b[i=i[y]]");
}

test "Noahs Ark compares attributes before dropping a formatting entry" {
    try expectFragment("<p><b data-copy=one><b data-copy=two><b data-copy=three><b data-copy=four>x</p>y", "p[b=one[b=two[b=three[b=four[x]]]]]b=one[b=two[b=three[b=four[y]]]]");
}

test "formatting token storage is freed when parsing ends or entries are removed" {
    try expectFragment("<b data-copy='a long attribute value held by a heap allocation'>x</b>", "b=a long attribute value held by a heap allocation[x]");
}

test "fostered text precedes the table and is reconstructed with formatting" {
    try expectFragment("<table>one<tr><td>cell</td></tr>two</table>", "onetwotable[tbody[tr[td[cell]]]]");
    try expectFragment("<table><b data-copy=b>x<tr><td>cell</td></tr>y</table>", "b=b[x]b=b[y]table[tbody[tr[td[cell]]]]");
}

test "nested anchor and nobr starts close the previous formatting element" {
    try expectFragment("<a>one<a>two</a>three", "a[one]a[two]three");
    try expectFragment("<nobr>one<nobr>two</nobr>three", "nobr[one]nobr[two]three");
}

test "formatting markers keep reconstruction inside objects" {
    try expectFragment("<object><b>x</object>y", "object[b[x]]y");
}

test "Noahs Ark removes the earliest fourth identical entry" {
    try expectFragment("<p><b><b><b><b>x</p>y", "p[b[b[b[b[x]]]]]b[b[b[y]]]");
}

test "adoption special elements include buttons and foreign integration points" {
    try expectFragment("<b>1<button>2</b>3</button>", "b[1]button[b[2]3]");
}
