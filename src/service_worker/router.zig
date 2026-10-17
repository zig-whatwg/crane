//! Static routing (Service Workers 4.5.1 InstallEvent.addRoutes and Appendix
//! A's router algorithms), engine-free: a service worker's list of router
//! rules, as addRoutes() converts them (add_routes.zig, in the worker's
//! realm), the checks made on them - Verify Router Condition's structural
//! steps, Check Router Registration Limit - and Get Router Source, which
//! Handle Fetch runs on the FETCHING thread for an active worker that has
//! rules (manager.handleFetch, step 13).
//!
//! A condition's URL pattern is opaque here: the realm side compiled it (Parse
//! URL Pattern, in the worker's realm) and owns its freeing (`PatternOps`),
//! and matching it is asked of a `Matcher` the caller supplies - production
//! runs the urlpattern module's match in a realm of the fetching thread
//! (realm.zig), tests answer as they please. So the lists cross threads as
//! plain data: a `Rules` is immutable once it is a worker's, and counted
//! (atomically) by whoever evaluates it outside the manager's lock.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#dom-installevent-addroutes
//! Spec: https://w3c.github.io/ServiceWorker/#get-router-source

const std = @import("std");
const Allocator = std.mem.Allocator;
const fetch = @import("fetch");

pub const RequestMode = fetch.internal.RequestMode;
pub const Destination = fetch.internal.Destination;

/// RunningStatus.
pub const RunningStatus = enum { running, not_running };

/// A RouterCondition: each member it has must match (Match Router Condition
/// step 3), except `or` and `not`, which Verify Router Condition keeps apart
/// from every other member.
pub const Condition = struct {
    /// urlPattern, Parse URL Pattern's result. OWNED through `PatternOps`.
    url_pattern: ?*anyopaque = null,
    /// requestMethod, as given (Match normalizes it). OWNED.
    method: ?[]u8 = null,
    mode: ?RequestMode = null,
    /// requestDestination, as the IDL spells it ("" included; "text" is one
    /// no request of Crane's has). OWNED.
    destination: ?[]u8 = null,
    running_status: ?RunningStatus = null,
    /// _or. OWNED, each and the slice.
    any_of: ?[]Condition = null,
    /// not. OWNED.
    not: ?*Condition = null,

    pub fn deinit(self: *Condition, allocator: Allocator, ops: PatternOps) void {
        if (self.url_pattern) |pattern| ops.free(pattern, allocator);
        if (self.method) |m| allocator.free(m);
        if (self.destination) |d| allocator.free(d);
        if (self.any_of) |list| {
            for (list) |*c| c.deinit(allocator, ops);
            allocator.free(list);
        }
        if (self.not) |c| {
            c.deinit(allocator, ops);
            allocator.destroy(c);
        }
        self.* = .{};
    }
};

/// RouterSource: a RouterSourceEnum, or a RouterSourceDict - whose cacheName
/// makes it a cache source with that name.
pub const Source = union(enum) {
    network,
    fetch_event,
    /// "cache", or {cacheName}: the name (OWNED), or null for any cache.
    cache: ?[]u8,
    race_network_and_fetch_handler,

    pub fn deinit(self: *Source, allocator: Allocator) void {
        switch (self.*) {
            .cache => |cache_name| if (cache_name) |n| allocator.free(n),
            else => {},
        }
        self.* = .network;
    }

    /// The RouterSourceEnum value's name (a timing info's router source).
    pub fn name(self: Source) []const u8 {
        return switch (self) {
            .network => "network",
            .fetch_event => "fetch-event",
            .cache => "cache",
            .race_network_and_fetch_handler => "race-network-and-fetch-handler",
        };
    }
};

/// A RouterRule.
pub const Rule = struct {
    condition: Condition,
    source: Source,

    pub fn deinit(self: *Rule, allocator: Allocator, ops: PatternOps) void {
        self.condition.deinit(allocator, ops);
        self.source.deinit(allocator);
    }
};

