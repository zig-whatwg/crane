//! Router Rules for Service Worker FetchEvent
//!
//! Static routing rules that can bypass the service worker for certain requests.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#dictdef-routerrule

const std = @import("std");
const Allocator = std.mem.Allocator;

/// URL pattern for router matching.
///
/// Simplified version - a full implementation would use URLPattern API.
pub const URLPattern = struct {
    /// Protocol pattern (e.g., "https").
    protocol: ?[]const u8 = null,

    /// Hostname pattern (e.g., "example.com", "*.example.com").
    hostname: ?[]const u8 = null,

    /// Port pattern.
    port: ?[]const u8 = null,

    /// Pathname pattern (e.g., "/api/*").
    pathname: ?[]const u8 = null,

    /// Search/query pattern.
    search: ?[]const u8 = null,

    /// Hash pattern.
    hash: ?[]const u8 = null,

    /// Check if this pattern matches a URL.
    ///
    /// Simplified matching - a real implementation would use full URLPattern spec.
    pub fn matches(self: *const URLPattern, url: []const u8) bool {
        // Very simplified matching
        if (self.pathname) |pattern| {
            if (std.mem.indexOf(u8, pattern, "*")) |_| {
                // Wildcard pattern - check prefix
                const prefix = pattern[0..std.mem.indexOf(u8, pattern, "*").?];
                if (!std.mem.startsWith(u8, url, prefix)) {
                    return false;
                }
            } else {
                // Exact match
                if (std.mem.indexOf(u8, url, pattern) == null) {
                    return false;
                }
            }
        }
        return true;
    }
};

/// Request condition for router matching.
pub const RequestCondition = struct {
    /// HTTP method to match (e.g., "GET", "POST").
    method: ?[]const u8 = null,

    /// Request mode to match.
    mode: ?RequestMode = null,

    /// Request destination to match.
    destination: ?RequestDestination = null,

    pub const RequestMode = enum {
        navigate,
        same_origin,
        no_cors,
        cors,
    };

    pub const RequestDestination = enum {
        document,
        embed,
        font,
        image,
        manifest,
        media,
        object,
        report,
        script,
        serviceworker,
        sharedworker,
        style,
        worker,
        xslt,
        audio,
        video,
        track,
        empty,
    };
};

/// Router condition - what requests to match.
pub const RouterCondition = union(enum) {
    /// Match by URL pattern.
    url_pattern: URLPattern,

    /// Match by request properties.
    request: RequestCondition,

    /// Match if any condition matches (OR).
    or_condition: []const RouterCondition,

    /// Match if condition does NOT match.
    not_condition: *const RouterCondition,

    /// Match running status of the service worker.
    running_status: RunningStatus,

    pub const RunningStatus = enum {
        running,
        not_running,
    };

    /// Evaluate this condition against a request.
    pub fn evaluate(self: *const RouterCondition, url: []const u8, method: []const u8) bool {
        return switch (self.*) {
            .url_pattern => |pattern| pattern.matches(url),
            .request => |req| {
                if (req.method) |m| {
                    if (!std.mem.eql(u8, method, m)) return false;
                }
                return true;
            },
            .or_condition => |conditions| {
                for (conditions) |cond| {
                    if (cond.evaluate(url, method)) return true;
                }
                return false;
            },
            .not_condition => |cond| !cond.evaluate(url, method),
            .running_status => true, // Simplified - would check SW running state
        };
    }
};

/// Cache source configuration.
pub const CacheSource = struct {
    /// Specific cache name to use (null = any cache).
    cache_name: ?[]const u8 = null,
};

/// Router source - where to get the response.
pub const RouterSource = union(enum) {
    /// Fetch from network directly (bypass SW).
    network: void,

    /// Fetch from cache.
    cache: CacheSource,

    /// Dispatch fetch event to service worker.
    fetch_event: void,

    /// Race network and fetch handler.
    race_network_and_fetch_handler: void,

    /// Get the source name for timing info.
    pub fn getName(self: *const RouterSource) []const u8 {
        return switch (self.*) {
            .network => "network",
            .cache => "cache",
            .fetch_event => "fetch-event",
            .race_network_and_fetch_handler => "race-network-and-fetch-handler",
        };
    }
};

/// Router rule - condition + source.
pub const RouterRule = struct {
    /// Condition that must match for this rule to apply.
    condition: RouterCondition,

    /// Source to use when condition matches.
    source: RouterSource,

    /// Evaluate this rule against a request.
    pub fn matches(self: *const RouterRule, url: []const u8, method: []const u8) bool {
        return self.condition.evaluate(url, method);
    }
};

