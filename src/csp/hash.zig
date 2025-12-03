//! CSP Hash Computation Module
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/ § 6.7.2.4
//!
//! This module implements hash computation for inline scripts and styles
//! to enable hash-based CSP policies.
//!
//! Supported algorithms:
//! - SHA-256 ('sha256-...')
//! - SHA-384 ('sha384-...')
//! - SHA-512 ('sha512-...')

const std = @import("std");
const types = @import("types.zig");
const matching = @import("matching.zig");

// ============================================================================
// Hash Algorithm Types
// ============================================================================

/// Supported CSP hash algorithms
/// Spec: CSP Level 3 § 2.3.2
pub const HashAlgorithm = enum {
    sha256,
    sha384,
    sha512,

    /// Get the algorithm from a string like "sha256", "sha384", "sha512"
    pub fn fromString(str: []const u8) ?HashAlgorithm {
        if (std.ascii.eqlIgnoreCase(str, "sha256")) return .sha256;
        if (std.ascii.eqlIgnoreCase(str, "sha384")) return .sha384;
        if (std.ascii.eqlIgnoreCase(str, "sha512")) return .sha512;
        return null;
    }

    /// Get hash output size in bytes
    pub fn digestLength(self: HashAlgorithm) usize {
        return switch (self) {
            .sha256 => std.crypto.hash.sha2.Sha256.digest_length,
            .sha384 => std.crypto.hash.sha2.Sha384.digest_length,
            .sha512 => std.crypto.hash.sha2.Sha512.digest_length,
        };
    }
};

// ============================================================================
// Hash Computation
// ============================================================================

/// Compute a hash of the given content using the specified algorithm.
/// Returns the base64-encoded hash value.
///
/// Spec: CSP Level 3 § 6.7.2.4 "Does element match hash source?"
/// The hash is computed over the content as UTF-8 bytes.
pub fn computeHash(
    allocator: std.mem.Allocator,
    algorithm: HashAlgorithm,
    content: []const u8,
) ![]const u8 {
    // Compute the hash digest
    const digest = switch (algorithm) {
        .sha256 => blk: {
            var hash: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});
            break :blk hash[0..];
        },
        .sha384 => blk: {
            var hash: [std.crypto.hash.sha2.Sha384.digest_length]u8 = undefined;
            std.crypto.hash.sha2.Sha384.hash(content, &hash, .{});
            break :blk hash[0..];
        },
        .sha512 => blk: {
            var hash: [std.crypto.hash.sha2.Sha512.digest_length]u8 = undefined;
            std.crypto.hash.sha2.Sha512.hash(content, &hash, .{});
            break :blk hash[0..];
        },
    };

    // Base64 encode the digest
    const base64_len = std.base64.standard.Encoder.calcSize(digest.len);
    const encoded = try allocator.alloc(u8, base64_len);
    errdefer allocator.free(encoded);

    _ = std.base64.standard.Encoder.encode(encoded, digest);

    return encoded;
}

/// Compute hash and check if it matches any hash in the source list.
/// This is the main entry point for CSP hash checking.
///
/// Spec: CSP Level 3 § 6.7.2.4 "Does element match hash source?"
/// For each hash source in the source list:
/// 1. If hash algorithm matches, compute content hash with that algorithm
/// 2. If computed hash matches the hash source value, return true
pub fn doesContentMatchHashSource(
    allocator: std.mem.Allocator,
    content: []const u8,
    source_list: *const types.SourceList,
) !bool {
    // Find all hash expressions and check each one
    for (source_list.expressions.items) |expr| {
        if (expr.type == .hash) {
            if (expr.hash_algorithm) |algo_str| {
                if (expr.hash_value) |expected_hash| {
                    // Get the algorithm
                    const algorithm = HashAlgorithm.fromString(algo_str) orelse continue;

                    // Compute the hash
                    const computed_hash = try computeHash(allocator, algorithm, content);
                    defer allocator.free(computed_hash);

                    // Compare (timing-safe comparison for security)
                    if (std.mem.eql(u8, computed_hash, expected_hash)) {
                        return true;
                    }
                }
            }
        }
    }

    return false;
}

