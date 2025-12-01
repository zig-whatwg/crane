//! CookieChangeEvent Implementation
//!
//! Implements the CookieChangeEvent interface from the Cookie Store API.
//! Reference: https://cookiestore.spec.whatwg.org/#CookieChangeEvent
//!
//! This event is fired when cookies are changed via the CookieStore API.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// CookieListItem represents a cookie in change events
/// Mirrors the structure from cookie_store.zig
pub const CookieListItem = struct {
    name: []const u8,
    value: []const u8,
    domain: ?[]const u8 = null,
    path: []const u8 = "/",
    expires: ?i64 = null,
    secure: bool = false,
    sameSite: SameSite = .strict,
    partitioned: bool = false,

    allocator: Allocator,

    pub const SameSite = enum { strict, lax, none };

    pub fn deinit(self: *CookieListItem) void {
        self.allocator.free(self.name);
        self.allocator.free(self.value);
        if (self.domain) |d| self.allocator.free(d);
        self.allocator.free(self.path);
    }

    pub fn clone(self: CookieListItem, allocator: Allocator) !CookieListItem {
        return CookieListItem{
            .name = try allocator.dupe(u8, self.name),
            .value = try allocator.dupe(u8, self.value),
            .domain = if (self.domain) |d| try allocator.dupe(u8, d) else null,
            .path = try allocator.dupe(u8, self.path),
            .expires = self.expires,
            .secure = self.secure,
            .sameSite = self.sameSite,
            .partitioned = self.partitioned,
            .allocator = allocator,
        };
    }
};

/// Initialization dictionary for CookieChangeEvent
pub const CookieChangeEventInit = struct {
    // EventInit fields
    bubbles: bool = false,
    cancelable: bool = false,
    composed: bool = false,

    // CookieChangeEventInit fields
    changed: []const CookieListItem = &[_]CookieListItem{},
    deleted: []const CookieListItem = &[_]CookieListItem{},
};

/// CookieChangeEvent - fired when cookies change
/// https://cookiestore.spec.whatwg.org/#CookieChangeEvent
pub const CookieChangeEvent = struct {
    /// Event type (always "change" for CookieChangeEvent)
    event_type: []const u8,

    /// Cookies that were added or modified
    changed: []CookieListItem,

    /// Cookies that were deleted
    deleted: []CookieListItem,

    /// Whether the event bubbles
    bubbles: bool,

    /// Whether the event is cancelable
    cancelable: bool,

    /// Whether the event is composed
    composed: bool,

    /// Event target (set during dispatch)
    target: ?*anyopaque,

    /// Whether propagation should stop
    stop_propagation_flag: bool,

    /// Whether immediate propagation should stop
    stop_immediate_propagation_flag: bool,

    /// Whether default was prevented
    canceled_flag: bool,

    /// Dispatch flag
    dispatch_flag: bool,

    /// Initialized flag
    initialized_flag: bool,

    /// Allocator for cleanup
    allocator: Allocator,

    const Self = @This();

    /// Create a new CookieChangeEvent
    pub fn init(
        allocator: Allocator,
        event_type: []const u8,
        init_dict: CookieChangeEventInit,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy event type
        const type_copy = try allocator.dupe(u8, event_type);
        errdefer allocator.free(type_copy);

        // Copy changed cookies
        var changed: []CookieListItem = &[_]CookieListItem{};
        if (init_dict.changed.len > 0) {
            changed = try allocator.alloc(CookieListItem, init_dict.changed.len);
            errdefer allocator.free(changed);

            for (init_dict.changed, 0..) |cookie, i| {
                changed[i] = try cookie.clone(allocator);
            }
        }

        // Copy deleted cookies
        var deleted: []CookieListItem = &[_]CookieListItem{};
        if (init_dict.deleted.len > 0) {
            deleted = try allocator.alloc(CookieListItem, init_dict.deleted.len);
            errdefer allocator.free(deleted);

            for (init_dict.deleted, 0..) |cookie, i| {
                deleted[i] = try cookie.clone(allocator);
            }
        }

        self.* = .{
            .event_type = type_copy,
            .changed = changed,
            .deleted = deleted,
            .bubbles = init_dict.bubbles,
            .cancelable = init_dict.cancelable,
            .composed = init_dict.composed,
            .target = null,
            .stop_propagation_flag = false,
            .stop_immediate_propagation_flag = false,
            .canceled_flag = false,
            .dispatch_flag = false,
            .initialized_flag = true,
            .allocator = allocator,
        };

        return self;
    }

    /// Clean up
    pub fn deinit(self: *Self) void {
        // Free changed cookies
        for (self.changed) |*cookie| {
            cookie.deinit();
        }
        if (self.changed.len > 0) {
            self.allocator.free(self.changed);
        }

        // Free deleted cookies
        for (self.deleted) |*cookie| {
            cookie.deinit();
        }
        if (self.deleted.len > 0) {
            self.allocator.free(self.deleted);
        }

        // Free event type
        self.allocator.free(self.event_type);

        self.allocator.destroy(self);
    }

    // ============================================================
    // WebIDL Attributes (readonly)
    // ============================================================

    /// Get the list of changed cookies
    pub fn getChanged(self: *const Self) []const CookieListItem {
        return self.changed;
    }

    /// Get the list of deleted cookies
    pub fn getDeleted(self: *const Self) []const CookieListItem {
        return self.deleted;
    }

    // ============================================================
    // Event Interface Methods
    // ============================================================

    /// Get event type
    pub fn getType(self: *const Self) []const u8 {
        return self.event_type;
    }

    /// Get event target
    pub fn getTarget(self: *const Self) ?*anyopaque {
        return self.target;
    }

    /// Get bubbles flag
    pub fn getBubbles(self: *const Self) bool {
        return self.bubbles;
    }

    /// Get cancelable flag
    pub fn getCancelable(self: *const Self) bool {
        return self.cancelable;
    }

    /// Get composed flag
    pub fn getComposed(self: *const Self) bool {
        return self.composed;
    }

    /// Prevent default action
    pub fn preventDefault(self: *Self) void {
        if (self.cancelable) {
            self.canceled_flag = true;
        }
    }

    /// Stop propagation
    pub fn stopPropagation(self: *Self) void {
        self.stop_propagation_flag = true;
    }

    /// Stop immediate propagation
    pub fn stopImmediatePropagation(self: *Self) void {
        self.stop_propagation_flag = true;
        self.stop_immediate_propagation_flag = true;
    }

    /// Check if default was prevented
    pub fn defaultPrevented(self: *const Self) bool {
        return self.canceled_flag;
    }
};

