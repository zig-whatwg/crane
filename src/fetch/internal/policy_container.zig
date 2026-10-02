//! HTML's policy container (7.1.6): the policies that apply to a Document or
//! a WorkerGlobalScope.
//!
//! The container is HTML's, but every request carries one: Fetch "populate
//! request from client" step 3 gives a request a clone of its client's, and
//! main fetch reads the request's - its referrer policy at step 8 - so the
//! type lives with the request, below every global that owns one. A Document
//! and a WorkerGlobalScope each own theirs (src/dom/policy_containers.zig
//! reaches them); a request owns its clone.
//!
//! Not modelled, stated: the embedder policy, and the integrity and
//! report-only integrity policies - nothing reads them yet.
//!
//! The CSP list is a list of parsed policies; "a copy of policy" (clone step
//! 2) is csp.parsing.copyPolicy, the policy's serialization parsed again.
//!
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#policy-containers

const std = @import("std");
const Allocator = std.mem.Allocator;
const referrer_policy = @import("referrer_policy");
const csp = @import("csp");
const request_mod = @import("request.zig");
const origins = @import("origins.zig");

pub const ReferrerPolicy = request_mod.ReferrerPolicy;

pub const PolicyContainer = struct {
    /// Allocates what the container owns: the CSP list.
    allocator: Allocator,

    /// "A CSP list, which is a CSP list. It is initially empty." Owned.
    csp_list: csp.CSPList,

    /// "A referrer policy, which is a referrer policy. It is initially the
    /// default referrer policy." The empty string is one too: "create a policy
    /// container from a fetch response" leaves it empty when the response
    /// names none, and main fetch then falls back to the default.
    referrer_policy: ReferrerPolicy = .strict_origin_when_cross_origin,

    /// A new policy container: every policy at its initial value.
    pub fn init(allocator: Allocator) PolicyContainer {
        return .{ .allocator = allocator, .csp_list = csp.CSPList.init(allocator) };
    }

    /// HTML "clone a policy container" (steps 1, 4 and 6; the policies not
    /// modelled have nothing to copy).
    pub fn clone(self: *const PolicyContainer, allocator: Allocator) error{OutOfMemory}!PolicyContainer {
        // 1. Let clone be a new policy container, and 2. "for each policy in
        // policyContainer's CSP list, append a copy of policy into clone's
        // CSP list."
        var copy: PolicyContainer = .{
            .allocator = allocator,
            .csp_list = csp.parsing.copyList(allocator, &self.csp_list) catch return error.OutOfMemory,
        };
        // 4. Set clone's referrer policy to policyContainer's referrer policy.
        copy.referrer_policy = self.referrer_policy;
        // 6. Return clone.
        return copy;
    }

    /// Release what the container owns: its CSP list.
    pub fn deinit(self: *PolicyContainer) void {
        self.csp_list.deinit();
        self.* = undefined;
    }

    /// HTML "create a policy container from a fetch response", steps 2 and 5,
    /// given the response's header list as values: its combined
    /// `Referrer-Policy` header value, or null when it has none. Step 1 - a
    /// blob: URL's container is its blob URL entry's environment's - is the
    /// caller's, which knows the URL.
    pub fn fromResponse(allocator: Allocator, referrer_policy_header: ?[]const u8) error{OutOfMemory}!PolicyContainer {
        return fromResponseHeaders(allocator, .{ .referrer_policy = referrer_policy_header });
    }

    /// HTML "create a policy container from a fetch response", steps 2-3 and
    /// 5, given what it reads of the response: its URL and its combined
    /// `Content-Security-Policy`, `Content-Security-Policy-Report-Only` and
    /// `Referrer-Policy` header values.
    pub fn fromResponseHeaders(allocator: Allocator, response: ResponseHeaders) error{OutOfMemory}!PolicyContainer {
        // 2. Let result be a new policy container.
        var result = PolicyContainer.init(allocator);
        errdefer result.deinit();
        // 3. "Set result's CSP list to the result of parsing a response's
        // Content Security Policies given response."
        try parseResponseCsp(allocator, &result.csp_list, response);
        // 5. Set result's referrer policy to the result of parsing the
        // `Referrer-Policy` header given response: the last token that is a
        // referrer policy, or the empty string when none is.
        result.referrer_policy = parseReferrerPolicyHeader(response.referrer_policy);
        // 7. Return result.
        return result;
    }

    /// Whether an enforced policy of the CSP list carries
    /// upgrade-insecure-requests (Upgrade Insecure Requests 3.1: enforcing
    /// it sets the settings object's insecure requests policy to Upgrade).
    pub fn upgradesInsecureRequests(self: *const PolicyContainer) bool {
        for (self.csp_list.policies.items) |*policy| {
            if (policy.disposition == .enforce and policy.containsDirective("upgrade-insecure-requests")) return true;
        }
        return false;
    }
};