/// How a compiled URL pattern is freed (the realm side's).
pub const PatternOps = struct {
    free: *const fn (pattern: *anyopaque, allocator: Allocator) void,
};

/// A service worker's list of router rules, once set (addRoutes step 9.4):
/// immutable, shared by the worker's record and whoever evaluates it
/// outside the lock. Thread-safe counting; the allocator must be too (the
/// Browser's).
pub const Rules = struct {
    allocator: Allocator,
    refs: std.atomic.Value(u32) = .init(1),
    rules: []Rule,
    ops: PatternOps,

    /// A Rules holding `rules` (taken, made with `allocator`).
    pub fn create(allocator: Allocator, rules: []Rule, ops: PatternOps) Allocator.Error!*Rules {
        const self = try allocator.create(Rules);
        self.* = .{ .allocator = allocator, .rules = rules, .ops = ops };
        return self;
    }

    pub fn retain(self: *Rules) *Rules {
        _ = self.refs.fetchAdd(1, .monotonic);
        return self;
    }

    pub fn release(self: *Rules) void {
        if (self.refs.fetchSub(1, .acq_rel) != 1) return;
        freeRules(self.allocator, self.rules, self.ops);
        self.allocator.destroy(self);
    }

    /// The rules themselves (OWNED by the caller from here, the slice
    /// included), this list gone - when nothing else holds it; null (and
    /// nothing changed) when something does.
    pub fn unwrap(self: *Rules) ?[]Rule {
        if (self.refs.load(.acquire) != 1) return null;
        const rules = self.rules;
        self.allocator.destroy(self);
        return rules;
    }
};

/// Free a list of rules and the slice.
pub fn freeRules(allocator: Allocator, rules: []Rule, ops: PatternOps) void {
    for (rules) |*rule| rule.deinit(allocator, ops);
    allocator.free(rules);
}

// ============================================================================
// Verify Router Condition (its steps that need no realm)
// ============================================================================

/// Verify Router Condition for `condition`, whose url pattern - if any - was
/// already parsed without a throw and has no regexp groups (steps 2.2-2.3,
/// the realm side's): steps 1 and 3-9.
pub fn verifyCondition(condition: *const Condition) bool {
    // 1.
    var has_condition = false;
    // 2.4.
    if (condition.url_pattern != null) has_condition = true;
    // 3. requestMethod: a method that is not forbidden.
    if (condition.method) |method| {
        if (!fetch.internal.isValidHeaderName(method)) return false;
        if (fetch.cors.isForbiddenMethod(method)) return false;
        has_condition = true;
    }
    // 4-6.
    if (condition.mode != null) has_condition = true;
    if (condition.destination != null) has_condition = true;
    if (condition.running_status != null) has_condition = true;
    // 7. _or: exclusive with the rest; each of its conditions verified.
    if (condition.any_of) |list| {
        if (has_condition) return false;
        for (list) |*c| if (!verifyCondition(c)) return false;
        has_condition = true;
    }
    // 8. not: exclusive too, verified.
    if (condition.not) |c| {
        if (has_condition) return false;
        if (!verifyCondition(c)) return false;
        has_condition = true;
    }
    // 9.
    return has_condition;
}

// ============================================================================
// Check Router Registration Limit, Count Router Inner Conditions
// ============================================================================

/// The total number of conditions, nested ones counted.
pub const max_conditions: u32 = 1024;
/// How deep `or` and `not` may nest.
pub const max_depth: u32 = 10;

const CountResult = struct {
    condition_count: u32,
    quota_exceeded: bool,
};

/// Check Router Registration Limit for `rules`.
pub fn checkRegistrationLimit(rules: []const Rule) bool {
    // 1-3.
    var result: CountResult = .{ .condition_count = max_conditions, .quota_exceeded = false };
    // 4.
    for (rules) |*rule| {
        result = countInnerConditions(&rule.condition, result, max_depth);
        if (result.quota_exceeded) return false;
    }
    // 5.
    return true;
}

