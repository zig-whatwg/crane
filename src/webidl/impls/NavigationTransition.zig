//! Implementation for NavigationTransition interface
//!
//! HTML Standard §7.2.6.8 - Ongoing navigation tracking
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationtransition
//!
//! `navigation.transition`: an intercepted navigation that has not yet
//! reached navigatesuccess or navigateerror - its navigation type, the entry
//! it comes from, its destination, and its committed and finished promises.
//! The navigation API makes one (dom.navigation_objects, which this
//! installs) and settles the promises; this keeps them for its getters.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const engine = @import("engine");
const dom = @import("dom");
const same_object = @import("same_object.zig");
const NavigationTransition = interfaces.NavigationTransition;

pub const State = NavigationTransition.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// Its from entry and destination, and its promises, kept alive by its
/// wrapper: edges (same_object.Traced for the entries, engine.traceValue for
/// the promises - `committed_slot`, `finished_slot`), never roots. Held as
/// roots (engine.Owned), the promises kept the transition's realm alive for
/// as long as the transition's instance lived.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    from_edge: same_object.Traced = .{ .slot = .{ .name = "from" } },
    to_edge: same_object.Traced = .{ .slot = .{ .name = "to" } },
    /// The promises were kept (`create`).
    has_promises: bool = false,

    /// `transition`: the object this state is, whose edges go.
    fn deinit(self: *InternalState, transition: *runtime.Instance) void {
        self.from_edge.release(transition);
        self.to_edge.release(transition);
        if (self.has_promises) {
            engine.forgetTracedChild(transition, committed_slot);
            engine.forgetTracedChild(transition, finished_slot);
        }
        self.has_promises = false;
    }
};

const committed_slot: engine.TracedSlot = .{ .name = "committed" };
const finished_slot: engine.TracedSlot = .{ .name = "finished" };

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom.navigation_objects.installTransitions(.{ .create = &create });
}

pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(instance);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

/// dom.navigation_objects: "a new NavigationTransition created in
/// navigation's relevant realm" with its navigation type, from entry,
/// destination and promises.
fn create(realm: runtime.Context, init_state: dom.navigation_objects.TransitionInit) anyerror!*runtime.Instance {
    const instance = try interfaces.NavigationTransition.init(realm.allocator, realm);
    errdefer runtime.Instance.deinit(instance);
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidStateError;
    state.own.navigationType = switch (init_state.navigation_type) {
        .push => ._push_,
        .replace => ._replace_,
        .reload => ._reload_,
        .traverse => ._traverse_,
    };
    state.own.from = init_state.from;
    internal.from_edge.hold(instance, init_state.from);
    state.own.to = init_state.destination;
    internal.to_edge.hold(instance, init_state.destination);
    engine.traceValue(instance, init_state.committed, committed_slot);
    engine.traceValue(instance, init_state.finished, finished_slot);
    internal.has_promises = true;
    state.own.committed = runtime.JSValue.jsUndefined;
    state.own.finished = runtime.JSValue.jsUndefined;
    return instance;
}

/// "The navigationType getter steps are to return this's navigation type."
pub fn get_navigationType(instance: *runtime.Instance) anyerror!enums.NavigationType {
    return instance.getState(State).own.navigationType;
}

/// "The from getter steps are to return this's from entry."
pub fn get_from(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return instance.getState(State).own.from;
}

/// "The to getter steps are to return this's destination."
pub fn get_to(instance: *runtime.Instance) anyerror!*runtime.Instance {
    return instance.getState(State).own.to;
}

/// "The committed getter steps are to return this's committed promise."
pub fn get_committed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (!internal.has_promises) return error.InvalidStateError;
    // The transition keeps its promise; the binding releases what a getter
    // returns, so it gets a hold of its own.
    const committed = engine.tracedValue(instance, committed_slot) orelse return error.InvalidStateError;
    return committed.take();
}

/// "The finished getter steps are to return this's finished promise."
pub fn get_finished(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (!internal.has_promises) return error.InvalidStateError;
    // The transition keeps its promise; the binding gets a hold of its own.
    const finished = engine.tracedValue(instance, finished_slot) orelse return error.InvalidStateError;
    return finished.take();
}
