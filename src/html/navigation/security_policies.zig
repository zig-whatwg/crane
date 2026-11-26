//! HTML §7.7 "The `X-Frame-Options` header" — parsing and adherence check.
//!
//! The cross-origin opener and embedder policies are fetch's data
//! (fetch.internal.cross_origin_policies) and html's decisions
//! (opener_policy.zig); the cross-origin resource policy check is Fetch's.
//! Sandboxing flag sets are dom.sandboxing; "allowed by sandboxing to
//! navigate" is html.navigation.sandbox_navigation.
//!
//! Spec: https://html.spec.whatwg.org/multipage/document-lifecycle.html#the-x-frame-options-header

const std = @import("std");
const fetch = @import("fetch");
const csp = @import("csp");

/// Outcome of parsing an `X-Frame-Options` header value per HTML §7.7 steps 3–8
/// and 10 (after Fetch's "get, decode, and split").
pub const XFrameOptions = enum {
    /// Header absent, single/multiple invalid values, or lone legacy `ALLOWALL`
    /// / `ALLOW-FROM`: framing is allowed.
    none,
    /// Single effective `DENY` directive: framing is disallowed.
    deny,
    /// Single effective `SAMEORIGIN` directive: every ancestor container
    /// document's origin must be same origin with the response URL's origin.
    sameorigin,
    /// Multiple distinct values where at least one is `deny`, `sameorigin`, or
    /// `allowall` (HTML §7.7 step 6): framing is disallowed.
    conflict,
};

/// HTML §7.7 step 2: whether `csp_list` contains any policy with disposition
/// `"enforce"` whose directive set contains a `frame-ancestors` directive.
/// Report-only policies do not disable `X-Frame-Options`.
pub fn cspHasEnforcingFrameAncestors(csp_list: *const csp.types.CSPList) bool {
    for (csp_list.policies.items) |*policy| {
        // Step 2.1: If policy's disposition is not "enforce", continue.
        if (policy.disposition != .enforce) continue;
        // Step 2.2: If policy's directive set contains a `frame-ancestors`
        // directive, return true.
        if (policy.getDirective("frame-ancestors") != null) return true;
    }
    return false;
}

/// HTML §7.7 steps 3–8 & 10: parse a combined `X-Frame-Options` header value
/// (as returned by Fetch header list `get`, joining multiple headers with ", ")
/// using Fetch "get, decode, and split".
pub fn parseXFrameOptions(allocator: std.mem.Allocator, raw_header: ?[]const u8) error{OutOfMemory}!XFrameOptions {
    const raw = raw_header orelse return .none;

    // Step 3: Let rawXFrameOptions be the result of getting, decoding, and
    // splitting `X-Frame-Options` from response's header list.
    // `getDecodeSplitValue` preserves quoted strings and trims ONLY HTTP tab or
    // space (0x09, 0x20), so \x0B / \x0C remain part of the token.
    const values = try fetch.internal.HeaderList.getDecodeSplitValue(allocator, raw);
    defer {
        for (values) |v| allocator.free(v);
        allocator.free(values);
    }

    // Steps 4–5: Build the set of ASCII-lowercased values.
    // Tracking presence of the three recognized keywords plus "any other value"
    // is mathematically equivalent to the Infra ordered set for steps 6–10:
    // - If none of {deny, sameorigin, allowall} appear, step 6 is false and
    //   steps 7/10 both return allow (.none), regardless of set size.
    // - If >= 2 of {deny, sameorigin, allowall} appear, or 1 appears alongside
    //   any other value, the set has size > 1 and contains a recognized keyword,
    //   so step 6 always returns false (.conflict).
    // - Otherwise all entries lowercase to the same single recognized keyword
    //   (set size == 1): step 8 -> .deny, step 9 -> .sameorigin, step 10 -> .none
    //   (lone legacy `ALLOWALL`).
    var has_deny = false;
    var has_sameorigin = false;
    var has_allowall = false;
    var has_other = false;

    for (values) |value| {
        if (std.ascii.eqlIgnoreCase(value, "deny")) {
            has_deny = true;
        } else if (std.ascii.eqlIgnoreCase(value, "sameorigin")) {
            has_sameorigin = true;
        } else if (std.ascii.eqlIgnoreCase(value, "allowall")) {
            has_allowall = true;
        } else {
            has_other = true;
        }
    }

    const known_count: u8 = @as(u8, @intFromBool(has_deny)) +
        @as(u8, @intFromBool(has_sameorigin)) +
        @as(u8, @intFromBool(has_allowall));

    // Step 6: If xFrameOptions's size > 1 and xFrameOptions contains any of
    // "deny", "allowall", or "sameorigin", return false (.conflict).
    if (known_count > 1 or (known_count == 1 and has_other)) return .conflict;

    // Step 7: Multiple invalid values (or single invalid value at step 10).
    if (known_count == 0) return .none;

    // Step 8: If xFrameOptions[0] is "deny", return false.
    if (has_deny) return .deny;

    // Step 9: If xFrameOptions[0] is "sameorigin", check ancestor origins.
    if (has_sameorigin) return .sameorigin;

    // Step 10: Lone legacy "allowall" -> treated as omitted.
    return .none;
}

