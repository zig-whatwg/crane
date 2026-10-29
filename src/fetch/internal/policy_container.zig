//! HTML's policy container (7.1.7): the policies that apply to a Document or
//! a WorkerGlobalScope.
//!
//! The container is HTML's, but every request carries one: Fetch "populate
//! request from client" step 3 gives a request a clone of its client's, and
//! main fetch reads the request's - its referrer policy at step 8 - so the
//! type lives with the request, below every global that owns one. A Document
//! and a WorkerGlobalScope each own theirs (src/dom/policy_containers.zig
//! reaches them); a request owns its clone.
//!
//! The embedder policy is HTML's (7.1.4; cross_origin_policies.zig). The
//! opener policy rides here too, though HTML keeps it on the Document and
//! never inherits it through a container - `clone` leaves it at its initial
//! value - as Chromium's PolicyContainerPolicies carries
//! cross_origin_opener_policy beside cross_origin_embedder_policy
//! (content/browser/renderer_host/policy_container_host.h): it is the
//! document's, set by the navigation that makes the document (stated).
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
const structured_fields = @import("structured_fields.zig");
const mixed_content = @import("../mixed_content.zig");
const cross_origin_policies = @import("cross_origin_policies.zig");
pub const EmbedderPolicy = cross_origin_policies.EmbedderPolicy;
pub const OpenerPolicy = cross_origin_policies.OpenerPolicy;
const basic_parser = @import("basic_parser");
const url_serializer = @import("url_serializer");

pub const ReferrerPolicy = request_mod.ReferrerPolicy;

