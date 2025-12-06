//! Cookie Change Event Dispatch
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! This module implements the "process cookie changes" algorithm that
//! dispatches CookieChangeEvent to windows and ExtendableCookieChangeEvent
//! to service workers when cookies change.

const std = @import("std");
const CookieChange = @import("change_observer.zig").CookieChange;
const ChangeType = @import("change_observer.zig").ChangeType;
const CookieChangeObserver = @import("change_observer.zig").CookieChangeObserver;
const CookieListItem = @import("cookie.zig").CookieListItem;
const domain_matching = @import("domain_matching.zig");

/// A pending change notification
pub const ChangeNotification = struct {
    /// The URL host to notify
    url_host: []const u8,
    /// The URL path
    url_path: []const u8,
    /// The changes to notify about
    changes: []const CookieChange,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.url_host);
        self.allocator.free(self.url_path);
        // Note: changes are not owned by this struct
        self.* = undefined;
    }
};

/// Result of processing changes for a target
pub const ProcessResult = struct {
    /// Changed cookies list
    changed: std.ArrayListUnmanaged(CookieListItem),
    /// Deleted cookies list
    deleted: std.ArrayListUnmanaged(CookieListItem),
    /// Allocator for cleanup
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .changed = .{},
            .deleted = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.changed.items) |*item| item.deinit();
        self.changed.deinit(self.allocator);
        for (self.deleted.items) |*item| item.deinit();
        self.deleted.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn isEmpty(self: *const Self) bool {
        return self.changed.items.len == 0 and self.deleted.items.len == 0;
    }
};

/// "process cookie changes" algorithm
/// https://cookiestore.spec.whatwg.org/#process-cookie-changes
///
/// This algorithm is triggered when cookies are modified and dispatches
/// events to interested parties (windows and service workers).
pub fn processCookieChanges(
    allocator: std.mem.Allocator,
    changes: []const CookieChange,
    target_url_host: []const u8,
    target_url_path: []const u8,
) !ProcessResult {
    var result = ProcessResult.init(allocator);
    errdefer result.deinit();

    // Step 1: Let observable changes be an empty list
    // Step 2: For each change in changes:
    for (changes) |change| {
        // Step 2.1: If change's cookie is HttpOnly, continue
        if (change.cookie.http_only) {
            continue;
        }

        // Step 2.2: Check domain matching
        const cookie_domain = change.cookie.domain orelse target_url_host;
        if (!domain_matching.domainMatches(target_url_host, cookie_domain)) {
            continue;
        }

        // Step 2.3: Check path matching
        if (!domain_matching.pathMatches(target_url_path, change.cookie.path)) {
            continue;
        }

        // Step 3: Create CookieListItem for this change
        const item = try CookieListItem.fromCookie(allocator, change.cookie);

        // Step 4: Add to appropriate list based on change type
        if (change.change_type == .changed) {
            try result.changed.append(allocator, item);
        } else {
            // For deleted cookies, value should be empty per spec
            allocator.free(item.value);
            var deleted_item = item;
            deleted_item.value = try allocator.dupe(u8, "");
            try result.deleted.append(allocator, deleted_item);
        }
    }

    return result;
}

/// Check if changes match a subscription
/// https://cookiestore.spec.whatwg.org/#subscription-matching
pub fn matchesSubscription(
    change: CookieChange,
    subscription_name: ?[]const u8,
    subscription_url_host: ?[]const u8,
    subscription_url_path: ?[]const u8,
    default_url_host: []const u8,
    default_url_path: []const u8,
) bool {
    // HttpOnly cookies are never matched
    if (change.cookie.http_only) {
        return false;
    }

    // Check name match (null = match all)
    if (subscription_name) |name| {
        if (!std.mem.eql(u8, change.cookie.name, name)) {
            return false;
        }
    }

    // Check URL match
    const url_host = subscription_url_host orelse default_url_host;
    const url_path = subscription_url_path orelse default_url_path;

    // Check domain matching
    const cookie_domain = change.cookie.domain orelse url_host;
    if (!domain_matching.domainMatches(url_host, cookie_domain)) {
        return false;
    }

    // Check path matching
    if (!domain_matching.pathMatches(url_path, change.cookie.path)) {
        return false;
    }

    return true;
}

/// Filter changes based on subscriptions
/// Returns only changes that match at least one subscription
pub fn filterChangesForSubscriptions(
    allocator: std.mem.Allocator,
    changes: []const CookieChange,
    subscriptions: []const Subscription,
    default_url_host: []const u8,
    default_url_path: []const u8,
) !std.ArrayListUnmanaged(CookieChange) {
    var result = std.ArrayListUnmanaged(CookieChange){};
    errdefer {
        for (result.items) |*c| c.deinit();
        result.deinit(allocator);
    }

    for (changes) |change| {
        var matches_any = false;

        for (subscriptions) |sub| {
            if (matchesSubscription(
                change,
                sub.name,
                sub.url_host,
                sub.url_path,
                default_url_host,
                default_url_path,
            )) {
                matches_any = true;
                break;
            }
        }

        if (matches_any) {
            try result.append(allocator, try change.clone(allocator));
        }
    }

    return result;
}

/// A subscription for cookie changes (mirrors CookieStoreManager.CookieSubscription)
pub const Subscription = struct {
    name: ?[]const u8,
    url_host: ?[]const u8,
    url_path: ?[]const u8,
};

// ============================================================================
// Tests
// ============================================================================

const Cookie = @import("cookie.zig").Cookie;

test "processCookieChanges - basic" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "session", "value123");
    defer cookie.deinit();
    try cookie.setDomain("example.com");

    var changes = [_]CookieChange{
        CookieChange{ .change_type = .changed, .cookie = cookie },
    };

    var result = try processCookieChanges(allocator, &changes, "example.com", "/");
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 1), result.changed.items.len);
    try std.testing.expectEqual(@as(usize, 0), result.deleted.items.len);
    try std.testing.expectEqualStrings("session", result.changed.items[0].name);
}

test "processCookieChanges - HttpOnly filtered" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "session", "value123");
    defer cookie.deinit();
    cookie.http_only = true;

    var changes = [_]CookieChange{
        CookieChange{ .change_type = .changed, .cookie = cookie },
    };

    var result = try processCookieChanges(allocator, &changes, "example.com", "/");
    defer result.deinit();

    try std.testing.expect(result.isEmpty());
}

test "processCookieChanges - domain mismatch" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "session", "value123");
    defer cookie.deinit();
    try cookie.setDomain("other.com");

    var changes = [_]CookieChange{
        CookieChange{ .change_type = .changed, .cookie = cookie },
    };

    var result = try processCookieChanges(allocator, &changes, "example.com", "/");
    defer result.deinit();

    try std.testing.expect(result.isEmpty());
}

test "matchesSubscription - name filter" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "session", "value");
    defer cookie.deinit();

    const change = CookieChange{ .change_type = .changed, .cookie = cookie };

    // Matching name
    try std.testing.expect(matchesSubscription(
        change,
        "session",
        null,
        null,
        "example.com",
        "/",
    ));

    // Non-matching name
    try std.testing.expect(!matchesSubscription(
        change,
        "other",
        null,
        null,
        "example.com",
        "/",
    ));

    // No name filter (matches all)
    try std.testing.expect(matchesSubscription(
        change,
        null,
        null,
        null,
        "example.com",
        "/",
    ));
}
