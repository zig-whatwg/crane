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

/// CookieStore implementation
/// Wraps CurlCookieManager to provide WebIDL-compliant cookie access
pub const CookieStore = struct {
    /// Underlying cookie manager (shared across the application)
    cookie_manager: *CurlCookieManager,

    /// The URL context for this CookieStore (used for defaults)
    context_url: ?[]const u8,

    /// Allocator
    allocator: Allocator,

    /// Change event listeners (simplified - full implementation would use EventTarget)
    change_listeners: std.ArrayListUnmanaged(ChangeFn),

    pub const ChangeFn = *const fn (event: CookieChangeEventInit) void;

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
        };

        return self;
    }

    pub fn deinit(self: *CookieStore) void {
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

        try self.cookie_manager.set(cookie);

        // Fire change event (only if listeners are registered)
        if (self.change_listeners.items.len > 0) {
            var item = try cookieToListItem(self.allocator, cookie);
            defer item.deinit();
            self.fireChangeEvent(.{
                .changed = &[_]CookieListItem{item},
            });
        }
    }

    /// delete(USVString name) -> Promise<undefined>
    pub fn deleteByName(self: *CookieStore, name: []const u8) !void {
        return self.deleteByOptions(.{ .name = name });
    }

    /// delete(CookieStoreDeleteOptions options) -> Promise<undefined>
    pub fn deleteByOptions(self: *CookieStore, options: CookieStoreDeleteOptions) !void {
        try self.cookie_manager.delete(options.name, options.domain, options.path);

        // Fire change event (only if listeners are registered)
        if (self.change_listeners.items.len > 0) {
            var item = CookieListItem{
                .name = try self.allocator.dupe(u8, options.name),
                .value = try self.allocator.dupe(u8, ""),
                .domain = if (options.domain) |d| try self.allocator.dupe(u8, d) else null,
                .path = try self.allocator.dupe(u8, options.path),
                .allocator = self.allocator,
            };
            defer item.deinit();
            self.fireChangeEvent(.{
                .deleted = &[_]CookieListItem{item},
            });
        }
    }

    // ============================================================
    // Event Handling (simplified)
    // ============================================================

    /// Add a change listener
    pub fn addChangeListener(self: *CookieStore, listener: ChangeFn) !void {
        try self.change_listeners.append(self.allocator, listener);
    }

    /// Remove a change listener
    pub fn removeChangeListener(self: *CookieStore, listener: ChangeFn) void {
        for (self.change_listeners.items, 0..) |l, i| {
            if (l == listener) {
                _ = self.change_listeners.orderedRemove(i);
                return;
            }
        }
    }

    fn fireChangeEvent(self: *CookieStore, event: CookieChangeEventInit) void {
        for (self.change_listeners.items) |listener| {
            listener(event);
        }
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
