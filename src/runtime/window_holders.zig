//! What may keep a Window past its realm's end, and whether a Window's slab
//! slot may go back to its Browser's slab (lane winslot1).
//!
//! A realm's end tears its Window down (context_manager.removeContextByKey);
//! a page makes a new Window per navigation. The slot can go back - to be
//! issued again, to any type - only once nothing reads the old address as
//! that Window: every holder that can outlive the realm reads it through a
//! slab-generation check (`Link`), is cleared at the Window's teardown, or
//! keeps the WindowProxy instead (a traced edge). The inventory of holders
//! is tmp/analysis/winslot1/inventory.txt in the lane's evidence; each kind
//! that needed work is a `Holder`.
//!
//! The decision is an ALLOWLIST (AGENTS.md: a gate defaults to the safe
//! answer). A holder kind is safe for a reused slot only once its conversion
//! has landed with its forced-reuse test, and that commit lists it in
//! `safe`. `reusable` - may the slot go back at all - is true only when every
//! kind is listed; a kind added to `Holder` and not to `safe` turns it false,
//! and the Window keeps its slot until its Browser ends, as before.

const std = @import("std");
const Instance = @import("instance.zig").Instance;
const Context = @import("context.zig").Context;
const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
const instance_lifecycle = @import("instance_lifecycle.zig");

/// A Window held across its realm's end: the address, its slab generation
/// and its realm when it was taken. WebKit's `WeakPtr<LocalDOMWindow>`
/// (LocalDOMWindowProperty): a reference that reads "gone" once the window
/// is, never the object that took its place.
pub const Link = struct {
    instance: *Instance,
    generation: u64,
    realm: Context,

    pub fn of(window: *Instance) Link {
        return .{ .instance = window, .generation = SlabAllocator.generationOf(window), .realm = window.ctx };
    }

    /// The Window while it is the one taken: its slot not reissued (the
    /// generation), its teardown not begun (the realm's end marks it), and
    /// its realm still able to run script (a detached realm the collector
    /// took has none, before its end runs). Reads only the slot's stamp and
    /// the realm record - never the Window.
    pub fn get(self: Link) ?*Instance {
        if (SlabAllocator.generationOf(self.instance) != self.generation) return null;
        if (instance_lifecycle.isCleanupStarted(self.instance)) return null;
        if (!self.realm.hasEngine() and self.realm.agent != null) return null;
        return self.instance;
    }

    /// Whether `other` is this Window - the same address AND the slot not
    /// reissued since. Compares only; reads neither.
    pub fn is(self: Link, other: *const anyopaque) bool {
        return @intFromPtr(self.instance) == @intFromPtr(other) and
            SlabAllocator.generationOf(self.instance) == self.generation;
    }
};

/// Every kind of holder the inventory found reading a Window without such a
/// check, and the engine paths that could reach a freed Window.
pub const Holder = enum {
    /// A browsing context's active window (html BrowsingContext).
    browsing_context_active_window,
    /// A popup Window's stored opener (Window's opener fallback).
    window_opener,
    /// MessageEvent's source, its WindowProxy arm.
    message_event_source,
    /// UIEvent's view, for every subclass.
    ui_event_view,
    /// An event's target, currentTarget and related target.
    event_targets,
    /// A page the back/forward cache keeps (dom.bfcache.KeptPage).
    bfcache_kept_page,
    /// The event loop's suspended groups, read for idle requests.
    suspended_idle_request,
    /// A navigation's source global, read for its timing reporter.
    navigation_source_reporter,
    /// A fetch's CSP, timing and integrity reporters.
    fetch_reporters,
    /// Navigation's own reads of its window.
    navigation_window_reads,
    /// The WindowProxy's and the hidden global's native pointer.
    engine_window_proxy_field,
    /// The WindowProperties object's native pointer.
    engine_window_properties_field,
    /// A torn-down Window wrapped in another realm's cache (E3).
    engine_foreign_window_wrapper,
    /// A Window whose detached realm was collected, converted (E4).
    engine_collected_realm_global,
    /// A teardown ended inside another (E9).
    nested_teardown_coordinator,
};

/// The kinds whose conversion has landed, each with its test. Append a kind
/// in the commit that makes it safe; never by hand otherwise.
const safe = [_]Holder{
    .engine_foreign_window_wrapper, // tests/v8/window_dead_conversion_test.zig
    .engine_collected_realm_global, // tests/v8/window_collected_realm_conversion_test.zig
    .nested_teardown_coordinator, // tests/v8/cleanup_coordinator_nested_test.zig
    .message_event_source, // tests/html/winslot_proxy_holders_test.zig
    .ui_event_view, // tests/html/winslot_proxy_holders_test.zig
    .browsing_context_active_window, // tests/html/winslot_browsing_context_test.zig
    .event_targets, // tests/v8/winslot_event_target_test.zig
    .window_opener, // the opener realm outlives its popups' (a realm's children end first); tests/html/winslot_reporters_test.zig reads the fallback
    .bfcache_kept_page, // tests/html/winslot_reporters_test.zig
    .suspended_idle_request, // the same generation check as groupOf; reached only through the idle scheduler
    .navigation_source_reporter, // GuardedReporter.liveGlobal; no script reaches the window between beforeunload and the read
    .fetch_reporters, // tests/html/winslot_reporters_test.zig
    .navigation_window_reads, // same realm; the generation the Navigation keeps
};

/// Whether `holder` is in `table`. Every kind a table does not list is
/// unsafe.
pub fn safeForReusedSlotIn(comptime table: []const Holder, holder: Holder) bool {
    for (table) |listed| {
        if (listed == holder) return true;
    }
    return false;
}

/// Whether `holder` is safe for a reused Window slot.
pub fn safeForReusedSlot(holder: Holder) bool {
    return safeForReusedSlotIn(&safe, holder);
}

/// Whether every kind is in `table`.
pub fn reusableWith(comptime table: []const Holder) bool {
    for (std.enums.values(Holder)) |holder| {
        if (!safeForReusedSlotIn(table, holder)) return false;
    }
    return true;
}

/// May a torn-down Window's slot go back to its Browser's slab: only once
/// every holder kind is safe.
pub const reusable: bool = reusableWith(&safe);
