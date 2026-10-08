//! The prescan's boundary applies to the whole byte window, not each attribute.
const std = @import("std");
const sniffing = @import("html_core").parser.encoding_sniffing;

test "prescan reads charset after a long MIME parameter inside the first 1024 bytes" {
    const a = std.testing.allocator;
    const bytes = try std.fmt.allocPrint(a, "<meta http-equiv=content-type content=\"text/html; note={s}; charset=iso-8859-15\">", .{"x" ** 90});
    defer a.free(bytes);
    const result = sniffing.sniff(bytes, .{});
    try std.testing.expectEqualStrings("ISO-8859-15", sniffing.canonicalName(result.encoding));
    try std.testing.expectEqual(sniffing.Confidence.tentative, result.confidence);
}

test "encoding labels can have long surrounding ASCII whitespace" {
    const a = std.testing.allocator;
    const bytes = try std.fmt.allocPrint(a, "<meta charset=\"{s}utf-8{s}\">", .{ " " ** 80, "\t" ** 80 });
    defer a.free(bytes);
    const result = sniffing.sniff(bytes, .{});
    try std.testing.expectEqualStrings("UTF-8", sniffing.canonicalName(result.encoding));
    const content_type = try std.fmt.allocPrint(a, "text/html; charset=\"{s}utf-8{s}\"", .{ " " ** 80, "\t" ** 80 });
    defer a.free(content_type);
    const transport = sniffing.transportEncoding(a, content_type) orelse return error.MissingTransportEncoding;
    try std.testing.expectEqualStrings("UTF-8", sniffing.canonicalName(transport));
}

test "a long meta attribute ending at the prescan boundary is accepted only when complete" {
    var bytes: [1025]u8 = @splat(' ');
    const declaration = "<meta content=\"text/html; charset=gbk\" http-equiv=content-type>";
    @memcpy(bytes[1024 - declaration.len .. 1024], declaration);
    try std.testing.expectEqualStrings("GBK", sniffing.canonicalName(sniffing.prescan(&bytes).?));
    @memmove(bytes[1..], bytes[0..1024]);
    bytes[0] = ' ';
    try std.testing.expect(sniffing.prescan(&bytes) == null);
}
