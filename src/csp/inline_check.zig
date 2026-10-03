//! CSP §4.2.3 "Should element's inline type behavior be blocked by Content
//! Security Policy?", per policy, over the inline checks of the fetch
//! directives (§6.1.3.3 default-src, §6.1.10.3 script-src, §6.1.11.3
//! script-src-elem, ... - each runs only when §6.8.4 "should fetch directive
//! execute" picks it) and the element matching algorithms of §6.7.3.
//!
//! CSP knows policies, not elements: the caller hands the element over as
//! what §6.7.3 reads of it - its nonce, when it is nonceable, and whether it
//! is parser-inserted - and reports the violation itself (§4.2.3 steps
//! 3.1.3-3.1.7) with the directive this returns.
//!
//! Spec: https://w3c.github.io/webappsec-csp/#should-block-inline

const std = @import("std");
const types = @import("types.zig");
const fallback = @import("fallback.zig");

/// The inline behaviour being checked (§4.2.3's `type`).
pub const InlineType = enum {
    script,
    script_attribute,
    style,
    style_attribute,
    navigation,
};

/// An element, as §6.7.3 reads it.
pub const Element = struct {
    /// Its nonce attribute's value when the element is nonceable (§6.7.3.1);
    /// null for an element with no nonce attribute or one that is not
    /// nonceable.
    nonce: ?[]const u8 = null,
    /// A script element that is parser-inserted.
    parser_inserted: bool = false,
};

/// §6.8.2 Get the effective directive for inline checks.
pub fn effectiveDirectiveForInlineCheck(inline_type: InlineType) []const u8 {
    return switch (inline_type) {
        .script, .navigation => "script-src-elem",
        .script_attribute => "script-src-attr",
        .style => "style-src-elem",
        .style_attribute => "style-src-attr",
    };
}

/// §4.2.3 step 3.1 for one policy: the directive whose inline check returns
/// "Blocked" for `element`'s inline `inline_type` behaviour with `source`,
/// or null when every directive allows it. Of the directives with an inline
/// check, only the one §6.8.4 picks for the effective directive runs - the
/// first of its fallback list the policy has - so a policy blocks through
/// one directive at most.
pub fn blockingDirective(policy: *const types.Policy, element: Element, inline_type: InlineType, source: []const u8) ?*const types.Directive {
    const name = effectiveDirectiveForInlineCheck(inline_type);
    const directive = fallback.getEffectiveDirective(policy, name) orelse return null;
    if (doesElementMatchSourceList(element, &directive.value, inline_type, source)) return null;
    return directive;
}

/// §6.7.3.2 Does a source list allow all inline behavior for type?
pub fn allowsAllInline(list: *const types.SourceList, inline_type: InlineType) bool {
    // 1. Let allow all inline be false.
    var allow_all_inline = false;
    // 2. For each expression of list:
    for (list.expressions.items) |*expression| {
        switch (expression.type) {
            // 2.1. A nonce-source or hash-source: "Does Not Allow".
            .nonce, .hash => return false,
            // 2.2. 'strict-dynamic', for script, script attribute or
            // navigation.
            .keyword_strict_dynamic => switch (inline_type) {
                .script, .script_attribute, .navigation => return false,
                else => {},
            },
            // 2.3. 'unsafe-inline'.
            .keyword_unsafe_inline => allow_all_inline = true,
            else => {},
        }
    }
    // 3.
    return allow_all_inline;
}

