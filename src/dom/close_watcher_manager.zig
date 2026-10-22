//! HTML 6.10.2 "close watcher infrastructure", the data model: "Each Window
//! has a close watcher manager", its groups of close watchers, the allowed
//! number of groups and whether the next user interaction allows a new
//! group; and the close watchers themselves.
//!
//! The manager is the Window's own state - Window's InternalState embeds one
//! - and no IDL member reaches it: the close watcher algorithms do
//! (src/html/close_watchers.zig), and so do the user activation notification
//! and the close request steps. So Window installs `of` from its
//! installHooks, as it installs dom.user_activation_state, and nothing here
//! imports Window. Two Browsers on two threads each have their own Windows,
//! and so their own managers: nothing in this module is shared but the
//! accessor.
//!
//! OWNERSHIP. The manager owns every close watcher it holds, from "establish
//! a close watcher" to the watcher's last reference. Its creators - a
//! CloseWatcher object, an element's popover, a dialog - keep no pointer to
//! it: they name their watcher by its kind and its owner (`find`). A
//! destroyed watcher is then simply not found, which is exactly how the
//! spec reads a watcher that is not active (requestClose returns true, close
//! returns). A watcher is freed when its last reference ends: the manager
//! holds one while it is active, and every algorithm that runs its actions
//! holds one across them - "close" runs the close action AFTER "destroy",
//! and a cancel action runs script that can destroy the watcher or end its
//! Window (lesson: a task that runs script frees its object after the
//! script). A watcher keeps its owner (node_holds.TaskHold) for as long as it
//! exists: an active CloseWatcher must still be told of a close request after
//! script dropped it, as Blink's CloseWatcherStack traces its watchers from
//! LocalDOMWindow.
//!
//! Spec: https://html.spec.whatwg.org/multipage/interaction.html#close-watcher-infrastructure
//!
//! lint-impls: hook for Window

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const process_start = @import("process_start.zig");
const node_holds = @import("node_holds.zig");

/// Whose close watcher it is: what `find` tells apart on one owner (an
/// element can be both a popover and a dialog).
pub const Kind = enum {
    /// A CloseWatcher object's internal close watcher.
    object,
    /// An element's popover close watcher (HTML 6.12).
    popover,
    /// A dialog element's close watcher (HTML 4.11.4).
    dialog,
};

/// A close watcher's algorithms, given its owner. None may throw.
pub const Actions = struct {
    /// "cancel action", given canPreventClose: true to proceed to the close
    /// action, false to bail out (only when canPreventClose is true).
    cancel: *const fn (owner: *runtime.Instance, can_prevent_close: bool) bool,
    /// "close action".
    close: *const fn (owner: *runtime.Instance) void,
    /// "get enabled state".
    enabled: *const fn (owner: *runtime.Instance) bool,
};

/// HTML "close watcher": its window is its manager's; the cancel action, the
/// close action and the get enabled state are its owner's `actions`.
pub const CloseWatcher = struct {
    kind: Kind,
    /// The object whose actions these are, kept while the watcher exists.
    owner: node_holds.TaskHold = .{},
    actions: *const Actions,
    /// "is running cancel action".
    is_running_cancel_action: bool = false,
    /// The manager whose groups hold it: non-null exactly while it is
    /// active. The manager's end clears it.
    manager: ?*Manager = null,
    /// The manager's reference while active, and one per algorithm running
    /// its actions.
    refs: u32 = 1,
    allocator: Allocator,

    /// HTML "is active": a group of its window's manager contains it.
    pub fn isActive(self: *const CloseWatcher) bool {
        return self.manager != null;
    }

    pub fn retain(self: *CloseWatcher) void {
        self.refs += 1;
    }

    /// End one reference; the last frees the watcher and lets its owner go.
    pub fn release(self: *CloseWatcher) void {
        std.debug.assert(self.refs != 0);
        self.refs -= 1;
        if (self.refs != 0) return;
        std.debug.assert(self.manager == null);
        self.owner.release();
        self.allocator.destroy(self);
    }
};

