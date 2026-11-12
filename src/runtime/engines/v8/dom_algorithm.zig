//! The "DOM algorithm active" depth (refcount design section 9, risk 4;
//! lane refcount9, B5): the V8 adapter's half of the contract in
//! docs/engine-protocol.md, "Deferred teardown".
//!
//! An agent's deferred teardown queue (runtime.gc.DeferredTeardown) frees
//! nothing while a DOM algorithm is on the agent's stack. The adapter counts
//! the two ways one gets there: every binding entry - script calling a
//! platform object's operation, attribute or constructor (interface.zig) -
//! and every native-to-script callback invocation - a native dispatch, a
//! custom element reaction or an observer callback calling script
//! (protocol.zig's invokeCallbackFunction, constructCallbackFunction,
//! callUserObjectOperation). What the queue owes meanwhile - its memory
//! bound past high_water, a full collection's drain, the finalizers of
//! collected wrappers - runs at the binding
//! exit that brings the depth back to zero: that exit returns into script,
//! with nothing of the DOM below it. A callback's return goes back into the
//! native algorithm that invoked it and runs nothing. One thing runs at a
//! binding's return into a callback's script: the finalizer of an object made
//! since that callback began, which no algorithm on the stack can hold
//! (finalizer_safe_point.zig, "Inside a callback").
//!
//! The queue is found from the isolate through the isolate's own adapter
//! storage (isolate_templates.IsolateTemplates, V8 data slot 1: every one of
//! V8's four data slots is taken), set by protocol_agents.createAgent and
//! cleared at the agent's end: a binding entry is the hottest path there is.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("ffi.zig");
const isolate_templates = @import("isolate_templates.zig");

const DeferredTeardown = runtime.gc.DeferredTeardown;

/// A DOM algorithm begins: the agent's queue, its depth raised, or null (an
/// isolate createAgent did not make, or after its agent's end).
pub inline fn enter(isolate: *v8.Isolate) ?*DeferredTeardown {
    const storage = isolate_templates.getTemplateStorage(isolate) orelse return null;
    const queue = storage.deferred_teardown orelse return null;
    queue.enterAlgorithm();
    return queue;
}

/// A callback invocation on the agent's stack, from `enterCallback` to
/// `leaveCallback`: its queue (null for a realm with no agent, or an isolate
/// with no queue) and the invocation it found innermost.
pub const Callback = struct {
    queue: ?*DeferredTeardown,
    outer: DeferredTeardown.OuterCallback = .{ .active = 0, .depth = 0 },
};

/// `enter` for a callback invoked in `realm` - a native algorithm calls
/// script: besides the depth, the agent's callback clock ticks and this
/// invocation becomes the innermost one (DeferredTeardown.Callbacks), which
/// is what a binding's return into the callback's script compares a fresh
/// finalizer's stamp with.
pub inline fn enterCallback(realm: runtime.Context) Callback {
    const agent = realm.agent orelse return .{ .queue = null };
    const storage = isolate_templates.getTemplateStorage(@ptrCast(@alignCast(agent))) orelse return .{ .queue = null };
    const queue = storage.deferred_teardown orelse return .{ .queue = null };
    return .{ .queue = queue, .outer = queue.enterCallback() };
}

/// A binding returns into script: at depth zero the queue runs what it owes -
/// the finalizers of the wrappers V8's collector found dead
/// (finalizer_safe_point.zig, through the queue's finalizer steps), a relief,
/// a drain, and the report of the agent's DOM memory to V8
/// (external_memory.zig, through the queue's report steps); returning into a
/// callback's own script it runs the FRESH finalizers alone - those of
/// objects a script-called constructor made since that callback began. All
/// behind the one check of what is owed.
pub inline fn leaveToScript(queue: ?*DeferredTeardown) void {
    if (queue) |q| q.leaveAlgorithmToScript();
}

/// A callback returns into its native caller: nothing runs, and the
/// invocation below is the innermost again.
pub inline fn leaveCallback(callback: Callback) void {
    if (callback.queue) |q| q.leaveCallback(callback.outer);
}

/// Set (or, null, clear) the agent's queue on its isolate. On the agent's
/// thread; a set the storage cannot be made for (out of memory) leaves the
/// agent uncounted - it then frees between tasks only.
pub fn install(isolate: *v8.Isolate, queue: ?*DeferredTeardown) void {
    if (queue == null) {
        if (isolate_templates.getTemplateStorage(isolate)) |storage| storage.deferred_teardown = null;
        return;
    }
    const storage = isolate_templates.storageFor(isolate) orelse return;
    storage.deferred_teardown = queue;
}
