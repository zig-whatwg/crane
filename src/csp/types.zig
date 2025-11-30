//! CSP Core Data Structures
//!
//! W3C Content Security Policy Level 3
//! Spec: https://www.w3.org/TR/CSP3/
//!
//! This module defines the fundamental CSP data structures:
//! - Policy: A single CSP policy with directives and disposition
//! - Directive: Name/value pair controlling specific behavior
//! - DirectiveSet: Ordered collection of directives
//! - SourceExpression: Individual source expression in directive value
//! - SourceList: Ordered list of source expressions
//! - CSPList: Multiple policies for a document/worker
//! - Violation: Security violation for reporting

const std = @import("std");

// ============================================================================
// Policy Enums
// ============================================================================

/// Policy disposition - how violations are handled
/// Spec: CSP Level 3 § 2.2
pub const PolicyDisposition = enum {
    /// Block violations (Content-Security-Policy header)
    enforce,
    /// Report-only mode, don't block (Content-Security-Policy-Report-Only header)
    report,
};

/// Policy source - where the policy came from
/// Spec: CSP Level 3 § 2.2
pub const PolicySource = enum {
    /// From HTTP header (Content-Security-Policy or Content-Security-Policy-Report-Only)
    header,
    /// From <meta http-equiv="Content-Security-Policy">
    meta,
};

// ============================================================================
// Source Expression Types
// ============================================================================

/// Type of source expression in a directive value
/// Spec: CSP Level 3 § 2.3
pub const SourceExpressionType = enum {
    // Keywords (enclosed in single quotes)
    keyword_none, // 'none'
    keyword_self, // 'self'
    keyword_unsafe_inline, // 'unsafe-inline'
    keyword_unsafe_eval, // 'unsafe-eval'
    keyword_unsafe_hashes, // 'unsafe-hashes'
    keyword_strict_dynamic, // 'strict-dynamic'
    keyword_wasm_unsafe_eval, // 'wasm-unsafe-eval'
    keyword_report_sample, // 'report-sample'
    keyword_trusted_types_eval, // 'trusted-types-eval' (Trusted Types integration)
    keyword_allow_duplicates, // 'allow-duplicates' (Trusted Types)

    // Value expressions
    scheme, // https:, data:, blob:, etc.
    host, // example.com, *.example.com, https://example.com
    nonce, // 'nonce-abc123'
    hash, // 'sha256-...', 'sha384-...', 'sha512-...'
    wildcard, // * (for trusted-types directive)
    policy_name, // Policy name (for trusted-types directive)
};

/// Parsed source expression
/// Spec: CSP Level 3 § 6.7
pub const SourceExpression = struct {
    /// Type of this expression
    type: SourceExpressionType,

    /// Raw value as it appeared in the directive
    raw_value: []const u8,

    // Parsed components (populated based on type)

    /// For scheme/host expressions: the scheme part (e.g., "https")
    scheme_part: ?[]const u8 = null,
    /// For host expressions: the host part (e.g., "example.com", "*.example.com")
    host_part: ?[]const u8 = null,
    /// For host expressions with port: the port number
    port_part: ?u16 = null,
    /// For host expressions with path: the path prefix
    path_part: ?[]const u8 = null,
    /// For nonce expressions: the nonce value (without 'nonce-' prefix)
    nonce_value: ?[]const u8 = null,
    /// For hash expressions: algorithm ('sha256', 'sha384', 'sha512')
    hash_algorithm: ?[]const u8 = null,
    /// For hash expressions: base64-encoded hash value
    hash_value: ?[]const u8 = null,

    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create an expression with copied raw value
    pub fn create(allocator: std.mem.Allocator, expr_type: SourceExpressionType, raw_value: []const u8) !Self {
        return Self{
            .type = expr_type,
            .raw_value = try allocator.dupe(u8, raw_value),
            .allocator = allocator,
        };
    }

    /// Create an expression with borrowed raw value (no allocation)
    pub fn createBorrowed(expr_type: SourceExpressionType, raw_value: []const u8) Self {
        return Self{
            .type = expr_type,
            .raw_value = raw_value,
            .allocator = null,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.raw_value);
            if (self.scheme_part) |s| alloc.free(s);
            if (self.host_part) |s| alloc.free(s);
            if (self.path_part) |s| alloc.free(s);
            if (self.nonce_value) |s| alloc.free(s);
            if (self.hash_algorithm) |s| alloc.free(s);
            if (self.hash_value) |s| alloc.free(s);
        }
        self.* = Self{
            .type = .keyword_none,
            .raw_value = "",
            .allocator = null,
        };
    }
};

