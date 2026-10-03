//! Implementation for CookieChangeEvent interface
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! The CookieChangeEvent interface represents an event for cookie changes
//! in Window contexts. It contains lists of changed and deleted cookies.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const cookiestore = @import("cookiestore");
const CookieChangeEvent = interfaces.CookieChangeEvent;
const CookieListItem = cookiestore.CookieListItem;
/// CookieChangeEvent is an Event: its Event state is reached through Event's
/// impl (AGENTS.md "The impls boundary", rule 1).
const EventImpl = @import("Event.zig");

// The FrozenArray<CookieListItem> attributes are made through the engine
// protocol (cookie_values.zig).
const engine = @import("engine");
const cookie_values = @import("cookie_values.zig");

pub const State = CookieChangeEvent.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
};

/// Internal state for CookieChangeEvent implementation
pub const InternalState = struct {
    /// Changed cookies (FrozenArray<CookieListItem>)
    changed: std.ArrayListUnmanaged(CookieListItem),

    /// Deleted cookies (FrozenArray<CookieListItem>)
    deleted: std.ArrayListUnmanaged(CookieListItem),

    /// The attributes' values: `[SameObject] FrozenArray<CookieListItem>`,
    /// each made on its first read and returned on every read after - one
    /// frozen array per attribute for the event's life, kept by an edge from
    /// the event's wrapper (`changed_slot`, `deleted_slot`; engine.traceValue),
    /// never a root.
    has_changed_array: bool = false,
    has_deleted_array: bool = false,

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*InternalState {
        const internal = try allocator.create(InternalState);
        internal.* = InternalState{
            .changed = .empty,
            .deleted = .empty,
            .allocator = allocator,
        };
        return internal;
    }

    /// The attributes' arrays are let go - where the event ends, its
    /// instance deinit; the Zig state (`deinit`) holds no engine value. An
    /// event the collector freed lost them with its wrapper; one freed before
    /// script saw it lets go of the arrays waiting for its wrapper.
    fn releaseArrays(self: *InternalState, event: *runtime.Instance) void {
        if (self.has_changed_array) engine.forgetTracedChild(event, changed_slot);
        if (self.has_deleted_array) engine.forgetTracedChild(event, deleted_slot);
        self.has_changed_array = false;
        self.has_deleted_array = false;
    }

    pub fn deinit(self: *InternalState) void {
        for (self.changed.items) |*item| {
            item.deinit();
        }
        self.changed.deinit(self.allocator);

        for (self.deleted.items) |*item| {
            item.deinit();
        }
        self.deleted.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Add a changed cookie
    pub fn addChanged(self: *InternalState, item: CookieListItem) !void {
        try self.changed.append(self.allocator, item);
    }

    /// Add a deleted cookie
    pub fn addDeleted(self: *InternalState, item: CookieListItem) !void {
        try self.deleted.append(self.allocator, item);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize internal state
    const internal = try InternalState.init(allocator);

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.releaseArrays(instance);
        internal.deinit();
        state.own._internal = null;
    }
    // The Event state the constructor made: the type, the Event internal.
    EventImpl.deinit(instance);
}

/// Helper to get internal state
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Constructor implementation
/// https://cookiestore.spec.whatwg.org/#dom-cookiechangeevent-cookiechangeevent
///
/// The CookieChangeEvent(type, eventInitDict) constructor steps are:
/// 1. Set this's changed attribute to eventInitDict["changed"]
/// 2. Set this's deleted attribute to eventInitDict["deleted"]
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.CookieChangeEventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &CookieChangeEvent.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // DOM "inner event creation steps" and the constructor's step 2, through
    // Event's impl (CookieChangeEvent is an Event): the initialized flag -
    // without which dispatchEvent throws InvalidStateError - the timeStamp,
    // EventInit's members, then the type. (The type was dropped, and the flag
    // never set.) Step 5, the event constructing steps, is this
    // constructor's own: changed and deleted, below.
    const event_init = if (eventInitDict.was_passed) eventInitDict.value.base else dictionaries.EventInit{};
    try EventImpl.innerEventCreationSteps(instance, @"type", event_init);

    // Process eventInitDict if provided
    if (eventInitDict.was_passed) {
        const init_dict = eventInitDict.value;

        // Process changed cookies
        // init_dict.changed is ?[]const dictionaries.CookieListItem (CookieList typedef)
        if (init_dict.changed) |changed_list| {
            for (changed_list) |dict_item| {
                // Convert dictionary CookieListItem to our internal CookieListItem
                const item = CookieListItem{
                    .name = try ctx.allocator.dupe(u8, dict_item.name orelse ""),
                    .value = try ctx.allocator.dupe(u8, dict_item.value orelse ""),
                    // An absent member stays absent when the list is read.
                    .has_value = dict_item.value != null,
                    .allocator = ctx.allocator,
                };
                try internal.addChanged(item);
            }
        }

        // Process deleted cookies
        if (init_dict.deleted) |deleted_list| {
            for (deleted_list) |dict_item| {
                const item = CookieListItem{
                    .name = try ctx.allocator.dupe(u8, dict_item.name orelse ""),
                    .value = try ctx.allocator.dupe(u8, dict_item.value orelse ""),
                    // An absent member stays absent when the list is read.
                    .has_value = dict_item.value != null,
                    .allocator = ctx.allocator,
                };
                try internal.addDeleted(item);
            }
        }
    }

    return instance;
}

