//! Platform Notification Backend Abstraction
//!
//! Spec: https://notifications.spec.whatwg.org/
//! Notifications API Standard
//!
//! Provides a pluggable interface for notification operations, allowing the
//! Notifications API to work with different implementations (real OS notifications,
//! mock notifications for testing, etc.).
//!
//! The notification backend is responsible for:
//! - Displaying notifications to the end user
//! - Managing notification lifecycle (show, click, close)
//! - Handling notification permissions
//! - Managing notification actions
//!
//! ## Usage
//!
//! ```zig
//! const notification_backend = @import("platform/notification_backend.zig");
//!
//! // Create a stub backend for testing (in-memory notifications)
//! const stub = try StubNotificationBackend.init(allocator);
//! defer stub.deinit();
//!
//! // Get notification interface
//! const backend = stub.backend();
//!
//! // Show a notification
//! const notification = try Notification.create(allocator, "Hello", .{});
//! const result = backend.show(notification);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Notification permission state
/// Spec: https://notifications.spec.whatwg.org/#enumdef-notificationpermission
pub const NotificationPermission = enum {
    /// The user has not yet made a choice
    default,
    /// The user has explicitly denied permission
    denied,
    /// The user has explicitly granted permission
    granted,
};

/// Notification direction for bidirectional text
/// Spec: https://notifications.spec.whatwg.org/#enumdef-notificationdirection
pub const NotificationDirection = enum {
    /// Direction determined by the user agent algorithm
    auto,
    /// Left-to-right
    ltr,
    /// Right-to-left
    rtl,
};

/// Result of a notification operation
pub const NotificationResult = enum {
    success,
    permission_denied,
    not_supported,
    invalid_options,
    quota_exceeded,
    error_unknown,
};

/// Notification action
/// Spec: https://notifications.spec.whatwg.org/#dictdef-notificationaction
pub const NotificationAction = struct {
    /// Action identifier
    action: []const u8,
    /// Action title displayed to user
    title: []const u8,
    /// Optional navigation URL
    navigate: ?[]const u8 = null,
    /// Optional icon URL
    icon: ?[]const u8 = null,
};

/// Notification options for creation
/// Spec: https://notifications.spec.whatwg.org/#dictdef-notificationoptions
pub const NotificationOptions = struct {
    /// Text direction
    dir: NotificationDirection = .auto,
    /// Language tag (BCP 47)
    lang: []const u8 = "",
    /// Notification body text
    body: []const u8 = "",
    /// Navigation URL when notification is clicked
    navigate: ?[]const u8 = null,
    /// Tag for notification grouping/replacement
    tag: []const u8 = "",
    /// Large image URL
    image: ?[]const u8 = null,
    /// Small icon URL
    icon: ?[]const u8 = null,
    /// Badge icon URL (shown when space is limited)
    badge: ?[]const u8 = null,
    /// Vibration pattern
    vibrate: ?[]const u32 = null,
    /// Timestamp (milliseconds since epoch)
    timestamp: ?i64 = null,
    /// Whether to alert user when replacing a notification with same tag
    renotify: bool = false,
    /// Whether to suppress sounds/vibrations
    silent: ?bool = null,
    /// Whether to require user interaction to dismiss
    require_interaction: bool = false,
    /// Arbitrary data associated with notification
    data: ?*anyopaque = null,
    /// Notification actions
    actions: []const NotificationAction = &[_]NotificationAction{},
};

