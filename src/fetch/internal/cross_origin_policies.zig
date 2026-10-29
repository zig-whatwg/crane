//! HTML's embedder policy (7.1.4) and opener policy (7.1.3) as data, how
//! each is obtained from a response's headers, and Fetch's
//! `Cross-Origin-Resource-Policy` check (3.7) that the embedder policy feeds.
//!
//! The types live with the request, below every global, for the reason
//! HTML's policy container does (policy_container.zig): every request
//! carries a clone of its client's container, and Fetch's cross-origin
//! resource policy check and "Cross-Origin-Embedder-Policy allows
//! credentials" read the embedder policy from that clone. HTML's decisions
//! over opener policies - matching, the browsing context group switch - are
//! html_core's (src/html/navigation/opener_policy.zig).
//!
//! Every header is read as Fetch "get a structured field value" given
//! "item" reads it: the header list's combined value parsed as one RFC 9651
//! item, so two headers (`require-corp, require-corp`) are a list, not an
//! item, and the header is ignored (HTML 7.1.4.1's table).
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#coep
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#cross-origin-opener-policies
//! Spec: https://fetch.spec.whatwg.org/#cross-origin-resource-policy-header

const std = @import("std");
const Allocator = std.mem.Allocator;
const structured_fields = @import("structured_fields.zig");
const origins = @import("origins.zig");
const cookiestore = @import("cookiestore");

/// HTML "embedder policy value".
pub const EmbedderPolicyValue = enum {
    unsafe_none,
    require_corp,
    credentialless,

    /// HTML: "compatible with cross-origin isolation" - "credentialless" or
    /// "require-corp".
    pub fn compatibleWithCrossOriginIsolation(self: EmbedderPolicyValue) bool {
        return self != .unsafe_none;
    }

    /// The token, as reports and `Cross-Origin-Embedder-Policy` spell it.
    pub fn token(self: EmbedderPolicyValue) []const u8 {
        return switch (self) {
            .unsafe_none => "unsafe-none",
            .require_corp => "require-corp",
            .credentialless => "credentialless",
        };
    }

    /// The value a header's token names, or null for any other token.
    pub fn fromToken(value: []const u8) ?EmbedderPolicyValue {
        if (std.mem.eql(u8, value, "require-corp")) return .require_corp;
        if (std.mem.eql(u8, value, "credentialless")) return .credentialless;
        if (std.mem.eql(u8, value, "unsafe-none")) return .unsafe_none;
        return null;
    }
};

/// HTML "embedder policy": a value and a report-only value, each with its
/// reporting endpoint (the empty string when none). Endpoint strings are
/// OWNED by `allocator` when non-empty.
pub const EmbedderPolicy = struct {
    value: EmbedderPolicyValue = .unsafe_none,
    reporting_endpoint: []const u8 = "",
    report_only_value: EmbedderPolicyValue = .unsafe_none,
    report_only_reporting_endpoint: []const u8 = "",

    /// A copy whose endpoints `allocator` owns (HTML "clone a policy
    /// container" step 3: "a copy of policyContainer's embedder policy").
    pub fn clone(self: *const EmbedderPolicy, allocator: Allocator) error{OutOfMemory}!EmbedderPolicy {
        var copy: EmbedderPolicy = .{ .value = self.value, .report_only_value = self.report_only_value };
        errdefer copy.deinit(allocator);
        if (self.reporting_endpoint.len > 0) copy.reporting_endpoint = try allocator.dupe(u8, self.reporting_endpoint);
        if (self.report_only_reporting_endpoint.len > 0) copy.report_only_reporting_endpoint = try allocator.dupe(u8, self.report_only_reporting_endpoint);
        return copy;
    }

    pub fn deinit(self: *EmbedderPolicy, allocator: Allocator) void {
        if (self.reporting_endpoint.len > 0) allocator.free(self.reporting_endpoint);
        if (self.report_only_reporting_endpoint.len > 0) allocator.free(self.report_only_reporting_endpoint);
        self.* = .{};
    }
};