/// §6.7.3.3 Does element match source list for type and source?
pub fn doesElementMatchSourceList(element: Element, list: *const types.SourceList, inline_type: InlineType, source: []const u8) bool {
    // 1. A list that allows all inline behaviour for type matches.
    if (allowsAllInline(list, inline_type)) return true;
    // 2. Script or style, and the element nonceable: a nonce-source whose
    // base64-value is the element's nonce attribute matches.
    if (inline_type == .script or inline_type == .style) {
        if (element.nonce) |nonce| {
            for (list.expressions.items) |*expression| {
                if (expression.type != .nonce) continue;
                if (std.mem.eql(u8, expression.nonce_value orelse continue, nonce)) return true;
            }
        }
    }
    // 3-4. The unsafe-hashes flag.
    const unsafe_hashes = list.contains(.keyword_unsafe_hashes);
    // 5. Script or style, or unsafe-hashes: 'strict-dynamic' and hashes.
    if (inline_type == .script or inline_type == .style or unsafe_hashes) {
        // 5.1. source, "JavaScript string converted" (a lone surrogate
        // becomes U+FFFD) and UTF-8 encoded: Crane's strings are UTF-8, a
        // lone surrogate from script kept as its WTF-8 sequence, which the
        // hash below reads as U+FFFD.
        for (list.expressions.items) |*expression| {
            switch (expression.type) {
                // 5.2.1. 'strict-dynamic': a script that is not
                // parser-inserted matches.
                .keyword_strict_dynamic => if (inline_type == .script and !element.parser_inserted) return true,
                // 5.2.2. A hash-source whose algorithm is one of
                // sha256/sha384/sha512: its base64-value, base64url
                // normalized to base64, against the base64 digest of source.
                .hash => if (hashMatches(expression, source)) return true,
                else => {},
            }
        }
    }
    // 6. "Return Does Not Match."
    return false;
}

/// §6.7.3.3 step 5.2.2 for one hash-source expression.
fn hashMatches(expression: *const types.SourceExpression, source: []const u8) bool {
    const algorithm = expression.hash_algorithm orelse return false;
    const value = expression.hash_value orelse return false;
    var digest_buf: [std.crypto.hash.sha2.Sha512.digest_length]u8 = undefined;
    const digest: []const u8 = if (std.ascii.eqlIgnoreCase(algorithm, "sha256")) blk: {
        hashScalarValues(std.crypto.hash.sha2.Sha256, source, digest_buf[0..32]);
        break :blk digest_buf[0..32];
    } else if (std.ascii.eqlIgnoreCase(algorithm, "sha384")) blk: {
        hashScalarValues(std.crypto.hash.sha2.Sha384, source, digest_buf[0..48]);
        break :blk digest_buf[0..48];
    } else if (std.ascii.eqlIgnoreCase(algorithm, "sha512")) blk: {
        hashScalarValues(std.crypto.hash.sha2.Sha512, source, digest_buf[0..64]);
        break :blk digest_buf[0..64];
    } else return false;
    // 5.2.2.5.1. actual: the base64 encoding of the digest.
    var actual_buf: [std.base64.standard.Encoder.calcSize(64)]u8 = undefined;
    const actual = std.base64.standard.Encoder.encode(&actual_buf, digest);
    // 5.2.2.5.2. expected: '-' as '+', '_' as '/'. 5.2.2.5.3. Identical.
    if (actual.len != value.len) return false;
    for (actual, value) |a, raw| {
        const e: u8 = switch (raw) {
            '-' => '+',
            '_' => '/',
            else => raw,
        };
        if (a != e) return false;
    }
    return true;
}

/// `Hash` of `source` with each surrogate code point - a WTF-8 sequence
/// ED A0..BF xx, what a lone surrogate from script is stored as - hashed as
/// U+FFFD (EF BF BD): Infra's "JavaScript string convert", then UTF-8.
/// 0xED is only ever a lead byte, so the scan cannot land mid-sequence.
fn hashScalarValues(comptime Hash: type, source: []const u8, out: *[Hash.digest_length]u8) void {
    var hasher = Hash.init(.{});
    var start: usize = 0;
    var i: usize = 0;
    while (i + 2 < source.len) {
        if (source[i] == 0xED and source[i + 1] >= 0xA0 and source[i + 1] <= 0xBF) {
            hasher.update(source[start..i]);
            hasher.update("\u{FFFD}");
            i += 3;
            start = i;
            continue;
        }
        i += 1;
    }
    hasher.update(source[start..]);
    hasher.final(out);
}

const testing = std.testing;
const parsing = @import("parsing.zig");

fn testPolicy(serialized: []const u8) !types.Policy {
    return parsing.parseSerializedCSP(testing.allocator, serialized, .meta, .enforce);
}

// SHA-256 of the empty string.
const empty_sha256 = "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=";

