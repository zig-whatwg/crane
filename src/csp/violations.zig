//! CSP Violation Creation and Reporting
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/ § 5
//!
//! This module implements:
//! - Violation creation (§ 5.2)
//! - Violation reporting infrastructure (§ 5.3)
//! - Trusted Types violation creation

const std = @import("std");
const types = @import("types.zig");
const fallback = @import("fallback.zig");

// ============================================================================
// Violation Creation
// ============================================================================

/// Create a violation object for a blocked resource.
/// Spec: CSP Level 3 § 5.2.1
///
/// Algorithm:
/// 1. Let violation be a new violation with provided values
/// 2. Set violation's document-uri to the document's URL
/// 3. Set violation's violated-directive to the directive name
/// 4. Set violation's effective-directive to the effective directive
/// 5. Set violation's original-policy to the serialized policy
/// 6. Set other fields as provided
/// 7. Return violation
pub fn createViolation(
    allocator: std.mem.Allocator,
    policy: *const types.Policy,
    directive_name: []const u8,
    resource: types.ViolationResource,
    options: ViolationOptions,
) !types.Violation {
    // Get effective directive name (handles fallback chains)
    const effective_directive_name = fallback.getMatchingDirectiveName(policy, directive_name) orelse directive_name;

    // Serialize policy for reporting
    const serialized_policy = try serializePolicy(allocator, policy);
    errdefer allocator.free(serialized_policy);

    // Copy strings
    const doc_uri = try allocator.dupe(u8, options.document_uri orelse "");
    errdefer allocator.free(doc_uri);

    const violated = try allocator.dupe(u8, directive_name);
    errdefer allocator.free(violated);

    const effective = try allocator.dupe(u8, effective_directive_name);
    errdefer allocator.free(effective);

    // Copy URL if resource is URL type
    const blocked_uri: types.ViolationResource = switch (resource) {
        .url => |u| .{ .url = try allocator.dupe(u8, u) },
        else => resource,
    };
    errdefer if (blocked_uri == .url) allocator.free(blocked_uri.url);

    var violation = types.Violation{
        .document_uri = doc_uri,
        .status_code = options.status_code,
        .blocked_uri = blocked_uri,
        .referrer = if (options.referrer) |r| try allocator.dupe(u8, r) else null,
        .violated_directive = violated,
        .effective_directive = effective,
        .original_policy = serialized_policy,
        .disposition = policy.disposition,
        .source_file = if (options.source_file) |s| try allocator.dupe(u8, s) else null,
        .line_number = options.line_number,
        .column_number = options.column_number,
        .sample = null,
        .allocator = allocator,
    };

    // Add sample if 'report-sample' is present and sample provided
    if (options.sample) |sample| {
        if (shouldIncludeSample(policy, directive_name)) {
            violation.sample = try truncateSample(allocator, sample);
        }
    }

    return violation;
}

/// Options for violation creation
pub const ViolationOptions = struct {
    /// Document/worker URL
    document_uri: ?[]const u8 = null,
    /// HTTP status code of the document
    status_code: u16 = 0,
    /// Referrer of the document
    referrer: ?[]const u8 = null,
    /// Source file where violation occurred
    source_file: ?[]const u8 = null,
    /// Line number in source
    line_number: ?u32 = null,
    /// Column number in source
    column_number: ?u32 = null,
    /// Sample of violating content (will be truncated to 40 chars)
    sample: ?[]const u8 = null,
};

// ============================================================================
// Trusted Types Violations
// ============================================================================

/// Create a violation for Trusted Types policy creation block.
/// Spec: Trusted Types spec § 4.3.1
pub fn createTrustedTypesPolicyViolation(
    allocator: std.mem.Allocator,
    policy: *const types.Policy,
    policy_name: []const u8,
    options: ViolationOptions,
) !types.Violation {
    var violation = try createViolation(
        allocator,
        policy,
        "trusted-types",
        .trusted_types_policy,
        options,
    );

    // Sample contains the policy name (truncated to 40 chars)
    if (violation.sample != null) {
        allocator.free(violation.sample.?);
    }
    violation.sample = try truncateSample(allocator, policy_name);

    return violation;
}