/// HTML "opener policy value".
pub const OpenerPolicyValue = enum {
    unsafe_none,
    same_origin_allow_popups,
    same_origin,
    /// Never sent: `same-origin` with an embedder policy compatible with
    /// cross-origin isolation ("obtain an opener policy" step 4.1.2).
    same_origin_plus_coep,
    noopener_allow_popups,

    /// The value as COOP reports' `effectivePolicy` spells it.
    pub fn token(self: OpenerPolicyValue) []const u8 {
        return switch (self) {
            .unsafe_none => "unsafe-none",
            .same_origin_allow_popups => "same-origin-allow-popups",
            .same_origin => "same-origin",
            .same_origin_plus_coep => "same-origin-plus-coep",
            .noopener_allow_popups => "noopener-allow-popups",
        };
    }
};

/// HTML "opener policy". Endpoint strings are OWNED by `allocator` when
/// non-null.
pub const OpenerPolicy = struct {
    value: OpenerPolicyValue = .unsafe_none,
    reporting_endpoint: ?[]const u8 = null,
    report_only_value: OpenerPolicyValue = .unsafe_none,
    report_only_reporting_endpoint: ?[]const u8 = null,

    pub fn clone(self: *const OpenerPolicy, allocator: Allocator) error{OutOfMemory}!OpenerPolicy {
        var copy: OpenerPolicy = .{ .value = self.value, .report_only_value = self.report_only_value };
        errdefer copy.deinit(allocator);
        if (self.reporting_endpoint) |endpoint| copy.reporting_endpoint = try allocator.dupe(u8, endpoint);
        if (self.report_only_reporting_endpoint) |endpoint| copy.report_only_reporting_endpoint = try allocator.dupe(u8, endpoint);
        return copy;
    }

    pub fn deinit(self: *OpenerPolicy, allocator: Allocator) void {
        if (self.reporting_endpoint) |endpoint| allocator.free(endpoint);
        if (self.report_only_reporting_endpoint) |endpoint| allocator.free(endpoint);
        self.* = .{};
    }
};

/// What "obtain an embedder policy" and "obtain an opener policy" read of a
/// response: each header list value combined (Fetch "get"), null when the
/// response has none. BORROWED.
pub const Headers = struct {
    coep: ?[]const u8 = null,
    coep_report_only: ?[]const u8 = null,
    coop: ?[]const u8 = null,
    coop_report_only: ?[]const u8 = null,
};

/// One header's item: its token (borrowing the value) and its `report-to`
/// String parameter (owned), or null for each when the header is absent,
/// does not parse as an item, or holds no token / no String.
const Item = struct {
    token: ?[]const u8 = null,
    report_to: ?[]u8 = null,
};

/// Fetch "get a structured field value" given `name` and "item": the item,
/// or an empty one for null (no header, or a value that is not one item).
fn itemOf(allocator: Allocator, value: ?[]const u8) error{OutOfMemory}!Item {
    const header = value orelse return .{};
    const parsed = structured_fields.parseItemToken(allocator, header) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidField => return .{},
    };
    return .{ .token = parsed.token, .report_to = parsed.report_to };
}

/// HTML "obtain an embedder policy" from a response whose headers are
/// `headers`, for an environment that `secure` says is a secure context.
/// Allocates only for a `report-to` endpoint.
pub fn obtainEmbedderPolicy(allocator: Allocator, headers: Headers, secure: bool) error{OutOfMemory}!EmbedderPolicy {
    // 1. Let policy be a new embedder policy.
    var policy: EmbedderPolicy = .{};
    errdefer policy.deinit(allocator);
    // 2. If environment is a non-secure context, then return policy.
    if (!secure) return policy;
    // 3. Let parsedItem be the result of getting a structured field value
    // given `Cross-Origin-Embedder-Policy` and "item".
    var item = try itemOf(allocator, headers.coep);
    defer if (item.report_to) |endpoint| allocator.free(endpoint);
    // 4. If parsedItem is non-null, parsedItem[0] is a token, and it is
    // compatible with cross-origin isolation:
    if (item.token) |token| if (EmbedderPolicyValue.fromToken(token)) |value| if (value.compatibleWithCrossOriginIsolation()) {
        // 4.1. Set policy's value to parsedItem[0].
        policy.value = value;
        // 4.2. If parsedItem[1]["report-to"] exists and it is a string, set
        // policy's reporting endpoint to it.
        if (item.report_to) |endpoint| {
            policy.reporting_endpoint = endpoint;
            item.report_to = null;
        }
    };
    // 5-6. The same, from `Cross-Origin-Embedder-Policy-Report-Only`, for
    // the report-only value and its endpoint.
    var report_only = try itemOf(allocator, headers.coep_report_only);
    defer if (report_only.report_to) |endpoint| allocator.free(endpoint);
    if (report_only.token) |token| if (EmbedderPolicyValue.fromToken(token)) |value| if (value.compatibleWithCrossOriginIsolation()) {
        policy.report_only_value = value;
        if (report_only.report_to) |endpoint| {
            policy.report_only_reporting_endpoint = endpoint;
            report_only.report_to = null;
        }
    };
    // 7. Return policy.
    return policy;
}

