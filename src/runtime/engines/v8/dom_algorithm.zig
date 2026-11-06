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
//! bound past high_water, a full collection's drain - runs at the binding
//! exit that brings the depth back to zero: that exit returns into script,
//! with nothing of the DOM below it. A callback's return goes back into the
//! native algorithm that invoked it and runs nothing.
//!
//! The queue is found from the isolate through the isolate's own adapter
//! storage (isolate_templates.IsolateTemplates, V8 data slot 1: every one of
//! V8's four data slots is taken), set by protocol_agents.createAgent and
//! cleared at the agent's end: a binding entry is the hottest path there is.

const std = @import("std");
const runtime = @import("runtime");
const v8 = @import("ffi.zig");
const isolate_templates = @import("isolate_templates.zig");
const external_memory = @import("external_memory.zig");

const DeferredTeardown = runtime.gc.DeferredTeardown;

/// What `enter` hands its `leave`: the isolate's adapter storage, which
/// carries the agent's queue (and its DOM memory figure, external_memory.zig),
/// or null - no queue, nothing counted.
pub const Algorithm = ?*isolate_templates.IsolateTemplates;

/// A DOM algorithm begins: its depth raised on the agent's queue, or null (an
/// isolate createAgent did not make, or after its agent's end).
pub inline fn enter(isolate: *v8.Isolate) Algorithm {
    const storage = isolate_templates.getTemplateStorage(isolate) orelse return null;
    const queue = storage.deferred_teardown orelse return null;
    queue.enterAlgorithm();
    return storage;
}

/// `enter` for a callback invoked in `realm`: null for a realm with no agent.
pub inline fn enterRealm(realm: runtime.Context) Algorithm {
    const agent = realm.agent orelse return null;
    return enter(@ptrCast(@alignCast(agent)));
}

/// A binding returns into script: at depth zero the queue runs what it owes,
/// and V8 is told how the agent's DOM memory moved (external_memory.zig) -
/// both at the safe point with no DOM frame below.
pub inline fn leaveToScript(algorithm: Algorithm) void {
    const storage = algorithm orelse return;
    const queue = storage.deferred_teardown orelse return;
    queue.leaveAlgorithmToScript();
    if (queue.inAlgorithm()) return;
    external_memory.reportIfMoved(storage);
}

/// A callback returns into its native caller: nothing runs.
pub inline fn leaveToNative(algorithm: Algorithm) void {
    const storage = algorithm orelse return;
    if (storage.deferred_teardown) |q| q.leaveAlgorithmToNative();
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
