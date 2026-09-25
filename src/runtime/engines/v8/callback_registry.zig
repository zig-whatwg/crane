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
const callback_wrapper = @import("callback_wrapper.zig");
const CallbackWrapper = callback_wrapper.CallbackWrapper;

/// Wrappers on this thread not yet deinitialized. Each isolate is confined to
/// one thread, and a wrapper belongs to its creating isolate.
threadlocal var live: std.AutoHashMapUnmanaged(*CallbackWrapper, void) = .empty;

/// Track `wrapper`. Idempotent. Called by the wrapper's constructors.
pub fn register(wrapper: *CallbackWrapper) void {
    // An allocation failure leaves the wrapper untracked: its handles then
    // live until its owner deinitializes it, as they did before tracking.
    live.put(std.heap.page_allocator, wrapper, {}) catch {};
}

/// Stop tracking `wrapper`. Called by `CallbackWrapper.deinit`.
pub fn unregister(wrapper: *CallbackWrapper) void {
    _ = live.remove(wrapper);
}

/// Release the handles of every wrapper created for the context whose raw V8
/// address is `context_raw_addr`, and stop tracking them. Call while the
/// isolate is alive, before the context's entry goes.
pub fn cleanupForContext(context_raw_addr: ?*anyopaque) void {
    const addr = context_raw_addr orelse return;
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
}

/// How many wrappers are tracked - for tests.
pub fn liveCount() usize {
    return live.count();
}
