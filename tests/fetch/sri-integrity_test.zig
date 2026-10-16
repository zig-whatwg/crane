//! SRI metadata is enforced by Fetch before the response is handed over.
const std = @import("std");
const fetch = @import("fetch");

const sha256 = "sha256-ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=";
const sha384 = "sha384-ywB1P0WjXou1oD1pmsZQBycsMqsO3tFjGotgWkP/W+2AhgcroefMI1i67KE0yCWn";
const sha512 = "sha512-3a81oZNherrMQXNJriBBMRLm+k6JqX6iCp7u5ktV05ohkpkqJ0/BqDa6PCOj/uu9RU1EI2Q86A4qmslPpUyknw==";

fn check(metadata: []const u8, matches: bool) !void {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "data:text/plain,abc");
    defer request.deinit();
    try request.setIntegrityMetadata(metadata);
    var result = try fetch.fetch(allocator, request, .{});
    defer result.deinit();
    if (matches) {
        try std.testing.expectEqual(fetch.internal.ResponseType.basic, result.response.response_type);
        try std.testing.expectEqualStrings("abc", result.response.body.?.getBytes());
    } else {
        try std.testing.expectEqual(fetch.internal.ResponseType.@"error", result.response.response_type);
        try std.testing.expectEqual(@as(u16, 0), result.response.status);
        try std.testing.expect(result.response.body == null);
        try std.testing.expectEqual(@as(usize, 0), result.response.header_list.entries.items.len);
    }
}

test "SRI rejects a well-formed mismatched digest" {
    try check("sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=", false);
}

test "SRI supports SHA-256 SHA-384 and SHA-512" {
    try check(sha256, true);
    try check(sha384, true);
    try check(sha512, true);
}

test "SRI ignores unsupported algorithms and syntactically invalid metadata" {
    for ([_][]const u8{ "", " \t\r\n\x0c", "sha1-aaaa", "sha256", "sha256-", "sha256-...", "?-hash", "-hash", "sha256-a===", "sha256-abc!" }) |metadata| {
        try check(metadata, true);
    }
}

test "SRI chooses the strongest algorithm and accepts any equal-strength match" {
    try check(sha256 ++ " sha512-AAAA", false);
    try check("sha512-AAAA " ++ sha256, false);
    try check("sha256-AAAA " ++ sha384, true);
    try check("sha512-AAAA " ++ sha512, true);
    try check(sha512 ++ " sha512-AAAA", true);
    try check(sha256 ++ " sha512-...", true);
    // A syntactically accepted but undecodable strong digest still prevents downgrade.
    try check(sha256 ++ " sha512-A", false);
}

test "SRI accepts ASCII whitespace options case-insensitive algorithms and base64url" {
    try check("\tsha256-AAAA\r\n" ++ sha384 ++ "?future=1?other\x0c", true);
    try check("SHA256-ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=", true);
    try check("sha256-ungWv48Bz-pBQUDeXa4iI7ADYaOWF3qctBD_YfIAFa0", true);
    try check(sha512[0 .. sha512.len - 2], true);
    try check("sha256-UngWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=", false);
}

test "SRI distinguishes an empty body from a null body" {
    const allocator = std.testing.allocator;
    const request = try fetch.internal.InternalRequest.init(allocator, "data:text/plain,");
    defer request.deinit();
    try request.setIntegrityMetadata("sha256-47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=");
    var empty = try fetch.fetch(allocator, request, .{});
    defer empty.deinit();
    try std.testing.expectEqual(fetch.internal.ResponseType.basic, empty.response.response_type);
    try std.testing.expect(empty.response.body != null);
    try request.setMethod("HEAD");
    var head = try fetch.fetch(allocator, request, .{});
    defer head.deinit();
    try std.testing.expectEqual(fetch.internal.ResponseType.@"error", head.response.response_type);
}

test "SRI padding-only hashes parse and prevent downgrade" {
    try check(sha256 ++ " sha512-=", false);
    try check(sha256 ++ " sha512-==", false);
}

test "SRI skips hashes with excess padding" {
    try check(sha256 ++ " sha512-===", true);
    try check(sha256 ++ " sha512-A===", true);
}

test "SRI skips hashes with interior padding" {
    try check(sha256 ++ " sha512-A=A", true);
    try check(sha256 ++ " sha512-=A", true);
}

test "SRI skips hashes containing characters outside the base64 alphabet" {
    try check(sha256 ++ " sha512-AA!A", true);
    try check(sha256 ++ " sha512-AA\xc3\xa9A", true);
}

test "SRI skips an empty digest even with options" {
    try check(sha256 ++ " sha512-", true);
    try check(sha256 ++ " sha512-?x", true);
}

test "SRI ignores options including non-ASCII and control characters" {
    for ([_][]const u8{ "?future=value", "?\xc3\xa9", "?\x01", "?" }) |options| {
        const strong = try std.mem.concat(std.testing.allocator, u8, &.{ sha256, " sha512-AAAA", options });
        defer std.testing.allocator.free(strong);
        try check(strong, false);
    }
}