// ============================================================================
// FrozenArray<CookieListItem> attributes
//
// `changed` and `deleted` are `[SameObject] FrozenArray<CookieListItem>`: the
// attribute returns the same frozen array on every read. Each is made on its
// first read - in the event's relevant realm - kept by an edge from the
// event's wrapper, and returned as a hold of the binding's own. The getters built a fresh, unfrozen array per read and handed it
// back as non-owning, which leaked the array's handle on every read.
// ============================================================================

/// The array `slot` holds, made from `items` on the first call.
fn frozenAttribute(instance: *runtime.Instance, internal: *InternalState, slot: engine.TracedSlot, made: *bool, items: []const CookieListItem) !runtime.JSValue {
    // The event keeps its array ([SameObject]); the binding gets a hold of
    // its own.
    if (made.*) {
        if (engine.tracedValue(instance, slot)) |array| return array.take();
    }
    const array = try cookie_values.frozenList(instance.ctx, items, internal.allocator);
    engine.traceValue(instance, array.value, slot);
    made.* = true;
    return array.take();
}

const changed_slot: engine.TracedSlot = .{ .name = "changed" };
const deleted_slot: engine.TracedSlot = .{ .name = "deleted" };

/// Getter for changed
/// https://cookiestore.spec.whatwg.org/#dom-cookiechangeevent-changed
pub fn get_changed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return frozenAttribute(instance, internal, changed_slot, &internal.has_changed_array, internal.changed.items);
}

/// Getter for deleted
/// https://cookiestore.spec.whatwg.org/#dom-cookiechangeevent-deleted
pub fn get_deleted(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return frozenAttribute(instance, internal, deleted_slot, &internal.has_deleted_array, internal.deleted.items);
}

// ============================================================================
// Public API for event creation
// ============================================================================

/// Create a CookieChangeEvent from cookie changes
/// This is used by the "fire a change event" algorithm
pub fn createFromChanges(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    changed: []const cookiestore.CookieChange,
) !*runtime.Instance {
    const instance = try init(allocator, State, &CookieChangeEvent.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // Separate changed and deleted
    for (changed) |change| {
        const item = try CookieListItem.fromCookie(allocator, change.cookie);

        if (change.change_type == .changed) {
            try internal.addChanged(item);
        } else {
            // For deleted, value should be empty per spec
            allocator.free(item.value);
            var deleted_item = item;
            deleted_item.value = try allocator.dupe(u8, "");
            try internal.addDeleted(deleted_item);
        }
    }

    return instance;
}