pub const PolicyContainer = struct {
    /// Allocates the container's owned policies and header values.
    allocator: Allocator,

    /// "A CSP list, which is a CSP list. It is initially empty." Owned.
    csp_list: csp.CSPList,

    /// Reporting §3.3: the response's endpoints, owned by this global's
    /// container. A request/inherited-document clone does not copy them.
    endpoints: ?*Endpoints = null,

    /// SRI §3.8: owned policies; absent headers allocate nothing.
    integrity_policy: ?*IntegrityPolicy = null,
    integrity_policy_report_only: ?*IntegrityPolicy = null,

    /// CSPEE §2.4 item 2: the serialized requirement for nested navigations.
    /// Owned. HTML's clone algorithm copies enforced policies, not this item.
    required_csp: ?[]u8 = null,

    /// Upgrade Insecure Requests' "insecure requests policy" inherited from
    /// the embedding document (UIR 3.3: a nested browsing context's
    /// documents) or from the worker's creator (a worker's settings object):
    /// Upgrade when true. UIR keeps it on settings objects and browsing
    /// contexts; it rides here, on the container every inheritance path
    /// already carries (stated). The container's own CSP list can set it too
    /// - `upgradesInsecureRequests`.
    inherited_upgrade_insecure_requests: bool = false,

    /// UIR 3.3: inherited upgrade-insecure-navigations (host, port) tuples.
    /// Each host is OWNED. Own opt-ins are derived from enforced policies'
    /// delivery URLs, so an uninherited set adds no allocation.
    inherited_upgrade_insecure_navigations: std.ArrayListUnmanaged(NavigationUpgrade) = .empty,

    /// "A referrer policy, which is a referrer policy. It is initially the
    /// default referrer policy." The empty string is one too: "create a policy
    /// container from a fetch response" leaves it empty when the response
    /// names none, and main fetch then falls back to the default.
    referrer_policy: ReferrerPolicy = .strict_origin_when_cross_origin,

    /// "An embedder policy, which is an embedder policy. It is initially a
    /// new embedder policy." Its endpoints are owned.
    embedder_policy: EmbedderPolicy = .{},

    /// The Document's opener policy (HTML 7.1.3), carried with its
    /// container as Chromium's PolicyContainerPolicies does (module doc).
    /// NOT part of HTML's policy container: `clone` gives a new opener
    /// policy - a document inheriting a container (srcdoc, about:blank,
    /// a local URL) gets its opener policy from its own navigation params,
    /// never from the container - and a request never reads it. Its
    /// endpoints are owned. Meaningful for a top-level document only.
    opener_policy: OpenerPolicy = .{},

    const NavigationUpgrade = struct { host: []const u8, port: ?u16 };

    /// The container a global's settings object answers with when the one
    /// it keeps cannot be found - a Window whose document, or whose
    /// document's container, is gone. Not knowing the policies is not "no
    /// policies": its CSP list is csp.CSPList.unavailable (empty,
    /// unenforceable), so every CSP decision against it, or against a clone
    /// of it - a request's (Fetch "populate request from client" step 3), a
    /// worker's - is "Blocked", and the strictest referrer policy applies.
    /// Static and read-only: reading or cloning it allocates nothing. Never
    /// deinit.
    pub const unavailable: PolicyContainer = .{
        .allocator = std.mem.Allocator.failing,
        .csp_list = csp.CSPList.unavailable,
        .referrer_policy = .no_referrer,
    };

    /// A new policy container: every policy at its initial value.
    pub fn init(allocator: Allocator) PolicyContainer {
        return .{ .allocator = allocator, .csp_list = csp.CSPList.init(allocator) };
    }

    /// HTML "clone a policy container"; each request owns its snapshot.
    pub fn clone(self: *const PolicyContainer, allocator: Allocator) error{OutOfMemory}!PolicyContainer {
        // 1. Let clone be a new policy container, and 2. "for each policy in
        // policyContainer's CSP list, append a copy of policy into clone's
        // CSP list."
        var copy: PolicyContainer = .{
            .allocator = allocator,
            .csp_list = csp.parsing.copyList(allocator, &self.csp_list) catch return error.OutOfMemory,
        };
        errdefer copy.deinit();
        // 3. Set clone's embedder policy to a copy of policyContainer's
        // embedder policy.
        copy.embedder_policy = try self.embedder_policy.clone(allocator);
        // 4. Set clone's referrer policy to policyContainer's referrer policy.
        copy.referrer_policy = self.referrer_policy;
        copy.inherited_upgrade_insecure_requests = self.inherited_upgrade_insecure_requests;
        if (self.inherited_upgrade_insecure_navigations.items.len != 0) {
            try copy.inherited_upgrade_insecure_navigations.ensureTotalCapacity(allocator, self.inherited_upgrade_insecure_navigations.items.len);
            for (self.inherited_upgrade_insecure_navigations.items) |tuple| {
                copy.inherited_upgrade_insecure_navigations.appendAssumeCapacity(.{
                    .host = try allocator.dupe(u8, tuple.host),
                    .port = tuple.port,
                });
            }
        }
        // 5. Copy the integrity policy. DEVIATION from HTML's clone step 5,
        // which copies only the enforced policy: the report-only policy is
        // copied too, because SRI §3.8.2 step 6 reads it from the request's
        // clone and could otherwise never report. A srcdoc or about:blank
        // document that inherits a container inherits it as well (row 48
        // review S2).
        if (self.integrity_policy) |policy| copy.integrity_policy = try policy.clone(allocator);
        if (self.integrity_policy_report_only) |policy| copy.integrity_policy_report_only = try policy.clone(allocator);
        // 6. Return clone.
        return copy;
    }

    /// Release the container's owned policies and header values.
    pub fn deinit(self: *PolicyContainer) void {
        self.csp_list.deinit();
        self.embedder_policy.deinit(self.allocator);
        self.opener_policy.deinit(self.allocator);
        if (self.endpoints) |endpoints| endpoints.deinit();
        if (self.integrity_policy) |policy| policy.deinit();
        if (self.integrity_policy_report_only) |policy| policy.deinit();
        if (self.required_csp) |required| self.allocator.free(required);
        for (self.inherited_upgrade_insecure_navigations.items) |tuple| self.allocator.free(tuple.host);
        self.inherited_upgrade_insecure_navigations.deinit(self.allocator);
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
    /// 5-6, given what it reads of the response: its URL and its combined
    /// `Content-Security-Policy`, `Content-Security-Policy-Report-Only` and
    /// `Referrer-Policy` and Integrity-Policy header values.
    pub fn fromResponseHeaders(allocator: Allocator, response: ResponseHeaders) error{OutOfMemory}!PolicyContainer {
        // 2. Let result be a new policy container.
        var result = PolicyContainer.init(allocator);
        errdefer result.deinit();
        // 3. "Set result's CSP list to the result of parsing a response's
        // Content Security Policies given response."
        try parseResponseCsp(allocator, &result.csp_list, response);
        // 4. "If environment is non-null, then set result's embedder policy
        // to the result of obtaining an embedder policy given response and
        // environment. Otherwise, set it to "unsafe-none"."
        if (response.environment_secure) |secure| result.embedder_policy = try cross_origin_policies.obtainEmbedderPolicy(allocator, .{
            .coep = response.coep,
            .coep_report_only = response.coep_report_only,
        }, secure);
        if (response.reporting_endpoints) |header| result.endpoints = try Endpoints.fromHeader(allocator, response.url, header);
        // 5. Set result's referrer policy to the result of parsing the
        // `Referrer-Policy` header given response: the last token that is a
        // referrer policy, or the empty string when none is.
        result.referrer_policy = parseReferrerPolicyHeader(response.referrer_policy);
        // 6. SRI §3.8.1: parse each present Integrity-Policy header.
        if (response.integrity_policy) |header| result.integrity_policy = try IntegrityPolicy.fromHeader(allocator, header);
        if (response.integrity_policy_report_only) |header| result.integrity_policy_report_only = try IntegrityPolicy.fromHeader(allocator, header);
        try result.applyRequiredCSP(response.required_csp, response.url, response.blanket_csp_acceptance);
        // 7. Return result.
        return result;
    }

    /// CSPEE §2.4 item 10, also used after local-document inheritance.
    /// Deviation: Chrome 154 NavigationRequest::CheckCSPEmbeddedEnforcement
    /// appends unconditionally after blanket acceptance (:8266-8279); only
    /// implicit acceptance skips a subsumed requirement. The draft instead
    /// skips both, to allow an embedee's compatible but different nonce.
    pub fn applyRequiredCSP(self: *PolicyContainer, required: ?[]const u8, response_url: []const u8, blanket: bool) error{OutOfMemory}!void {
        const serialized = required orelse return;
        const owned = try self.allocator.dupe(u8, serialized);
        errdefer self.allocator.free(owned);
        var policy = csp.parsing.parseSerializedCSP(self.allocator, serialized, .header, .enforce) catch return error.OutOfMemory;
        var policy_owned = true;
        defer if (policy_owned) policy.deinit();
        policy.self_origin = try selfOriginOf(self.allocator, response_url);
        policy.delivery_url = try self.allocator.dupe(u8, response_url);
        if (blanket or !(csp.embedded_enforcement.subsumes(self.allocator, &policy, &self.csp_list) catch return error.OutOfMemory)) {
            try self.csp_list.append(policy);
            policy_owned = false;
        }
        if (self.required_csp) |previous| self.allocator.free(previous);
        self.required_csp = owned;
    }

    /// Whether an enforced policy of the CSP list carries
    /// upgrade-insecure-requests (Upgrade Insecure Requests 3.1: enforcing
    /// it sets the settings object's insecure requests policy to Upgrade).
    pub fn upgradesInsecureRequests(self: *const PolicyContainer) bool {
        if (self.inherited_upgrade_insecure_requests) return true;
        for (self.csp_list.policies.items) |*policy| {
            if (policy.disposition == .enforce and policy.containsDirective("upgrade-insecure-requests")) return true;
        }
        return false;
    }

    /// UIR 3.3: snapshot the parent's inherited and own navigation opt-ins.
    /// An empty or already-inherited set allocates nothing. On failure, the
    /// caller must discard this partial container rather than commit it.
    pub fn inheritUpgradeInsecureNavigations(self: *PolicyContainer, parent: *const PolicyContainer) error{OutOfMemory}!void {
        for (parent.inherited_upgrade_insecure_navigations.items) |tuple| try self.appendNavigationUpgrade(tuple);
        for (parent.csp_list.policies.items) |*policy| {
            if (ownNavigationUpgrade(policy)) |tuple| try self.appendNavigationUpgrade(tuple);
        }
    }

    /// UIR 4.1 steps 2.3-2.4: test the canonical request URL's host and
    /// port without allocating. Only top-level navigation asks this.
    /// Gecko compares principals after http->https and WebKit compares
    /// http-ified origins, both preserving nondefault ports; follow the
    /// spec's pair, rather than Blink's host-only set (no newer spec).
    pub fn upgradesNavigationTo(self: *const PolicyContainer, url: []const u8) bool {
        const tuple = navigationUpgradeOf(url) orelse return false;
        for (self.inherited_upgrade_insecure_navigations.items) |inherited| {
            if (sameNavigationUpgrade(inherited, tuple)) return true;
        }
        for (self.csp_list.policies.items) |*policy| {
            if (ownNavigationUpgrade(policy)) |own| {
                if (sameNavigationUpgrade(own, tuple)) return true;
            }
        }
        return false;
    }

    fn appendNavigationUpgrade(self: *PolicyContainer, tuple: NavigationUpgrade) error{OutOfMemory}!void {
        for (self.inherited_upgrade_insecure_navigations.items) |existing| {
            if (sameNavigationUpgrade(existing, tuple)) return;
        }
        const host = try self.allocator.dupe(u8, tuple.host);
        errdefer self.allocator.free(host);
        try self.inherited_upgrade_insecure_navigations.append(self.allocator, .{ .host = host, .port = tuple.port });
    }

    /// UIR 3.1 steps 3-4: only enforcement opts the protected resource in.
    fn ownNavigationUpgrade(policy: *const csp.Policy) ?NavigationUpgrade {
        if (policy.disposition != .enforce or !policy.containsDirective("upgrade-insecure-requests")) return null;
        return navigationUpgradeOf(policy.delivery_url orelse return null);
    }

    /// Borrow the tuple of an already-parsed, serialized URL.
    fn navigationUpgradeOf(url: []const u8) ?NavigationUpgrade {
        const parts = @import("../algorithms/csp_check.zig").urlParts(url);
        return .{ .host = parts.host orelse return null, .port = parts.port };
    }

    fn sameNavigationUpgrade(a: NavigationUpgrade, b: NavigationUpgrade) bool {
        return a.port == b.port and std.mem.eql(u8, a.host, b.host);
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
    reporting_endpoints: ?[]const u8 = null,
    integrity_policy: ?[]const u8 = null,
    integrity_policy_report_only: ?[]const u8 = null,
    required_csp: ?[]const u8 = null,
    blanket_csp_acceptance: bool = false,
    /// `Cross-Origin-Embedder-Policy` and its -Report-Only twin.
    coep: ?[]const u8 = null,
    coep_report_only: ?[]const u8 = null,
    /// Step 4's environment: null when there is none (the embedder policy
    /// stays "unsafe-none"), else whether it is a secure context - "obtain
    /// an embedder policy" step 2 returns a new policy for a non-secure one.
    environment_secure: ?bool = null,
};

/// SRI §3.8's policy, projected onto the source and destination browsers
/// ship. Endpoint names are owned independently of the response's headers.
pub const IntegrityPolicy = struct {
    allocator: Allocator,
    inline_source: bool = true,
    block_script: bool = false,
    block_style: bool = false,
    endpoints: std.ArrayListUnmanaged([]const u8) = .empty,

    pub fn deinit(self: *IntegrityPolicy) void {
        const allocator = self.allocator;
        for (self.endpoints.items) |name| allocator.free(name);
        self.endpoints.deinit(allocator);
        allocator.destroy(self);
    }

    fn copyEndpoints(self: *IntegrityPolicy, names: []const []const u8) error{OutOfMemory}!void {
        try self.endpoints.ensureUnusedCapacity(self.allocator, names.len);
        for (names) |name| self.endpoints.appendAssumeCapacity(try self.allocator.dupe(u8, name));
    }

    fn clone(self: *const IntegrityPolicy, allocator: Allocator) error{OutOfMemory}!*IntegrityPolicy {
        const copy = try allocator.create(IntegrityPolicy);
        copy.* = .{ .allocator = allocator, .inline_source = self.inline_source, .block_script = self.block_script, .block_style = self.block_style };
        errdefer copy.deinit();
        try copy.copyEndpoints(self.endpoints.items);
        return copy;
    }

    fn fromHeader(allocator: Allocator, header: []const u8) error{OutOfMemory}!?*IntegrityPolicy {
        // Processing steps 1-2: a malformed dictionary invalidates the
        // whole field. Allocation failures remain failures.
        var dictionary = structured_fields.parseTokenListDictionary(allocator, header) catch |err| switch (err) {
            error.InvalidField => return null,
            error.OutOfMemory => return error.OutOfMemory,
        };
        defer dictionary.deinit(allocator);
        const result = try allocator.create(IntegrityPolicy);
        result.* = .{ .allocator = allocator };
        errdefer result.deinit();
        for (dictionary.members.items) |member| {
            // WebKit processIntegrityPolicy + Gecko ParseSources treat a
            // scalar as absent. Thus scalar sources keeps default inline,
            // whereas an empty inner list disables it (row 48 Q10).
            const tokens = member.tokens orelse continue;
            if (std.mem.eql(u8, member.key, "sources")) {
                // Step 3. Tokens are case-sensitive; ignore unknown ones.
                result.inline_source = contains(tokens, "inline");
            } else if (std.mem.eql(u8, member.key, "blocked-destinations")) {
                // Step 4.1-4.2: "script" and "style". "style" came with
                // w3c/webappsec-subresource-integrity PR #146 (2025-07-07),
                // which no browser ships by default yet (Gecko bug 1984960
                // and WebKit bug 295582 open; WPT updated): golden rule 2 as
                // refined 2026-10-17 takes a newer spec the browsers merely
                // lag. This reverses Codex row 48 Q10's "scripts only"
                // ruling (gr2audit D8). JSON is not a policy destination.
                result.block_script = contains(tokens, "script");
                result.block_style = contains(tokens, "style");
            } else if (std.mem.eql(u8, member.key, "endpoints")) {
                // Step 5. The projection skips non-token items, as Blink
                // and WebKit do, but validates all their RFC 9651 syntax.
                try result.copyEndpoints(tokens);
            }
        }
        return result;
    }

    fn contains(tokens: []const []const u8, expected: []const u8) bool {
        for (tokens) |token| if (std.mem.eql(u8, token, expected)) return true;
        return false;
    }
};

pub const Endpoint = struct {
    name: []u8,
    url: []const u8,
    failures: u64 = 0,
};

/// Native data only. Responses to an upload may mutate its endpoint's
/// failures or remove it while the containing policy remains read-only.
pub const Endpoints = struct {
    allocator: Allocator,
    items: std.ArrayListUnmanaged(Endpoint) = .empty,

    pub fn deinit(self: *Endpoints) void {
        const allocator = self.allocator;
        for (self.items.items) |endpoint| {
            allocator.free(endpoint.name);
            allocator.free(endpoint.url);
        }
        self.items.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn find(self: *Endpoints, name: []const u8) ?*Endpoint {
        for (self.items.items) |*endpoint| if (std.mem.eql(u8, endpoint.name, name)) return endpoint;
        return null;
    }

    pub fn remove(self: *Endpoints, name: []const u8, url: []const u8) void {
        for (self.items.items, 0..) |endpoint, index| {
            if (!std.mem.eql(u8, endpoint.name, name) or !std.mem.eql(u8, endpoint.url, url)) continue;
            const removed = self.items.orderedRemove(index);
            self.allocator.free(removed.name);
            self.allocator.free(removed.url);
            return;
        }
    }

    fn fromHeader(allocator: Allocator, response_url: []const u8, header: []const u8) error{OutOfMemory}!?*Endpoints {
        // Reporting §3.3 steps 1-3. Invalid structured fields are ignored
        // as a whole; allocation failures remain failures.
        if (!try mixed_content.isOriginAuthenticated(allocator, response_url)) return null;
        var parsed = structured_fields.parseDictionary(allocator, header) catch |err| switch (err) {
            error.InvalidField => return null,
            error.OutOfMemory => return error.OutOfMemory,
        };
        defer parsed.deinit(allocator);
        var base = basic_parser.parse(allocator, response_url, null) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return null,
        };
        defer base.deinit();
        const result = try allocator.create(Endpoints);
        result.* = .{ .allocator = allocator };
        errdefer result.deinit();
        // Steps 4-5: only String values resolve to trustworthy endpoints.
        for (parsed.members.items) |member| {
            const value = member.string orelse continue;
            var record = basic_parser.parse(allocator, value, &base) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => continue,
            };
            defer record.deinit();
            const url = url_serializer.serialize(allocator, &record, false) catch return error.OutOfMemory;
            var url_owned = true;
            defer if (url_owned) allocator.free(url);
            if (!try mixed_content.isOriginAuthenticated(allocator, url)) continue;
            const name = try allocator.dupe(u8, member.key);
            errdefer allocator.free(name);
            try result.items.append(allocator, .{ .name = name, .url = url });
            url_owned = false;
        }
        return result;
    }
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
    // 4. "Return a CSP list whose policies is policies and self-origin is
    // response's url's origin." Matching reads each policy's self-origin, so
    // each parsed policy takes a copy too.
    const origin = (try selfOriginOf(allocator, response.url)) orelse return;
    if (list.self_origin) |*previous| previous.deinit();
    list.self_origin = origin;
    for (list.policies.items[first..]) |*policy| {
        policy.self_origin = try csp.Origin.create(allocator, origin.scheme, origin.host, origin.port);
        policy.delivery_url = try allocator.dupe(u8, response.url);
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

test "a container from a response records the response URL's origin as its CSP list's self-origin, policies or none" {
    const allocator = std.testing.allocator;
    // A sandboxed frame's document has an opaque origin, but its CSP list's
    // self-origin is the response URL's: a <meta> policy's 'self' matches it.
    var container = try PolicyContainer.fromResponseHeaders(allocator, .{ .url = "http://web-platform.test:8000/a/b.html" });
    defer container.deinit();
    try std.testing.expectEqual(@as(usize, 0), container.csp_list.policies.items.len);
    const self_origin = container.csp_list.self_origin.?;
    try std.testing.expectEqualStrings("http", self_origin.scheme);
    try std.testing.expectEqualStrings("web-platform.test", self_origin.host);
    try std.testing.expectEqual(@as(?u16, 8000), self_origin.port);

    var copy = try container.clone(allocator);
    defer copy.deinit();
    try std.testing.expectEqualStrings("web-platform.test", copy.csp_list.self_origin.?.host);

    // A new container (no response) has none.
    var fresh = PolicyContainer.init(allocator);
    defer fresh.deinit();
    try std.testing.expect(fresh.csp_list.self_origin == null);
}