/// A notification instance
/// Spec: https://notifications.spec.whatwg.org/#concept-notification
pub const Notification = struct {
    allocator: Allocator,

    /// Notification title (required)
    title: []const u8,
    /// Text direction
    dir: NotificationDirection,
    /// Language tag
    lang: []const u8,
    /// Body text
    body: []const u8,
    /// Navigation URL
    navigate: ?[]const u8,
    /// Tag for grouping
    tag: []const u8,
    /// Image URL
    image: ?[]const u8,
    /// Icon URL
    icon: ?[]const u8,
    /// Badge URL
    badge: ?[]const u8,
    /// Vibration pattern (owned)
    vibrate: ?[]u32,
    /// Timestamp
    timestamp: i64,
    /// Renotify flag
    renotify: bool,
    /// Silent flag
    silent: ?bool,
    /// Require interaction flag
    require_interaction: bool,
    /// Associated data
    data: ?*anyopaque,
    /// Actions (owned)
    actions: []NotificationAction,

    /// Internal ID assigned by backend
    internal_id: ?u64 = null,

    /// Create a notification from title and options
    pub fn create(allocator: Allocator, title: []const u8, options: NotificationOptions) !*Notification {
        const self = try allocator.create(Notification);
        errdefer allocator.destroy(self);

        // Copy title
        const title_copy = try allocator.dupe(u8, title);
        errdefer allocator.free(title_copy);

        // Copy lang
        const lang_copy = try allocator.dupe(u8, options.lang);
        errdefer allocator.free(lang_copy);

        // Copy body
        const body_copy = try allocator.dupe(u8, options.body);
        errdefer allocator.free(body_copy);

        // Copy tag
        const tag_copy = try allocator.dupe(u8, options.tag);
        errdefer allocator.free(tag_copy);

        // Copy optional URLs
        const navigate_copy = if (options.navigate) |n| try allocator.dupe(u8, n) else null;
        errdefer if (navigate_copy) |n| allocator.free(n);

        const image_copy = if (options.image) |i| try allocator.dupe(u8, i) else null;
        errdefer if (image_copy) |i| allocator.free(i);

        const icon_copy = if (options.icon) |i| try allocator.dupe(u8, i) else null;
        errdefer if (icon_copy) |i| allocator.free(i);

        const badge_copy = if (options.badge) |b| try allocator.dupe(u8, b) else null;
        errdefer if (badge_copy) |b| allocator.free(b);

        // Copy vibrate pattern
        const vibrate_copy = if (options.vibrate) |v| try allocator.dupe(u32, v) else null;
        errdefer if (vibrate_copy) |v| allocator.free(v);

        // Copy actions
        const actions_copy = try allocator.alloc(NotificationAction, options.actions.len);
        errdefer allocator.free(actions_copy);

        for (options.actions, 0..) |action, i| {
            actions_copy[i] = .{
                .action = try allocator.dupe(u8, action.action),
                .title = try allocator.dupe(u8, action.title),
                .navigate = if (action.navigate) |n| try allocator.dupe(u8, n) else null,
                .icon = if (action.icon) |ic| try allocator.dupe(u8, ic) else null,
            };
        }

        self.* = Notification{
            .allocator = allocator,
            .title = title_copy,
            .dir = options.dir,
            .lang = lang_copy,
            .body = body_copy,
            .navigate = navigate_copy,
            .tag = tag_copy,
            .image = image_copy,
            .icon = icon_copy,
            .badge = badge_copy,
            .vibrate = vibrate_copy,
            .timestamp = options.timestamp orelse std.time.milliTimestamp(),
            .renotify = options.renotify,
            .silent = options.silent,
            .require_interaction = options.require_interaction,
            .data = options.data,
            .actions = actions_copy,
        };

        return self;
    }

    /// Free all resources
    pub fn deinit(self: *Notification) void {
        // Free actions
        for (self.actions) |action| {
            self.allocator.free(action.action);
            self.allocator.free(action.title);
            if (action.navigate) |n| self.allocator.free(n);
            if (action.icon) |i| self.allocator.free(i);
        }
        self.allocator.free(self.actions);

        // Free optional fields
        if (self.vibrate) |v| self.allocator.free(v);
        if (self.badge) |b| self.allocator.free(b);
        if (self.icon) |i| self.allocator.free(i);
        if (self.image) |i| self.allocator.free(i);
        if (self.navigate) |n| self.allocator.free(n);

        // Free required fields
        self.allocator.free(self.tag);
        self.allocator.free(self.body);
        self.allocator.free(self.lang);
        self.allocator.free(self.title);

        self.allocator.destroy(self);
    }
};

/// Notification event type
pub const NotificationEventType = enum {
    /// Notification was shown
    show,
    /// Notification was clicked
    click,
    /// Notification was closed
    close,
    /// An error occurred
    @"error",
};

/// Notification event callback
pub const NotificationEventCallback = *const fn (notification: *Notification, event_type: NotificationEventType, action: ?[]const u8) void;