/// HTML "close watcher manager".
pub const Manager = struct {
    allocator: Allocator,
    /// The Window whose manager this is (set by its accessor).
    window: ?*runtime.Instance = null,
    /// "groups": a list of lists of close watchers, initially empty.
    groups: std.ArrayListUnmanaged(std.ArrayListUnmanaged(*CloseWatcher)) = .empty,
    /// "allowed number of groups", initially 1.
    allowed_number_of_groups: usize = 1,
    /// "next user interaction allows a new group", initially true.
    next_user_interaction_allows_a_new_group: bool = true,

    pub fn init(allocator: Allocator) Manager {
        return .{ .allocator = allocator };
    }

    /// The Window's teardown: every watcher stops being active - its link
    /// cleared while the manager still exists, so an algorithm still on the
    /// stack sees it inactive - and the manager's reference ends.
    pub fn deinit(self: *Manager) void {
        for (self.groups.items) |*group| {
            for (group.items) |watcher| {
                watcher.manager = null;
                watcher.release();
            }
            group.deinit(self.allocator);
        }
        self.groups.deinit(self.allocator);
        self.groups = .empty;
    }

    /// The active watcher of `kind` whose owner is `owner`, if any.
    pub fn find(self: *const Manager, kind: Kind, owner: *runtime.Instance) ?*CloseWatcher {
        for (self.groups.items) |group| {
            for (group.items) |watcher| {
                if (watcher.kind == kind and watcher.owner.get() == owner) return watcher;
            }
        }
        return null;
    }

    /// A new close watcher of `kind` for `owner`, not yet in any group.
    pub fn create(self: *Manager, kind: Kind, owner: *runtime.Instance, actions: *const Actions) Allocator.Error!*CloseWatcher {
        const watcher = try self.allocator.create(CloseWatcher);
        watcher.* = .{ .kind = kind, .actions = actions, .allocator = self.allocator };
        watcher.owner.take(owner);
        return watcher;
    }

    /// "Establish a close watcher" steps 4-5: append « watcher » to the
    /// groups while their size is less than the allowed number of groups,
    /// otherwise append it to the last group. The manager takes `watcher`'s
    /// first reference; on failure the caller still has it.
    pub fn add(self: *Manager, watcher: *CloseWatcher) Allocator.Error!void {
        if (self.groups.items.len < self.allowed_number_of_groups) {
            try self.groups.ensureUnusedCapacity(self.allocator, 1);
            var group: std.ArrayListUnmanaged(*CloseWatcher) = .empty;
            try group.append(self.allocator, watcher);
            self.groups.appendAssumeCapacity(group);
        } else {
            // 5.1. Assert: the groups' size is at least 1, since the allowed
            // number of groups is always at least 1.
            std.debug.assert(self.groups.items.len >= 1);
            // 5.2. Append closeWatcher to the groups' last item.
            try self.groups.items[self.groups.items.len - 1].append(self.allocator, watcher);
        }
        watcher.manager = self;
    }

    /// "Destroy" steps 2-3: remove `watcher` from every group, then remove
    /// every empty group; the manager's reference ends. Nothing for a
    /// watcher that is not active.
    pub fn remove(self: *Manager, watcher: *CloseWatcher) void {
        if (watcher.manager != self) return;
        for (self.groups.items) |*group| {
            var i: usize = 0;
            while (i < group.items.len) {
                if (group.items[i] == watcher) _ = group.orderedRemove(i) else i += 1;
            }
        }
        var g: usize = 0;
        while (g < self.groups.items.len) {
            if (self.groups.items[g].items.len == 0) {
                var empty = self.groups.orderedRemove(g);
                empty.deinit(self.allocator);
            } else g += 1;
        }
        watcher.manager = null;
        watcher.release();
    }
};

/// What Window supplies.
pub const Implementation = struct {
    /// `window`'s manager, or null when `window` is not a Window (or its
    /// state is gone).
    of: *const fn (window: *runtime.Instance) ?*Manager,
};

// process-wide: Window installs one immutable accessor at process start (process_start.zig); each Manager it returns is that Window's own state, of its own Browser
var implementation: ?Implementation = null;

/// Called by Window's installHooks, once, at process start.
pub fn install(impl: Implementation) void {
    process_start.assertInstalling();
    implementation = impl;
}

/// `window`'s close watcher manager; null when it has none (not a Window,
/// its state torn down, or no Window impl installed - a test realm).
pub fn of(window: *runtime.Instance) ?*Manager {
    const impl = implementation orelse return null;
    return impl.of(window);
}