/// Router for evaluating rules against requests.
pub const Router = struct {
    allocator: Allocator,

    /// List of router rules.
    rules: std.ArrayListUnmanaged(RouterRule),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .rules = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.rules.deinit(self.allocator);
    }

    /// Add a rule.
    pub fn addRule(self: *Self, rule: RouterRule) !void {
        try self.rules.append(self.allocator, rule);
    }

    /// Add multiple rules.
    pub fn addRules(self: *Self, rules: []const RouterRule) !void {
        for (rules) |rule| {
            try self.rules.append(self.allocator, rule);
        }
    }

    /// Evaluate rules and return the matching source.
    ///
    /// Returns the source from the first matching rule, or null if no rules match.
    pub fn evaluate(self: *const Self, url: []const u8, method: []const u8) ?RouterSource {
        for (self.rules.items) |rule| {
            if (rule.matches(url, method)) {
                return rule.source;
            }
        }
        return null;
    }

    /// Get the number of rules.
    pub fn count(self: *const Self) usize {
        return self.rules.items.len;
    }
};

// =============================================================================
// Tests
// =============================================================================

test "URLPattern.matches basic" {
    const pattern = URLPattern{
        .pathname = "/api/",
    };

    try std.testing.expect(pattern.matches("/api/users"));
    try std.testing.expect(pattern.matches("/api/"));
    try std.testing.expect(!pattern.matches("/other/path"));
}

test "URLPattern.matches wildcard" {
    const pattern = URLPattern{
        .pathname = "/static/*",
    };

    try std.testing.expect(pattern.matches("/static/image.png"));
    try std.testing.expect(pattern.matches("/static/css/style.css"));
    try std.testing.expect(!pattern.matches("/dynamic/page"));
}

test "RouterCondition.evaluate url_pattern" {
    const cond = RouterCondition{
        .url_pattern = .{ .pathname = "/api/" },
    };

    try std.testing.expect(cond.evaluate("/api/users", "GET"));
    try std.testing.expect(!cond.evaluate("/other", "GET"));
}

test "RouterCondition.evaluate request method" {
    const cond = RouterCondition{
        .request = .{ .method = "POST" },
    };

    try std.testing.expect(cond.evaluate("/any/path", "POST"));
    try std.testing.expect(!cond.evaluate("/any/path", "GET"));
}

test "RouterCondition.evaluate or_condition" {
    const conditions = [_]RouterCondition{
        .{ .url_pattern = .{ .pathname = "/api/" } },
        .{ .url_pattern = .{ .pathname = "/v2/" } },
    };

    const cond = RouterCondition{
        .or_condition = &conditions,
    };

    try std.testing.expect(cond.evaluate("/api/test", "GET"));
    try std.testing.expect(cond.evaluate("/v2/test", "GET"));
    try std.testing.expect(!cond.evaluate("/v3/test", "GET"));
}

test "RouterCondition.evaluate not_condition" {
    const inner = RouterCondition{
        .url_pattern = .{ .pathname = "/api/" },
    };

    const cond = RouterCondition{
        .not_condition = &inner,
    };

    try std.testing.expect(!cond.evaluate("/api/test", "GET"));
    try std.testing.expect(cond.evaluate("/other/test", "GET"));
}

test "RouterRule.matches" {
    const rule = RouterRule{
        .condition = .{ .url_pattern = .{ .pathname = "/static/*" } },
        .source = .network,
    };

    try std.testing.expect(rule.matches("/static/image.png", "GET"));
    try std.testing.expect(!rule.matches("/api/data", "GET"));
}

test "Router.evaluate" {
    const allocator = std.testing.allocator;

    var router_inst = Router.init(allocator);
    defer router_inst.deinit();

    try router_inst.addRule(.{
        .condition = .{ .url_pattern = .{ .pathname = "/static/*" } },
        .source = .network,
    });

    try router_inst.addRule(.{
        .condition = .{ .url_pattern = .{ .pathname = "/api/*" } },
        .source = .fetch_event,
    });

    // Static files go to network
    const static_source = router_inst.evaluate("/static/image.png", "GET");
    try std.testing.expect(static_source != null);
    try std.testing.expectEqualStrings("network", static_source.?.getName());

    // API goes to fetch event
    const api_source = router_inst.evaluate("/api/users", "GET");
    try std.testing.expect(api_source != null);
    try std.testing.expectEqualStrings("fetch-event", api_source.?.getName());

    // Unknown path - no match
    const unknown_source = router_inst.evaluate("/other/path", "GET");
    try std.testing.expect(unknown_source == null);
}

test "RouterSource.getName" {
    try std.testing.expectEqualStrings("network", (RouterSource{ .network = {} }).getName());
    try std.testing.expectEqualStrings("cache", (RouterSource{ .cache = .{} }).getName());
    try std.testing.expectEqualStrings("fetch-event", (RouterSource{ .fetch_event = {} }).getName());
}