/// HTML "obtain an opener policy" from a response whose headers are
/// `headers`, for a reserved environment that `secure` says is a secure
/// context. Steps 4.1.1 and 6.1.1 obtain the response's embedder policy
/// too: `same-origin` with one compatible with cross-origin isolation is
/// "same-origin-plus-COEP". Allocates only for a `report-to` endpoint.
pub fn obtainOpenerPolicy(allocator: Allocator, headers: Headers, secure: bool) error{OutOfMemory}!OpenerPolicy {
    // 1. Let policy be a new opener policy.
    var policy: OpenerPolicy = .{};
    errdefer policy.deinit(allocator);
    // 2. If reservedEnvironment is a non-secure context, then return policy.
    if (!secure) return policy;
    // Steps 4.1.1 and 6.1.1: the response's embedder policy, obtained
    // without its endpoints (only the values are read).
    var coep = try obtainEmbedderPolicy(allocator, .{ .coep = headers.coep, .coep_report_only = headers.coep_report_only }, secure);
    defer coep.deinit(allocator);
    // 3. Let parsedItem be the result of getting a structured field value
    // given `Cross-Origin-Opener-Policy` and "item".
    var item = try itemOf(allocator, headers.coop);
    defer if (item.report_to) |endpoint| allocator.free(endpoint);
    // 4. If parsedItem is not null and parsedItem[0] is a token:
    if (item.token) |token| {
        if (std.mem.eql(u8, token, "same-origin")) {
            // 4.1.2-3: same-origin-plus-COEP when the COEP value is
            // compatible with cross-origin isolation, else same-origin.
            policy.value = if (coep.value.compatibleWithCrossOriginIsolation()) .same_origin_plus_coep else .same_origin;
        }
        // 4.2.
        if (std.mem.eql(u8, token, "same-origin-allow-popups")) policy.value = .same_origin_allow_popups;
        // 4.3.
        if (std.mem.eql(u8, token, "noopener-allow-popups")) policy.value = .noopener_allow_popups;
        // 4.4. If parsedItem[1]["report-to"] exists and it is a string, set
        // policy's reporting endpoint to it.
        if (item.report_to) |endpoint| {
            policy.reporting_endpoint = endpoint;
            item.report_to = null;
        }
    }
    // 5. `Cross-Origin-Opener-Policy-Report-Only`.
    var report_only = try itemOf(allocator, headers.coop_report_only);
    defer if (report_only.report_to) |endpoint| allocator.free(endpoint);
    // 6. If parsedItem is not null and parsedItem[0] is a token:
    if (report_only.token) |token| {
        if (std.mem.eql(u8, token, "same-origin")) {
            // 6.1.2: report-only COOP also considers report-only COEP.
            policy.report_only_value = if (coep.value.compatibleWithCrossOriginIsolation() or coep.report_only_value.compatibleWithCrossOriginIsolation())
                .same_origin_plus_coep
            else
                .same_origin;
        }
        // 6.2. (No noopener-allow-popups step: HTML lists none for the
        // report-only header.)
        if (std.mem.eql(u8, token, "same-origin-allow-popups")) policy.report_only_value = .same_origin_allow_popups;
        // 6.3.
        if (report_only.report_to) |endpoint| {
            policy.report_only_reporting_endpoint = endpoint;
            report_only.report_to = null;
        }
    }
    // 7. Return policy.
    return policy;
}

/// Fetch's check results.
pub const CorpResult = enum { allowed, blocked };