/// Count Router Inner Conditions.
fn countInnerConditions(condition: *const Condition, start: CountResult, depth_in: u32) CountResult {
    var result = start;
    var depth = depth_in;
    // 1.
    result.condition_count -|= 1;
    // 2.
    if (result.condition_count == 0 or depth == 0) {
        result.quota_exceeded = true;
        return result;
    }
    // 3.
    if (condition.any_of) |list| {
        depth -= 1;
        for (list) |*c| {
            result = countInnerConditions(c, result, depth);
            if (result.quota_exceeded) return result;
        }
    } else if (condition.not) |c| {
        // 4.
        depth -= 1;
        result = countInnerConditions(c, result, depth);
        if (result.quota_exceeded) return result;
    }
    // 5.
    return result;
}

// ============================================================================
// Match Router Condition, Get Router Source
// ============================================================================

/// What Match Router Condition reads of a request. BORROWED.
pub const RequestFacts = struct {
    /// Its URL, serialized.
    url: []const u8,
    method: []const u8,
    mode: RequestMode,
    destination: Destination,
};

/// How a condition's URL pattern is matched against a URL: the urlpattern
/// module's "match" in a realm of the calling thread (production), anything
/// in a test. Null: no URL pattern matches.
pub const Matcher = struct {
    context: ?*anyopaque = null,
    matches: *const fn (context: ?*anyopaque, pattern: *anyopaque, url: []const u8) bool,
};

/// Match Router Condition for `condition`, the service worker being
/// `running` or not, and the request `request`.
pub fn matchCondition(condition: *const Condition, running: bool, request: RequestFacts, matcher: ?Matcher) bool {
    // 1. or: any of them.
    if (condition.any_of) |list| {
        for (list) |*c| if (matchCondition(c, running, request, matcher)) return true;
        return false;
    }
    // 2. not.
    if (condition.not) |c| return !matchCondition(c, running, request, matcher);
    // 3.1. urlPattern: match it against the request's URL.
    if (condition.url_pattern) |pattern| {
        const m = matcher orelse return false;
        if (!m.matches(m.context, pattern, request.url)) return false;
    }
    // 3.2. requestMethod, normalized: the request's method.
    if (condition.method) |method| {
        if (!methodMatches(method, request.method)) return false;
    }
    // 3.3-3.4. requestMode, requestDestination.
    if (condition.mode) |mode| if (mode != request.mode) return false;
    if (condition.destination) |destination| if (!std.mem.eql(u8, destination, destinationName(request.destination))) return false;
    // 3.5. runningStatus.
    if (condition.running_status) |status| switch (status) {
        .running => if (!running) return false,
        .not_running => if (running) return false,
    };
    // 3.6.
    return true;
}

/// A request destination as the IDL spells it.
fn destinationName(destination: Destination) []const u8 {
    return switch (destination) {
        .empty => "",
        else => @tagName(destination),
    };
}

/// Fetch "normalize" a method - DELETE, GET, HEAD, OPTIONS, POST and PUT
/// byte-uppercased - then compare it with the request's (already normalized)
/// method.
fn methodMatches(method: []const u8, request_method: []const u8) bool {
    const normalized = [_][]const u8{ "DELETE", "GET", "HEAD", "OPTIONS", "POST", "PUT" };
    for (normalized) |name| {
        if (std.ascii.eqlIgnoreCase(method, name)) return std.mem.eql(u8, name, request_method);
    }
    return std.mem.eql(u8, method, request_method);
}

/// Get Router Source: the source of the first of `rules` whose condition
/// matches, or null.
pub fn getRouterSource(rules: []const Rule, running: bool, request: RequestFacts, matcher: ?Matcher) ?*const Source {
    for (rules) |*rule| {
        if (matchCondition(&rule.condition, running, request, matcher)) return &rule.source;
    }
    return null;
}