test "6.7.3.2: 'unsafe-inline' allows all inline behaviour unless a nonce, a hash or (for scripts) 'strict-dynamic' overrides it" {
    var a = try testPolicy("script-src 'unsafe-inline' http://a.com");
    defer a.deinit();
    try testing.expect(allowsAllInline(&a.directive_set.get("script-src").?.value, .script));
    var b = try testPolicy("script-src http://example.com 'unsafe-inline' 'nonce-abc'");
    defer b.deinit();
    try testing.expect(!allowsAllInline(&b.directive_set.get("script-src").?.value, .script));
    var c = try testPolicy("style-src 'unsafe-inline' 'strict-dynamic'");
    defer c.deinit();
    try testing.expect(allowsAllInline(&c.directive_set.get("style-src").?.value, .style));
    var d = try testPolicy("script-src 'unsafe-inline' 'strict-dynamic'");
    defer d.deinit();
    try testing.expect(!allowsAllInline(&d.directive_set.get("script-src").?.value, .script));
}

test "6.7.3.3: a hash matches the UTF-8 source's digest, base64 or base64url, the algorithm case-insensitively" {
    var policy = try testPolicy("script-src 'SHA256-47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU='");
    defer policy.deinit();
    const list = &policy.directive_set.get("script-src").?.value;
    try testing.expect(doesElementMatchSourceList(.{}, list, .script, ""));
    try testing.expect(!doesElementMatchSourceList(.{}, list, .script, " "));
    var exact = try testPolicy("script-src 'sha256-" ++ empty_sha256 ++ "'");
    defer exact.deinit();
    try testing.expect(doesElementMatchSourceList(.{}, &exact.directive_set.get("script-src").?.value, .script, ""));
    // A hash does not apply to a script attribute without 'unsafe-hashes'.
    try testing.expect(!doesElementMatchSourceList(.{}, &exact.directive_set.get("script-src").?.value, .script_attribute, ""));
}

test "6.7.3.3: a lone surrogate hashes as U+FFFD" {
    var replaced: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("//\u{FFFD}\nscript_ran();", &replaced, .{});
    var surrogate: [32]u8 = undefined;
    hashScalarValues(std.crypto.hash.sha2.Sha256, "//\xED\xA0\x81\nscript_ran();", &surrogate);
    try testing.expectEqualSlices(u8, &replaced, &surrogate);
    var plain: [32]u8 = undefined;
    hashScalarValues(std.crypto.hash.sha2.Sha256, "alert(1)", &plain);
    var expected: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash("alert(1)", &expected, .{});
    try testing.expectEqualSlices(u8, &expected, &plain);
}

test "6.7.3.3: a nonce matches a nonceable element's nonce; 'strict-dynamic' a script that is not parser-inserted" {
    var policy = try testPolicy("script-src 'nonce-abc' 'strict-dynamic'");
    defer policy.deinit();
    const list = &policy.directive_set.get("script-src").?.value;
    try testing.expect(doesElementMatchSourceList(.{ .nonce = "abc", .parser_inserted = true }, list, .script, "x"));
    try testing.expect(!doesElementMatchSourceList(.{ .nonce = "abd", .parser_inserted = true }, list, .script, "x"));
    try testing.expect(doesElementMatchSourceList(.{ .parser_inserted = false }, list, .script, "x"));
}

test "4.2.3: the directive the fallback list picks blocks, and only it" {
    var policy = try testPolicy("script-src 'self'; default-src 'unsafe-inline'");
    defer policy.deinit();
    const blocked = blockingDirective(&policy, .{}, .script, "alert(1)") orelse return error.TestExpectedBlocked;
    try testing.expectEqualStrings("script-src", blocked.name);
    var allows = try testPolicy("script-src-elem 'unsafe-inline'; script-src 'none'");
    defer allows.deinit();
    try testing.expect(blockingDirective(&allows, .{}, .script, "alert(1)") == null);
    var none = try testPolicy("img-src 'none'");
    defer none.deinit();
    try testing.expect(blockingDirective(&none, .{}, .script, "alert(1)") == null);
}