/// HTML §7.7 step 9: check `SAMEORIGIN` against every ancestor container
/// document's serialized origin.
///
/// Golden Rule 2: All three shipping browsers compare each ancestor's origin
/// against the response URL's tuple origin (NOT a sandboxed target iframe's
/// opaque origin), while still blocking when any ancestor document has an
/// opaque origin (`"null"`):
/// - Chromium: content/browser/renderer_host/ancestor_throttle.cc (`url::Origin::Create(url)` vs `parent->GetLastCommittedOrigin().IsSameOriginWith`)
/// - WebKit: Source/WebCore/loader/FrameLoader.cpp (`SecurityOrigin::create(url)` vs `isSameSchemeHostPort(ancestor->document()->securityOrigin())`)
/// - Gecko: dom/security/FramingChecker.cpp (`httpChannel->GetURI` vs `principal->IsSameOrigin(uri)`)
///
/// Both tuple origin strings must be ASCII URL-origin serializations; `"null"`
/// (opaque) and `null` (unavailable) always fail closed.
pub fn sameOriginAncestorsAdhere(
    response_url_origin: ?[]const u8,
    ancestor_origins: []const ?[]const u8,
) bool {
    const dest = response_url_origin orelse return false;
    if (dest.len == 0 or std.mem.eql(u8, dest, "null")) return false;
    // A child navigable must have at least one container document; fail closed.
    if (ancestor_origins.len == 0) return false;
    for (ancestor_origins) |maybe_ancestor| {
        const ancestor = maybe_ancestor orelse return false;
        if (ancestor.len == 0 or std.mem.eql(u8, ancestor, "null")) return false;
        if (!std.mem.eql(u8, ancestor, dest)) return false;
    }
    return true;
}

/// HTML §7.7 "check a navigation response's adherence to `X-Frame-Options`".
/// Returns `true` if the response adheres (framing allowed), `false` if blocked.
pub fn checkAdherence(
    allocator: std.mem.Allocator,
    is_child_navigable: bool,
    csp_list: ?*const csp.types.CSPList,
    raw_x_frame_options: ?[]const u8,
    response_url_origin: ?[]const u8,
    ancestor_origins: []const ?[]const u8,
) error{OutOfMemory}!bool {
    // Step 1: If navigable is not a child navigable, return true.
    if (!is_child_navigable) return true;

    // Step 2: An enforcing CSP `frame-ancestors` directive overrides XFO.
    if (csp_list) |list| {
        if (cspHasEnforcingFrameAncestors(list)) return true;
    }

    // Steps 3–8 & 10.
    return switch (try parseXFrameOptions(allocator, raw_x_frame_options)) {
        .none => true,
        .deny, .conflict => false,
        // Step 9: SAMEORIGIN.
        .sameorigin => sameOriginAncestorsAdhere(response_url_origin, ancestor_origins),
    };
}

// ============================================================================
// Tests (run by src-html_core)
// ============================================================================

