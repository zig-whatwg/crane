//! Subresource Integrity: parse metadata, choose the strongest algorithm,
//! and match the full response body (SRI 3.3.2-3.3.4).
//!
//! Browser behavior takes precedence over the draft's literal-space split
//! and encoded-string comparison: ASCII whitespace, base64url and omitted
//! padding are accepted. Malformed tokens are
//! ignored, but an undecodable hash with valid syntax still participates in
//! strongest selection. WebKit's SubresourceIntegrity.cpp and
//! ResourceCryptographicDigest.cpp use the same parse/select/decode order.
//! WPT subresource-integrity.html: Chrome 154, Firefox 157, Safari 27 all
//! 60/60 at cc74d2669f (runs 6218298311311360, 4877098740350976,
//! 5164107446878208). See row 48 D1.
//!
//! https://w3c.github.io/webappsec-subresource-integrity/#parse-metadata
//! https://github.com/WebKit/WebKit/blob/main/Source/WebCore/loader/SubresourceIntegrity.cpp
//! https://github.com/chromium/chromium/blob/main/third_party/blink/renderer/platform/loader/subresource_integrity.cc
//! https://github.com/mozilla-firefox/firefox/blob/main/dom/security/SRIMetadata.cpp

const std = @import("std");
const platform = @import("platform");
const base64 = @import("infra").base64;
const request_mod = @import("internal/request.zig");
const policy_container = @import("internal/policy_container.zig");

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
    // Browser-majority deviation from the draft's ASCII-lowercase rule:
    // Blink ParseAttributeAlgorithm uses case-sensitive starts_with and
    // Gecko SRIMetadata uses EqualsLiteral. WebKit's
    // ResourceCryptographicDigest.cpp ignores ASCII case (the minority).
    // Blink-only sha-256/384/512 spellings likewise remain unsupported.
    const algorithm: Algorithm = if (std.mem.eql(u8, name, "sha256")) .sha256 else if (std.mem.eql(u8, name, "sha384")) .sha384 else if (std.mem.eql(u8, name, "sha512")) .sha512 else return null;
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
        if (result == null or @backingInt(item.algorithm) > @backingInt(result.?)) result = item.algorithm;
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

/// SRI §3.8.2 steps 12-13: whether `policy`'s blocked destinations contain
/// `destination`.
fn blocksDestination(policy: *const policy_container.IntegrityPolicy, destination: request_mod.Destination) bool {
    return switch (destination) {
        .script => policy.block_script,
        .style => policy.block_style,
        else => false,
    };
}

/// SRI §3.8.2, called by main fetch step 7 before dispatch. Policies are
/// the concrete client snapshot populated on the request. Empty policies
/// and unsupported destinations do not parse metadata or allocate.
pub fn shouldRequestBeBlocked(request: *const request_mod.InternalRequest) bool {
    // Blocked destinations are "script" and "style" (PolicyContainer's
    // parser); no other destination can be blocked.
    if (request.destination != .script and request.destination != .style) return false;
    const container = switch (request.policy_container) {
        .client => return false,
        .container => |*value| value,
    };
    // Steps 5-7 and 12-13: compute whether either policy applies first.
    // Parsing metadata is pure, so the empty-policy fast path is equivalent
    // to the spec's later early return and performs no unnecessary work.
    const block = if (container.integrity_policy) |policy| policy.inline_source and blocksDestination(policy, request.destination) else false;
    const report_block = if (container.integrity_policy_report_only) |policy| policy.inline_source and blocksDestination(policy, request.destination) else false;
    if (!block and !report_block) return false;
    // Steps 2-3: syntactically accepted metadata plus a CORS-readable mode.
    if ((request.mode == .cors or request.mode == .same_origin) and strongest(request.integrity_metadata) != null) return false;
    // Step 4: Fetch's local schemes are about, blob and data (not file).
    const url = request.getUrl();
    if (std.mem.indexOfScalar(u8, url, ':')) |colon| {
        const scheme = url[0..colon];
        if (std.ascii.eqlIgnoreCase(scheme, "about") or std.ascii.eqlIgnoreCase(scheme, "blob") or std.ascii.eqlIgnoreCase(scheme, "data")) return false;
    }
    // Steps 8-9, 14: the client supplies its global's borrowed reporter.
    // A native caller may omit it; enforcement still fails closed.
    if (request.integrity_violation_reporter) |reporter| {
        if (block) reporter.report(reporter.context, &.{
            .blocked_url = url,
            .destination = request.destination,
            .report_only = false,
            .endpoints = container.integrity_policy.?.endpoints.items,
        });
        if (report_block) reporter.report(reporter.context, &.{
            .blocked_url = url,
            .destination = request.destination,
            .report_only = true,
            .endpoints = container.integrity_policy_report_only.?.endpoints.items,
        });
    }
    // Step 15: report-only never blocks.
    return block;
}