/// What the cross-origin resource policy checks read of a response.
pub const CorpResponse = struct {
    /// The response's URL (serialized): its origin is the resource's.
    url: []const u8,
    /// The response's `Cross-Origin-Resource-Policy` header list value
    /// (Fetch "get": combined), null when it has none. BORROWED.
    corp: ?[]const u8,
    /// The response's request-includes-credentials.
    request_includes_credentials: bool,
};

/// Fetch "cross-origin resource policy internal check" given the request's
/// `origin` (a serialized origin, "null" when opaque), an embedder policy
/// value, the response and `for_navigation`.
pub fn corpInternalCheck(allocator: Allocator, origin: []const u8, embedder_policy: EmbedderPolicyValue, response: CorpResponse, for_navigation: bool) error{OutOfMemory}!CorpResult {
    // 1. If forNavigation is true and embedderPolicyValue is "unsafe-none",
    // then return allowed.
    if (for_navigation and embedder_policy == .unsafe_none) return .allowed;
    // 2. Let policy be the result of getting `Cross-Origin-Resource-Policy`
    // from response's header list. (Combined, so two headers - or
    // `same-site, same-origin` - match no value below.)
    // 3. If policy is neither `same-origin`, `same-site`, nor
    // `cross-origin`, then set policy to null.
    const Policy = enum { same_origin, same_site, cross_origin };
    var policy: ?Policy = null;
    if (response.corp) |value| {
        if (std.mem.eql(u8, value, "same-origin")) policy = .same_origin;
        if (std.mem.eql(u8, value, "same-site")) policy = .same_site;
        if (std.mem.eql(u8, value, "cross-origin")) policy = .cross_origin;
    }
    // 4. If policy is null, then switch on embedderPolicyValue:
    if (policy == null) switch (embedder_policy) {
        // "unsafe-none": do nothing.
        .unsafe_none => {},
        // "credentialless": same-origin if response's
        // request-includes-credentials is true, or forNavigation is true.
        .credentialless => if (response.request_includes_credentials or for_navigation) {
            policy = .same_origin;
        },
        // "require-corp": same-origin.
        .require_corp => policy = .same_origin,
    };
    // 5. Switch on policy:
    const p = policy orelse return .allowed; // null: allowed
    switch (p) {
        // `cross-origin`: allowed.
        .cross_origin => return .allowed,
        // `same-origin`: allowed if origin is same origin with response's
        // URL's origin, otherwise blocked.
        .same_origin => return if (try sameOrigin(allocator, origin, response.url)) .allowed else .blocked,
        // `same-site`: allowed if origin is schemelessly same site with
        // response's URL's origin, and origin's scheme is "https" or
        // response's URL's scheme is not "https".
        .same_site => {
            if (!try schemelesslySameSite(allocator, origin, response.url)) return .blocked;
            if (std.ascii.startsWithIgnoreCase(origin, "https:") or !std.ascii.startsWithIgnoreCase(response.url, "https:")) return .allowed;
            return .blocked;
        },
    }
}

/// HTML "same origin" for a serialized origin and a URL (origins.zig). A
/// value that does not parse is no origin, and same origin with nothing.
fn sameOrigin(allocator: Allocator, a: []const u8, b: []const u8) error{OutOfMemory}!bool {
    return origins.sameOrigin(allocator, a, b) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => false,
    };
}

/// origins.serializedOriginOf, out of memory its only failure: a value that
/// does not parse is an opaque origin, "null".
fn serializedOriginOf(allocator: Allocator, url: []const u8) error{OutOfMemory}![]u8 {
    return origins.serializedOriginOf(allocator, url) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => allocator.dupe(u8, "null"),
    };
}

/// HTML "schemelessly same site" for a serialized origin and a URL: both
/// tuple origins whose hosts are the same site - equal registrable domains,
/// or equal hosts when either has none (an IP address, a public suffix).
/// An opaque origin is schemelessly same site with nothing here.
fn schemelesslySameSite(allocator: Allocator, origin: []const u8, url: []const u8) error{OutOfMemory}!bool {
    const a = try serializedOriginOf(allocator, origin);
    defer allocator.free(a);
    const b = try serializedOriginOf(allocator, url);
    defer allocator.free(b);
    const host_a = hostOf(a) orelse return false;
    const host_b = hostOf(b) orelse return false;
    // The scheme plays no part: compare the hosts as one scheme's.
    const site_a = try std.fmt.allocPrint(allocator, "https://{s}", .{host_a});
    defer allocator.free(site_a);
    const site_b = try std.fmt.allocPrint(allocator, "https://{s}", .{host_b});
    defer allocator.free(site_b);
    // A failure (out of memory included) is not same site: the check
    // blocks rather than allows.
    return cookiestore.sameSite(allocator, site_a, site_b) catch false;
}

