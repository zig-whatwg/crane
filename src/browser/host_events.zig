//! What a Browser tells its host as it happens: its tabs and frames coming
//! and going (the instances design's host API, section 5.3 - WebDriver BiDi's
//! browsingContext.contextCreated / contextDestroyed, CDP's Target and Page
//! frame events). One list of listeners per Browser - the host API's event
//! callback (BrowserHost, the C ABI's on_event), a DevTools session, a
//! WebDriver session - each told every event, in order, on the Browser's
//! thread.
//!
//! A listener only records or queues: it must not run script - except for
//! `document_start`, which exists for that - and must not close or create
//! tabs from inside the call (the Browser is in the middle of the step that
//! made the event). It may add or remove listeners; one removed
//! during a delivery is not called again.
//!
//! The source is the Browser's navigation observer (lane life1's
//! html.navigation.observer), whose one slot the Browser sets to its own
//! dispatcher (lane cdph's agreement through main, 5:58 PM ET 2026-11-21):
//! every milestone is passed on as a `navigation` event, and its
//! navigable_created / navigable_destroyed become tab_created /
//! frame_created / tab_destroyed / frame_destroyed first - the host's own
//! tabs and the ones script opens alike.

const std = @import("std");

/// A navigation milestone (html.navigation.observer.Milestone).
pub const Milestone = @import("html").navigation.observer.Milestone;
/// A new document ready for host scripts (html.navigation.document_start).
pub const DocumentStart = @import("html").navigation.document_start.Start;
/// A simple dialog opening and closing (html.navigation.user_prompts).
pub const DialogOpening = @import("html").navigation.user_prompts.Opening;
pub const DialogClosed = @import("html").navigation.user_prompts.Closed;
pub const DialogAnswer = @import("html").navigation.user_prompts.DialogAnswer;
pub const DialogKind = @import("html").navigation.user_prompts.Kind;
/// A page asking for a new window (html.navigation.window_open).
pub const WindowOpen = @import("html").navigation.window_open.Opened;
/// An open dialog as a host reads it from any thread
/// (BrowserHost.userPromptOf).
pub const UserPromptInfo = @import("html").simple_dialogs.Info;

/// A tab: its top-level traversable's browsing context id (process-unique,
/// kept for its life; the BiDi navigable id, the source of CDP's target id).
pub const TabId = u64;

/// Who made a top-level traversable.
pub const MadeBy = enum {
    /// The host: the Browser's first page, or a tab it opened (createTab).
    host,
    /// A page's script: window.open(), or a link's or a form's target.
    page,
};

pub const Event = union(enum) {
    /// A new top-level traversable, after it exists with its initial
    /// about:blank document and before its first navigation starts.
    tab_created: TabCreated,
    /// A top-level traversable is gone: after HTML "close a top-level
    /// traversable" - its documents unloaded and destroyed (instances design
    /// 4.7 step 6) - so the host never hears of a tab it cannot use that
    /// still runs.
    tab_destroyed: struct { tab: TabId },
    /// A child navigable (an iframe's) was made under `parent`.
    frame_created: struct { navigable: u64, parent: u64 },
    /// A child navigable was destroyed.
    frame_destroyed: struct { navigable: u64 },
    /// A navigation milestone of one of the Browser's navigables, at its
    /// spec step (html.navigation.observer: BORROWED for the call).
    navigation: *const Milestone,
    /// A new document's Window realm is set up and none of the document's
    /// own scripts has run (html.navigation.document_start; Blink's
    /// DidCreateMainWorldContext): the one event a listener MAY run script
    /// for - a host's scripts for every new document (CDP
    /// Page.addScriptToEvaluateOnNewDocument), in its main world or in world
    /// realms it makes. BORROWED for the call.
    document_start: *const DocumentStart,
    /// A simple dialog opens (WebDriver BiDi "user prompt opened"; HTML
    /// 8.9.1, beforeunload's prompt), before the Browser thread pauses for
    /// it: its tab, kind, message, default and URL, the `answer` any host may
    /// call from ANY thread (at most once; false when already answered or
    /// closed), and `claim`, which a host that will answer sets (else the
    /// platform's dialog answers). BORROWED for the call.
    dialog_opening: *const DialogOpening,
    /// The dialog closed, whoever answered (WebDriver BiDi "user prompt
    /// closed"). BORROWED for the call.
    dialog_closed: *const DialogClosed,
    /// A page asks for a new window - window.open(), or a link or form whose
    /// target names none - before the new top-level traversable is made
    /// (CDP's Page.windowOpen; Blink's probe::WindowOpen): the opener's tab
    /// and navigable, the URL, the name and the features. tab_created
    /// follows when the window is made. BORROWED for the call.
    window_open: *const WindowOpen,

    pub const TabCreated = struct {
        tab: TabId,
        /// The traversable whose page opened it, while that is not noopener.
        opener: ?TabId = null,
        made_by: MadeBy,
        /// The URL its first navigation will go to ("about:blank" when it
        /// stays on its initial document). BORROWED for the call.
        url: []const u8 = "about:blank",
    };
};