// ============================================================================
// Source List
// ============================================================================

/// Ordered list of source expressions (directive value)
/// Spec: CSP Level 3 § 2.3
pub const SourceList = struct {
    expressions: std.ArrayListUnmanaged(SourceExpression),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .expressions = .{},
            .allocator = allocator,
        };
    }

    /// Append a source expression
    pub fn append(self: *Self, expr: SourceExpression) !void {
        try self.expressions.append(self.allocator, expr);
    }

    /// Check if list contains an expression of given type
    pub fn contains(self: *const Self, expr_type: SourceExpressionType) bool {
        for (self.expressions.items) |expr| {
            if (expr.type == expr_type) return true;
        }
        return false;
    }

    /// Check if source list is 'none' (single 'none' keyword)
    pub fn isNone(self: *const Self) bool {
        return self.expressions.items.len == 1 and
            self.expressions.items[0].type == .keyword_none;
    }

    /// Check if source list is empty
    pub fn isEmpty(self: *const Self) bool {
        return self.expressions.items.len == 0;
    }

    pub fn deinit(self: *Self) void {
        for (self.expressions.items) |*expr| {
            expr.deinit();
        }
        self.expressions.deinit(self.allocator);
    }
};

// ============================================================================
// Directive
// ============================================================================

/// A directive is a name/value pair controlling specific behavior
/// Spec: CSP Level 3 § 2.3
pub const Directive = struct {
    /// Non-empty directive name (e.g., 'script-src', 'trusted-types')
    /// Always lowercase.
    name: []const u8,

    /// Ordered set of source expressions (may be empty)
    value: SourceList,

    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new directive with copied name
    pub fn create(allocator: std.mem.Allocator, name: []const u8) !Self {
        return Self{
            .name = try allocator.dupe(u8, name),
            .value = SourceList.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
        self.value.deinit();
        self.name = "";
    }
};

// ============================================================================
// Directive Set
// ============================================================================

/// Ordered set of directives
/// Spec: CSP Level 3 § 2.2
pub const DirectiveSet = struct {
    /// Map from directive name to directive
    items: std.StringArrayHashMap(Directive),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .items = std.StringArrayHashMap(Directive).init(allocator),
            .allocator = allocator,
        };
    }

    /// Get directive by name
    pub fn get(self: *const Self, name: []const u8) ?*const Directive {
        return self.items.getPtr(name);
    }

    /// Get mutable directive by name
    pub fn getMut(self: *Self, name: []const u8) ?*Directive {
        return self.items.getPtr(name);
    }

    /// Append directive (only if name not already present - first wins)
    /// Spec: CSP Level 3 § 2.2.1 step 3.e
    pub fn append(self: *Self, directive: Directive) !void {
        if (!self.items.contains(directive.name)) {
            try self.items.put(directive.name, directive);
        }
    }

    /// Check if set contains a directive with given name
    pub fn containsDirective(self: *const Self, name: []const u8) bool {
        return self.items.contains(name);
    }

    /// Check if directive set is empty
    pub fn isEmpty(self: *const Self) bool {
        return self.items.count() == 0;
    }

    /// Get the number of directives
    pub fn count(self: *const Self) usize {
        return self.items.count();
    }

    pub fn deinit(self: *Self) void {
        var iter = self.items.iterator();
        while (iter.next()) |entry| {
            var directive = entry.value_ptr;
            directive.deinit();
        }
        self.items.deinit();
    }
};

// ============================================================================
// Origin (simplified for CSP 'self' matching)
// ============================================================================

/// Origin for 'self' matching
/// Spec: HTML § 7.5 Origin
pub const Origin = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?u16,

    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create with borrowed strings (no allocation)
    pub fn createBorrowed(scheme: []const u8, host: []const u8, port: ?u16) Self {
        return Self{
            .scheme = scheme,
            .host = host,
            .port = port,
            .allocator = null,
        };
    }

    /// Create with copied strings
    pub fn create(allocator: std.mem.Allocator, scheme: []const u8, host: []const u8, port: ?u16) !Self {
        return Self{
            .scheme = try allocator.dupe(u8, scheme),
            .host = try allocator.dupe(u8, host),
            .port = port,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.scheme);
            alloc.free(self.host);
        }
        self.scheme = "";
        self.host = "";
        self.port = null;
    }
};

