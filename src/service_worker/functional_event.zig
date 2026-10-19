//! A functional event on its way to a registration's active worker (Service
//! Workers "Fire Functional Event"): what the event is made with on the
//! worker's thread, copied when the user agent decided to fire it - before
//! the worker is started and the task queued (lesson
//! spec-compliance-capture-cookie-changes-before-queueing). One kind today:
//! Cookie Store's `cookiechange` (ExtendableCookieChangeEvent); push, sync
//! and the rest are kinds of the same thing.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#fire-functional-event

const std = @import("std");
const Allocator = std.mem.Allocator;
const cookiestore = @import("cookiestore");

/// Cookie Store "prepare lists" (7.4): a changed cookie's item has its
/// value; a deleted one's has none. OWNED (the event's).
pub const CookieChangeLists = struct {
    changed: []cookiestore.CookieListItem = &.{},
    deleted: []cookiestore.CookieListItem = &.{},

    /// The lists for one change of `cookie` (borrowed).
    pub fn ofChange(allocator: Allocator, change_type: cookiestore.CookieChangeType, cookie: *const cookiestore.Cookie) Allocator.Error!CookieChangeLists {
        const items = try allocator.alloc(cookiestore.CookieListItem, 1);
        errdefer allocator.free(items);
        // 3.1. Create a CookieListItem from the cookie.
        items[0] = try cookiestore.CookieListItem.init(allocator, cookie.name, if (change_type == .changed) cookie.value else "");
        return switch (change_type) {
            // 3.2. changed: appended to changedList.
            .changed => .{ .changed = items },
            // 3.3. Otherwise: its value is undefined, appended to deletedList.
            .deleted => blk: {
                items[0].has_value = false;
                break :blk .{ .deleted = items };
            },
        };
    }

    pub fn deinit(self: *CookieChangeLists, allocator: Allocator) void {
        for (self.changed) |*item| item.deinit();
        allocator.free(self.changed);
        for (self.deleted) |*item| item.deinit();
        allocator.free(self.deleted);
        self.* = .{};
    }
};

pub const FunctionalEvent = struct {
    allocator: Allocator,
    /// The registration it is fired on (Fire Functional Event's input): its
    /// staleness decides steps 3.1, 5.1 and 8's Soft Update.
    registration_id: u64,
    kind: Kind,

    pub const Kind = union(enum) {
        /// Cookie Store 7.4 step 2.5: "cookiechange" using
        /// ExtendableCookieChangeEvent, with changed and deleted.
        cookie_change: CookieChangeLists,
    };

    /// The event's name (Fire Functional Event's eventName).
    pub fn name(self: *const FunctionalEvent) []const u8 {
        return switch (self.kind) {
            .cookie_change => "cookiechange",
        };
    }

    /// OWNED by the caller until handed on; `destroy` ends it.
    pub fn create(allocator: Allocator, registration_id: u64, kind: Kind) Allocator.Error!*FunctionalEvent {
        const self = try allocator.create(FunctionalEvent);
        self.* = .{ .allocator = allocator, .registration_id = registration_id, .kind = kind };
        return self;
    }

    pub fn destroy(self: *FunctionalEvent) void {
        switch (self.kind) {
            .cookie_change => |*lists| lists.deinit(self.allocator),
        }
        self.allocator.destroy(self);
    }
};