/// A host's side.
pub const Listener = struct {
    context: *anyopaque,
    on_event: *const fn (context: *anyopaque, event: *const Event) void,

    fn same(a: Listener, b: Listener) bool {
        return a.context == b.context and a.on_event == b.on_event;
    }
};

/// One Browser's listeners. Browser-thread only.
pub const Listeners = struct {
    /// Null for one removed while a delivery was under way (compacted when
    /// the outermost delivery ends).
    items: std.ArrayListUnmanaged(?Listener) = .empty,
    /// How many deliveries are under way (a listener may cause another).
    delivering: u32 = 0,

    pub fn deinit(self: *Listeners, allocator: std.mem.Allocator) void {
        self.items.deinit(allocator);
    }

    pub fn add(self: *Listeners, allocator: std.mem.Allocator, listener: Listener) std.mem.Allocator.Error!void {
        try self.items.append(allocator, listener);
    }

    /// `listener` hears nothing more, from now on - a delivery under way
    /// included.
    pub fn remove(self: *Listeners, listener: Listener) void {
        for (self.items.items, 0..) |item, i| {
            const present = item orelse continue;
            if (!present.same(listener)) continue;
            if (self.delivering > 0) {
                self.items.items[i] = null;
            } else {
                _ = self.items.orderedRemove(i);
            }
            return;
        }
    }

    pub fn count(self: *const Listeners) usize {
        var n: usize = 0;
        for (self.items.items) |item| {
            if (item != null) n += 1;
        }
        return n;
    }

    /// Tell every listener `event`, in the order they were added. Listeners
    /// added during the delivery hear the next event, not this one.
    pub fn emit(self: *Listeners, event: Event) void {
        if (self.items.items.len == 0) return;
        self.delivering += 1;
        const end = self.items.items.len;
        var i: usize = 0;
        while (i < end and i < self.items.items.len) : (i += 1) {
            const listener = self.items.items[i] orelse continue;
            listener.on_event(listener.context, &event);
        }
        self.delivering -= 1;
        if (self.delivering == 0) {
            var write: usize = 0;
            for (self.items.items) |item| {
                if (item == null) continue;
                self.items.items[write] = item;
                write += 1;
            }
            self.items.shrinkRetainingCapacity(write);
        }
    }
};

test "listeners hear events in order; one removed during a delivery is not called again" {
    const testing = std.testing;
    const Recorder = struct {
        heard: std.ArrayListUnmanaged(TabId) = .empty,
        list: ?*Listeners = null,
        remove_on_event: ?Listener = null,

        fn onEvent(context: *anyopaque, event: *const Event) void {
            const self: *@This() = @ptrCast(@alignCast(context));
            switch (event.*) {
                .tab_created => |created| self.heard.append(testing.allocator, created.tab) catch {},
                else => {},
            }
            if (self.remove_on_event) |other| self.list.?.remove(other);
        }
    };
    var listeners: Listeners = .{};
    defer listeners.deinit(testing.allocator);
    var first: Recorder = .{ .list = &listeners };
    defer first.heard.deinit(testing.allocator);
    var second: Recorder = .{ .list = &listeners };
    defer second.heard.deinit(testing.allocator);
    const second_listener: Listener = .{ .context = &second, .on_event = Recorder.onEvent };
    try listeners.add(testing.allocator, .{ .context = &first, .on_event = Recorder.onEvent });
    try listeners.add(testing.allocator, second_listener);
    // The first removes the second while the first event is delivered.
    first.remove_on_event = second_listener;
    listeners.emit(.{ .tab_created = .{ .tab = 7, .made_by = .host } });
    listeners.emit(.{ .tab_created = .{ .tab = 8, .made_by = .page } });
    try testing.expectEqualSlices(TabId, &.{ 7, 8 }, first.heard.items);
    try testing.expectEqualSlices(TabId, &.{}, second.heard.items);
    try testing.expectEqual(@as(usize, 1), listeners.count());
}