// ============================================================================
// Policy
// ============================================================================

/// Content Security Policy object
/// Spec: CSP Level 3 § 2.2
pub const Policy = struct {
    /// Ordered set of directives defining the policy's implications
    directive_set: DirectiveSet,

    /// Either 'enforce' or 'report'
    disposition: PolicyDisposition,

    /// Either 'header' or 'meta'
    source: PolicySource,

    /// Origin used for 'self' matching
    /// Needed for local scheme documents with opaque origins
    self_origin: ?Origin = null,

    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new empty policy
    pub fn init(
        allocator: std.mem.Allocator,
        disposition: PolicyDisposition,
        source: PolicySource,
    ) Self {
        return Self{
            .directive_set = DirectiveSet.init(allocator),
            .disposition = disposition,
            .source = source,
            .self_origin = null,
            .allocator = allocator,
        };
    }

    /// Check if policy contains a directive with given name
    pub fn containsDirective(self: *const Self, name: []const u8) bool {
        return self.directive_set.containsDirective(name);
    }

    /// Get directive by name
    pub fn getDirective(self: *const Self, name: []const u8) ?*const Directive {
        return self.directive_set.get(name);
    }

    pub fn deinit(self: *Self) void {
        self.directive_set.deinit();
        if (self.self_origin) |*origin| {
            origin.deinit();
        }
    }
};

// ============================================================================
// CSP List
// ============================================================================

/// Multiple policies combined for a document/worker
/// Spec: CSP Level 3 § 2.2
pub const CSPList = struct {
    policies: std.ArrayListUnmanaged(Policy),
    allocator: std.mem.Allocator,

    /// Optimization flag for quick header check
    contains_header_policy: bool = false,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .policies = .{},
            .allocator = allocator,
            .contains_header_policy = false,
        };
    }

    /// Append a policy
    pub fn append(self: *Self, policy: Policy) !void {
        try self.policies.append(self.allocator, policy);
        if (policy.source == .header) {
            self.contains_header_policy = true;
        }
    }

    /// Check if any policy has enforcement disposition
    pub fn hasEnforcingPolicy(self: *const Self) bool {
        for (self.policies.items) |policy| {
            if (policy.disposition == .enforce) return true;
        }
        return false;
    }

    /// Check if any policy has report-only disposition
    pub fn hasReportOnlyPolicy(self: *const Self) bool {
        for (self.policies.items) |policy| {
            if (policy.disposition == .report) return true;
        }
        return false;
    }

    /// Check if CSP list is empty
    pub fn isEmpty(self: *const Self) bool {
        return self.policies.items.len == 0;
    }

    pub fn deinit(self: *Self) void {
        for (self.policies.items) |*policy| {
            policy.deinit();
        }
        self.policies.deinit(self.allocator);
    }
};

// ============================================================================
// Violation
// ============================================================================

/// Resource that was blocked
/// Spec: CSP Level 3 § 5.2
pub const ViolationResource = union(enum) {
    /// URL of blocked resource
    url: []const u8,
    /// Inline script blocked
    inline_script,
    /// Inline style blocked
    inline_style,
    /// eval() or similar blocked
    eval_script,
    /// WebAssembly.compile/instantiate blocked
    wasm_eval,
    /// Trusted Types policy creation blocked
    trusted_types_policy,
    /// Trusted Types sink assignment blocked
    trusted_types_sink,
};

/// CSP Violation for reporting
/// Spec: CSP Level 3 § 5.2
pub const Violation = struct {
    /// Document/worker URL
    document_uri: []const u8,

    /// HTTP status code of document
    status_code: u16 = 0,

    /// The resource that was blocked
    blocked_uri: ViolationResource,

    /// Referrer of the document
    referrer: ?[]const u8 = null,

    /// The directive that was violated (e.g., "script-src")
    violated_directive: []const u8,

    /// Effective directive after fallback (e.g., "script-src" even if default-src applied)
    effective_directive: []const u8,

    /// Original policy text
    original_policy: []const u8,

    /// Disposition (enforce or report)
    disposition: PolicyDisposition,

    /// Source file where violation occurred
    source_file: ?[]const u8 = null,

    /// Line number in source
    line_number: ?u32 = null,

    /// Column number in source
    column_number: ?u32 = null,

    /// Sample of violating content (first 40 chars if 'report-sample' specified)
    sample: ?[]const u8 = null,

    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        if (self.allocator) |alloc| {
            alloc.free(self.document_uri);
            switch (self.blocked_uri) {
                .url => |u| alloc.free(u),
                else => {},
            }
            if (self.referrer) |r| alloc.free(r);
            alloc.free(self.violated_directive);
            alloc.free(self.effective_directive);
            alloc.free(self.original_policy);
            if (self.source_file) |s| alloc.free(s);
            if (self.sample) |s| alloc.free(s);
        }
    }
};