test "parseXFrameOptions: single values and HTML §7.7 tables" {
    const a = std.testing.allocator;
    // Absent
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, null));
    // Valid single values (case-insensitive, HTTP tab/space trimmed)
    try std.testing.expectEqual(XFrameOptions.deny, try parseXFrameOptions(a, "DENY"));
    try std.testing.expectEqual(XFrameOptions.deny, try parseXFrameOptions(a, "denY"));
    try std.testing.expectEqual(XFrameOptions.deny, try parseXFrameOptions(a, "  \tDENY \t "));
    try std.testing.expectEqual(XFrameOptions.sameorigin, try parseXFrameOptions(a, "SAMEORIGIN"));
    try std.testing.expectEqual(XFrameOptions.sameorigin, try parseXFrameOptions(a, "  sameOriGin "));
    // Invalid / legacy lone values -> .none (allow)
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "INVALID"));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "ALLOWALL"));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "ALLOW-FROM https://example.com/"));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "ALLOW-FROM=https://example.com/"));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "\"DENY\""));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "DE NY"));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "\"SAMEORIGIN\""));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "\"SAMEORIGIN,DENY\""));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, ""));
    // Non-HTTP whitespace (\x0B, \x0C) must NOT be trimmed (get-decode-split)
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "\x0bDENY"));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "\x0cDENY"));
    // Duplicate identical values (ASCII case-insensitive set)
    try std.testing.expectEqual(XFrameOptions.sameorigin, try parseXFrameOptions(a, "SAMEORIGIN, SAMEORIGIN"));
    try std.testing.expectEqual(XFrameOptions.sameorigin, try parseXFrameOptions(a, "SAMEORIGIN, sameOrigin"));
    try std.testing.expectEqual(XFrameOptions.deny, try parseXFrameOptions(a, "DENY, deny"));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "ALLOWALL, allowAll"));
    // Conflicting values (HTML §7.7 table 2) -> .conflict (block)
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, "SAMEORIGIN, DENY"));
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, "SAMEORIGIN,"));
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, "SAMEORIGIN, ALLOWALL"));
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, "SAMEORIGIN, INVALID"));
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, "SAMEORIGIN, \"DENY\""));
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, "DENY, INVALID"));
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, "DENY, ALLOWALL"));
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, "ALLOWALL, INVALID"));
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, "ALLOWALL,"));
    try std.testing.expectEqual(XFrameOptions.conflict, try parseXFrameOptions(a, ",SAMEORIGIN,,DENY,"));
    // Multiple invalid values -> .none (allow)
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "INVALID, INVALID"));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "INVALID, FOO"));
    try std.testing.expectEqual(XFrameOptions.none, try parseXFrameOptions(a, "INVALID, "));
}

test "checkAdherence: top-level, CSP precedence, SAMEORIGIN ancestors, opaque origins" {
    const a = std.testing.allocator;
    // Step 1: top-level navigable always adheres even with DENY.
    try std.testing.expect(try checkAdherence(a, false, null, "DENY", "https://a.test", &.{}));

    // Step 2: enforcing frame-ancestors overrides DENY; report-only or other directives do not.
    var enforce_fa = csp.types.CSPList.init(a);
    defer enforce_fa.deinit();
    try enforce_fa.append(try csp.parsing.parseSerializedCSP(a, "frame-ancestors 'self'", .header, .enforce));
    try std.testing.expect(try checkAdherence(a, true, &enforce_fa, "DENY", "https://a.test", &.{"https://a.test"}));

    var enforce_default = csp.types.CSPList.init(a);
    defer enforce_default.deinit();
    try enforce_default.append(try csp.parsing.parseSerializedCSP(a, "default-src 'self'", .header, .enforce));
    try std.testing.expect(!try checkAdherence(a, true, &enforce_default, "DENY", "https://a.test", &.{"https://a.test"}));

    var report_only_fa = csp.types.CSPList.init(a);
    defer report_only_fa.deinit();
    try report_only_fa.append(try csp.parsing.parseSerializedCSP(a, "frame-ancestors 'self'", .header, .report));
    try std.testing.expect(!try checkAdherence(a, true, &report_only_fa, "DENY", "https://a.test", &.{"https://a.test"}));

    // Step 9: SAMEORIGIN ancestor chain & opaque origins.
    try std.testing.expect(try checkAdherence(a, true, null, "SAMEORIGIN", "https://a.test", &.{"https://a.test"}));
    try std.testing.expect(try checkAdherence(a, true, null, "SAMEORIGIN", "https://a.test", &.{ "https://a.test", "https://a.test" }));
    try std.testing.expect(!try checkAdherence(a, true, null, "SAMEORIGIN", "https://a.test", &.{"https://b.test"}));
    // Nested A -> B -> A must fail.
    try std.testing.expect(!try checkAdherence(a, true, null, "SAMEORIGIN", "https://a.test", &.{ "https://b.test", "https://a.test" }));
    // Opaque origins ("null") never match, not even "null" == "null".
    try std.testing.expect(!try checkAdherence(a, true, null, "SAMEORIGIN", "https://a.test", &.{"null"}));
    try std.testing.expect(!try checkAdherence(a, true, null, "SAMEORIGIN", "null", &.{"null"}));
    try std.testing.expect(!try checkAdherence(a, true, null, "SAMEORIGIN", "https://a.test", &.{}));
}

test "parseXFrameOptions cleans up on every allocation failure" {
    const Case = struct {
        fn run(allocator: std.mem.Allocator) !void {
            _ = try parseXFrameOptions(allocator, "SAMEORIGIN, \"DENY\", INVALID");
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Case.run, .{});
}
