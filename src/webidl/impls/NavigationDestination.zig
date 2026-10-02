//! Implementation for NavigationDestination interface
//!
//! HTML Standard §7.2.6.10.3 - The NavigationDestination interface
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#the-navigationdestination-interface
//!
//! Where a navigation the navigate event reports is going: a URL, the
//! NavigationHistoryEntry it is for a traversal (null otherwise), a
//! navigation API state and whether it stays in the same document. The
//! navigation API makes one per navigate event (dom.navigation_objects,
//! which this installs); nothing else can.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const engine = @import("engine");
const dom = @import("dom");
const joint_history = @import("html_core").navigation.joint_history;
const same_object = @import("same_object.zig");
const navigation_entries = @import("navigation_entries.zig");
const NavigationDestination = interfaces.NavigationDestination;

pub const State = NavigationDestination.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// HTML "a NavigationDestination has an associated URL, entry, state and is
/// same document".
pub const InternalState = struct {
    allocator: Allocator,
    url: []u8 = &.{},
    /// The NavigationHistoryEntry, kept alive by this one's wrapper (an
    /// edge: same_object.Traced).
    entry: ?*runtime.Instance = null,
    entry_edge: same_object.Traced = .{ .slot = .{ .name = "entry" } },
    state: joint_history.SerializedState = .null,
    is_same_document: bool = false,

    /// `destination`: the object this state is, whose edge goes.
    fn deinit(self: *InternalState, destination: *runtime.Instance) void {
        self.allocator.free(self.url);
        self.entry_edge.release(destination);
        self.state.deinit(self.allocator);
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    dom.navigation_objects.installDestinations(.{
        .create = &create,
        .set_url = &setUrl,
        .set_state = &setState,
        .entry = &entryOf,
    });
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

// ============================================================================
// dom.navigation_objects
// ============================================================================

/// "Let destination be a new NavigationDestination created in navigation's
/// relevant realm", with its URL, entry, state and is same document.
fn create(realm: runtime.Context, init_state: dom.navigation_objects.DestinationInit) anyerror!*runtime.Instance {
    const instance = try interfaces.NavigationDestination.init(realm.allocator, realm);
    errdefer runtime.Instance.deinit(instance);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.url = try internal.allocator.dupe(u8, init_state.url);
    internal.state = try init_state.state.clone(internal.allocator);
    internal.is_same_document = init_state.is_same_document;
    if (init_state.entry) |entry| {
        internal.entry = entry;
        internal.entry_edge.hold(instance, entry);
    }
    return instance;
}

fn setUrl(instance: *runtime.Instance, url: []const u8) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const copy = try internal.allocator.dupe(u8, url);
    internal.allocator.free(internal.url);
    internal.url = copy;
}

fn setState(instance: *runtime.Instance, state: joint_history.SerializedState) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const copy = try state.clone(internal.allocator);
    internal.state.deinit(internal.allocator);
    internal.state = copy;
}

fn entryOf(instance: *runtime.Instance) ?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.entry;
}

// ============================================================================
// Attributes
// ============================================================================

/// "The url getter steps are to return this's URL, serialized." A copy:
/// the binding frees what a USVString getter returns.
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return instance.ctx.allocator.dupe(u8, internal.url);
}

/// "1. If this's entry is null, then return the empty string. 2. Return
/// this's entry's key."
pub fn get_key(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const entry = internal.entry orelse return runtime.DOMString.initEmpty();
    return interfaces.NavigationHistoryEntry.get_key(entry);
}

/// "1. If this's entry is null, then return the empty string. 2. Return
/// this's entry's ID."
pub fn get_id(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const entry = internal.entry orelse return runtime.DOMString.initEmpty();
    return interfaces.NavigationHistoryEntry.get_id(entry);
}

/// "1. If this's entry is null, then return −1. 2. Return this's entry's
/// index."
pub fn get_index(instance: *runtime.Instance) anyerror!i64 {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const entry = internal.entry orelse return -1;
    return interfaces.NavigationHistoryEntry.get_index(entry);
}

/// "The sameDocument getter steps are to return this's is same document."
pub fn get_sameDocument(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.is_same_document;
}

/// "The getState() method steps are to return
/// StructuredDeserialize(this's state)." A fresh value each call, made in
/// the current realm.
pub fn call_getState(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return (try navigation_entries.deserialize(engine.currentRealm() orelse instance.ctx, internal.state)).take();
}
