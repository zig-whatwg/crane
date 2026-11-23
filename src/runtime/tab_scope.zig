//! A tab's scope: where what belongs to one tab lives, reached through the
//! realm (docs/instances.md, rule 2: "a realm will carry its Browser's scope
//! and its Tab's scope. Per-Browser and per-Tab state of a subsystem is a
//! supplement of that scope (Blink's `Supplementable`), made on first use and
//! destroyed with the scope").
//!
//! A tab is a top-level traversable: its top-level browsing context's record
//! (html.BrowsingContext), which ends after the last Window that showed it
//! (lesson architecture-what-a-tab-holds-ends-with-its-browsing-context-
//! record.md). That record makes the tab's scope on first use and CLOSES it
//! in its end - every slot's state ends there, the moment the tab's session
//! history and session storage always ended. The scope itself is counted:
//! the record holds it, each of the tab's frame contexts (a frame's context
//! names its tab for life, even after its parent link is cut), and each
//! Window realm that carries it (`runtime.ContextData.tab_scope`, set by the
//! Window and released at the Window's end). The last release frees it, so a
//! frame Window script still holds after its tab closed reads a closed scope,
//! never a freed one.
//!
//! What a tab holds that a lower layer cannot name - its session history, its
//! traversal queue, its frame clock, its session storage shed - is kept in a
//! SLOT: an owner makes it and hands it over (`put`), and the scope ends it,
//! in `Slot` order, when the tab closes. A slot is one load (`get`).
//!
//! THREADS: the Browser's window thread only. Everything a tab holds is
//! [Exposed=Window] state - sessionStorage, history, animation frames, focus -
//! and a worker, shared worker or service worker realm has no tab
//! (instances design 4.5), so nothing here is locked.

const std = @import("std");
const Allocator = std.mem.Allocator;
const engine = @import("engine");
const ContextData = @import("context.zig").ContextData;

/// How many tab scopes are alive - made and not yet freed - for diagnostics
/// (`liveCount`).
// process-wide: a diagnostics count over every Browser's tabs in the process (as BrowserScope's live_scopes counts scopes); every write is an atomic add or sub (std.atomic.Value), so tabs of Browsers on many threads never race it; tests read it to find a tab scope a tab's end left behind
var live_tabs: std.atomic.Value(usize) = .init(0);

