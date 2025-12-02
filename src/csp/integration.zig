//! CSP Integration Module
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/
//!
//! This module provides integration between CSP and other web platform
//! components such as Fetch, DOM, and scripting.

const std = @import("std");
const types = @import("types.zig");
const parsing = @import("parsing.zig");
const matching = @import("matching.zig");
const fallback = @import("fallback.zig");
const violations = @import("violations.zig");
const directives = @import("directives/root.zig");

// ============================================================================
// Document Loading Integration
// ============================================================================

/// HTTP header names for CSP
pub const CSP_HEADER = "Content-Security-Policy";
pub const CSP_REPORT_ONLY_HEADER = "Content-Security-Policy-Report-Only";

/// Parse CSP headers and create a CSP list.
/// Spec: CSP Level 3 § 3.1
pub fn parseCSPHeaders(
    allocator: std.mem.Allocator,
    headers: []const HTTPHeader,
) !types.CSPList {
    var csp_list = types.CSPList.init(allocator);
    errdefer csp_list.deinit();

    for (headers) |header| {
        if (std.ascii.eqlIgnoreCase(header.name, CSP_HEADER)) {
            const policy = try parsing.parseSerializedCSP(
                allocator,
                header.value,
                .header,
                .enforce,
            );
            try csp_list.append(policy);
        } else if (std.ascii.eqlIgnoreCase(header.name, CSP_REPORT_ONLY_HEADER)) {
            const policy = try parsing.parseSerializedCSP(
                allocator,
                header.value,
                .header,
                .report,
            );
            try csp_list.append(policy);
        }
    }

    return csp_list;
}

/// Simple HTTP header representation
pub const HTTPHeader = struct {
    name: []const u8,
    value: []const u8,
};

// ============================================================================
// Meta Tag Integration
// ============================================================================

/// Directives NOT allowed in <meta> tag
/// Spec: CSP Level 3 § 3.2.1
const meta_disallowed_directives = [_][]const u8{
    "frame-ancestors",
    "report-uri",
    "report-to",
    "sandbox",
};

/// Check if a directive is allowed in <meta> tags.
pub fn isDirectiveAllowedInMeta(directive_name: []const u8) bool {
    for (meta_disallowed_directives) |disallowed| {
        if (std.ascii.eqlIgnoreCase(directive_name, disallowed)) {
            return false;
        }
    }
    return true;
}

/// Parse CSP from <meta> tag and validate it.
/// Returns error if policy contains disallowed directives.
pub fn parseMetaCSP(
    allocator: std.mem.Allocator,
    content: []const u8,
) !types.Policy {
    var policy = try parsing.parseSerializedCSP(
        allocator,
        content,
        .meta,
        .enforce, // Meta can only be enforce, not report-only
    );
    errdefer policy.deinit();

    // Validate no disallowed directives
    for (meta_disallowed_directives) |disallowed| {
        if (policy.containsDirective(disallowed)) {
            return error.DisallowedDirectiveInMeta;
        }
    }

    return policy;
}

// ============================================================================
// Resource Fetch Integration
// ============================================================================

/// Fetch destinations and their corresponding CSP directives
/// Spec: Fetch Standard § 2.2.4
pub const FetchDestination = enum {
    // Documents
    document,
    iframe,
    frame,
    embed,
    object,

    // Scripts
    script,
    worker,
    sharedworker,
    serviceworker,

    // Styles
    style,

    // Media
    audio,
    video,
    track,
    image,
    font,

    // Data
    manifest,
    xslt,

    // Network
    fetch,
    xmlhttprequest,
    websocket,
    eventsource,

    // Unknown/other
    empty,
    report,
};

/// Get the CSP directive name for a fetch destination.
/// Spec: CSP Level 3 § 6.1
pub fn getDirectiveForDestination(destination: FetchDestination) []const u8 {
    return switch (destination) {
        .script, .worker, .sharedworker, .serviceworker => "script-src",
        .style => "style-src",
        .image => "img-src",
        .font => "font-src",
        .audio, .video, .track => "media-src",
        .object, .embed => "object-src",
        .frame, .iframe => "frame-src",
        .manifest => "manifest-src",
        .fetch, .xmlhttprequest, .websocket, .eventsource => "connect-src",
        .document => "default-src", // Navigation uses different checks
        .xslt => "script-src", // XSLT is executable
        .empty, .report => "default-src",
    };
}

