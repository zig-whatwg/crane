//! The prescan's boundary applies to the whole byte window, not each attribute.
const std = @import("std");
const sniffing = @import("html_core").parser.encoding_sniffing;
const meta_charset_scan = @import("html_core").parser.meta_charset_scan;

test "prescan reads charset after a long MIME parameter inside the first 1024 bytes" {
    const a = std.testing.allocator;
    const bytes = try std.fmt.allocPrint(a, "<meta http-equiv=content-type content=\"text/html; note={s}; charset=iso-8859-15\">", .{&@as([90:0]u8, @splat('x'))});
    defer a.free(bytes);
    const result = try meta_charset_scan.sniff(a, bytes, .{});
    try std.testing.expectEqualStrings("ISO-8859-15", sniffing.canonicalName(result.encoding));
    try std.testing.expectEqual(sniffing.Confidence.tentative, result.confidence);
}

test "encoding labels can have long surrounding ASCII whitespace" {
    const a = std.testing.allocator;
    const bytes = try std.fmt.allocPrint(a, "<meta charset=\"{s}utf-8{s}\">", .{ &@as([80:0]u8, @splat(' ')), &@as([80:0]u8, @splat(0x09)) });
    defer a.free(bytes);
    const result = try meta_charset_scan.sniff(a, bytes, .{});
    try std.testing.expectEqualStrings("UTF-8", sniffing.canonicalName(result.encoding));
    const content_type = try std.fmt.allocPrint(a, "text/html; charset=\"{s}utf-8{s}\"", .{ &@as([80:0]u8, @splat(' ')), &@as([80:0]u8, @splat(0x09)) });
    defer a.free(content_type);
    const transport = sniffing.transportEncoding(a, content_type) orelse return error.MissingTransportEncoding;
    try std.testing.expectEqualStrings("UTF-8", sniffing.canonicalName(transport));
}

test "a long meta attribute ending at or after the 1024th character is read whole" {
    const a = std.testing.allocator;
    var bytes: [1025]u8 = @splat(' ');
    const declaration = "<meta content=\"text/html; charset=gbk\" http-equiv=content-type>";
    @memcpy(bytes[1024 - declaration.len .. 1024], declaration);
    try std.testing.expectEqualStrings("GBK", sniffing.canonicalName((try meta_charset_scan.prescan(a, &bytes)).?));
    // One byte later it ends at the 1025th: the browsers' scan reads a tag
    // that starts within its 1024 characters to its end (the spec's byte
    // scan, cut at 1024 bytes, ran out inside it) - and after a <p> too.
    @memmove(bytes[1..], bytes[0..1024]);
    bytes[0] = ' ';
    try std.testing.expectEqualStrings("GBK", sniffing.canonicalName((try meta_charset_scan.prescan(a, &bytes)).?));
    @memcpy(bytes[0..3], "<p>");
    try std.testing.expectEqualStrings("GBK", sniffing.canonicalName((try meta_charset_scan.prescan(a, &bytes)).?));
}
