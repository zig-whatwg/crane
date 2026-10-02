//! Implementation for NavigationActivation interface
//!
//! HTML Standard §7.2.6.9 - The NavigationActivation interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#navigationactivation
//!
//! "Each NavigationActivation has an old entry, null or a
//! NavigationHistoryEntry; a new entry, null or a NavigationHistoryEntry; and
//! a navigation type, a NavigationType." The navigation API makes one for a
//! document's `navigation.activation` and for the pageswap event of the
//! document a navigation replaces (dom.navigation_objects, which this
//! installs); nothing else can - the interface has no constructor.
//!
//! Both entries are kept alive with the activation: script can hold it after
//! the navigation API has let the entries go (same_object.zig).

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const dom = @import("dom");
const same_object = @import("same_object.zig");
const NavigationActivation = interfaces.NavigationActivation;

pub const State = NavigationActivation.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// The old entry, the new entry and the navigation type.
pub const InternalState = struct {
    allocator: Allocator,
    old_entry: ?*runtime.Instance = null,
    old_edge: same_object.Traced = .{ .slot = .{ .name = "from" } },
    new_entry: ?*runtime.Instance = null,
    new_edge: same_object.Traced = .{ .slot = .{ .name = "entry" } },
    navigation_type: enums.NavigationType = ._push_,

    /// `activation`: the object this state is, whose edges go (its teardown,
    /// the collector's too).
    fn release(self: *InternalState, activation: *runtime.Instance) void {
        self.old_edge.release(activation);
        self.new_edge.release(activation);
        self.old_entry = null;
        self.new_entry = null;
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom.navigation_objects.installActivations(.{ .create = &create });
}

/// Initialize instance (creates the instance), and install this type's part
/// of dom.navigation_objects.
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

/// Deinitialize instance: the edges to its entries go with it.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.release(instance);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

/// dom.navigation_objects: "a new NavigationActivation created in" `realm`,
/// with its old entry, new entry and navigation type.
fn create(realm: runtime.Context, init_state: dom.navigation_objects.ActivationInit) anyerror!*runtime.Instance {
    const instance = try interfaces.NavigationActivation.init(realm.allocator, realm);
    errdefer runtime.Instance.deinit(instance);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    if (init_state.from) |from| {
        internal.old_entry = from;
        internal.old_edge.hold(instance, from);
    }
    internal.new_entry = init_state.entry;
    internal.new_edge.hold(instance, init_state.entry);
    internal.navigation_type = switch (init_state.navigation_type) {
        .push => ._push_,
        .replace => ._replace_,
        .reload => ._reload_,
        .traverse => ._traverse_,
    };
    return instance;
}

/// "The from getter steps are to return this's old entry."
pub fn get_from(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.old_entry;
}

/// "The entry getter steps are to return this's new entry." The navigation
/// API always gives one.
pub fn get_entry(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.new_entry orelse error.InvalidStateError;
}

/// "The navigationType getter steps are to return this's navigation type."
pub fn get_navigationType(instance: *runtime.Instance) anyerror!enums.NavigationType {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.navigation_type;
}
