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
//! Spec: https://html.spec.whatwg.org/multipage/browsers.html#policy-containers

const std = @import("std");
const Allocator = std.mem.Allocator;
const referrer_policy = @import("referrer_policy");
const request_mod = @import("request.zig");

pub const ReferrerPolicy = request_mod.ReferrerPolicy;

pub const PolicyContainer = struct {
    /// Allocates what the container owns (the CSP list, once there is one).
    allocator: Allocator,

    /// "A referrer policy, which is a referrer policy. It is initially the
    /// default referrer policy." The empty string is one too: "create a policy
    /// container from a fetch response" leaves it empty when the response
    /// names none, and main fetch then falls back to the default.
    referrer_policy: ReferrerPolicy = .strict_origin_when_cross_origin,

    /// A new policy container: every policy at its initial value.
    pub fn init(allocator: Allocator) PolicyContainer {
        return .{ .allocator = allocator };
    }

    /// HTML "clone a policy container" (steps 1, 4 and 6; the policies not
    /// modelled have nothing to copy).
    pub fn clone(self: *const PolicyContainer, allocator: Allocator) error{OutOfMemory}!PolicyContainer {
        // 1. Let clone be a new policy container.
        var copy = PolicyContainer.init(allocator);
        // 4. Set clone's referrer policy to policyContainer's referrer policy.
        copy.referrer_policy = self.referrer_policy;
        // 6. Return clone.
        return copy;
    }

    /// Release what the container owns. Nothing yet; the CSP list will be.
    pub fn deinit(self: *PolicyContainer) void {
        self.* = undefined;
    }

    /// HTML "create a policy container from a fetch response", steps 2 and 5,
    /// given the response's header list as values: its combined
    /// `Referrer-Policy` header value, or null when it has none. Step 1 - a
    /// blob: URL's container is its blob URL entry's environment's - is the
    /// caller's, which knows the URL.
    pub fn fromResponse(allocator: Allocator, referrer_policy_header: ?[]const u8) error{OutOfMemory}!PolicyContainer {
        // 2. Let result be a new policy container.
        var result = PolicyContainer.init(allocator);
        // 5. Set result's referrer policy to the result of parsing the
        // `Referrer-Policy` header given response: the last token that is a
        // referrer policy, or the empty string when none is.
        result.referrer_policy = parseReferrerPolicyHeader(referrer_policy_header);
        // 7. Return result.
        return result;
    }
};

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
