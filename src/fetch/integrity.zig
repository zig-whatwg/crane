//! Subresource Integrity: parse metadata, choose the strongest algorithm,
//! and match the full response body (SRI 3.3.2-3.3.4).
//!
//! Browser behavior takes precedence over the draft's literal-space split
//! and encoded-string comparison: ASCII whitespace, case-insensitive hash
//! names, base64url and omitted padding are accepted. Malformed tokens are
//! ignored, but an undecodable hash with valid syntax still participates in
//! strongest selection. WebKit's SubresourceIntegrity.cpp and
//! ResourceCryptographicDigest.cpp use the same parse/select/decode order.
//! WPT subresource-integrity.html: Chrome 154, Firefox 157, Safari 27 all
//! 60/60 at cc74d2669f (runs 6218298311311360, 4877098740350976,
//! 5164107446878208). See row 48 D1.
//!
//! https://w3c.github.io/webappsec-subresource-integrity/#parse-metadata
//! https://github.com/WebKit/WebKit/blob/main/Source/WebCore/loader/SubresourceIntegrity.cpp

const std = @import("std");
const platform = @import("platform");
const base64 = @import("infra").base64;

const Algorithm = enum(u8) {
    sha256,
    sha384,
    sha512,

    fn platformAlgorithm(self: Algorithm) platform.HashAlgorithm {
        return switch (self) {
            .sha256 => .sha256,
            .sha384 => .sha384,
            .sha512 => .sha512,
        };
    }
};

const Metadata = struct { algorithm: Algorithm, digest: []const u8 };

/// SRI 3.3.2: one ASCII-whitespace-delimited metadata token. No allocation.
fn parse(token: []const u8) ?Metadata {
    const dash = std.mem.indexOfScalar(u8, token, '-') orelse return null;
    const name = token[0..dash];
    const algorithm: Algorithm = if (std.ascii.eqlIgnoreCase(name, "sha256")) .sha256 else if (std.ascii.eqlIgnoreCase(name, "sha384")) .sha384 else if (std.ascii.eqlIgnoreCase(name, "sha512")) .sha512 else return null;
    const start = dash + 1;
    var end = start;
    while (end < token.len and isBase64(token[end])) : (end += 1) {}
    // Browser-majority grammar (the SRI draft does not validate base64):
    // WebKit ResourceCryptographicDigest.cpp:105-113 and Blink
    // subresource_integrity.cc:33-38 accept padding-only hashes; WebKit and
    // Gecko nsCSPParser.cpp:91-116 reject excess or interior padding.
    // Decodability is checked AFTER strongest selection, never here.
    var padding: usize = 0;
    while (end < token.len and token[end] == '=' and padding < 2) : (padding += 1) end += 1;
    if (end == start) return null;
    // Options are ignored even when not VCHAR: Blink
    // subresource_integrity.cc:536-563 + Gecko SRIMetadata.cpp:45-53.
    // WebKit's stricter options validation is the minority (row 48 Q9).
    if (end < token.len and token[end] != '?') return null;
    return .{ .algorithm = algorithm, .digest = token[start..end] };
}

fn isBase64(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '+' or c == '/' or c == '-' or c == '_';
}

/// SRI 3.3.3: strongest accepted metadata, independent of whether its hash
/// decodes. Invalid strong bytes must never enable a weaker hash.
fn strongest(metadata: []const u8) ?Algorithm {
    var result: ?Algorithm = null;
    var tokens = std.mem.tokenizeAny(u8, metadata, " \t\n\r\x0c");
    while (tokens.next()) |token| {
        const item = parse(token) orelse continue;
        if (result == null or @intFromEnum(item.algorithm) > @intFromEnum(result.?)) result = item.algorithm;
    }
    return result;
}

/// SRI 3.3.4 steps 1-6, after Fetch has checked response eligibility and
/// fully read its body. Hash once with the strongest algorithm, through the
/// platform protocol. Unknown/malformed metadata alone imposes no hash.
pub fn matches(allocator: std.mem.Allocator, metadata: []const u8, bytes: []const u8) !bool {
    const algorithm = strongest(metadata) orelse return true;
    const digest = try platform.digest(allocator, algorithm.platformAlgorithm(), platform.Bytes.from(bytes));
    defer allocator.free(digest);
    var tokens = std.mem.tokenizeAny(u8, metadata, " \t\n\r\x0c");
    while (tokens.next()) |token| {
        const item = parse(token) orelse continue;
        if (item.algorithm != algorithm) continue;
        // SHA-512 is the longest supported digest: 88 encoded bytes. A
        // longer digest cannot match, but was still strongest metadata.
        var normalized: [88]u8 = undefined;
        if (item.digest.len > normalized.len) continue;
        for (item.digest, 0..) |c, i| normalized[i] = switch (c) {
            '-' => '+',
            '_' => '/',
            else => c,
        };
        // Infra's decoder accepts omitted padding and discards unused tail
        // bits. Bounded scratch avoids a heap allocation for each candidate.
        var storage: [512]u8 = undefined;
        var scratch = std.heap.FixedBufferAllocator.init(&storage);
        const decoded = base64.forgivingBase64Decode(scratch.allocator(), normalized[0..item.digest.len]) catch continue;
        if (std.mem.eql(u8, digest, decoded)) return true;
    }
    return false;
}