/// Abstract notification backend interface.
///
/// This uses a vtable pattern to allow different implementations
/// (real OS notifications, mock notifications) to be swapped at runtime.
pub const NotificationBackend = struct {
    /// Implementation pointer.
    /// KEEP: VTable polymorphism - type erasure for pluggable backend implementations
    ptr: *anyopaque,

    /// Virtual function table.
    vtable: *const VTable,

    pub const VTable = struct {
        // === Permission Operations ===

        /// Get current permission state
        /// Spec: https://notifications.spec.whatwg.org/#dom-notification-permission
        getPermission: *const fn (ptr: *anyopaque) NotificationPermission,

        /// Request permission from user
        /// Spec: https://notifications.spec.whatwg.org/#dom-notification-requestpermission
        requestPermission: *const fn (ptr: *anyopaque) NotificationPermission,

        // === Notification Operations ===

        /// Show a notification
        /// Spec: https://notifications.spec.whatwg.org/#showing-a-notification
        show: *const fn (ptr: *anyopaque, notification: *Notification) NotificationResult,

        /// Close a notification
        /// Spec: https://notifications.spec.whatwg.org/#closing-a-notification
        close: *const fn (ptr: *anyopaque, notification: *Notification) NotificationResult,

        /// Get list of active notifications (for service worker getNotifications)
        getNotifications: *const fn (ptr: *anyopaque, tag: ?[]const u8, allocator: Allocator) ?[]*Notification,

        // === Configuration ===

        /// Get maximum number of actions supported
        /// Spec: https://notifications.spec.whatwg.org/#dom-notification-maxactions
        getMaxActions: *const fn (ptr: *anyopaque) u32,

        /// Set event callback for notification events
        setEventCallback: *const fn (ptr: *anyopaque, callback: ?NotificationEventCallback) void,

        // === Lifecycle ===

        /// Free backend resources
        deinit: *const fn (ptr: *anyopaque) void,
    };

    // === Convenience Methods ===

    /// Get current permission state
    pub fn getPermission(self: NotificationBackend) NotificationPermission {
        return self.vtable.getPermission(self.ptr);
    }

    /// Request permission from user
    pub fn requestPermission(self: NotificationBackend) NotificationPermission {
        return self.vtable.requestPermission(self.ptr);
    }

    /// Show a notification
    pub fn show(self: NotificationBackend, notification: *Notification) NotificationResult {
        return self.vtable.show(self.ptr, notification);
    }

    /// Close a notification
    pub fn close(self: NotificationBackend, notification: *Notification) NotificationResult {
        return self.vtable.close(self.ptr, notification);
    }

    /// Get list of active notifications
    pub fn getNotifications(self: NotificationBackend, tag: ?[]const u8, allocator: Allocator) ?[]*Notification {
        return self.vtable.getNotifications(self.ptr, tag, allocator);
    }

    /// Get maximum number of actions
    pub fn getMaxActions(self: NotificationBackend) u32 {
        return self.vtable.getMaxActions(self.ptr);
    }

    /// Set event callback
    pub fn setEventCallback(self: NotificationBackend, callback: ?NotificationEventCallback) void {
        self.vtable.setEventCallback(self.ptr, callback);
    }

    /// Free resources
    pub fn deinit(self: NotificationBackend) void {
        self.vtable.deinit(self.ptr);
    }
};