/// Result of CSP check
pub const CSPCheckResult = struct {
    /// Whether the resource should be blocked
    blocked: bool,
    /// The policy that caused the block (if any)
    violated_policy: ?*const types.Policy = null,
    /// The directive that was violated
    violated_directive: ?[]const u8 = null,
};

/// Check if a fetch request should be blocked by CSP.
/// Spec: CSP Level 3 § 6.1.2.1
pub fn shouldBlockFetch(
    csp_list: *const types.CSPList,
    url_scheme: []const u8,
    url_host: []const u8,
    url_port: ?u16,
    url_path: []const u8,
    destination: FetchDestination,
    redirect_count: u32,
) CSPCheckResult {
    if (csp_list.isEmpty()) {
        return .{ .blocked = false };
    }

    const directive_name = getDirectiveForDestination(destination);

    for (csp_list.policies.items) |*policy| {
        const effective = fallback.getEffectiveDirective(policy, directive_name);
        if (effective) |directive| {
            if (!matching.doesUrlMatchSourceList(
                url_scheme,
                url_host,
                url_port,
                url_path,
                &directive.value,
                if (policy.self_origin) |*o| o else null,
                redirect_count,
            )) {
                // Blocked
                if (policy.disposition == .enforce) {
                    return .{
                        .blocked = true,
                        .violated_policy = policy,
                        .violated_directive = directive_name,
                    };
                }
                // Report-only: don't block but would have
            }
        }
    }

    return .{ .blocked = false };
}

// ============================================================================
// Inline Script/Style Integration
// ============================================================================

/// Context for inline content checking
pub const InlineContext = struct {
    /// The inline content
    content: []const u8,
    /// Nonce attribute if present
    nonce: ?[]const u8 = null,
    /// Whether this was parser-inserted
    parser_inserted: bool = true,
    /// Source file for violation reporting
    source_file: ?[]const u8 = null,
    /// Line number for violation reporting
    line_number: ?u32 = null,
};

/// Check if inline script should be blocked.
/// Spec: CSP Level 3 § 6.1.3
pub fn shouldBlockInlineScript(
    csp_list: *const types.CSPList,
    context: InlineContext,
) CSPCheckResult {
    if (csp_list.isEmpty()) {
        return .{ .blocked = false };
    }

    for (csp_list.policies.items) |*policy| {
        const directive = fallback.getEffectiveDirective(policy, "script-src-elem") orelse
            fallback.getEffectiveDirective(policy, "script-src") orelse
            fallback.getEffectiveDirective(policy, "default-src");

        if (directive) |d| {
            // Check nonce
            if (context.nonce) |nonce| {
                if (matching.doesNonceMatch(nonce, &d.value)) {
                    continue; // Allowed by nonce
                }
            }

            // Check hash (compute if needed)
            // TODO: Implement hash computation and matching

            // Check 'unsafe-inline'
            if (matching.allowsUnsafeInline(&d.value)) {
                // But 'strict-dynamic' overrides 'unsafe-inline'
                if (!matching.hasStrictDynamic(&d.value)) {
                    continue; // Allowed by unsafe-inline
                }
            }

            // Check 'strict-dynamic' for non-parser-inserted
            if (matching.hasStrictDynamic(&d.value) and !context.parser_inserted) {
                continue; // Allowed by strict-dynamic
            }

            // Blocked
            if (policy.disposition == .enforce) {
                return .{
                    .blocked = true,
                    .violated_policy = policy,
                    .violated_directive = "script-src",
                };
            }
        }
    }

    return .{ .blocked = false };
}

/// Check if inline style should be blocked.
/// Spec: CSP Level 3 § 6.1.3
pub fn shouldBlockInlineStyle(
    csp_list: *const types.CSPList,
    context: InlineContext,
) CSPCheckResult {
    if (csp_list.isEmpty()) {
        return .{ .blocked = false };
    }

    for (csp_list.policies.items) |*policy| {
        const directive = fallback.getEffectiveDirective(policy, "style-src-elem") orelse
            fallback.getEffectiveDirective(policy, "style-src") orelse
            fallback.getEffectiveDirective(policy, "default-src");

        if (directive) |d| {
            // Check nonce
            if (context.nonce) |nonce| {
                if (matching.doesNonceMatch(nonce, &d.value)) {
                    continue;
                }
            }

            // Check 'unsafe-inline'
            if (matching.allowsUnsafeInline(&d.value)) {
                continue;
            }

            // Blocked
            if (policy.disposition == .enforce) {
                return .{
                    .blocked = true,
                    .violated_policy = policy,
                    .violated_directive = "style-src",
                };
            }
        }
    }

    return .{ .blocked = false };
}

