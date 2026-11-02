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
/// set; its storage is page_allocator's, freed whenever its last wrapper goes
/// (each page's end brings that, cleanupForContext) and at the agent's end
/// (`endAgent`).
// tombstones: freed (clearAndFree) whenever its last wrapper goes, which each page's end brings (cleanupForContext), and at its agent's end: a 1,069-file runner sample found it empty at every sampled insert
pub const Live = std.AutoHashMapUnmanaged(*CallbackWrapper, void);

/// Track `wrapper` on its agent. Idempotent. Called by the wrapper's
/// constructors. A wrapper of an isolate createAgent did not make (a test's
/// own) is not tracked: its handles live until its owner deinitializes it,
/// as they did before tracking - and as an allocation failure here leaves
/// any wrapper.
pub fn register(wrapper: *CallbackWrapper) void {
    const live = protocol_agents.callbacksOf(wrapper.isolate) orelse return;
    live.put(std.heap.page_allocator, wrapper, {}) catch {};
}

/// Stop tracking `wrapper`. Called by `CallbackWrapper.deinit`.
pub fn unregister(wrapper: *CallbackWrapper) void {
    const live = protocol_agents.callbacksOf(wrapper.isolate) orelse return;
    _ = live.remove(wrapper);
    if (live.count() == 0) live.clearAndFree(std.heap.page_allocator);
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
    var matched: std.ArrayListUnmanaged(*CallbackWrapper) = .empty;
    defer matched.deinit(std.heap.page_allocator);
    var it = live.keyIterator();
    while (it.next()) |wrapper| {
        if (wrapper.*.callback_context_raw_addr == addr) {
            matched.append(std.heap.page_allocator, wrapper.*) catch return;
        }
    }
    for (matched.items) |wrapper| {
        wrapper.releaseHandles();
        _ = live.remove(wrapper);
    }
    if (live.count() == 0) live.clearAndFree(std.heap.page_allocator);
}

/// The agent's end, once its realms have ended (protocol_agents.removeAgent):
/// the set's storage goes. A wrapper still in it outlived every realm of its
/// agent untracked by them; its owner still frees it.
pub fn endAgent(live: *Live) void {
    live.deinit(std.heap.page_allocator);
    live.* = .empty;
}

/// How many wrappers the agent whose isolate this is tracks - for tests.
pub fn liveCount(isolate: *v8.Isolate) usize {
    const live = protocol_agents.callbacksOf(isolate) orelse return 0;
    return live.count();
}