/// Stub notification backend for testing and headless environments.
///
/// Provides an in-memory notification system that:
/// - Tracks permission state
/// - Stores active notifications
/// - Fires events synchronously
/// - Useful for testing without OS notification access
pub const StubNotificationBackend = struct {
    allocator: Allocator,

    /// Current permission state
    permission: NotificationPermission,

    /// Active notifications
    active_notifications: std.ArrayListUnmanaged(*Notification),

    /// Next notification ID
    next_id: u64,

    /// Event callback
    event_callback: ?NotificationEventCallback,

    /// Maximum actions (configurable for testing)
    max_actions: u32,

    /// Initialize a new stub notification backend.
    pub fn init(allocator: Allocator) !*StubNotificationBackend {
        const self = try allocator.create(StubNotificationBackend);
        self.* = StubNotificationBackend{
            .allocator = allocator,
            .permission = .default,
            .active_notifications = .{},
            .next_id = 1,
            .event_callback = null,
            .max_actions = 2, // Common default
        };
        return self;
    }

    /// Create a NotificationBackend interface for this stub.
    pub fn backend(self: *StubNotificationBackend) NotificationBackend {
        return NotificationBackend{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    /// Set permission state (for testing)
    pub fn setPermission(self: *StubNotificationBackend, permission: NotificationPermission) void {
        self.permission = permission;
    }

    /// Simulate clicking a notification
    pub fn simulateClick(self: *StubNotificationBackend, notification: *Notification, action: ?[]const u8) void {
        if (self.event_callback) |callback| {
            callback(notification, .click, action);
        }
    }

    /// Free the stub backend and its contents.
    pub fn deinit(self: *StubNotificationBackend) void {
        self.active_notifications.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    const vtable = NotificationBackend.VTable{
        .getPermission = getPermissionImpl,
        .requestPermission = requestPermissionImpl,
        .show = showImpl,
        .close = closeImpl,
        .getNotifications = getNotificationsImpl,
        .getMaxActions = getMaxActionsImpl,
        .setEventCallback = setEventCallbackImpl,
        .deinit = deinitImpl,
    };

    fn getPermissionImpl(ptr: *anyopaque) NotificationPermission {
        const self: *StubNotificationBackend = @ptrCast(@alignCast(ptr));
        return self.permission;
    }

    fn requestPermissionImpl(ptr: *anyopaque) NotificationPermission {
        const self: *StubNotificationBackend = @ptrCast(@alignCast(ptr));
        // Stub always grants permission when requested
        if (self.permission == .default) {
            self.permission = .granted;
        }
        return self.permission;
    }

    fn showImpl(ptr: *anyopaque, notification: *Notification) NotificationResult {
        const self: *StubNotificationBackend = @ptrCast(@alignCast(ptr));

        // Check permission
        if (self.permission != .granted) {
            return .permission_denied;
        }

        // Assign internal ID
        notification.internal_id = self.next_id;
        self.next_id += 1;

        // Handle tag replacement
        if (notification.tag.len > 0) {
            var i: usize = 0;
            while (i < self.active_notifications.items.len) {
                const existing = self.active_notifications.items[i];
                if (std.mem.eql(u8, existing.tag, notification.tag)) {
                    // Fire close event for replaced notification
                    if (self.event_callback) |callback| {
                        callback(existing, .close, null);
                    }
                    _ = self.active_notifications.orderedRemove(i);
                } else {
                    i += 1;
                }
            }
        }

        // Add to active list
        self.active_notifications.append(self.allocator, notification) catch return .error_unknown;

        // Fire show event
        if (self.event_callback) |callback| {
            callback(notification, .show, null);
        }

        return .success;
    }

    fn closeImpl(ptr: *anyopaque, notification: *Notification) NotificationResult {
        const self: *StubNotificationBackend = @ptrCast(@alignCast(ptr));

        // Find and remove from active list
        for (self.active_notifications.items, 0..) |n, i| {
            if (n == notification) {
                _ = self.active_notifications.orderedRemove(i);

                // Fire close event
                if (self.event_callback) |callback| {
                    callback(notification, .close, null);
                }

                return .success;
            }
        }

        return .error_unknown;
    }

    fn getNotificationsImpl(ptr: *anyopaque, tag: ?[]const u8, allocator: Allocator) ?[]*Notification {
        const self: *StubNotificationBackend = @ptrCast(@alignCast(ptr));

        // Count matching notifications
        var count: usize = 0;
        for (self.active_notifications.items) |n| {
            if (tag == null or std.mem.eql(u8, n.tag, tag.?)) {
                count += 1;
            }
        }

        if (count == 0) return null;

        // Allocate result array
        const result = allocator.alloc(*Notification, count) catch return null;

        // Copy matching notifications
        var idx: usize = 0;
        for (self.active_notifications.items) |n| {
            if (tag == null or std.mem.eql(u8, n.tag, tag.?)) {
                result[idx] = n;
                idx += 1;
            }
        }

        return result;
    }

    fn getMaxActionsImpl(ptr: *anyopaque) u32 {
        const self: *StubNotificationBackend = @ptrCast(@alignCast(ptr));
        return self.max_actions;
    }

    fn setEventCallbackImpl(ptr: *anyopaque, callback: ?NotificationEventCallback) void {
        const self: *StubNotificationBackend = @ptrCast(@alignCast(ptr));
        self.event_callback = callback;
    }

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *StubNotificationBackend = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

/// Permission-denied notification backend.
///
/// A notification backend that always denies permission.
/// Useful for testing permission error handling.
pub const DeniedNotificationBackend = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) !*DeniedNotificationBackend {
        const self = try allocator.create(DeniedNotificationBackend);
        self.* = DeniedNotificationBackend{
            .allocator = allocator,
        };
        return self;
    }

    pub fn backend(self: *DeniedNotificationBackend) NotificationBackend {
        return NotificationBackend{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = NotificationBackend.VTable{
        .getPermission = getPermissionImpl,
        .requestPermission = requestPermissionImpl,
        .show = showImpl,
        .close = closeImpl,
        .getNotifications = getNotificationsImpl,
        .getMaxActions = getMaxActionsImpl,
        .setEventCallback = setEventCallbackImpl,
        .deinit = deinitImpl,
    };

    fn getPermissionImpl(_: *anyopaque) NotificationPermission {
        return .denied;
    }

    fn requestPermissionImpl(_: *anyopaque) NotificationPermission {
        return .denied;
    }

    fn showImpl(_: *anyopaque, _: *Notification) NotificationResult {
        return .permission_denied;
    }

    fn closeImpl(_: *anyopaque, _: *Notification) NotificationResult {
        return .permission_denied;
    }

    fn getNotificationsImpl(_: *anyopaque, _: ?[]const u8, _: Allocator) ?[]*Notification {
        return null;
    }

    fn getMaxActionsImpl(_: *anyopaque) u32 {
        return 0;
    }

    fn setEventCallbackImpl(_: *anyopaque, _: ?NotificationEventCallback) void {}

    fn deinitImpl(ptr: *anyopaque) void {
        const self: *DeniedNotificationBackend = @ptrCast(@alignCast(ptr));
        self.allocator.destroy(self);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "Notification - create and deinit" {
    const allocator = std.testing.allocator;

    const notification = try Notification.create(allocator, "Test Title", .{
        .body = "Test body text",
        .tag = "test-tag",
        .icon = "https://example.com/icon.png",
    });
    defer notification.deinit();

    try std.testing.expectEqualStrings("Test Title", notification.title);
    try std.testing.expectEqualStrings("Test body text", notification.body);
    try std.testing.expectEqualStrings("test-tag", notification.tag);
    try std.testing.expectEqualStrings("https://example.com/icon.png", notification.icon.?);
}

test "Notification - with actions" {
    const allocator = std.testing.allocator;

    const actions = [_]NotificationAction{
        .{ .action = "reply", .title = "Reply", .navigate = "https://example.com/reply" },
        .{ .action = "dismiss", .title = "Dismiss" },
    };

    const notification = try Notification.create(allocator, "Message", .{
        .body = "You have a new message",
        .actions = &actions,
    });
    defer notification.deinit();

    try std.testing.expectEqual(@as(usize, 2), notification.actions.len);
    try std.testing.expectEqualStrings("reply", notification.actions[0].action);
    try std.testing.expectEqualStrings("Reply", notification.actions[0].title);
    try std.testing.expectEqualStrings("dismiss", notification.actions[1].action);
}

test "StubNotificationBackend - permission states" {
    const allocator = std.testing.allocator;

    const stub = try StubNotificationBackend.init(allocator);
    const backend_iface = stub.backend();
    defer backend_iface.deinit();

    // Default state
    try std.testing.expectEqual(NotificationPermission.default, backend_iface.getPermission());

    // Request permission grants it
    const result = backend_iface.requestPermission();
    try std.testing.expectEqual(NotificationPermission.granted, result);
    try std.testing.expectEqual(NotificationPermission.granted, backend_iface.getPermission());
}

test "StubNotificationBackend - show notification" {
    const allocator = std.testing.allocator;

    const stub = try StubNotificationBackend.init(allocator);
    const backend_iface = stub.backend();
    defer backend_iface.deinit();

    // Grant permission first
    stub.setPermission(.granted);

    // Create and show notification
    const notification = try Notification.create(allocator, "Hello", .{});
    defer notification.deinit();

    const result = backend_iface.show(notification);
    try std.testing.expectEqual(NotificationResult.success, result);
    try std.testing.expect(notification.internal_id != null);
}

test "StubNotificationBackend - permission denied" {
    const allocator = std.testing.allocator;

    const stub = try StubNotificationBackend.init(allocator);
    const backend_iface = stub.backend();
    defer backend_iface.deinit();

    // Don't grant permission

    const notification = try Notification.create(allocator, "Hello", .{});
    defer notification.deinit();

    const result = backend_iface.show(notification);
    try std.testing.expectEqual(NotificationResult.permission_denied, result);
}

test "StubNotificationBackend - tag replacement" {
    const allocator = std.testing.allocator;

    const stub = try StubNotificationBackend.init(allocator);
    const backend_iface = stub.backend();
    defer backend_iface.deinit();

    stub.setPermission(.granted);

    // Show first notification with tag
    const n1 = try Notification.create(allocator, "First", .{ .tag = "chat" });
    defer n1.deinit();
    _ = backend_iface.show(n1);

    // Show second notification with same tag - should replace
    const n2 = try Notification.create(allocator, "Second", .{ .tag = "chat" });
    defer n2.deinit();
    _ = backend_iface.show(n2);

    // Should only have one active notification
    try std.testing.expectEqual(@as(usize, 1), stub.active_notifications.items.len);
    try std.testing.expectEqualStrings("Second", stub.active_notifications.items[0].title);
}

test "StubNotificationBackend - getNotifications" {
    const allocator = std.testing.allocator;

    const stub = try StubNotificationBackend.init(allocator);
    const backend_iface = stub.backend();
    defer backend_iface.deinit();

    stub.setPermission(.granted);

    // Show multiple notifications
    const n1 = try Notification.create(allocator, "Chat 1", .{ .tag = "chat" });
    defer n1.deinit();
    _ = backend_iface.show(n1);

    const n2 = try Notification.create(allocator, "Email", .{ .tag = "email" });
    defer n2.deinit();
    _ = backend_iface.show(n2);

    const n3 = try Notification.create(allocator, "Chat 2", .{ .tag = "chat" });
    defer n3.deinit();
    _ = backend_iface.show(n3);

    // Get all notifications
    const all = backend_iface.getNotifications(null, allocator);
    try std.testing.expect(all != null);
    defer allocator.free(all.?);
    try std.testing.expectEqual(@as(usize, 2), all.?.len); // chat replaced

    // Get by tag
    const chats = backend_iface.getNotifications("chat", allocator);
    try std.testing.expect(chats != null);
    defer allocator.free(chats.?);
    try std.testing.expectEqual(@as(usize, 1), chats.?.len);
}

test "StubNotificationBackend - close notification" {
    const allocator = std.testing.allocator;

    const stub = try StubNotificationBackend.init(allocator);
    const backend_iface = stub.backend();
    defer backend_iface.deinit();

    stub.setPermission(.granted);

    const notification = try Notification.create(allocator, "Hello", .{});
    defer notification.deinit();

    _ = backend_iface.show(notification);
    try std.testing.expectEqual(@as(usize, 1), stub.active_notifications.items.len);

    const close_result = backend_iface.close(notification);
    try std.testing.expectEqual(NotificationResult.success, close_result);
    try std.testing.expectEqual(@as(usize, 0), stub.active_notifications.items.len);
}

test "StubNotificationBackend - event callback" {
    const allocator = std.testing.allocator;

    const stub = try StubNotificationBackend.init(allocator);
    const backend_iface = stub.backend();
    defer backend_iface.deinit();

    stub.setPermission(.granted);

    // Track events
    const S = struct {
        var show_count: u32 = 0;
        var click_count: u32 = 0;
        var close_count: u32 = 0;

        fn callback(_: *Notification, event_type: NotificationEventType, _: ?[]const u8) void {
            switch (event_type) {
                .show => show_count += 1,
                .click => click_count += 1,
                .close => close_count += 1,
                .@"error" => {},
            }
        }
    };

    backend_iface.setEventCallback(S.callback);

    const notification = try Notification.create(allocator, "Hello", .{});
    defer notification.deinit();

    _ = backend_iface.show(notification);
    try std.testing.expectEqual(@as(u32, 1), S.show_count);

    stub.simulateClick(notification, null);
    try std.testing.expectEqual(@as(u32, 1), S.click_count);

    _ = backend_iface.close(notification);
    try std.testing.expectEqual(@as(u32, 1), S.close_count);
}

test "DeniedNotificationBackend - always denied" {
    const allocator = std.testing.allocator;

    const denied = try DeniedNotificationBackend.init(allocator);
    const backend_iface = denied.backend();
    defer backend_iface.deinit();

    try std.testing.expectEqual(NotificationPermission.denied, backend_iface.getPermission());
    try std.testing.expectEqual(NotificationPermission.denied, backend_iface.requestPermission());

    const notification = try Notification.create(allocator, "Hello", .{});
    defer notification.deinit();

    try std.testing.expectEqual(NotificationResult.permission_denied, backend_iface.show(notification));
    try std.testing.expectEqual(@as(u32, 0), backend_iface.getMaxActions());
}
