//! Cookie Change Observer and Notification System
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! This module implements the cookie change notification system that
//! powers CookieChangeEvent dispatching to windows and service workers.

const std = @import("std");
const Cookie = @import("cookie.zig").Cookie;
const CookieListItem = @import("cookie.zig").CookieListItem;
const domain_matching = @import("domain_matching.zig");

/// Type of cookie change
pub const ChangeType = enum {
    /// Cookie was added or updated
    changed,
    /// Cookie was deleted or expired
    deleted,
};

/// Represents a single cookie change
pub const CookieChange = struct {
    /// Type of change
    change_type: ChangeType,

    /// The cookie that changed (for changed events, the new value)
    cookie: Cookie,

    /// Allocator for cleanup
    allocator: ?std.mem.Allocator = null,

    const Self = @This();

    /// Create a change record
    pub fn init(allocator: std.mem.Allocator, change_type: ChangeType, cookie: Cookie) !Self {
        return Self{
            .change_type = change_type,
            .cookie = try cookie.clone(allocator),
            .allocator = allocator,
        };
    }

    /// Free resources
    pub fn deinit(self: *Self) void {
        if (self.allocator != null) {
            self.cookie.deinit();
        }
        self.* = undefined;
    }

    /// Clone the change record
    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        return Self{
            .change_type = self.change_type,
            .cookie = try self.cookie.clone(allocator),
            .allocator = allocator,
        };
    }
};

/// Listener callback function type
pub const ListenerFn = *const fn (changes: []const CookieChange, context: ?*anyopaque) void;

/// A registered listener
const Listener = struct {
    /// Callback function
    callback: ListenerFn,

    /// User context
    context: ?*anyopaque,

    /// URL to filter by (null = all)
    filter_url_host: ?[]const u8,
    filter_url_path: ?[]const u8,

    /// Name to filter by (null = all)
    filter_name: ?[]const u8,

    /// Allocator for owned strings
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        if (self.filter_url_host) |h| self.allocator.free(h);
        if (self.filter_url_path) |p| self.allocator.free(p);
        if (self.filter_name) |n| self.allocator.free(n);
        self.* = undefined;
    }
};

