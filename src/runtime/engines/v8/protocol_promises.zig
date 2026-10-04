//! The engine protocol's promise reactions (design section 4.9): WebIDL "react
//! to" a promise, as V8 implements it.
//!
//! v8_Promise_React is PerformPromiseThen(promise, onFulfilled, onRejected,
//! newCapability) with both reactions calling back into Zig - functions made
//! with Function::New, not a template per reaction, which a context would
//! keep for its lifetime. The promise it derives is marked handled: "react
//! to" returns nothing here, so nothing observes it (WebIDL allows not
//! creating it at all).
//!
//! A reaction ends one of three ways, and its record (`Reaction`) with it -
//! exactly one of the host's fulfilled, rejected and dropped steps runs
//! (engine.PromiseReactionSteps):
//! - its promise settles: the step for the outcome, or `dropped` when the
//!   host gave none;
//! - its realm ends first: the record is on the realm's list
//!   (realm_finalizers.zig), which the realm's end drains - the reaction is
//!   disarmed, so a function of it that another realm's promise still runs
//!   later does nothing, and `dropped` runs;
//! - the collector takes its functions with the promise unsettled: the
//!   record's handle of the functions' holder is weak, and its second pass
//!   runs `dropped` (never the first: v8-weak-callback-info.h allows no
//!   engine call there). Weak, never strong - a strong handle would keep the
//!   realm alive (docs/lessons/architecture-an-api-callback-s-current-context-
//!   is-the-callee-s-realm.md).

const std = @import("std");
const engine = @import("engine");

const ffi = @import("ffi.zig");
const support = @import("protocol_support.zig");
const realm_finalizers = @import("realm_finalizers.zig");

const Context = engine.Context;
const JSValue = engine.JSValue;
const Error = engine.Error;

const Reaction = struct {
    steps: *const engine.PromiseReactionSteps,
    data: ?*anyopaque,
    /// The reaction functions' holder, WEAK: empty once the collector took
    /// it. Disposed when the reaction ends.
    holder: ?*ffi.Value = null,
    /// On its realm's list until it ends.
    node: realm_finalizers.Node = .{ .drop = droppedByRealm },

    const allocator = std.heap.c_allocator;

    /// Release what the record holds - its place on the realm's list, its
    /// holder handle (disposing it cancels a second pass still to come) -
    /// and free it. Returns what the host's step needs.
    fn end(self: *Reaction) struct { steps: *const engine.PromiseReactionSteps, data: ?*anyopaque } {
        const steps = self.steps;
        const data = self.data;
        self.node.unlink();
        if (self.holder) |holder| ffi.v8_Global_Dispose(holder);
        allocator.destroy(self);
        return .{ .steps = steps, .data = data };
    }

    /// Exactly once, when the promise settles (and the reaction was not
    /// ended first): `value` is a new Global this owns.
    fn settled(raw: ?*anyopaque, value: ?*ffi.Value, rejected: bool) callconv(.c) void {
        const self: *Reaction = @ptrCast(@alignCast(raw.?));
        const host = self.end();
        defer if (value) |v| ffi.v8_Global_Dispose(v);
        const argument: JSValue = if (value) |v| support.borrowed(v) else JSValue.jsUndefined;
        if (rejected) {
            // onRejectedSteps: 1. Let reason be R converted to `any`.
            // 2. If there is a set of steps to be run if the promise was
            //    rejected, then let result be the result of performing them,
            //    given reason. Otherwise, let result be a promise rejected with
            //    reason - the derived promise's, which nothing observes.
            if (host.steps.rejected) |rejected_steps| return rejected_steps(host.data, argument);
        } else {
            // onFulfilledSteps: 1. Let value be V converted to T (the steps'
            //    own conversion). 2. If there is a set of steps to be run if
            //    the promise was fulfilled, then let result be the result of
            //    performing them, given value. Otherwise, let result be value.
            if (host.steps.fulfilled) |fulfilled_steps| return fulfilled_steps(host.data, argument);
        }
        // No step for this outcome: the reaction ends without one.
        if (host.steps.dropped) |dropped| dropped(host.data);
        // 3. Return result, converted to a JavaScript value: the derived
        //    promise's value, which nothing observes.
    }

    /// V8's second pass, after the collector took the holder - and with it
    /// both reaction functions - while the promise was unsettled.
    fn collected(raw: ?*anyopaque, _: usize) callconv(.c) void {
        const self: *Reaction = @ptrCast(@alignCast(raw.?));
        const host = self.end();
        if (host.steps.dropped) |dropped| dropped(host.data);
    }

    /// The realm ended first (realm_finalizers.List.drain; already
    /// unlinked): disarm the functions - another realm's promise may still
    /// hold them - and drop.
    fn droppedByRealm(node: *realm_finalizers.Node) void {
        const self: *Reaction = @fieldParentPtr("node", node);
        if (self.holder) |holder| ffi.v8_Array_ClearElement(holder, ffi.reaction_data_slot);
        const host = self.end();
        if (host.steps.dropped) |dropped| dropped(host.data);
    }
};

/// WebIDL "react to" `promise`: `steps` upon fulfillment and upon rejection,
/// in `realm`. `steps` and `data` are BORROWED until one of the steps runs
/// (engine.PromiseReactionSteps); on an error none ever does.
pub fn reactToPromise(realm: Context, promise: JSValue, steps: *const engine.PromiseReactionSteps, data: ?*anyopaque) Error!void {
    const entered = try support.enter(realm);
    defer entered.leave();
    const target = support.handleOf(promise) orelse return error.TypeError;
    if (!ffi.v8_Value_IsPromise(target)) return error.TypeError;
    // A realm whose end is under way runs no reaction: its list is drained.
    const list = realm_finalizers.listOf(realm);
    if (list) |l| if (l.ended) return error.OperationFailed;

    const reaction = Reaction.allocator.create(Reaction) catch return error.OutOfMemory;
    reaction.* = .{ .steps = steps, .data = data };
    // 1-4. onFulfilled and onRejected: CreateBuiltinFunction over the steps.
    // 5-6. Let newCapability be ? NewPromiseCapability(%Promise% of the
    //      promise's realm) - V8's derived promise.
    // 7. Perform PerformPromiseThen(promise.[[Promise]], onFulfilled,
    //    onRejected, newCapability).
    var holder: ?*ffi.Value = null;
    if (!ffi.v8_Promise_React(entered.context(), target, Reaction.settled, reaction, &holder)) {
        Reaction.allocator.destroy(reaction);
        return error.OperationFailed;
    }
    reaction.holder = holder;
    if (list) |l| l.add(&reaction.node) catch {
        // The realm's end began in between: no step will ever run.
        if (holder) |h| ffi.v8_Array_ClearElement(h, ffi.reaction_data_slot);
        _ = reaction.end();
        return error.OperationFailed;
    };
    if (holder) |h| ffi.v8_Global_SetWeakFinalizer(h, reaction, null, Reaction.collected);
    // 8. Return newCapability: not observed (see above).
}
