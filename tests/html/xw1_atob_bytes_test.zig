const std = @import("std");
const html = @import("html_core");

test "xw1 atob ByteString result is raw octets while native text stays UTF-8" {
    const util = html.base64_utility;
    try std.testing.expect(@hasDecl(util, "atobBytes"));
    if (comptime !@hasDecl(util, "atobBytes")) return;
    const a = std.testing.allocator;
    var raw: [128]u8 = undefined;
    for (&raw, 128..) |*byte, n| byte.* = @intCast(n);
    const encoded = try @import("infra").base64.forgivingBase64Encode(a, &raw);
    defer a.free(encoded);
    const bytes = try util.atobBytes(a, encoded);
    defer a.free(bytes);
    try std.testing.expectEqualSlices(u8, &raw, bytes);
    const text = try util.atob(a, encoded);
    defer a.free(text);
    const back = try util.btoa(a, text);
    defer a.free(back);
    try std.testing.expectEqualStrings(encoded, back);
}