/// Cookie change observer that manages listeners and dispatches events
pub const CookieChangeObserver = struct {
    /// Registered listeners
    listeners: std.ArrayListUnmanaged(Listener),

    /// Pending changes (batched before dispatch)
    pending_changes: std.ArrayListUnmanaged(CookieChange),

    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create a new observer
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .listeners = .{},
            .pending_changes = .{},
            .allocator = allocator,
        };
    }

    /// Free all resources
    pub fn deinit(self: *Self) void {
        for (self.listeners.items) |*listener| {
            listener.deinit();
        }
        self.listeners.deinit(self.allocator);

        for (self.pending_changes.items) |*change| {
            change.deinit();
        }
        self.pending_changes.deinit(self.allocator);
    }

    /// Add a listener
    pub fn addListener(
        self: *Self,
        callback: ListenerFn,
        context: ?*anyopaque,
        filter_url_host: ?[]const u8,
        filter_url_path: ?[]const u8,
        filter_name: ?[]const u8,
    ) !void {
        const listener = Listener{
            .callback = callback,
            .context = context,
            .filter_url_host = if (filter_url_host) |h| try self.allocator.dupe(u8, h) else null,
            .filter_url_path = if (filter_url_path) |p| try self.allocator.dupe(u8, p) else null,
            .filter_name = if (filter_name) |n| try self.allocator.dupe(u8, n) else null,
            .allocator = self.allocator,
        };

        try self.listeners.append(self.allocator, listener);
    }

    /// Remove a listener by callback
    pub fn removeListener(self: *Self, callback: ListenerFn, context: ?*anyopaque) void {
        var i: usize = 0;
        while (i < self.listeners.items.len) {
            const listener = &self.listeners.items[i];
            if (listener.callback == callback and listener.context == context) {
                var removed = self.listeners.orderedRemove(i);
                removed.deinit();
            } else {
                i += 1;
            }
        }
    }

    /// Record a cookie change
    pub fn recordChange(self: *Self, change_type: ChangeType, cookie: Cookie) !void {
        // Don't record HttpOnly cookie changes (not observable via JS)
        if (cookie.http_only) {
            return;
        }

        const change = try CookieChange.init(self.allocator, change_type, cookie);
        try self.pending_changes.append(self.allocator, change);
    }

    /// Flush pending changes to listeners
    pub fn flush(self: *Self) void {
        if (self.pending_changes.items.len == 0) {
            return;
        }

        // Dispatch to each listener
        for (self.listeners.items) |listener| {
            // Filter changes for this listener
            var filtered = std.ArrayListUnmanaged(CookieChange){};
            defer filtered.deinit(self.allocator);

            for (self.pending_changes.items) |change| {
                if (self.changeMatchesFilter(change, listener)) {
                    // Just reference, don't clone for dispatch
                    filtered.append(self.allocator, change) catch continue;
                }
            }

            if (filtered.items.len > 0) {
                listener.callback(filtered.items, listener.context);
            }
        }

        // Clear pending changes
        for (self.pending_changes.items) |*change| {
            change.deinit();
        }
        self.pending_changes.clearRetainingCapacity();
    }

    /// Get observable changes for a URL
    /// https://cookiestore.spec.whatwg.org/#observable-changes
    pub fn getObservableChanges(
        self: *Self,
        allocator: std.mem.Allocator,
        url_host: []const u8,
        url_path: []const u8,
    ) !std.ArrayListUnmanaged(CookieChange) {
        var result = std.ArrayListUnmanaged(CookieChange){};
        errdefer {
            for (result.items) |*c| c.deinit();
            result.deinit(allocator);
        }

        for (self.pending_changes.items) |change| {
            // HttpOnly cookies are never observable
            if (change.cookie.http_only) {
                continue;
            }

            // Check domain matching
            const cookie_domain = change.cookie.domain orelse url_host;
            if (!domain_matching.domainMatches(url_host, cookie_domain)) {
                continue;
            }

            // Check path matching
            if (!domain_matching.pathMatches(url_path, change.cookie.path)) {
                continue;
            }

            try result.append(allocator, try change.clone(allocator));
        }

        return result;
    }

    /// Check if a change matches a listener's filters
    fn changeMatchesFilter(self: *Self, change: CookieChange, listener: Listener) bool {
        _ = self;

        // HttpOnly cookies are never observable
        if (change.cookie.http_only) {
            return false;
        }

        // Check name filter
        if (listener.filter_name) |name| {
            if (!std.mem.eql(u8, change.cookie.name, name)) {
                return false;
            }
        }

        // Check URL filter
        if (listener.filter_url_host) |host| {
            const cookie_domain = change.cookie.domain orelse host;
            if (!domain_matching.domainMatches(host, cookie_domain)) {
                return false;
            }
        }

        if (listener.filter_url_path) |path| {
            if (!domain_matching.pathMatches(path, change.cookie.path)) {
                return false;
            }
        }

        return true;
    }

    /// Prepare changed and deleted lists for events
    /// https://cookiestore.spec.whatwg.org/#prepare-lists
    pub fn prepareLists(
        self: *Self,
        allocator: std.mem.Allocator,
        changes: []const CookieChange,
    ) !struct { changed: std.ArrayListUnmanaged(CookieListItem), deleted: std.ArrayListUnmanaged(CookieListItem) } {
        _ = self;

        var changed = std.ArrayListUnmanaged(CookieListItem){};
        errdefer {
            for (changed.items) |*item| item.deinit();
            changed.deinit(allocator);
        }

        var deleted = std.ArrayListUnmanaged(CookieListItem){};
        errdefer {
            for (deleted.items) |*item| item.deinit();
            deleted.deinit(allocator);
        }

        for (changes) |change| {
            var item = try CookieListItem.fromCookie(allocator, change.cookie);

            if (change.change_type == .changed) {
                try changed.append(allocator, item);
            } else {
                // For deleted cookies, value is undefined per spec
                // We set it to empty string
                allocator.free(item.value);
                item.value = try allocator.dupe(u8, "");
                try deleted.append(allocator, item);
            }
        }

        return .{ .changed = changed, .deleted = deleted };
    }
};

// ============================================================================
// Tests
// ============================================================================

var test_callback_called: bool = false;
var test_callback_count: usize = 0;

fn testCallback(changes: []const CookieChange, context: ?*anyopaque) void {
    _ = context;
    test_callback_called = true;
    test_callback_count = changes.len;
}

