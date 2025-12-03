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
// Violation Reporting Infrastructure
// ============================================================================

/// Interface for sending HTTP reports.
/// This abstraction allows dependency injection for testing and
/// integration with different HTTP backends.
pub const ReportSender = struct {
    /// Context pointer for the sender implementation
    ctx: *anyopaque,

    /// Send a report to a URL endpoint
    /// Returns true if the report was successfully queued/sent
    sendFn: *const fn (ctx: *anyopaque, url: []const u8, body: []const u8) bool,

    /// Send a report to the endpoint
    pub fn send(self: ReportSender, url: []const u8, body: []const u8) bool {
        return self.sendFn(self.ctx, url, body);
    }
};

/// Interface for firing SecurityPolicyViolationEvent.
/// Allows integration with the DOM event system.
pub const EventDispatcher = struct {
    /// Context pointer for the dispatcher implementation
    ctx: *anyopaque,

    /// Fire a security policy violation event
    /// The event_data is the same JSON as the report body
    fireFn: *const fn (ctx: *anyopaque, event_data: []const u8) void,

    /// Fire the event
    pub fn fire(self: EventDispatcher, event_data: []const u8) void {
        self.fireFn(self.ctx, event_data);
    }
};

/// Configuration for violation reporting
pub const ReportingConfig = struct {
    /// HTTP report sender (null = no HTTP reporting)
    sender: ?ReportSender = null,

    /// Event dispatcher for SecurityPolicyViolationEvent (null = no events)
    event_dispatcher: ?EventDispatcher = null,

    /// Rate limiter (null = no rate limiting, use default)
    rate_limiter: ?*RateLimiter = null,

    /// Allocator for report generation
    allocator: std.mem.Allocator,
};

// ============================================================================
// Rate Limiting
// ============================================================================

/// Rate limiter to prevent report flooding.
/// Spec: CSP Level 3 § 5.3 recommends limiting report frequency.
///
/// Uses a sliding window approach: tracks reports per endpoint
/// and limits to max_reports_per_window within the window duration.
pub const RateLimiter = struct {
    /// Maximum reports per endpoint within the window
    max_reports_per_window: u32 = 100,

    /// Window duration in seconds
    window_seconds: u64 = 60,

    /// Report counts per endpoint (endpoint URL -> (count, window_start))
    report_counts: std.StringHashMapUnmanaged(ReportCount),

    /// Allocator
    allocator: std.mem.Allocator,

    const ReportCount = struct {
        count: u32,
        window_start: i64,
    };

    const Self = @This();

    /// Initialize a new rate limiter
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .report_counts = .{},
            .allocator = allocator,
        };
    }

    /// Initialize with custom limits
    pub fn initWithLimits(allocator: std.mem.Allocator, max_reports: u32, window_secs: u64) Self {
        return Self{
            .max_reports_per_window = max_reports,
            .window_seconds = window_secs,
            .report_counts = .{},
            .allocator = allocator,
        };
    }

    /// Check if a report to the given endpoint should be allowed.
    /// Returns true if allowed, false if rate limited.
    pub fn shouldAllowReport(self: *Self, endpoint: []const u8) bool {
        const now = std.time.timestamp();

        if (self.report_counts.getPtr(endpoint)) |entry| {
            // Check if we're in a new window
            const window_end = entry.window_start + @as(i64, @intCast(self.window_seconds));
            if (now >= window_end) {
                // New window, reset count
                entry.count = 1;
                entry.window_start = now;
                return true;
            }

            // Same window, check count
            if (entry.count >= self.max_reports_per_window) {
                return false; // Rate limited
            }

            // Increment and allow
            entry.count += 1;
            return true;
        } else {
            // First report to this endpoint
            const owned_endpoint = self.allocator.dupe(u8, endpoint) catch return false;
            self.report_counts.put(self.allocator, owned_endpoint, .{
                .count = 1,
                .window_start = now,
            }) catch {
                self.allocator.free(owned_endpoint);
                return false;
            };
            return true;
        }
    }

    /// Deinitialize the rate limiter
    pub fn deinit(self: *Self) void {
        var iter = self.report_counts.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(key.*);
        }
        self.report_counts.deinit(self.allocator);
    }
};

/// Thread-local default rate limiter
threadlocal var default_rate_limiter: ?RateLimiter = null;

/// Get or create the default rate limiter
fn getDefaultRateLimiter(allocator: std.mem.Allocator) *RateLimiter {
    if (default_rate_limiter == null) {
        default_rate_limiter = RateLimiter.init(allocator);
    }
    return &default_rate_limiter.?;
}

/// Deinitialize the thread-local rate limiter (for testing)
pub fn deinitThreadLocalRateLimiter() void {
    if (default_rate_limiter) |*limiter| {
        limiter.deinit();
        default_rate_limiter = null;
    }
}

// ============================================================================
// Violation Reporting
// ============================================================================