pub const TabScope = struct {
    /// Its record's allocator: every slot's state is made and freed with it.
    allocator: Allocator,
    /// The tab's id: its top-level traversable's navigable id - the TabId the
    /// host lists (Browser.traversableIds) and the platform names a tab by.
    id: u64,
    /// The holders: the record, its frame contexts, its realms.
    refs: u32 = 1,
    /// The tab's record ended (HTML "destroy a top-level traversable"): its
    /// slots ended with it, and none is made again.
    closed: bool = false,
    /// HTML 7.3.1.1 "system visibility state" of the tab's traversable
    /// navigable: "determined by the user agent, including its initial value
    /// upon creation" (HTML 6.2) - the platform's.
    system_visibility: Visibility = .visible,
    /// HTML 6.6.2: whether the tab's top-level traversable "has system focus
    /// ... when it can receive keyboard input channeled from the operating
    /// system". True for every tab unless its Browser's host narrows focus to
    /// its active tab (the user's ruling, 2026-11-19: "Host decides, headless
    /// default").
    system_focus: bool = true,
    /// How many DevTools sessions emulate focus for this tab (CDP
    /// Emulation.setFocusEmulationEnabled): while one does, the tab answers
    /// as focused whatever its system focus is, as Chrome's emulated page
    /// does.
    focus_emulation: u32 = 0,
    /// The system focus the tab's pages last heard of (html.focus's
    /// SystemFocusTask fires the events of a change), and whether a task to
    /// tell them is queued: a change undone before it runs is never heard.
    focus_reported: bool = true,
    focus_task_queued: bool = false,
    slots: [slot_count]?*anyopaque = @splat(null),
    ends: [slot_count]?*const fn (ptr: *anyopaque, allocator: Allocator) void = @splat(null),

    /// HTML's system visibility state.
    pub const Visibility = enum { visible, hidden };

    /// The state a tab holds that its owner made, by kind. Declared in the
    /// order the tab's close ends them: the traversal queue before the
    /// session history its items name, as the record's end always did.
    pub const Slot = enum {
        /// html.navigation.TraversalQueue: the traversable navigable's
        /// session history traversal queue (HTML 7.4.1.3).
        traversal_queue,
        /// html.navigation.JointHistory: the traversable's session history.
        session_history,
        /// The tab's frame clock and its documents' animation frame
        /// bookkeeping (browser/rendering.zig).
        frames,
        /// storage.StorageShed: "a traversable navigable holds a storage
        /// shed" (Storage 4.3) - session storage.
        session_storage,
    };
    const slot_count = @typeInfo(Slot).@"enum".field_names.len;

    /// A new tab's scope, held once - by the record that made it.
    pub fn create(allocator: Allocator, id: u64) Allocator.Error!*TabScope {
        const self = try allocator.create(TabScope);
        self.* = .{ .allocator = allocator, .id = id };
        _ = live_tabs.fetchAdd(1, .monotonic);
        return self;
    }

    /// One more holder.
    pub fn retain(self: *TabScope) *TabScope {
        std.debug.assert(self.refs > 0);
        self.refs += 1;
        return self;
    }

    /// A holder lets go; the last frees the scope. A scope freed unclosed -
    /// its record never ended, a test's scope - ends its slots first.
    pub fn release(self: *TabScope) void {
        std.debug.assert(self.refs > 0);
        self.refs -= 1;
        if (self.refs != 0) return;
        self.close();
        const allocator = self.allocator;
        self.* = undefined;
        allocator.destroy(self);
        _ = live_tabs.fetchSub(1, .monotonic);
    }

    /// The tab's end - its record's: every slot's state ends, in `Slot`
    /// order, and none is made again. Once.
    pub fn close(self: *TabScope) void {
        if (self.closed) return;
        self.closed = true;
        for (&self.slots, &self.ends) |*slot, *end| {
            const ptr = slot.* orelse continue;
            slot.* = null;
            const end_fn = end.*;
            end.* = null;
            if (end_fn) |f| f(ptr, self.allocator);
        }
    }

    /// The state in `slot`, if its owner put it there.
    pub inline fn get(self: *const TabScope, comptime slot: Slot, comptime T: type) ?*T {
        const ptr = self.slots[@backingInt(slot)] orelse return null;
        return @ptrCast(@alignCast(ptr));
    }

    /// Hand `value` - made with this scope's allocator - to `slot`, which
    /// must be empty: it ends with the tab (`T.deinit`, then the block
    /// freed). A closed tab takes nothing: `value` is ended at once, and
    /// false returned - the caller must not keep it.
    pub fn put(self: *TabScope, comptime slot: Slot, comptime T: type, value: *T) bool {
        if (self.closed) {
            Destroy(T).destroy(value, self.allocator);
            return false;
        }
        const index = @backingInt(slot);
        std.debug.assert(self.slots[index] == null);
        self.slots[index] = value;
        self.ends[index] = Destroy(T).destroy;
        return true;
    }

    /// HTML 6.6.2: whether the tab's top-level traversable has system focus
    /// - or a DevTools session emulates it.
    pub inline fn hasSystemFocus(self: *const TabScope) bool {
        return self.system_focus or self.focus_emulation != 0;
    }

    /// The tab `realm` is of: a Window realm's own (`ContextData.tab_scope`),
    /// an isolated world's that of the main realm whose Window it wraps
    /// (engine.mainRealmOf - one load without worlds), a ShadowRealm's its
    /// principal realm's. Null for a realm of no tab: a worker's, one no
    /// Browser made, a Window's realm after the Window ended.
    pub fn ofRealm(realm: *ContextData) ?*TabScope {
        if (realm.tab_scope) |tab| return tab;
        if (realm.principal_realm) |principal| return ofRealm(principal);
        if (!realm.hasEngine()) return null;
        const main = engine.mainRealmOf(realm);
        if (main == realm) return null;
        return main.tab_scope;
    }

    /// How many tab scopes are alive in the process. Diagnostics only.
    pub fn liveCount() usize {
        return live_tabs.load(.monotonic);
    }

    fn Destroy(comptime T: type) type {
        return struct {
            fn destroy(ptr: *anyopaque, allocator: Allocator) void {
                const value: *T = @ptrCast(@alignCast(ptr));
                value.deinit();
                allocator.destroy(value);
            }
        };
    }
};