/// Create a violation for Trusted Types sink mismatch.
/// Spec: Trusted Types spec § 4.3.4
pub fn createTrustedTypesSinkViolation(
    allocator: std.mem.Allocator,
    policy: *const types.Policy,
    sink: []const u8,
    value: []const u8,
    options: ViolationOptions,
) !types.Violation {
    _ = sink; // Sink name could be used for enhanced reporting

    var violation = try createViolation(
        allocator,
        policy,
        "require-trusted-types-for",
        .trusted_types_sink,
        options,
    );

    // Sample contains the value that was assigned (truncated to 40 chars)
    if (violation.sample != null) {
        allocator.free(violation.sample.?);
    }
    violation.sample = try truncateSample(allocator, value);

    return violation;
}

// ============================================================================
// Violation Reporting
// ============================================================================

/// Report a violation to the appropriate endpoints.
/// Spec: CSP Level 3 § 5.3
///
/// This is a placeholder for the reporting infrastructure.
/// Actual reporting requires:
/// 1. Creating a violation report body (JSON)
/// 2. Sending to report-uri endpoints (deprecated)
/// 3. Sending to report-to endpoints (Reporting API)
/// 4. Firing securitypolicyviolation event on document
pub fn reportViolation(
    violation: *const types.Violation,
    report_endpoints: ?[]const []const u8,
) !void {
    // TODO: Implement actual HTTP reporting
    // For now, this is a placeholder that logs the violation

    _ = violation;
    _ = report_endpoints;

    // Implementation would:
    // 1. Serialize violation to JSON
    // 2. POST to each endpoint in report_endpoints
    // 3. Fire SecurityPolicyViolationEvent on globalObject
}