/// What "create a policy container from a fetch response" reads of a
/// response: header values combined as Fetch "get" combines them (", "),
/// null when the response has none.
pub const ResponseHeaders = struct {
    /// The response's URL - its origin is each parsed policy's self-origin.
    url: []const u8 = "",
    csp: ?[]const u8 = null,
    csp_report_only: ?[]const u8 = null,
    referrer_policy: ?[]const u8 = null,
};

/// CSP 2.2.2 "Parse a response's Content Security Policies", into `list`.
fn parseResponseCsp(allocator: Allocator, list: *csp.CSPList, response: ResponseHeaders) error{OutOfMemory}!void {
    const first = list.policies.items.len;
    // 2. For each token of the `Content-Security-Policy` values: a policy
    // whose source is "header" and disposition "enforce"; 3. of the
    // `-Report-Only` values: disposition "report". An empty directive set is
    // not appended.
    const headers = [_]struct { value: ?[]const u8, disposition: csp.PolicyDisposition }{
        .{ .value = response.csp, .disposition = .enforce },
        .{ .value = response.csp_report_only, .disposition = .report },
    };
    for (headers) |header| {
        const value = header.value orelse continue;
        var tokens = std.mem.splitScalar(u8, value, ',');
        while (tokens.next()) |token| {
            var policy = csp.parsing.parseSerializedCSP(allocator, token, .header, header.disposition) catch return error.OutOfMemory;
            if (policy.directive_set.isEmpty()) {
                policy.deinit();
                continue;
            }
            list.append(policy) catch {
                policy.deinit();
                return error.OutOfMemory;
            };
        }
    }
    // 4. "For each policy of policies: set policy's self-origin to
    // response's url's origin."
    if (list.policies.items.len == first) return;
    const origin = (try selfOriginOf(allocator, response.url)) orelse return;
    defer {
        var o = origin;
        o.deinit();
    }
    for (list.policies.items[first..]) |*policy| {
        policy.self_origin = try csp.Origin.create(allocator, origin.scheme, origin.host, origin.port);
    }
}

/// `url`'s origin as a CSP self-origin (owned), or null for an opaque one.
pub fn selfOriginOf(allocator: Allocator, url: []const u8) error{OutOfMemory}!?csp.Origin {
    const serialized = origins.serializedOriginOf(allocator, url) catch return error.OutOfMemory;
    defer allocator.free(serialized);
    const sep = std.mem.indexOf(u8, serialized, "://") orelse return null;
    const authority = serialized[sep + 3 ..];
    const host_end = if (authority.len > 0 and authority[0] == '[')
        (std.mem.indexOfScalar(u8, authority, ']') orelse return null) + 1
    else
        std.mem.indexOfScalar(u8, authority, ':') orelse authority.len;
    const port: ?u16 = if (host_end < authority.len and authority[host_end] == ':')
        std.fmt.parseInt(u16, authority[host_end + 1 ..], 10) catch return null
    else
        null;
    return try csp.Origin.create(allocator, serialized[0..sep], authority[0..host_end], port);
}

/// Referrer Policy "parse a referrer policy from a Referrer-Policy header",
/// given the header's combined value (null when there is none).
pub fn parseReferrerPolicyHeader(value: ?[]const u8) ReferrerPolicy {
    const header = value orelse return .empty;
    const parsed = referrer_policy.parseReferrerPolicyHeader(header) orelse return .empty;
    return std.meta.stringToEnum(ReferrerPolicy, @tagName(parsed)) orelse .empty;
}

/// HTML 4.2.5.1, the "referrer" metadata name, steps 4-6: the referrer policy
/// a meta element named referrer with this `content` sets, or null for none.
pub fn referrerPolicyFromMeta(content: []const u8) ?ReferrerPolicy {
    const parsed = referrer_policy.parseMetaReferrer(content) orelse return null;
    return std.meta.stringToEnum(ReferrerPolicy, @tagName(parsed));
}

/// HTML's referrer policy attribute (2.5.x): an enumerated attribute whose
/// keywords are the referrer policies, matched ASCII case-insensitively, and
/// whose missing and invalid value defaults are the empty string state.
/// `value` is the content attribute's value, or null when it is absent.
///
/// Spec: https://html.spec.whatwg.org/multipage/urls-and-fetching.html#referrer-policy-attribute
pub fn referrerPolicyFromAttribute(value: ?[]const u8) ReferrerPolicy {
    const v = value orelse return .empty;
    for (std.enums.values(referrer_policy.ReferrerPolicy)) |candidate| {
        if (candidate == .empty) continue;
        if (std.ascii.eqlIgnoreCase(v, candidate.toString())) {
            return std.meta.stringToEnum(ReferrerPolicy, @tagName(candidate)) orelse .empty;
        }
    }
    return .empty;
}