/// Report a violation to the appropriate endpoints.
/// Spec: CSP Level 3 § 5.3
///
/// Algorithm:
/// 1. Create a violation report body (JSON)
/// 2. Fire SecurityPolicyViolationEvent on globalObject
/// 3. If reporting is configured:
///    a. Check rate limits
///    b. Send to report-uri endpoints (deprecated but still used)
///    c. Queue for report-to endpoints (Reporting API)
///
/// Parameters:
/// - allocator: Memory allocator for report generation
/// - violation: The violation to report
/// - report_endpoints: Legacy report-uri endpoints (deprecated)
/// - config: Reporting configuration with sender and event dispatcher
pub fn reportViolation(
    allocator: std.mem.Allocator,
    violation: *const types.Violation,
    report_endpoints: ?[]const []const u8,
    config: ?ReportingConfig,
) !void {
    // Step 1: Create JSON report body
    const report_body = try createViolationReport(allocator, violation);
    defer allocator.free(report_body);

    // Wrap in CSP report format for legacy report-uri
    const legacy_report = try createLegacyReportWrapper(allocator, report_body);
    defer allocator.free(legacy_report);

    // Step 2: Fire SecurityPolicyViolationEvent
    if (config) |cfg| {
        if (cfg.event_dispatcher) |dispatcher| {
            dispatcher.fire(report_body);
        }
    }

    // Step 3: Send to report endpoints
    const endpoints = report_endpoints orelse return;
    if (endpoints.len == 0) return;

    // Get rate limiter
    var rate_limiter: *RateLimiter = undefined;
    if (config) |cfg| {
        if (cfg.rate_limiter) |limiter| {
            rate_limiter = limiter;
        } else {
            rate_limiter = getDefaultRateLimiter(allocator);
        }
    } else {
        rate_limiter = getDefaultRateLimiter(allocator);
    }

    // Get sender
    const sender = if (config) |cfg| cfg.sender else null;

    // Send to each endpoint (with rate limiting)
    for (endpoints) |endpoint| {
        // Check rate limit
        if (!rate_limiter.shouldAllowReport(endpoint)) {
            continue; // Skip this endpoint due to rate limiting
        }

        // Send the report
        if (sender) |s| {
            _ = s.send(endpoint, legacy_report);
        }
        // If no sender configured, the report is silently dropped
        // This matches browser behavior when reporting fails
    }
}

/// Create the legacy report-uri wrapper format.
/// Spec: CSP Level 3 § 5.3 (deprecated report-uri format)
///
/// The legacy format wraps the report in: {"csp-report": <report>}
fn createLegacyReportWrapper(allocator: std.mem.Allocator, report_body: []const u8) ![]const u8 {
    var buffer = std.ArrayListUnmanaged(u8){};
    errdefer buffer.deinit(allocator);

    try buffer.appendSlice(allocator, "{\"csp-report\":");
    try buffer.appendSlice(allocator, report_body);
    try buffer.appendSlice(allocator, "}");

    return buffer.toOwnedSlice(allocator);
}