/// The host of a serialized tuple origin ("scheme://host[:port]"); null for
/// "null".
fn hostOf(serialized: []const u8) ?[]const u8 {
    const separator = std.mem.indexOf(u8, serialized, "://") orelse return null;
    const authority = serialized[separator + 3 ..];
    if (authority.len > 0 and authority[0] == '[') {
        const end = std.mem.indexOfScalar(u8, authority, ']') orelse return null;
        return authority[0 .. end + 1];
    }
    return authority[0 .. std.mem.indexOfScalar(u8, authority, ':') orelse authority.len];
}

/// Fetch "cross-origin resource policy check" steps 3 and 5, without the
/// reports (steps 4 and 6 are the caller's, which knows the settings object
/// and its reporter): blocked when the check with "unsafe-none" blocks, or
/// the check with `embedder_policy`'s value does. `report_only_blocks` tells
/// the caller whether step 4's report-only check blocked, and `enforced`
/// whether the block came from the embedder policy (step 6's report) rather
/// than from the header alone (step 3, which reports nothing).
pub const CorpCheck = struct {
    result: CorpResult,
    /// Step 4: the report-only value's check blocked (a "reporting" report).
    report_only_blocks: bool = false,
    /// Step 6: the block is the embedder policy's (an "enforce" report).
    enforced_by_embedder_policy: bool = false,
};

/// Fetch "cross-origin resource policy check" given the request's `origin`,
/// its client's embedder policy (`embedder_policy`; a client-less request
/// passes a new one), the response and `for_navigation`.
pub fn corpCheck(allocator: Allocator, origin: []const u8, embedder_policy: *const EmbedderPolicy, response: CorpResponse, for_navigation: bool) error{OutOfMemory}!CorpCheck {
    // 3. If the internal check with "unsafe-none" returns blocked, then
    // return blocked (no report: the block is not the embedder policy's).
    if (try corpInternalCheck(allocator, origin, .unsafe_none, response, for_navigation) == .blocked) return .{ .result = .blocked };
    var check: CorpCheck = .{ .result = .allowed };
    // 4. The report-only value's check blocking queues a report.
    if (try corpInternalCheck(allocator, origin, embedder_policy.report_only_value, response, for_navigation) == .blocked) check.report_only_blocks = true;
    // 5. If the check with the embedder policy's value returns allowed,
    // then return allowed.
    if (try corpInternalCheck(allocator, origin, embedder_policy.value, response, for_navigation) == .allowed) return check;
    // 6-7. Queue an "enforce" report, and return blocked.
    check.result = .blocked;
    check.enforced_by_embedder_policy = true;
    return check;
}

/// Fetch "Cross-Origin-Embedder-Policy allows credentials" for a request in
/// `mode` whose client's embedder policy value is `client_policy` (null: no
/// client), whose origin is `origin`, current URL `current_url` and whose
/// redirect-taint is same-origin when `same_origin_taint`.
pub fn coepAllowsCredentials(allocator: Allocator, no_cors: bool, client_policy: ?EmbedderPolicyValue, origin: []const u8, current_url: []const u8, same_origin_taint: bool) error{OutOfMemory}!bool {
    // 2. If request's mode is not "no-cors", then return true.
    if (!no_cors) return true;
    // 3. If request's client is null, then return true.
    const policy = client_policy orelse return true;
    // 4. If the client's embedder policy's value is not "credentialless",
    // then return true.
    if (policy != .credentialless) return true;
    // 5. If request's origin is same origin with request's current URL's
    // origin and request's redirect-taint is "same-origin", return true.
    if (same_origin_taint and try sameOrigin(allocator, origin, current_url)) return true;
    // 6. Return false.
    return false;
}