test "a referrer policy attribute: its keywords, else the empty string" {
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, referrerPolicyFromAttribute("no-referrer"));
    try std.testing.expectEqual(ReferrerPolicy.unsafe_url, referrerPolicyFromAttribute("UNSAFE-URL"));
    try std.testing.expectEqual(ReferrerPolicy.empty, referrerPolicyFromAttribute(null));
    try std.testing.expectEqual(ReferrerPolicy.empty, referrerPolicyFromAttribute(""));
    // An enumerated attribute: no whitespace stripped, no legacy keywords.
    try std.testing.expectEqual(ReferrerPolicy.empty, referrerPolicyFromAttribute(" origin"));
    try std.testing.expectEqual(ReferrerPolicy.empty, referrerPolicyFromAttribute("never"));
}

test "a new policy container has the default referrer policy" {
    const container = PolicyContainer.init(std.testing.allocator);
    try std.testing.expectEqual(ReferrerPolicy.strict_origin_when_cross_origin, container.referrer_policy);
}

test "a container from a response takes its Referrer-Policy header, or the empty string" {
    const a = std.testing.allocator;
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, (try PolicyContainer.fromResponse(a, "no-referrer")).referrer_policy);
    try std.testing.expectEqual(ReferrerPolicy.origin, (try PolicyContainer.fromResponse(a, "unsafe-url, origin, bogus")).referrer_policy);
    try std.testing.expectEqual(ReferrerPolicy.empty, (try PolicyContainer.fromResponse(a, "bogus")).referrer_policy);
    try std.testing.expectEqual(ReferrerPolicy.empty, (try PolicyContainer.fromResponse(a, null)).referrer_policy);
}

test "a clone copies the referrer policy and is independent of the original" {
    var original = try PolicyContainer.fromResponse(std.testing.allocator, "same-origin");
    defer original.deinit();
    var copy = try original.clone(std.testing.allocator);
    defer copy.deinit();
    original.referrer_policy = .unsafe_url;
    try std.testing.expectEqual(ReferrerPolicy.same_origin, copy.referrer_policy);
}

test "a meta referrer's content maps to the request's referrer policy enum" {
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, referrerPolicyFromMeta("never").?);
    try std.testing.expectEqual(ReferrerPolicy.strict_origin_when_cross_origin, referrerPolicyFromMeta("default").?);
    try std.testing.expect(referrerPolicyFromMeta("bogus") == null);
}

test "a container from a response parses its CSP headers, each a policy with the response's origin" {
    const allocator = std.testing.allocator;
    var container = try PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "https://web-platform.test:8443/x/page.html",
        .csp = "worker-src 'none', upgrade-insecure-requests",
        .csp_report_only = "script-src 'self'",
        .referrer_policy = "no-referrer",
    });
    defer container.deinit();
    try std.testing.expectEqual(@as(usize, 3), container.csp_list.policies.items.len);
    const first = &container.csp_list.policies.items[0];
    try std.testing.expect(first.containsDirective("worker-src"));
    try std.testing.expectEqual(csp.PolicyDisposition.enforce, first.disposition);
    try std.testing.expectEqualStrings("web-platform.test", first.self_origin.?.host);
    try std.testing.expectEqual(@as(?u16, 8443), first.self_origin.?.port);
    try std.testing.expectEqual(csp.PolicyDisposition.report, container.csp_list.policies.items[2].disposition);
    try std.testing.expect(container.upgradesInsecureRequests());
    try std.testing.expectEqual(ReferrerPolicy.no_referrer, container.referrer_policy);
}

test "a clone copies the CSP list; a report-only upgrade-insecure-requests upgrades nothing" {
    const allocator = std.testing.allocator;
    var original = try PolicyContainer.fromResponseHeaders(allocator, .{
        .url = "http://a.test/",
        .csp_report_only = "upgrade-insecure-requests",
        .csp = "default-src 'self'",
    });
    defer original.deinit();
    try std.testing.expect(!original.upgradesInsecureRequests());
    var copy = try original.clone(allocator);
    defer copy.deinit();
    try std.testing.expectEqual(@as(usize, 2), copy.csp_list.policies.items.len);
    try std.testing.expectEqualStrings("a.test", copy.csp_list.policies.items[0].self_origin.?.host);
}