/// Simplified reporting function for common use case.
/// Uses default rate limiting and no event dispatching.
pub fn reportViolationSimple(
    allocator: std.mem.Allocator,
    violation: *const types.Violation,
    report_endpoints: ?[]const []const u8,
    sender: ?ReportSender,
) !void {
    const config = if (sender != null) ReportingConfig{
        .sender = sender,
        .event_dispatcher = null,
        .rate_limiter = null,
        .allocator = allocator,
    } else null;

    try reportViolation(allocator, violation, report_endpoints, config);
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

// ============================================================================
// Reporting Infrastructure Tests
// ============================================================================

test "RateLimiter - allows initial reports" {
    const allocator = std.testing.allocator;

    var limiter = RateLimiter.init(allocator);
    defer limiter.deinit();

    // First report should be allowed
    try std.testing.expect(limiter.shouldAllowReport("https://example.com/report"));

    // Subsequent reports should also be allowed (under limit)
    try std.testing.expect(limiter.shouldAllowReport("https://example.com/report"));
    try std.testing.expect(limiter.shouldAllowReport("https://example.com/report"));
}

test "RateLimiter - respects per-endpoint limits" {
    const allocator = std.testing.allocator;

    // Create limiter with low limit for testing
    var limiter = RateLimiter.initWithLimits(allocator, 3, 60);
    defer limiter.deinit();

    const endpoint = "https://example.com/report";

    // First 3 reports should be allowed
    try std.testing.expect(limiter.shouldAllowReport(endpoint));
    try std.testing.expect(limiter.shouldAllowReport(endpoint));
    try std.testing.expect(limiter.shouldAllowReport(endpoint));

    // 4th report should be rate limited
    try std.testing.expect(!limiter.shouldAllowReport(endpoint));
    try std.testing.expect(!limiter.shouldAllowReport(endpoint));
}

test "RateLimiter - separate limits per endpoint" {
    const allocator = std.testing.allocator;

    var limiter = RateLimiter.initWithLimits(allocator, 2, 60);
    defer limiter.deinit();

    const endpoint1 = "https://example.com/report1";
    const endpoint2 = "https://example.com/report2";

    // Fill up endpoint1
    try std.testing.expect(limiter.shouldAllowReport(endpoint1));
    try std.testing.expect(limiter.shouldAllowReport(endpoint1));
    try std.testing.expect(!limiter.shouldAllowReport(endpoint1)); // Rate limited

    // endpoint2 should still be allowed
    try std.testing.expect(limiter.shouldAllowReport(endpoint2));
    try std.testing.expect(limiter.shouldAllowReport(endpoint2));
    try std.testing.expect(!limiter.shouldAllowReport(endpoint2)); // Rate limited
}

test "createLegacyReportWrapper - wraps report correctly" {
    const allocator = std.testing.allocator;

    const report_body = "{\"document-uri\":\"https://example.com\"}";
    const wrapped = try createLegacyReportWrapper(allocator, report_body);
    defer allocator.free(wrapped);

    try std.testing.expectEqualStrings(
        "{\"csp-report\":{\"document-uri\":\"https://example.com\"}}",
        wrapped,
    );
}

test "reportViolation - with mock sender" {
    const allocator = std.testing.allocator;
    defer deinitThreadLocalRateLimiter();

    // Create a mock sender that tracks calls
    const MockSender = struct {
        var call_count: u32 = 0;
        var last_url_matched: bool = false;
        var body_contains_csp_report: bool = false;

        fn reset() void {
            call_count = 0;
            last_url_matched = false;
            body_contains_csp_report = false;
        }

        fn send(ctx: *anyopaque, url: []const u8, body: []const u8) bool {
            _ = ctx;
            call_count += 1;
            last_url_matched = std.mem.eql(u8, url, "https://example.com/csp-report");
            body_contains_csp_report = std.mem.indexOf(u8, body, "csp-report") != null;
            return true;
        }
    };
    MockSender.reset();

    var dummy_ctx: u8 = 0;
    const sender = ReportSender{
        .ctx = @ptrCast(&dummy_ctx),
        .sendFn = MockSender.send,
    };

    // Create a violation
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
        .{ .document_uri = "https://example.com" },
    );
    defer violation.deinit();

    // Report with endpoints
    const endpoints = [_][]const u8{"https://example.com/csp-report"};
    const config = ReportingConfig{
        .sender = sender,
        .event_dispatcher = null,
        .rate_limiter = null,
        .allocator = allocator,
    };

    try reportViolation(allocator, &violation, &endpoints, config);

    // Verify the sender was called with correct data
    try std.testing.expectEqual(@as(u32, 1), MockSender.call_count);
    try std.testing.expect(MockSender.last_url_matched);
    try std.testing.expect(MockSender.body_contains_csp_report);
}

test "reportViolation - with event dispatcher" {
    const allocator = std.testing.allocator;
    defer deinitThreadLocalRateLimiter();

    // Create a mock event dispatcher that validates data inline
    const MockDispatcher = struct {
        var fired: bool = false;
        var data_contains_document_uri: bool = false;

        fn reset() void {
            fired = false;
            data_contains_document_uri = false;
        }

        fn fire(ctx: *anyopaque, data: []const u8) void {
            _ = ctx;
            fired = true;
            data_contains_document_uri = std.mem.indexOf(u8, data, "document-uri") != null;
        }
    };
    MockDispatcher.reset();

    var dummy_ctx: u8 = 0;
    const dispatcher = EventDispatcher{
        .ctx = @ptrCast(&dummy_ctx),
        .fireFn = MockDispatcher.fire,
    };

    // Create a violation
    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var violation = try createViolation(
        allocator,
        &policy,
        "script-src",
        .inline_script,
        .{ .document_uri = "https://example.com" },
    );
    defer violation.deinit();

    // Report without HTTP endpoints but with event dispatcher
    const config = ReportingConfig{
        .sender = null,
        .event_dispatcher = dispatcher,
        .rate_limiter = null,
        .allocator = allocator,
    };

    try reportViolation(allocator, &violation, null, config);

    // Verify the event was fired with correct data
    try std.testing.expect(MockDispatcher.fired);
    try std.testing.expect(MockDispatcher.data_contains_document_uri);
}

test "reportViolation - no endpoints" {
    const allocator = std.testing.allocator;
    defer deinitThreadLocalRateLimiter();

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var violation = try createViolation(
        allocator,
        &policy,
        "script-src",
        .inline_script,
        .{},
    );
    defer violation.deinit();

    // Should not error when no endpoints provided
    try reportViolation(allocator, &violation, null, null);
    try reportViolation(allocator, &violation, &[_][]const u8{}, null);
}

test "reportViolationSimple - convenience function" {
    const allocator = std.testing.allocator;
    defer deinitThreadLocalRateLimiter();

    var policy = types.Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    var violation = try createViolation(
        allocator,
        &policy,
        "script-src",
        .inline_script,
        .{},
    );
    defer violation.deinit();

    // Should not error
    try reportViolationSimple(allocator, &violation, null, null);
}