// ============================================================================
// eval() Blocking
// ============================================================================

/// Check if eval() should be blocked.
/// Spec: CSP Level 3 § 6.1.4
pub fn shouldBlockEval(csp_list: *const types.CSPList) bool {
    if (csp_list.isEmpty()) {
        return false;
    }

    for (csp_list.policies.items) |*policy| {
        const directive = fallback.getEffectiveDirective(policy, "script-src") orelse
            fallback.getEffectiveDirective(policy, "default-src");

        if (directive) |d| {
            if (!matching.allowsUnsafeEval(&d.value)) {
                if (policy.disposition == .enforce) {
                    return true;
                }
            }
        }
    }

    return false;
}

/// Check if WebAssembly.compile/instantiate should be blocked.
/// Spec: CSP Level 3 § 6.1.4
pub fn shouldBlockWasmEval(csp_list: *const types.CSPList) bool {
    if (csp_list.isEmpty()) {
        return false;
    }

    for (csp_list.policies.items) |*policy| {
        const directive = fallback.getEffectiveDirective(policy, "script-src") orelse
            fallback.getEffectiveDirective(policy, "default-src");

        if (directive) |d| {
            // wasm-unsafe-eval allows WASM without unsafe-eval
            if (!matching.allowsUnsafeEval(&d.value) and !matching.allowsWasmUnsafeEval(&d.value)) {
                if (policy.disposition == .enforce) {
                    return true;
                }
            }
        }
    }

    return false;
}

// ============================================================================
// Tests
// ============================================================================

test "parseCSPHeaders" {
    const allocator = std.testing.allocator;

    const headers = [_]HTTPHeader{
        .{ .name = "Content-Security-Policy", .value = "default-src 'self'" },
        .{ .name = "Content-Security-Policy-Report-Only", .value = "script-src 'none'" },
    };

    var csp_list = try parseCSPHeaders(allocator, &headers);
    defer csp_list.deinit();

    try std.testing.expectEqual(@as(usize, 2), csp_list.policies.items.len);
    try std.testing.expectEqual(types.PolicyDisposition.enforce, csp_list.policies.items[0].disposition);
    try std.testing.expectEqual(types.PolicyDisposition.report, csp_list.policies.items[1].disposition);
}

test "isDirectiveAllowedInMeta" {
    try std.testing.expect(isDirectiveAllowedInMeta("script-src"));
    try std.testing.expect(isDirectiveAllowedInMeta("default-src"));
    try std.testing.expect(!isDirectiveAllowedInMeta("frame-ancestors"));
    try std.testing.expect(!isDirectiveAllowedInMeta("report-uri"));
    try std.testing.expect(!isDirectiveAllowedInMeta("sandbox"));
}

test "getDirectiveForDestination" {
    try std.testing.expectEqualStrings("script-src", getDirectiveForDestination(.script));
    try std.testing.expectEqualStrings("style-src", getDirectiveForDestination(.style));
    try std.testing.expectEqualStrings("img-src", getDirectiveForDestination(.image));
    try std.testing.expectEqualStrings("connect-src", getDirectiveForDestination(.fetch));
    try std.testing.expectEqualStrings("frame-src", getDirectiveForDestination(.iframe));
}

test "shouldBlockEval - no policy allows" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    try std.testing.expect(!shouldBlockEval(&csp_list));
}

test "shouldBlockEval - blocks without unsafe-eval" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var directive = try types.Directive.create(allocator, "script-src");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(directive);
    try csp_list.append(policy);

    try std.testing.expect(shouldBlockEval(&csp_list));
}

test "shouldBlockEval - allows with unsafe-eval" {
    const allocator = std.testing.allocator;

    var csp_list = types.CSPList.init(allocator);
    defer csp_list.deinit();

    var policy = types.Policy.init(allocator, .enforce, .header);
    var directive = try types.Directive.create(allocator, "script-src");
    try directive.value.append(types.SourceExpression.createBorrowed(.keyword_unsafe_eval, "'unsafe-eval'"));
    try policy.directive_set.append(directive);
    try csp_list.append(policy);

    try std.testing.expect(!shouldBlockEval(&csp_list));
}
