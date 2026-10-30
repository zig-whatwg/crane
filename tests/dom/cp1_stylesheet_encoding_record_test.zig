//! The fetched encoding is sheet metadata, independent of the source buffer.
const std = @import("std");
const dom = @import("dom");
const stylesheet_encoding = dom.style.css.rules.stylesheet_encoding;

fn retainedEncoding(a: std.mem.Allocator) !void {
    const encoding = stylesheet_encoding.encodingForLabel("windows-1251").?;
    const parent = try dom.style.SheetRecord.create(a, "a { color: red }", .{
        .location = "https://sheet.example/parent.css",
        .base_url = "https://sheet.example/parent.css",
        .encoding = encoding,
    });
    defer parent.unref();
    _ = try parent.rulesWith(.{ .allocator = a });
    try std.testing.expect(parent.text == null);
    parent.detach();
    try std.testing.expect(parent.encoding == encoding);
    // CSS Cascade 5 section 2.2: an import's environment encoding comes
    // from its parent, including after the parent's bytes have gone away.
    var child = try stylesheet_encoding.decode(a, ".\xe6 { color: blue }", .{
        .environment_label = parent.encoding.?.name,
    });
    defer child.deinit(a);
    try std.testing.expectEqualStrings(".ж { color: blue }", child.text);
    try std.testing.expect(child.encoding == encoding);
}

test "a fetched stylesheet keeps its encoding after lazy parsing and detachment" {
    try retainedEncoding(std.testing.allocator);
}

test "retaining a stylesheet encoding and decoding a later child unwind every allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, retainedEncoding, .{});
}

test "a Unicode-created stylesheet has no fetched byte encoding" {
    const record = try dom.style.SheetRecord.create(std.testing.allocator, "", .{});
    defer record.unref();
    try std.testing.expect(record.encoding == null);
}
