const std = @import("std");
const csp = @import("csp");

test "CSP nonce matching trims only surrounding Infra ASCII whitespace in Chromium and WebKit" {
    var policy = try csp.parsing.parseSerializedCSP(std.testing.allocator, "script-src 'nonce-abc'", .header, .enforce);
    defer policy.deinit();
    const list = &policy.getDirective("script-src").?.value;
    for ([_][]const u8{ "abc", " abc ", "\t\n\x0c\r abc\t\n\x0c\r " }) |nonce| {
        try std.testing.expect(csp.matching.doesNonceMatch(nonce, list));
        for ([_]csp.inline_check.InlineType{ .script, .style }) |kind| {
            try std.testing.expect(csp.inline_check.doesElementMatchSourceList(.{ .nonce = nonce }, list, kind, ""));
        }
    }
    for ([_][]const u8{ "", " \t", "a bc", "abc abc", "\x0babc\x0b", "\xc2\xa0abc\xc2\xa0" }) |nonce| {
        try std.testing.expect(!csp.matching.doesNonceMatch(nonce, list));
        try std.testing.expect(!csp.inline_check.doesElementMatchSourceList(.{ .nonce = nonce }, list, .script, ""));
    }
}