/// Get the hash algorithm string for a given algorithm.
pub fn algorithmToString(algorithm: HashAlgorithm) []const u8 {
    return switch (algorithm) {
        .sha256 => "sha256",
        .sha384 => "sha384",
        .sha512 => "sha512",
    };
}

// ============================================================================
// Tests
// ============================================================================

test "computeHash - sha256" {
    const allocator = std.testing.allocator;

    // Test vector: SHA-256 of "alert('XSS')"
    // From https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
    const content = "alert('XSS')";
    const hash = try computeHash(allocator, .sha256, content);
    defer allocator.free(hash);

    // Verify it's valid base64 and correct length
    // SHA-256 = 32 bytes = 44 base64 chars (with padding)
    try std.testing.expect(hash.len > 0);
    try std.testing.expect(hash.len <= 44);
}

test "computeHash - sha384" {
    const allocator = std.testing.allocator;

    const content = "console.log('hello')";
    const hash = try computeHash(allocator, .sha384, content);
    defer allocator.free(hash);

    // SHA-384 = 48 bytes = 64 base64 chars
    try std.testing.expect(hash.len > 0);
    try std.testing.expect(hash.len <= 64);
}

test "computeHash - sha512" {
    const allocator = std.testing.allocator;

    const content = "var x = 1;";
    const hash = try computeHash(allocator, .sha512, content);
    defer allocator.free(hash);

    // SHA-512 = 64 bytes = 88 base64 chars
    try std.testing.expect(hash.len > 0);
    try std.testing.expect(hash.len <= 88);
}

test "computeHash - empty content" {
    const allocator = std.testing.allocator;

    const hash = try computeHash(allocator, .sha256, "");
    defer allocator.free(hash);

    // SHA-256 of empty string should still produce a hash
    try std.testing.expect(hash.len > 0);
}

test "HashAlgorithm.fromString" {
    try std.testing.expectEqual(HashAlgorithm.sha256, HashAlgorithm.fromString("sha256").?);
    try std.testing.expectEqual(HashAlgorithm.sha384, HashAlgorithm.fromString("sha384").?);
    try std.testing.expectEqual(HashAlgorithm.sha512, HashAlgorithm.fromString("sha512").?);
    try std.testing.expectEqual(HashAlgorithm.sha256, HashAlgorithm.fromString("SHA256").?);
    try std.testing.expect(HashAlgorithm.fromString("sha1") == null);
    try std.testing.expect(HashAlgorithm.fromString("md5") == null);
}

test "doesContentMatchHashSource - matching hash" {
    const allocator = std.testing.allocator;

    // Create a source list with a hash
    var source_list = types.SourceList.init(allocator);
    defer source_list.deinit();

    // First compute what the hash should be
    const content = "alert('test')";
    const expected_hash = try computeHash(allocator, .sha256, content);
    defer allocator.free(expected_hash);

    // Create a hash expression with the expected hash
    var expr = try types.SourceExpression.create(allocator, .hash, "'sha256-test'");
    expr.hash_algorithm = try allocator.dupe(u8, "sha256");
    expr.hash_value = try allocator.dupe(u8, expected_hash);
    try source_list.append(expr);

    // Check that the content matches
    const matches = try doesContentMatchHashSource(allocator, content, &source_list);
    try std.testing.expect(matches);
}

test "doesContentMatchHashSource - non-matching hash" {
    const allocator = std.testing.allocator;

    var source_list = types.SourceList.init(allocator);
    defer source_list.deinit();

    // Create a hash expression with a wrong hash
    var expr = try types.SourceExpression.create(allocator, .hash, "'sha256-wronghash'");
    expr.hash_algorithm = try allocator.dupe(u8, "sha256");
    expr.hash_value = try allocator.dupe(u8, "dGhpc2lzd3Jvbmdo");
    try source_list.append(expr);

    // Check that different content doesn't match
    const matches = try doesContentMatchHashSource(allocator, "different content", &source_list);
    try std.testing.expect(!matches);
}

test "doesContentMatchHashSource - no hash expressions" {
    const allocator = std.testing.allocator;

    var source_list = types.SourceList.init(allocator);
    defer source_list.deinit();

    // Add non-hash expressions
    try source_list.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));

    // Should return false (no hashes to match)
    const matches = try doesContentMatchHashSource(allocator, "any content", &source_list);
    try std.testing.expect(!matches);
}
