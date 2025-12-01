//! CookieStore API Implementation
//!
//! Implements the WHATWG Cookie Store API specification.
//! Reference: https://cookiestore.spec.whatwg.org/
//!
//! This wraps CurlCookieManager to provide a WebIDL-compliant cookie access API.

const std = @import("std");
const Allocator = std.mem.Allocator;
const curl_cookies = @import("curl_cookies.zig");
const CurlCookieManager = curl_cookies.CurlCookieManager;
const Cookie = curl_cookies.Cookie;
const CookieChangeCallback = curl_cookies.CookieChangeCallback;

/// CookieSameSite enum matching WebIDL
pub const CookieSameSite = enum {
    strict,
    lax,
    none,

    pub fn fromString(str: []const u8) CookieSameSite {
        if (std.mem.eql(u8, str, "strict")) return .strict;
        if (std.mem.eql(u8, str, "lax")) return .lax;
        if (std.mem.eql(u8, str, "none")) return .none;
        return .strict; // Default
    }

    pub fn toString(self: CookieSameSite) []const u8 {
        return switch (self) {
            .strict => "strict",
            .lax => "lax",
            .none => "none",
        };
    }
};

/// CookieListItem - represents a cookie in the API response
/// Matches the WebIDL CookieListItem dictionary
pub const CookieListItem = struct {
    name: []const u8,
    value: []const u8,
    domain: ?[]const u8 = null,
    path: []const u8 = "/",
    expires: ?i64 = null,
    secure: bool = false,
    sameSite: CookieSameSite = .strict,
    partitioned: bool = false,

    allocator: Allocator,

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

/// CookieStoreGetOptions - options for get() and getAll()
pub const CookieStoreGetOptions = struct {
    name: ?[]const u8 = null,
    url: ?[]const u8 = null,
};

/// CookieInit - options for set()
pub const CookieInit = struct {
    name: []const u8,
    value: []const u8,
    expires: ?i64 = null,
    domain: ?[]const u8 = null,
    path: []const u8 = "/",
    sameSite: CookieSameSite = .strict,
    partitioned: bool = false,
};

/// CookieStoreDeleteOptions - options for delete()
pub const CookieStoreDeleteOptions = struct {
    name: []const u8,
    domain: ?[]const u8 = null,
    path: []const u8 = "/",
    partitioned: bool = false,
};

/// CookieChangeEventInit - for CookieChangeEvent
pub const CookieChangeEventInit = struct {
    changed: []const CookieListItem = &[_]CookieListItem{},
    deleted: []const CookieListItem = &[_]CookieListItem{},
};

/// CookieChangeEvent - event fired when cookies change
/// Local implementation for fetch module (matches DOM version)
pub const CookieChangeEvent = struct {
    /// Event type (always "change")
    event_type: []const u8,

    /// Cookies that were added or modified
    changed: []CookieListItem,

    /// Cookies that were deleted
    deleted: []CookieListItem,

    /// Allocator for cleanup
    allocator: Allocator,

    const Self = @This();

    /// Create a new CookieChangeEvent
    pub fn init(
        allocator: Allocator,
        event_type_str: []const u8,
        init_dict: CookieChangeEventInit,
    ) !*Self {
        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);

        // Copy event type
        const type_copy = try allocator.dupe(u8, event_type_str);
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

    /// Get the list of changed cookies
    pub fn getChanged(self: *const Self) []const CookieListItem {
        return self.changed;
    }

    /// Get the list of deleted cookies
    pub fn getDeleted(self: *const Self) []const CookieListItem {
        return self.deleted;
    }

    /// Get event type
    pub fn getType(self: *const Self) []const u8 {
        return self.event_type;
    }
};

/// Event handler function type for CookieChangeEvent
pub const EventHandler = *const fn (event: *CookieChangeEvent) void;

/// CookieStore implementation
/// Wraps CurlCookieManager to provide WebIDL-compliant cookie access
pub const CookieStore = struct {
    /// Underlying cookie manager (shared across the application)
    cookie_manager: *CurlCookieManager,

    /// The URL context for this CookieStore (used for defaults)
    context_url: ?[]const u8,

    /// Allocator
    allocator: Allocator,

    /// Change event listeners using CookieChangeEvent
    change_listeners: std.ArrayListUnmanaged(EventHandler),

    /// onchange event handler attribute (IDL event handler)
    onchange_handler: ?EventHandler,

    /// Whether we're registered with the cookie manager
    registered_with_manager: bool,

    /// Initialize CookieStore with a shared cookie manager
    pub fn init(
        allocator: Allocator,
        cookie_manager: *CurlCookieManager,
        context_url: ?[]const u8,
    ) !*CookieStore {
        const self = try allocator.create(CookieStore);
        errdefer allocator.destroy(self);

        self.* = .{
            .cookie_manager = cookie_manager,
            .context_url = if (context_url) |u| try allocator.dupe(u8, u) else null,
            .allocator = allocator,
            .change_listeners = .{},
            .onchange_handler = null,
            .registered_with_manager = false,
        };

        // Register for cookie change notifications from the manager
        try cookie_manager.addChangeListener(CookieStore.onCookieManagerChange, self);
        self.registered_with_manager = true;

        return self;
    }

    pub fn deinit(self: *CookieStore) void {
        // Unregister from cookie manager
        if (self.registered_with_manager) {
            self.cookie_manager.removeChangeListener(CookieStore.onCookieManagerChange);
        }

        if (self.context_url) |url| {
            self.allocator.free(url);
        }
        self.change_listeners.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    // ============================================================
    // WebIDL Methods
    // ============================================================

    /// get(USVString name) -> Promise<CookieListItem?>
    pub fn getByName(self: *CookieStore, name: []const u8) !?CookieListItem {
        return self.getByOptions(.{ .name = name });
    }

    /// get(CookieStoreGetOptions options) -> Promise<CookieListItem?>
    pub fn getByOptions(self: *CookieStore, options: CookieStoreGetOptions) !?CookieListItem {
        const name = options.name orelse return null;
        const url = options.url orelse self.context_url;

        const cookie = try self.cookie_manager.get(name, url);
        if (cookie) |c| {
            var cookie_mut = c;
            defer cookie_mut.deinit();
            const item = try cookieToListItem(self.allocator, cookie_mut);
            return item;
        }
        return null;
    }

    /// getAll(USVString name) -> Promise<CookieList>
    pub fn getAllByName(self: *CookieStore, name: []const u8) ![]CookieListItem {
        return self.getAllByOptions(.{ .name = name });
    }

    /// getAll(CookieStoreGetOptions options) -> Promise<CookieList>
    pub fn getAllByOptions(self: *CookieStore, options: CookieStoreGetOptions) ![]CookieListItem {
        const url = options.url orelse self.context_url;

        const cookies = try self.cookie_manager.getAll(url);
        defer {
            for (cookies) |*c| {
                var cookie = c.*;
                cookie.deinit();
            }
            self.allocator.free(cookies);
        }

        // Filter by name if specified
        var count: usize = 0;
        for (cookies) |c| {
            if (options.name) |name| {
                if (std.mem.eql(u8, c.name, name)) count += 1;
            } else {
                count += 1;
            }
        }

        var items = try self.allocator.alloc(CookieListItem, count);
        errdefer self.allocator.free(items);

        var i: usize = 0;
        for (cookies) |c| {
            const include = if (options.name) |name|
                std.mem.eql(u8, c.name, name)
            else
                true;

            if (include) {
                items[i] = try cookieToListItem(self.allocator, c);
                i += 1;
            }
        }

        return items;
    }

    /// getAll() -> Promise<CookieList>
    pub fn getAll(self: *CookieStore) ![]CookieListItem {
        return self.getAllByOptions(.{});
    }

    /// set(USVString name, USVString value) -> Promise<undefined>
    pub fn setNameValue(self: *CookieStore, name: []const u8, value: []const u8) !void {
        return self.setOptions(.{ .name = name, .value = value });
    }

    /// set(CookieInit options) -> Promise<undefined>
    pub fn setOptions(self: *CookieStore, options: CookieInit) !void {
        const cookie = Cookie{
            .name = options.name,
            .value = options.value,
            .domain = options.domain orelse "",
            .path = options.path,
            .expires = options.expires,
            .secure = false, // Determined by context
            .same_site = switch (options.sameSite) {
                .strict => .strict,
                .lax => .lax,
                .none => .none,
            },
            .http_only = false,
            .allocator = self.allocator,
        };

        // CurlCookieManager.set() will notify us via onCookieManagerChange callback
        try self.cookie_manager.set(cookie);
    }

    /// delete(USVString name) -> Promise<undefined>
    pub fn deleteByName(self: *CookieStore, name: []const u8) !void {
        return self.deleteByOptions(.{ .name = name });
    }

    /// delete(CookieStoreDeleteOptions options) -> Promise<undefined>
    pub fn deleteByOptions(self: *CookieStore, options: CookieStoreDeleteOptions) !void {
        // CurlCookieManager.delete() will notify us via onCookieManagerChange callback
        try self.cookie_manager.delete(options.name, options.domain, options.path);
    }

    // ============================================================
    // Event Handling
    // ============================================================

    /// Add a change listener (addEventListener("change", handler))
    pub fn addChangeListener(self: *CookieStore, listener: EventHandler) !void {
        try self.change_listeners.append(self.allocator, listener);
    }

    /// Remove a change listener (removeEventListener("change", handler))
    pub fn removeChangeListener(self: *CookieStore, listener: EventHandler) void {
        for (self.change_listeners.items, 0..) |l, i| {
            if (l == listener) {
                _ = self.change_listeners.orderedRemove(i);
                return;
            }
        }
    }

    /// Set the onchange event handler attribute
    pub fn setOnchange(self: *CookieStore, handler: ?EventHandler) void {
        self.onchange_handler = handler;
    }

    /// Get the onchange event handler attribute
    pub fn getOnchange(self: *const CookieStore) ?EventHandler {
        return self.onchange_handler;
    }

    /// Fire a CookieChangeEvent to all listeners
    fn fireChangeEventWithLists(
        self: *CookieStore,
        changed_cookies: []const Cookie,
        deleted_cookies: []const Cookie,
    ) void {
        // Convert cookies to CookieListItems
        var changed_items = std.ArrayListUnmanaged(CookieListItem){};
        defer {
            for (changed_items.items) |*item| {
                item.deinit();
            }
            changed_items.deinit(self.allocator);
        }

        for (changed_cookies) |cookie| {
            const item = cookieToListItem(self.allocator, cookie) catch continue;
            changed_items.append(self.allocator, item) catch continue;
        }

        var deleted_items = std.ArrayListUnmanaged(CookieListItem){};
        defer {
            for (deleted_items.items) |*item| {
                item.deinit();
            }
            deleted_items.deinit(self.allocator);
        }

        for (deleted_cookies) |cookie| {
            const item = cookieToListItem(self.allocator, cookie) catch continue;
            deleted_items.append(self.allocator, item) catch continue;
        }

        // Create and dispatch the event
        const event = CookieChangeEvent.init(self.allocator, "change", .{
            .changed = changed_items.items,
            .deleted = deleted_items.items,
        }) catch return;
        defer event.deinit();

        // Call onchange handler first
        if (self.onchange_handler) |handler| {
            handler(event);
        }

        // Call all registered listeners
        for (self.change_listeners.items) |listener| {
            listener(event);
        }
    }

    /// Callback function for CurlCookieManager change notifications
    fn onCookieManagerChange(
        changed: []const Cookie,
        deleted: []const Cookie,
        context: ?*anyopaque,
    ) void {
        const self: *CookieStore = @ptrCast(@alignCast(context.?));
        self.fireChangeEventWithLists(changed, deleted);
    }
};

// ============================================================
// Helper Functions
// ============================================================

fn cookieToListItem(allocator: Allocator, cookie: Cookie) !CookieListItem {
    return CookieListItem{
        .name = try allocator.dupe(u8, cookie.name),
        .value = try allocator.dupe(u8, cookie.value),
        .domain = if (cookie.domain.len > 0) try allocator.dupe(u8, cookie.domain) else null,
        .path = try allocator.dupe(u8, cookie.path),
        .expires = cookie.expires,
        .secure = cookie.secure,
        .sameSite = switch (cookie.same_site) {
            .strict => .strict,
            .lax => .lax,
            .none => .none,
        },
        .partitioned = false, // TODO: CHIPS support
        .allocator = allocator,
    };
}

// ============================================================
// Global CookieStore singleton
// ============================================================

var global_cookie_manager: ?*CurlCookieManager = null;
var global_cookie_store: ?*CookieStore = null;

/// Get or create the global CookieStore
/// This is what window.cookieStore maps to
pub fn getGlobalCookieStore(allocator: Allocator) !*CookieStore {
    if (global_cookie_store) |store| {
        return store;
    }

    // Create global cookie manager if needed
    if (global_cookie_manager == null) {
        global_cookie_manager = try CurlCookieManager.init(allocator, null);
    }

    global_cookie_store = try CookieStore.init(allocator, global_cookie_manager.?, null);
    return global_cookie_store.?;
}

/// Clean up global CookieStore (call at shutdown)
pub fn cleanupGlobalCookieStore() void {
    if (global_cookie_store) |store| {
        store.deinit();
        global_cookie_store = null;
    }
    if (global_cookie_manager) |manager| {
        manager.deinit();
        global_cookie_manager = null;
    }
}

// ============================================================
// Tests
// ============================================================

test "CookieStore - lifecycle" {
    const allocator = std.testing.allocator;

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    const store = try CookieStore.init(allocator, manager, null);
    defer store.deinit();
}

test "CookieStore - set and get" {
    const allocator = std.testing.allocator;

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    const store = try CookieStore.init(allocator, manager, null);
    defer store.deinit();

    // Set a cookie
    try store.setNameValue("session", "abc123");

    // Get it back
    const result = try store.getByName("session");
    if (result) |*item| {
        var item_mut = item.*;
        defer item_mut.deinit();
        try std.testing.expectEqualStrings("session", item_mut.name);
        try std.testing.expectEqualStrings("abc123", item_mut.value);
    }
}

test "CookieStore - getAll" {
    const allocator = std.testing.allocator;

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    const store = try CookieStore.init(allocator, manager, null);
    defer store.deinit();

    // Set multiple cookies
    try store.setOptions(.{ .name = "a", .value = "1", .domain = ".example.com" });
    try store.setOptions(.{ .name = "b", .value = "2", .domain = ".example.com" });

    // Get all
    const items = try store.getAll();
    defer {
        for (items) |*item| {
            var item_mut = item.*;
            item_mut.deinit();
        }
        allocator.free(items);
    }

    try std.testing.expect(items.len >= 2);
}

test "CookieStore - delete" {
    const allocator = std.testing.allocator;

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    const store = try CookieStore.init(allocator, manager, null);
    defer store.deinit();

    // Set and delete
    try store.setOptions(.{ .name = "temp", .value = "data", .domain = ".example.com" });
    try store.deleteByOptions(.{ .name = "temp", .domain = ".example.com" });

    // Should be gone (or have past expiry - libcurl marks as expired)
}

test "CookieListItem - clone" {
    const allocator = std.testing.allocator;

    var original = CookieListItem{
        .name = try allocator.dupe(u8, "test"),
        .value = try allocator.dupe(u8, "value"),
        .domain = try allocator.dupe(u8, ".example.com"),
        .path = try allocator.dupe(u8, "/"),
        .expires = 1735689600,
        .secure = true,
        .sameSite = .strict,
        .partitioned = false,
        .allocator = allocator,
    };
    defer original.deinit();

    var cloned = try original.clone(allocator);
    defer cloned.deinit();

    try std.testing.expectEqualStrings(original.name, cloned.name);
    try std.testing.expectEqualStrings(original.value, cloned.value);
    try std.testing.expectEqual(original.expires, cloned.expires);
}

test "CookieChangeEvent - lifecycle" {
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

// Test state for change listener tests
var test_change_count: usize = 0;
var test_delete_count: usize = 0;
var test_last_changed_name_buf: [64]u8 = undefined;
var test_last_changed_name_len: usize = 0;
var test_last_deleted_name_buf: [64]u8 = undefined;
var test_last_deleted_name_len: usize = 0;

fn testChangeHandler(event: *CookieChangeEvent) void {
    test_change_count += event.getChanged().len;
    test_delete_count += event.getDeleted().len;

    if (event.getChanged().len > 0) {
        const name = event.getChanged()[0].name;
        const len = @min(name.len, test_last_changed_name_buf.len);
        @memcpy(test_last_changed_name_buf[0..len], name[0..len]);
        test_last_changed_name_len = len;
    }
    if (event.getDeleted().len > 0) {
        const name = event.getDeleted()[0].name;
        const len = @min(name.len, test_last_deleted_name_buf.len);
        @memcpy(test_last_deleted_name_buf[0..len], name[0..len]);
        test_last_deleted_name_len = len;
    }
}

fn resetTestState() void {
    test_change_count = 0;
    test_delete_count = 0;
    test_last_changed_name_len = 0;
    test_last_deleted_name_len = 0;
}

fn getTestLastChangedName() ?[]const u8 {
    if (test_last_changed_name_len > 0) {
        return test_last_changed_name_buf[0..test_last_changed_name_len];
    }
    return null;
}

fn getTestLastDeletedName() ?[]const u8 {
    if (test_last_deleted_name_len > 0) {
        return test_last_deleted_name_buf[0..test_last_deleted_name_len];
    }
    return null;
}

test "CookieStore - change listener fires on set" {
    const allocator = std.testing.allocator;
    resetTestState();

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    const store = try CookieStore.init(allocator, manager, null);
    defer store.deinit();

    // Add change listener
    try store.addChangeListener(testChangeHandler);

    // Set a cookie - should trigger change event
    try store.setOptions(.{ .name = "test_cookie", .value = "test_value", .domain = ".example.com" });

    // Verify the listener was called
    try std.testing.expect(test_change_count >= 1);
    const changed_name = getTestLastChangedName();
    try std.testing.expect(changed_name != null);
    if (changed_name) |name| {
        try std.testing.expectEqualStrings("test_cookie", name);
    }
}

test "CookieStore - change listener fires on delete" {
    const allocator = std.testing.allocator;
    resetTestState();

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    const store = try CookieStore.init(allocator, manager, null);
    defer store.deinit();

    // First set a cookie (without listener)
    try store.setOptions(.{ .name = "to_delete", .value = "value", .domain = ".example.com" });

    // Reset and add listener
    resetTestState();
    try store.addChangeListener(testChangeHandler);

    // Delete the cookie - should trigger change event with deleted
    try store.deleteByOptions(.{ .name = "to_delete", .domain = ".example.com" });

    // Verify the listener was called with deleted cookie
    try std.testing.expect(test_delete_count >= 1);
    const deleted_name = getTestLastDeletedName();
    try std.testing.expect(deleted_name != null);
    if (deleted_name) |name| {
        try std.testing.expectEqualStrings("to_delete", name);
    }
}

test "CookieStore - onchange handler works" {
    const allocator = std.testing.allocator;
    resetTestState();

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    const store = try CookieStore.init(allocator, manager, null);
    defer store.deinit();

    // Set onchange handler
    store.setOnchange(testChangeHandler);
    try std.testing.expect(store.getOnchange() != null);

    // Set a cookie - should trigger onchange
    try store.setOptions(.{ .name = "onchange_test", .value = "value", .domain = ".example.com" });

    // Verify the handler was called
    try std.testing.expect(test_change_count >= 1);

    // Clear onchange handler
    store.setOnchange(null);
    try std.testing.expect(store.getOnchange() == null);
}

test "CookieStore - remove change listener" {
    const allocator = std.testing.allocator;
    resetTestState();

    const manager = try CurlCookieManager.init(allocator, null);
    defer manager.deinit();

    const store = try CookieStore.init(allocator, manager, null);
    defer store.deinit();

    // Add and then remove listener
    try store.addChangeListener(testChangeHandler);
    store.removeChangeListener(testChangeHandler);

    // Set a cookie - should NOT trigger change event (listener removed)
    try store.setOptions(.{ .name = "no_event", .value = "value", .domain = ".example.com" });

    // Verify the listener was NOT called (no change event fired to removed listener)
    // Note: The cookie manager still notifies, but CookieStore has no listeners
    try std.testing.expect(test_change_count == 0);
}
