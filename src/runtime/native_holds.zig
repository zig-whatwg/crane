//! Holds native frames take on engine-owned objects that script must not
//! see change under them (lane cs1): today, a computed style a caller reads
//! (dom.style.HeldStyle). A hold lives inside the native call that took it -
//! it is released before that call returns, never kept in a struct - and it
//! never crosses into script or an event-loop turn: no script runs, and no
//! task, while a native frame of the agent holds one.
//!
//! Debug checks it. The count is the agent's - holds are native frames on
//! the agent's thread, and the agent outlives every realm it runs - kept on
//! its deferred teardown queue (runtime.gc.DeferredTeardown, beside
//! `algorithm_depth` and `stack_roots`, the agent's other native-frame
//! books), reached through `engine.deferredTeardownOf`. `assertNone` runs at
//! every script entry of the engine protocol's generic layer (HTML "prepare
//! to run script", the Web IDL callback invocations, a microtask checkpoint,
//! the engine's own tasks) and at each turn of a Browser's event loop. An
//! agent with no queue (an adapter that makes none: JavaScriptCore, QuickJS,
//! the test adapter) or a realm with no agent is not checked. Outside Debug
//! the count is `void` and every function here does nothing.
//!
//! This module keeps no state of its own.

const std = @import("std");
const builtin = @import("builtin");
const engine = @import("engine");
const Context = @import("context.zig").Context;
const DeferredTeardown = @import("gc_integration.zig").DeferredTeardown;

/// Whether holds are counted and checked: Debug builds of this module.
pub const enabled = builtin.mode == .Debug;

/// The agent's count of live holds (runtime.gc.DeferredTeardown.native_holds).
pub const Count = if (enabled) u32 else void;

/// What a hold keeps to give its count back: the agent's queue it counted
/// on (null: an agent with none, unchecked).
pub const Ref = if (enabled) ?*DeferredTeardown else void;

/// The initial count.
pub const zero: Count = if (enabled) 0 else {};

fn queueOf(agent: ?*engine.Agent) ?*DeferredTeardown {
    return engine.deferredTeardownOf(agent orelse return null);
}

/// A native frame of `realm`'s agent takes a hold.
pub fn enter(realm: Context) Ref {
    if (comptime !enabled) return {};
    const queue = queueOf(realm.agent) orelse return null;
    queue.native_holds += 1;
    return queue;
}

/// The hold `ref` came from is released.
pub fn leave(ref: Ref) void {
    if (comptime !enabled) return;
    const queue = ref orelse return;
    std.debug.assert(queue.native_holds > 0);
    queue.native_holds -= 1;
}

/// The live holds of `agent`'s native frames: 0 outside Debug.
pub fn count(agent: ?*engine.Agent) u32 {
    if (comptime !enabled) return 0;
    const queue = queueOf(agent) orelse return 0;
    return queue.native_holds;
}

/// Script, or an event-loop turn, is about to run on `agent` (`where`
/// names the entry): no native frame may hold anything now.
pub fn assertNone(agent: ?*engine.Agent, comptime where: []const u8) void {
    if (comptime !enabled) return;
    const queue = queueOf(agent) orelse return;
    if (queue.native_holds != 0) std.debug.panic("{s} with {d} native hold(s) live: a held computed style (dom.style.HeldStyle) crosses into script or an event-loop turn - release it first (runtime.native_holds)", .{ where, queue.native_holds });
}
