//! CSS View Transitions 1 §6.2 (and Level 2's types and transitionRoot): a
//! same-document view transition. Its model and every algorithm of §7 are
//! dom.view_transitions' (a Transition, made in initOwn and freed in
//! deinitOwn), reached by the rest of Crane through the style hook
//! view_transition_of; update-the-rendering step 18 ("perform pending
//! transition operations") is installed here.
//!
//! Spec: https://drafts.csswg.org/css-view-transitions-1/#the-domtransition-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const view_transitions = dom.view_transitions;

pub const State = interfaces.ViewTransition.State;

pub const ImplError = error{ NotImplemented, InvalidStateError };

pub const InternalState = view_transitions.Transition;

fn transitionOf(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

fn modelOf(instance: *runtime.Instance) !*InternalState {
    return transitionOf(instance) orelse error.InvalidStateError;
}

pub fn installHooks() void {
    dom.style.hooks.install(.{ .view_transition_of = &transitionOf, .view_transition_classes = &view_transitions.viewTransitionClasses });
    dom.update_the_rendering.installStep(.view_transitions, &view_transitions.performPendingTransitionOperations);
}

/// §6.1.1 step 1's new ViewTransition: its promises are made now (§6.2:
/// "Initially a new promise in this's relevant Realm").
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    _ = args;
    const transition = try allocator.create(InternalState);
    transition.* = .init(allocator, instance);
    instance.getState(State).own._internal = transition;
    errdefer {
        transition.deinit(false);
        allocator.destroy(transition);
        instance.getState(State).own._internal = null;
    }
    if (instance.ctx.hasEngine()) try transition.makePromises();
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const transition = state.own._internal orelse return;
    state.own._internal = null;
    transition.deinit(instance.ctx.hasEngine());
    transition.allocator.destroy(transition);
}

/// "return this's update callback done promise".
pub fn get_updateCallbackDone(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return (try (try modelOf(instance)).update_callback_done.get(instance)).take();
}

/// "return this's ready promise".
pub fn get_ready(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return (try (try modelOf(instance)).ready.get(instance)).take();
}

/// "return this's finished promise".
pub fn get_finished(instance: *runtime.Instance) anyerror!runtime.JSValue {
    return (try (try modelOf(instance)).finished.get(instance)).take();
}

/// Level 2 §9: a ViewTransitionTypeSet over the active types - one object
/// ([SameObject]: the generated getter keeps it), starting with the types
/// startViewTransition() was given.
pub fn get_types(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const transition = try modelOf(instance);
    const set = try interfaces.ViewTransitionTypeSet.init(instance.ctx.allocator, instance.ctx);
    errdefer runtime.Instance.deinit(set);
    if (interfaces.ViewTransitionTypeSet.setlikeEntries(set)) |entries| {
        for (transition.active_types) |name| try entries.append(name);
    }
    return set;
}

/// Level 2: the transition root - for a document's transition, its document
/// element.
pub fn get_transitionRoot(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const transition = try modelOf(instance);
    const link = transition.document orelse return error.InvalidStateError;
    const document = link.get() orelse return error.InvalidStateError;
    return (try interfaces.Document.get_documentElement(document)) orelse error.InvalidStateError;
}

/// §6.2.1: "If this's phase is not "done", then skip the view transition
/// for this with an "AbortError" DOMException."
pub fn call_skipTransition(instance: *runtime.Instance) anyerror!void {
    const transition = try modelOf(instance);
    if (transition.phase == .done) return;
    try view_transitions.skipWithException(transition, "AbortError", "The view transition was skipped.");
}

/// Level 2 §12: extends a cross-document transition's lifetime - none starts
/// here.
pub fn call_waitUntil(instance: *runtime.Instance, promise: runtime.JSValue) anyerror!void {
    _ = instance;
    _ = promise;
    return error.NotImplemented;
}
