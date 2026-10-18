//! What the Cookie Store API's platform objects keep, and the query their
//! get() and getAll() run.
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! CookieStore, CookieStoreManager and CookieChangeEvent keep these as their
//! state, each in its own impl, which makes, owns and frees it (lesson
//! architecture-move-the-states-type-out-of-the-impl-not-the-state): only the
//! TYPES are here, beside the jar and the algorithms they use, so that what
//! they do is testable without an engine. Nothing here touches one.

const std = @import("std");
const cookiestore = @import("root.zig");

const CookieJar = cookiestore.CookieJar;
const CookieListItem = cookiestore.CookieListItem;
const CookieChangeObserver = cookiestore.CookieChangeObserver;

// ============================================================================
// CookieStore
// ============================================================================

/// A CookieStore's state.
///
/// The cookies are not here: they are the user agent's, in the jar the
/// store's relevant settings object reaches, which fetch, navigations and
/// document.cookie use too.
pub const CookieStoreState = struct {
    /// Whether this store is in a secure context
    is_secure_context: bool,
    /// Owned jar changes awaiting transfer to their event task. Each
    /// delivery transfers its records before another delivery can arrive.
    change_observer: CookieChangeObserver,
    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, is_secure_context: bool) !*CookieStoreState {
        const internal = try allocator.create(CookieStoreState);
        internal.* = CookieStoreState{
            .is_secure_context = is_secure_context,
            .change_observer = CookieChangeObserver.init(allocator),
            .allocator = allocator,
        };
        return internal;
    }

    pub fn deinit(self: *CookieStoreState) void {
        self.change_observer.deinit();
        self.allocator.destroy(self);
    }
};

// The jar is synchronous; everything asynchronous about the CookieStore
// interface is the Promise wrapper. Keeping the query out of the engine code
// makes it testable without an isolate - see
// tests/cookiestore/query_items_test.zig.

/// Cookie Store "query cookies" given `url` (serialized) and `name`:
/// `jar`'s cookies for the URL as a "non-HTTP" API sees them - no HttpOnly
/// cookie - those named `name`, or all for null.
///
/// https://cookiestore.spec.whatwg.org/#query-cookies
///
/// Caller owns the list and each item; pass both to `freeItems`.
pub fn queryItems(
    allocator: std.mem.Allocator,
    jar: *CookieJar,
    url: []const u8,
    name: ?[]const u8,
) !std.ArrayListUnmanaged(CookieListItem) {
    const parts = cookiestore.RequestUrl.of(url) orelse return .empty;
    return cookiestore.queryCookies(allocator, jar, parts.host, parts.path, name);
}

/// Release a list returned by `queryItems`.
pub fn freeItems(
    allocator: std.mem.Allocator,
    items: *std.ArrayListUnmanaged(CookieListItem),
) void {
    for (items.items) |*item| item.deinit();
    items.deinit(allocator);
}

// ============================================================================
// CookieStoreManager
// ============================================================================

/// A cookie subscription (matches CookieStoreGetOptions)
pub const CookieSubscription = struct {
    /// Cookie name to subscribe to (null = all cookies)
    name: ?[]const u8,
    /// URL to scope subscription to (null = registration scope)
    url: ?[]const u8,

    /// Allocator for owned strings
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: ?[]const u8, url: ?[]const u8) !Self {
        return Self{
            .name = if (name) |n| try allocator.dupe(u8, n) else null,
            .url = if (url) |u| try allocator.dupe(u8, u) else null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.name) |n| self.allocator.free(n);
        if (self.url) |u| self.allocator.free(u);
        self.* = undefined;
    }

    pub fn clone(self: Self, allocator: std.mem.Allocator) !Self {
        return Self.init(allocator, self.name, self.url);
    }

    /// Check if two subscriptions are equal (for deduplication)
    pub fn eql(self: Self, other: Self) bool {
        const name_eq = if (self.name) |n1| blk: {
            if (other.name) |n2| {
                break :blk std.mem.eql(u8, n1, n2);
            }
            break :blk false;
        } else other.name == null;

        const url_eq = if (self.url) |url1| blk: {
            if (other.url) |url2| {
                break :blk std.mem.eql(u8, url1, url2);
            }
            break :blk false;
        } else other.url == null;

        return name_eq and url_eq;
    }
};