/// Create a JSON violation report body.
/// Spec: CSP Level 3 § 5.3.1
pub fn createViolationReport(
    allocator: std.mem.Allocator,
    violation: *const types.Violation,
) ![]const u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(allocator);

    try buffer.appendSlice(allocator, "{");

    // document-uri
    try buffer.appendSlice(allocator, "\"document-uri\":\"");
    try appendJsonEscaped(allocator, &buffer, violation.document_uri);
    try buffer.appendSlice(allocator, "\",");

    // blocked-uri
    try buffer.appendSlice(allocator, "\"blocked-uri\":\"");
    switch (violation.blocked_uri) {
        .url => |u| try appendJsonEscaped(allocator, &buffer, u),
        .inline_script => try buffer.appendSlice(allocator, "inline"),
        .inline_style => try buffer.appendSlice(allocator, "inline"),
        .eval_script => try buffer.appendSlice(allocator, "eval"),
        .wasm_eval => try buffer.appendSlice(allocator, "wasm-eval"),
        .trusted_types_policy => try buffer.appendSlice(allocator, "trusted-types-policy"),
        .trusted_types_sink => try buffer.appendSlice(allocator, "trusted-types-sink"),
    }
    try buffer.appendSlice(allocator, "\",");

    // violated-directive
    try buffer.appendSlice(allocator, "\"violated-directive\":\"");
    try appendJsonEscaped(allocator, &buffer, violation.violated_directive);
    try buffer.appendSlice(allocator, "\",");

    // effective-directive
    try buffer.appendSlice(allocator, "\"effective-directive\":\"");
    try appendJsonEscaped(allocator, &buffer, violation.effective_directive);
    try buffer.appendSlice(allocator, "\",");

    // original-policy
    try buffer.appendSlice(allocator, "\"original-policy\":\"");
    try appendJsonEscaped(allocator, &buffer, violation.original_policy);
    try buffer.appendSlice(allocator, "\",");

    // disposition
    try buffer.appendSlice(allocator, "\"disposition\":\"");
    try buffer.appendSlice(allocator, switch (violation.disposition) {
        .enforce => "enforce",
        .report => "report",
    });
    try buffer.appendSlice(allocator, "\",");

    // status-code
    try buffer.appendSlice(allocator, "\"status-code\":");
    var status_buf: [6]u8 = undefined;
    const status_str = std.fmt.bufPrint(&status_buf, "{d}", .{violation.status_code}) catch "0";
    try buffer.appendSlice(allocator, status_str);

    // referrer (optional)
    if (violation.referrer) |referrer| {
        try buffer.appendSlice(allocator, ",\"referrer\":\"");
        try appendJsonEscaped(allocator, &buffer, referrer);
        try buffer.appendSlice(allocator, "\"");
    }

    // source-file (optional)
    if (violation.source_file) |source_file| {
        try buffer.appendSlice(allocator, ",\"source-file\":\"");
        try appendJsonEscaped(allocator, &buffer, source_file);
        try buffer.appendSlice(allocator, "\"");
    }

    // line-number (optional)
    if (violation.line_number) |line| {
        try buffer.appendSlice(allocator, ",\"line-number\":");
        var line_buf: [10]u8 = undefined;
        const line_str = std.fmt.bufPrint(&line_buf, "{d}", .{line}) catch "0";
        try buffer.appendSlice(allocator, line_str);
    }

    // column-number (optional)
    if (violation.column_number) |col| {
        try buffer.appendSlice(allocator, ",\"column-number\":");
        var col_buf: [10]u8 = undefined;
        const col_str = std.fmt.bufPrint(&col_buf, "{d}", .{col}) catch "0";
        try buffer.appendSlice(allocator, col_str);
    }

    // script-sample (optional)
    if (violation.sample) |sample| {
        try buffer.appendSlice(allocator, ",\"script-sample\":\"");
        try appendJsonEscaped(allocator, &buffer, sample);
        try buffer.appendSlice(allocator, "\"");
    }

    try buffer.appendSlice(allocator, "}");

    return buffer.toOwnedSlice(allocator);
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Serialize a policy's directives for the violation report.
/// Spec: CSP Level 3 § 5.2.1 step 5
fn serializePolicy(
    allocator: std.mem.Allocator,
    policy: *const types.Policy,
) ![]const u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    var first = true;
    var iter = policy.directive_set.items.iterator();
    while (iter.next()) |entry| {
        if (!first) {
            try result.appendSlice(allocator, "; ");
        }
        first = false;

        // Directive name
        try result.appendSlice(allocator, entry.key_ptr.*);

        // Directive value
        for (entry.value_ptr.value.expressions.items) |expr| {
            try result.append(allocator, ' ');
            try result.appendSlice(allocator, expr.raw_value);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Check if policy has 'report-sample' for the given directive.
fn shouldIncludeSample(policy: *const types.Policy, directive_name: []const u8) bool {
    const directive = fallback.getEffectiveDirective(policy, directive_name) orelse return false;
    return directive.value.contains(.keyword_report_sample);
}

/// Truncate sample to 40 characters (per spec).
fn truncateSample(allocator: std.mem.Allocator, sample: []const u8) ![]const u8 {
    const max_len: usize = 40;
    const len = @min(sample.len, max_len);
    return allocator.dupe(u8, sample[0..len]);
}

/// Append JSON-escaped string to buffer.
fn appendJsonEscaped(allocator: std.mem.Allocator, buffer: *std.ArrayListUnmanaged(u8), str: []const u8) !void {
    for (str) |c| {
        switch (c) {
            '"' => try buffer.appendSlice(allocator, "\\\""),
            '\\' => try buffer.appendSlice(allocator, "\\\\"),
            '\n' => try buffer.appendSlice(allocator, "\\n"),
            '\r' => try buffer.appendSlice(allocator, "\\r"),
            '\t' => try buffer.appendSlice(allocator, "\\t"),
            else => {
                if (c < 0x20) {
                    // Control character - use \u escape
                    var hex_buf: [6]u8 = undefined;
                    _ = std.fmt.bufPrint(&hex_buf, "\\u{x:0>4}", .{c}) catch unreachable;
                    try buffer.appendSlice(allocator, &hex_buf);
                } else {
                    try buffer.append(allocator, c);
                }
            },
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

test "createViolation - basic" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var script_src = try types.Directive.create(allocator, "script-src");
    try script_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(script_src);

    var violation = try createViolation(
        allocator,
        &policy,
        "script-src",
        .{ .url = "https://evil.com/script.js" },
        .{
            .document_uri = "https://example.com/page",
            .status_code = 200,
        },
    );
    defer violation.deinit();

    try std.testing.expectEqualStrings("https://example.com/page", violation.document_uri);
    try std.testing.expectEqualStrings("script-src", violation.violated_directive);
    try std.testing.expectEqualStrings("script-src", violation.effective_directive);
    try std.testing.expectEqual(types.PolicyDisposition.enforce, violation.disposition);
    try std.testing.expectEqual(@as(u16, 200), violation.status_code);
}

test "createViolation - with fallback" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    // Only have default-src
    var default_src = try types.Directive.create(allocator, "default-src");
    try default_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(default_src);

    var violation = try createViolation(
        allocator,
        &policy,
        "script-src-elem",
        .inline_script,
        .{},
    );
    defer violation.deinit();

    // Violated directive is what was requested
    try std.testing.expectEqualStrings("script-src-elem", violation.violated_directive);
    // Effective directive is what actually matched (default-src)
    try std.testing.expectEqualStrings("default-src", violation.effective_directive);
}

test "createTrustedTypesPolicyViolation" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var tt_directive = try types.Directive.create(allocator, "trusted-types");
    try tt_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "allowed-policy"));
    try policy.directive_set.append(tt_directive);

    var violation = try createTrustedTypesPolicyViolation(
        allocator,
        &policy,
        "evil-policy",
        .{ .document_uri = "https://example.com" },
    );
    defer violation.deinit();

    try std.testing.expect(violation.blocked_uri == .trusted_types_policy);
    try std.testing.expectEqualStrings("trusted-types", violation.violated_directive);
    try std.testing.expectEqualStrings("evil-policy", violation.sample.?);
}

