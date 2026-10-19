//! What the Cookie Store API's platform objects keep, and the query their
//! get() and getAll() run.
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! CookieStore and CookieChangeEvent keep these as their state, each in its
//! own impl, which makes, owns and frees it (lesson
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
