//! CSP base-uri Directive
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/#directive-base-uri
//!
//! The base-uri directive restricts the URLs that can be used
//! in a document's <base> element.

const std = @import("std");
const types = @import("../types.zig");
const matching = @import("../matching.zig");
const request_check = @import("../request_check.zig");
const violation_events = @import("../violation_events.zig");

// ============================================================================
// Base URI Checking
// ============================================================================

/// Check if a base URI is allowed by base-uri directive.
/// Spec: CSP Level 3 §6.3.1.1 step 2.4 (one policy's source match).
///
/// Arguments:
/// - policy: The CSP policy to check
/// - base_scheme: Scheme of the proposed base URI
/// - base_host: Host of the proposed base URI
/// - base_port: Port of the proposed base URI (null for default)
/// - base_path: Path of the proposed base URI
///
/// Returns: true if the base URI is allowed, false if blocked
pub fn isBaseUriAllowed(
    policy: *const types.Policy,
    base_scheme: []const u8,
    base_host: []const u8,
    base_port: ?u16,
    base_path: []const u8,
) bool {
    // Get base-uri directive
    const directive = policy.getDirective("base-uri") orelse {
        // No base-uri directive - any base is allowed
        return true;
    };

    // Check against source list
    return matching.doesUrlMatchSourceList(
        base_scheme,
        base_host,
        base_port,
        base_path,
        &directive.value,
        if (policy.self_origin) |*o| o else null,
        0,
    );
}

/// Check if base-uri blocks all base elements (has 'none').
pub fn blocksAllBaseUris(policy: *const types.Policy) bool {
    const directive = policy.getDirective("base-uri") orelse return false;
    return directive.value.isNone();
}

/// Check if base-uri allows only same origin ('self').
pub fn allowsOnlySameOriginBase(policy: *const types.Policy) bool {
    const directive = policy.getDirective("base-uri") orelse return false;

    // Must have exactly one expression and it must be 'self'
    if (directive.value.expressions.items.len != 1) return false;
    return directive.value.expressions.items[0].type == .keyword_self;
}

// ============================================================================
// CSP List Checking
// ============================================================================

/// Check the enforced policies, without reporting violations. Call
/// `isBaseAllowed` from HTML's "set the frozen base URL" to report too.
pub fn isBaseUriAllowedByList(
    csp_list: *const types.CSPList,
    base_scheme: []const u8,
    base_host: []const u8,
    base_port: ?u16,
    base_path: []const u8,
) bool {
    return checkList(csp_list, .{
        .scheme = base_scheme,
        .host = base_host,
        .port = base_port,
        .path = base_path,
    }, "", null);
}

/// CSP §6.3.1.1 "Is base allowed for document?", with the document's CSP
/// list and reporter. `base` is an already parsed, serialized absolute URL;
/// all inputs and violations are borrowed for this call.
///
/// HTML calls this when it freezes a base URL (insertion or href change),
/// never when a caller reads document.baseURI. A report-only policy reports
/// without blocking; a missing base-uri has no default-src fallback.
///
/// Browser behaviour, stated: step 2.4.2's resource is the base URL, rather
/// than "inline", and every violated policy reports even after an enforced
/// one blocks. Blink AllowBaseURI/AllowFromSource and WebKit
/// allowBaseURI/allPoliciesAllow do both; all three browsers pass
/// base-uri/base-uri-deny.sub.html, whose event asserts the URL.
pub fn isBaseAllowed(
    csp_list: *const types.CSPList,
    base: []const u8,
    reporter: ?violation_events.Reporter,
) bool {
    // No policies: no URL decomposition or reporting work.
    if (csp_list.isEmpty()) return true;
    return checkList(csp_list, request_check.Url.ofSerialized(base), base, reporter);
}

fn checkList(
    csp_list: *const types.CSPList,
    base: request_check.Url,
    serialized_base: []const u8,
    reporter: ?violation_events.Reporter,
) bool {
    // A list that could not record a policy blocks everything (fail closed).
    if (csp_list.blocksEverything()) return false;
    var allowed = true;
    // 1-2. For each policy of the document's CSP list:
    for (csp_list.policies.items) |*policy| {
        // 2.1-2.3. Only base-uri participates; there is no fallback.
        const directive = policy.getDirective("base-uri") orelse continue;
        // 2.4. The policy retains its origin through inherited containers;
        // a list constructed without per-policy origins supplies its own.
        const self_origin: ?*const types.Origin = if (policy.self_origin) |*o| o else if (csp_list.self_origin) |*o| o else null;
        if (matching.doesUrlMatchSourceList(base.scheme, base.host orelse "", base.port, base.path, &directive.value, self_origin, 0)) continue;
        // 2.4.1-2.4.3. The document's reporter owns queued delivery.
        if (reporter) |r| r.reportViolation(&.{
            .policy = policy,
            .effective_directive = "base-uri",
            .resource = .{ .url = serialized_base },
        });
        // 2.4.4. A monitored policy does not prevent the base URL.
        if (policy.disposition == .enforce) allowed = false;
    }
    // 3.
    return allowed;
}

// ============================================================================
// Tests
// ============================================================================

test "isBaseUriAllowed - no directive allows all" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // No base-uri directive - should allow everything
    try std.testing.expect(isBaseUriAllowed(&policy, "https", "example.com", 443, "/"));
    try std.testing.expect(isBaseUriAllowed(&policy, "https", "evil.com", 443, "/"));
}

test "isBaseUriAllowed - none blocks all" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var directive = try types.Directive.create(allocator, "base-uri");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(directive);

    // 'none' should block all base URIs
    try std.testing.expect(!isBaseUriAllowed(&policy, "https", "example.com", 443, "/"));
}

test "isBaseUriAllowed - self allows same origin" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Set self origin
    policy.self_origin = types.Origin.createBorrowed("https", "example.com", 443);

    var directive = try types.Directive.create(allocator, "base-uri");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(directive);

    // Same origin should be allowed
    try std.testing.expect(isBaseUriAllowed(&policy, "https", "example.com", 443, "/"));

    // Different origin should be blocked
    try std.testing.expect(!isBaseUriAllowed(&policy, "https", "evil.com", 443, "/"));
}

test "blocksAllBaseUris" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // No directive
    try std.testing.expect(!blocksAllBaseUris(&policy));

    // Add 'none'
    var directive = try types.Directive.create(allocator, "base-uri");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_none, "'none'"));
    try policy.directive_set.append(directive);

    try std.testing.expect(blocksAllBaseUris(&policy));
}