/// Create a CookieChangeEvent for cookie changes
pub fn createChangeEvent(
    allocator: Allocator,
    changed: []const CookieListItem,
    deleted: []const CookieListItem,
) !*CookieChangeEvent {
    return CookieChangeEvent.init(allocator, "change", .{
        .changed = changed,
        .deleted = deleted,
    });
}

// ============================================================
// Tests
// ============================================================

test "CookieChangeEvent - basic lifecycle" {
    const allocator = std.testing.allocator;

    const event = try CookieChangeEvent.init(allocator, "change", .{});
    defer event.deinit();

    try std.testing.expectEqualStrings("change", event.getType());
    try std.testing.expectEqual(@as(usize, 0), event.getChanged().len);
    try std.testing.expectEqual(@as(usize, 0), event.getDeleted().len);
}

test "CookieChangeEvent - with changed cookies" {
    const allocator = std.testing.allocator;

    var cookie = CookieListItem{
        .name = try allocator.dupe(u8, "session"),
        .value = try allocator.dupe(u8, "abc123"),
        .path = try allocator.dupe(u8, "/"),
        .allocator = allocator,
    };
    defer cookie.deinit();

    const event = try CookieChangeEvent.init(allocator, "change", .{
        .changed = &[_]CookieListItem{cookie},
    });
    defer event.deinit();

    try std.testing.expectEqual(@as(usize, 1), event.getChanged().len);
    try std.testing.expectEqualStrings("session", event.getChanged()[0].name);
    try std.testing.expectEqualStrings("abc123", event.getChanged()[0].value);
}

test "CookieChangeEvent - with deleted cookies" {
    const allocator = std.testing.allocator;

    var cookie = CookieListItem{
        .name = try allocator.dupe(u8, "old_session"),
        .value = try allocator.dupe(u8, ""),
        .path = try allocator.dupe(u8, "/"),
        .allocator = allocator,
    };
    defer cookie.deinit();

    const event = try CookieChangeEvent.init(allocator, "change", .{
        .deleted = &[_]CookieListItem{cookie},
    });
    defer event.deinit();

    try std.testing.expectEqual(@as(usize, 0), event.getChanged().len);
    try std.testing.expectEqual(@as(usize, 1), event.getDeleted().len);
    try std.testing.expectEqualStrings("old_session", event.getDeleted()[0].name);
}

test "CookieChangeEvent - event methods" {
    const allocator = std.testing.allocator;

    const event = try CookieChangeEvent.init(allocator, "change", .{
        .bubbles = true,
        .cancelable = true,
    });
    defer event.deinit();

    try std.testing.expect(event.getBubbles());
    try std.testing.expect(event.getCancelable());
    try std.testing.expect(!event.defaultPrevented());

    event.preventDefault();
    try std.testing.expect(event.defaultPrevented());
}

test "CookieChangeEvent - propagation control" {
    const allocator = std.testing.allocator;

    const event = try CookieChangeEvent.init(allocator, "change", .{});
    defer event.deinit();

    try std.testing.expect(!event.stop_propagation_flag);
    try std.testing.expect(!event.stop_immediate_propagation_flag);

    event.stopPropagation();
    try std.testing.expect(event.stop_propagation_flag);
    try std.testing.expect(!event.stop_immediate_propagation_flag);

    event.stopImmediatePropagation();
    try std.testing.expect(event.stop_immediate_propagation_flag);
}

test "CookieChangeEvent - createChangeEvent helper" {
    const allocator = std.testing.allocator;

    const event = try createChangeEvent(allocator, &[_]CookieListItem{}, &[_]CookieListItem{});
    defer event.deinit();

    try std.testing.expectEqualStrings("change", event.getType());
}