test "CookieChange - init and deinit" {
    const allocator = std.testing.allocator;

    var cookie = try Cookie.init(allocator, "test", "value");
    defer cookie.deinit();

    var change = try CookieChange.init(allocator, .changed, cookie);
    defer change.deinit();

    try std.testing.expectEqual(ChangeType.changed, change.change_type);
    try std.testing.expectEqualStrings("test", change.cookie.name);
}

test "CookieChangeObserver - addListener and recordChange" {
    const allocator = std.testing.allocator;

    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    // Reset test state
    test_callback_called = false;
    test_callback_count = 0;

    // Add listener
    try observer.addListener(testCallback, null, null, null, null);

    // Record a change
    var cookie = try Cookie.init(allocator, "session", "abc");
    defer cookie.deinit();
    try cookie.setDomain("example.com");

    try observer.recordChange(.changed, cookie);
    try std.testing.expectEqual(@as(usize, 1), observer.pending_changes.items.len);

    // Flush
    observer.flush();
    try std.testing.expect(test_callback_called);
    try std.testing.expectEqual(@as(usize, 1), test_callback_count);
    try std.testing.expectEqual(@as(usize, 0), observer.pending_changes.items.len);
}

test "CookieChangeObserver - HttpOnly not recorded" {
    const allocator = std.testing.allocator;

    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    var cookie = try Cookie.init(allocator, "session", "secret");
    defer cookie.deinit();
    cookie.http_only = true;

    try observer.recordChange(.changed, cookie);

    // HttpOnly cookies should not be recorded
    try std.testing.expectEqual(@as(usize, 0), observer.pending_changes.items.len);
}

test "CookieChangeObserver - name filter" {
    const allocator = std.testing.allocator;

    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    test_callback_called = false;
    test_callback_count = 0;

    // Add listener with name filter
    try observer.addListener(testCallback, null, null, null, "target");

    // Record matching cookie
    var cookie1 = try Cookie.init(allocator, "target", "value1");
    defer cookie1.deinit();
    try observer.recordChange(.changed, cookie1);

    // Record non-matching cookie
    var cookie2 = try Cookie.init(allocator, "other", "value2");
    defer cookie2.deinit();
    try observer.recordChange(.changed, cookie2);

    observer.flush();

    // Only one should match
    try std.testing.expect(test_callback_called);
    try std.testing.expectEqual(@as(usize, 1), test_callback_count);
}

test "CookieChangeObserver - getObservableChanges" {
    const allocator = std.testing.allocator;

    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    // Record changes
    var cookie1 = try Cookie.init(allocator, "a", "1");
    defer cookie1.deinit();
    try cookie1.setDomain("example.com");
    try observer.recordChange(.changed, cookie1);

    var cookie2 = try Cookie.init(allocator, "b", "2");
    defer cookie2.deinit();
    try cookie2.setDomain("other.com");
    try observer.recordChange(.changed, cookie2);

    // Get observable changes for example.com
    var changes = try observer.getObservableChanges(allocator, "example.com", "/");
    defer {
        for (changes.items) |*c| c.deinit();
        changes.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), changes.items.len);
    try std.testing.expectEqualStrings("a", changes.items[0].cookie.name);
}

test "CookieChangeObserver - prepareLists" {
    const allocator = std.testing.allocator;

    var observer = CookieChangeObserver.init(allocator);
    defer observer.deinit();

    var changes_arr = [_]CookieChange{
        blk: {
            const c = try Cookie.init(allocator, "new", "value");
            break :blk CookieChange{ .change_type = .changed, .cookie = c };
        },
        blk: {
            const c = try Cookie.init(allocator, "old", "gone");
            break :blk CookieChange{ .change_type = .deleted, .cookie = c };
        },
    };
    defer {
        for (&changes_arr) |*c| {
            c.cookie.deinit();
        }
    }

    var lists = try observer.prepareLists(allocator, &changes_arr);
    defer {
        for (lists.changed.items) |*item| item.deinit();
        lists.changed.deinit(allocator);
        for (lists.deleted.items) |*item| item.deinit();
        lists.deleted.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), lists.changed.items.len);
    try std.testing.expectEqual(@as(usize, 1), lists.deleted.items.len);
    try std.testing.expectEqualStrings("new", lists.changed.items[0].name);
    try std.testing.expectEqualStrings("old", lists.deleted.items[0].name);
}