/// A CookieStoreManager's state.
pub const CookieStoreManagerState = struct {
    /// List of active subscriptions
    subscriptions: std.ArrayListUnmanaged(CookieSubscription),

    /// The scope URL for this manager (from ServiceWorkerRegistration)
    scope_url: ?[]const u8,

    /// Whether this is in a secure context
    is_secure_context: bool,

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, scope_url: ?[]const u8, is_secure_context: bool) !*CookieStoreManagerState {
        const internal = try allocator.create(CookieStoreManagerState);
        errdefer allocator.destroy(internal);

        const scope_copy = if (scope_url) |s| try allocator.dupe(u8, s) else null;
        errdefer if (scope_copy) |s| allocator.free(s);

        internal.* = CookieStoreManagerState{
            .subscriptions = .empty,
            .scope_url = scope_copy,
            .is_secure_context = is_secure_context,
            .allocator = allocator,
        };

        return internal;
    }

    pub fn deinit(self: *CookieStoreManagerState) void {
        for (self.subscriptions.items) |*sub| {
            sub.deinit();
        }
        self.subscriptions.deinit(self.allocator);

        if (self.scope_url) |s| {
            self.allocator.free(s);
        }

        self.allocator.destroy(self);
    }

    /// Add a subscription (with deduplication)
    pub fn addSubscription(self: *CookieStoreManagerState, name: ?[]const u8, url: ?[]const u8) !void {
        // Check for duplicate
        for (self.subscriptions.items) |existing| {
            const new_sub = CookieSubscription{
                .name = name,
                .url = url,
                .allocator = self.allocator,
            };
            if (existing.eql(new_sub)) {
                return; // Already exists
            }
        }

        const sub = try CookieSubscription.init(self.allocator, name, url);
        try self.subscriptions.append(self.allocator, sub);
    }

    /// Remove a subscription
    pub fn removeSubscription(self: *CookieStoreManagerState, name: ?[]const u8, url: ?[]const u8) void {
        const to_remove = CookieSubscription{
            .name = name,
            .url = url,
            .allocator = self.allocator,
        };

        var i: usize = 0;
        while (i < self.subscriptions.items.len) {
            if (self.subscriptions.items[i].eql(to_remove)) {
                var removed = self.subscriptions.orderedRemove(i);
                removed.deinit();
            } else {
                i += 1;
            }
        }
    }

    /// Check if a URL is within the scope
    pub fn isWithinScope(self: *CookieStoreManagerState, url: []const u8) bool {
        const scope = self.scope_url orelse return true; // No scope = allow all
        return std.mem.startsWith(u8, url, scope);
    }
};

// ============================================================================
// CookieChangeEvent
// ============================================================================

/// A CookieChangeEvent's state.
pub const CookieChangeEventState = struct {
    /// Changed cookies (FrozenArray<CookieListItem>)
    changed: std.ArrayListUnmanaged(CookieListItem),

    /// Deleted cookies (FrozenArray<CookieListItem>)
    deleted: std.ArrayListUnmanaged(CookieListItem),

    /// The attributes' values: `[SameObject] FrozenArray<CookieListItem>`,
    /// each made on its first read and returned on every read after - one
    /// frozen array per attribute for the event's life, kept by an edge from
    /// the event's wrapper (CookieChangeEvent's `changed_slot` and
    /// `deleted_slot`), never a root. The event lets them go.
    has_changed_array: bool = false,
    has_deleted_array: bool = false,

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*CookieChangeEventState {
        const internal = try allocator.create(CookieChangeEventState);
        internal.* = CookieChangeEventState{
            .changed = .empty,
            .deleted = .empty,
            .allocator = allocator,
        };
        return internal;
    }

    pub fn deinit(self: *CookieChangeEventState) void {
        for (self.changed.items) |*item| {
            item.deinit();
        }
        self.changed.deinit(self.allocator);

        for (self.deleted.items) |*item| {
            item.deinit();
        }
        self.deleted.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Add a changed cookie
    pub fn addChanged(self: *CookieChangeEventState, item: CookieListItem) !void {
        try self.changed.append(self.allocator, item);
    }

    /// Add a deleted cookie
    pub fn addDeleted(self: *CookieChangeEventState, item: CookieListItem) !void {
        try self.deleted.append(self.allocator, item);
    }
};