// ============================================================================
// Tests
// ============================================================================

test "PolicyDisposition enum" {
    const enforce = PolicyDisposition.enforce;
    const report = PolicyDisposition.report;

    try std.testing.expect(enforce != report);
}

test "SourceExpression - create and deinit" {
    const allocator = std.testing.allocator;

    var expr = try SourceExpression.create(allocator, .keyword_self, "'self'");
    defer expr.deinit();

    try std.testing.expectEqual(SourceExpressionType.keyword_self, expr.type);
    try std.testing.expectEqualStrings("'self'", expr.raw_value);
}

test "SourceList - append and query" {
    const allocator = std.testing.allocator;

    var list = SourceList.init(allocator);
    defer list.deinit();

    try list.append(SourceExpression.createBorrowed(.keyword_self, "'self'"));
    try list.append(SourceExpression.createBorrowed(.scheme, "https:"));

    try std.testing.expect(list.contains(.keyword_self));
    try std.testing.expect(list.contains(.scheme));
    try std.testing.expect(!list.contains(.keyword_none));
    try std.testing.expect(!list.isNone());
}

test "SourceList - isNone" {
    const allocator = std.testing.allocator;

    var list = SourceList.init(allocator);
    defer list.deinit();

    try list.append(SourceExpression.createBorrowed(.keyword_none, "'none'"));

    try std.testing.expect(list.isNone());
}

test "Directive - create and deinit" {
    const allocator = std.testing.allocator;

    var directive = try Directive.create(allocator, "script-src");
    defer directive.deinit();

    try std.testing.expectEqualStrings("script-src", directive.name);
    try std.testing.expect(directive.value.isEmpty());
}

test "DirectiveSet - append first wins" {
    const allocator = std.testing.allocator;

    var set = DirectiveSet.init(allocator);
    defer set.deinit();

    var d1 = try Directive.create(allocator, "script-src");
    try d1.value.append(SourceExpression.createBorrowed(.keyword_self, "'self'"));

    var d2 = try Directive.create(allocator, "script-src");
    try d2.value.append(SourceExpression.createBorrowed(.scheme, "https:"));

    try set.append(d1);
    try set.append(d2); // Should be ignored (duplicate)
    d2.deinit(); // Need to clean up the rejected directive

    try std.testing.expectEqual(@as(usize, 1), set.count());

    const retrieved = set.get("script-src").?;
    try std.testing.expect(retrieved.value.contains(.keyword_self));
    try std.testing.expect(!retrieved.value.contains(.scheme));
}

test "Policy - init and containsDirective" {
    const allocator = std.testing.allocator;

    var policy = Policy.init(allocator, .enforce, .header);
    defer policy.deinit();

    const directive = try Directive.create(allocator, "default-src");
    try policy.directive_set.append(directive);

    try std.testing.expect(policy.containsDirective("default-src"));
    try std.testing.expect(!policy.containsDirective("script-src"));
}

test "CSPList - multiple policies" {
    const allocator = std.testing.allocator;

    var list = CSPList.init(allocator);
    defer list.deinit();

    const p1 = Policy.init(allocator, .enforce, .header);
    const p2 = Policy.init(allocator, .report, .header);

    try list.append(p1);
    try list.append(p2);

    try std.testing.expect(list.hasEnforcingPolicy());
    try std.testing.expect(list.hasReportOnlyPolicy());
    try std.testing.expect(list.contains_header_policy);
}

test "Origin - create borrowed" {
    const origin = Origin.createBorrowed("https", "example.com", 443);

    try std.testing.expectEqualStrings("https", origin.scheme);
    try std.testing.expectEqualStrings("example.com", origin.host);
    try std.testing.expectEqual(@as(?u16, 443), origin.port);
}