test "createTrustedTypesSinkViolation" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var rttf_directive = try types.Directive.create(allocator, "require-trusted-types-for");
    try rttf_directive.value.append(types.SourceExpression.createBorrowed(.policy_name, "'script'"));
    try policy.directive_set.append(rttf_directive);

    var violation = try createTrustedTypesSinkViolation(
        allocator,
        &policy,
        "Element.innerHTML",
        "<script>evil()</script>",
        .{},
    );
    defer violation.deinit();

    try std.testing.expect(violation.blocked_uri == .trusted_types_sink);
    try std.testing.expectEqualStrings("require-trusted-types-for", violation.violated_directive);
    try std.testing.expectEqualStrings("<script>evil()</script>", violation.sample.?);
}

test "truncateSample - short sample" {
    const allocator = std.testing.allocator;

    const sample = try truncateSample(allocator, "short");
    defer allocator.free(sample);

    try std.testing.expectEqualStrings("short", sample);
}

test "truncateSample - long sample" {
    const allocator = std.testing.allocator;

    const long_sample = "This is a very long sample that exceeds forty characters and should be truncated";
    const sample = try truncateSample(allocator, long_sample);
    defer allocator.free(sample);

    try std.testing.expectEqual(@as(usize, 40), sample.len);
    // "This is a very long sample that exceeds " (40 chars, ends with space)
    try std.testing.expectEqualStrings("This is a very long sample that exceeds ", sample);
}

test "serializePolicy" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var script_src = try types.Directive.create(allocator, "script-src");
    try script_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try script_src.value.append(types.SourceExpression.createBorrowed(.scheme, "https:"));
    try policy.directive_set.append(script_src);

    const serialized = try serializePolicy(allocator, &policy);
    defer allocator.free(serialized);

    try std.testing.expectEqualStrings("script-src 'self' https:", serialized);
}

test "createViolationReport - JSON format" {
    const allocator = std.testing.allocator;

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var script_src = try types.Directive.create(allocator, "script-src");
    try script_src.value.append(types.SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try policy.directive_set.append(script_src);

    var violation = try createViolation(
        allocator,
        &policy,
        "script-src",
        .inline_script,
        .{
            .document_uri = "https://example.com/page",
            .status_code = 200,
        },
    );
    defer violation.deinit();

    const report = try createViolationReport(allocator, &violation);
    defer allocator.free(report);

    // Verify it's valid JSON-like structure
    try std.testing.expect(std.mem.startsWith(u8, report, "{"));
    try std.testing.expect(std.mem.endsWith(u8, report, "}"));
    try std.testing.expect(std.mem.indexOf(u8, report, "\"document-uri\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"blocked-uri\":\"inline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"disposition\":\"enforce\"") != null);
}

test "appendJsonEscaped - special characters" {
    const allocator = std.testing.allocator;

    var buffer = std.ArrayListUnmanaged(u8){};
    defer buffer.deinit(allocator);

    try appendJsonEscaped(allocator, &buffer, "hello\"world\\test\nnewline");

    try std.testing.expectEqualStrings("hello\\\"world\\\\test\\nnewline", buffer.items);
}
