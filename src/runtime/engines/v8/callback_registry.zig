//! Every live V8 `CallbackWrapper`, so that a context's teardown can release
//! the handles its callbacks hold.
//!
//! A callback's `Global<Function>` points into the context that created it,
//! and so does its context handle, so one registered event listener keeps its
//! whole page alive. Nothing releases them otherwise: a page's EventTargets are
//! not torn down with their context (the slab frees them in bulk), and
//! EventTarget's teardown deliberately leaves listener callbacks alone.
//!
//! `cleanupForContext` RESETS the handles and leaves each wrapper in place.
//! Freeing wrappers here would be a use-after-free: a dispatch in progress
//! holds a snapshot of listener records, and a listener can tear down its own
//! frame. An emptied wrapper answers that snapshot with no function, and its
//! owner still frees it through `deinit`.

const std = @import("std");
const v8 = @import("ffi.zig");
const callback_wrapper = @import("callback_wrapper.zig");
const CallbackWrapper = callback_wrapper.CallbackWrapper;
/// The agent records, where each agent's wrappers are tracked.
const protocol_agents = @import("protocol_agents.zig");

/// One agent's wrappers not yet deinitialized: a field of its record
/// (protocol_agents.AgentRecord.callbacks). A wrapper belongs to the agent of
/// its isolate (`CallbackWrapper.isolate`), and is made and freed on that
/// agent's thread. It was a `threadlocal`, every agent's on the thread in one
/// set.
///
/// Its storage is the agent's allocator's (AgentOptions.allocator, taken at
/// the first wrapper) and goes at the agent's end (`endAgent`). It KEEPS its
/// capacity when its last wrapper leaves: every addEventListener and
/// removeEventListener converts its callback argument into a wrapper that
/// joins the set and leaves it again, so a set that freed its storage
/// whenever it emptied - as this one did, on page_allocator - mapped and
/// unmapped a page per call (80% of events.add-remove-listener, lane perf2
/// batch 2). WTF's HashTable never frees a table its last entry leaves
/// either: it shrinks only while it is larger than its minimum (WebKit
/// Source/WTF/wtf/HashTable.h `shouldShrink`, `tableSize >
/// KeyTraits::minimumTableSize`; Blink platform/wtf/hash_table.h
/// `ShouldShrink`; minimum 8 in both), and only `clear()` or its end frees it.
pub const Live = struct {
    // tombstones: cleared whenever its last wrapper goes (clearRetainingCapacity resets every slot), which an add/remove pair and each page's end bring; a 1,069-file runner sample found it empty at every sampled insert
    set: std.AutoHashMapUnmanaged(*CallbackWrapper, void) = .empty,
    /// The agent's allocator, from its first wrapper on.
    allocator: ?std.mem.Allocator = null,

    pub const empty: Live = .{};

    /// How many wrappers the agent tracks.
    pub fn count(self: *const Live) usize {
        return self.set.count();
    }

    /// How many the storage holds without growing.
    pub fn capacity(self: *const Live) usize {
        return self.set.capacity();
    }

    /// Forget every wrapper and keep the storage: an empty table has no
    /// tombstones.
    fn emptied(self: *Live) void {
        if (self.set.count() == 0) self.set.clearRetainingCapacity();
    }
};

/// Track `wrapper` on its agent. Idempotent. Called by the wrapper's
/// constructors. A wrapper of an isolate createAgent did not make (a test's
/// own) is not tracked: its handles live until its owner deinitializes it,
/// as they did before tracking - and as an allocation failure here leaves
/// any wrapper.
pub fn register(wrapper: *CallbackWrapper) void {
    const live = protocol_agents.callbacksOf(wrapper.isolate) orelse return;
    const allocator = live.allocator orelse allocator: {
        const record = protocol_agents.recordOf(wrapper.isolate) orelse return;
        live.allocator = record.allocator;
        break :allocator record.allocator;
    };
    live.set.put(allocator, wrapper, {}) catch {};
}

/// Stop tracking `wrapper`. Called by `CallbackWrapper.deinit`.
pub fn unregister(wrapper: *CallbackWrapper) void {
    const live = protocol_agents.callbacksOf(wrapper.isolate) orelse return;
    _ = live.set.remove(wrapper);
    live.emptied();
}

/// Release the handles of every wrapper the current agent made for the
/// context whose raw V8 address is `context_raw_addr`, and stop tracking
/// them. Call while the isolate is alive and current - the context's realm
/// ending (context_manager.removeContextByKey, protocol_realms.detach) - before
/// the context's entry goes.
pub fn cleanupForContext(context_raw_addr: ?*anyopaque) void {
    const addr = context_raw_addr orelse return;
    const isolate = v8.v8_Isolate_GetCurrent() orelse return;
    const live = protocol_agents.callbacksOf(isolate) orelse return;
    // A set with no allocator has never held a wrapper.
    const allocator = live.allocator orelse return;
    var matched: std.ArrayListUnmanaged(*CallbackWrapper) = .empty;
    defer matched.deinit(allocator);
    var it = live.set.keyIterator();
    while (it.next()) |wrapper| {
        if (wrapper.*.callback_context_raw_addr == addr) {
            matched.append(allocator, wrapper.*) catch return;
        }
    }
    for (matched.items) |wrapper| {
        wrapper.releaseHandles();
        _ = live.set.remove(wrapper);
    }
    live.emptied();
}

/// The agent's end, once its realms have ended (protocol_agents.removeAgent):
/// the set's storage goes. A wrapper still in it outlived every realm of its
/// agent untracked by them; its owner still frees it.
pub fn endAgent(live: *Live) void {
    if (live.allocator) |allocator| live.set.deinit(allocator);
    live.* = .empty;
}

/// How many wrappers the agent whose isolate this is tracks - for tests.
pub fn liveCount(isolate: *v8.Isolate) usize {
    const live = protocol_agents.callbacksOf(isolate) orelse return 0;
    return live.count();
}
