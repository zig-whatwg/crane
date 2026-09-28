//! Implementation for ExtendableCookieChangeEvent interface
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! The ExtendableCookieChangeEvent interface represents a cookie change event
//! in Service Worker contexts. It extends ExtendableEvent to allow the
//! Service Worker to extend its lifetime while processing the event.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const cookie_values = @import("cookie_values.zig");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const cookiestore = @import("cookiestore");
const clock = @import("clock");
const ExtendableCookieChangeEvent = interfaces.ExtendableCookieChangeEvent;
const CookieListItem = cookiestore.CookieListItem;

pub const State = ExtendableCookieChangeEvent.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
};

/// Internal state for ExtendableCookieChangeEvent implementation
/// Same as CookieChangeEvent but extends ExtendableEvent
pub const InternalState = struct {
    /// Changed cookies (FrozenArray<CookieListItem>)
    changed: std.ArrayListUnmanaged(CookieListItem),

    /// Deleted cookies (FrozenArray<CookieListItem>)
    deleted: std.ArrayListUnmanaged(CookieListItem),

    /// The attributes' values: `[SameObject] FrozenArray<CookieListItem>`,
    /// each made on its first read and returned on every read after - one
    /// frozen array per attribute for the event's life. OWNED, released in
    /// deinit.
    changed_array: ?engine.Owned = null,
    deleted_array: ?engine.Owned = null,

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

    /// The attributes' arrays go back to the engine - where the event ends,
    /// its instance deinit; the Zig state (`deinit`) holds no engine value.
    fn releaseArrays(self: *InternalState) void {
        if (self.changed_array) |array| array.release();
        if (self.deleted_array) |array| array.release();
        self.changed_array = null;
        self.deleted_array = null;
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
        internal.releaseArrays();
        internal.deinit();
        state.own._internal = null;
    }
}

/// Helper to get internal state
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Constructor implementation
/// https://cookiestore.spec.whatwg.org/#dom-extendablecookiechangeevent-extendablecookiechangeevent
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.ExtendableCookieChangeEventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &ExtendableCookieChangeEvent.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // Get the ExtendableEvent state (parent) to initialize base event properties
    const state = instance.getState(State);

    // Initialize Event base properties (grandparent)
    // Access path: state.base (ExtendableEvent) -> .base (Event) -> .own (Event's fields)
    const event_state = &state.base.base.own;
    event_state.type = try @"type".clone(ctx.allocator);
    event_state.bubbles = false;
    event_state.cancelable = false;
    event_state.composed = false;
    event_state.target = null;
    event_state.srcElement = null;
    event_state.currentTarget = null;
    event_state.eventPhase = 0; // NONE
    event_state.cancelBubble = false;
    event_state.returnValue = true;
    event_state.defaultPrevented = false;
    event_state.isTrusted = false;
    event_state.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));

    // Process eventInitDict if provided
    if (eventInitDict.was_passed) {
        const init_dict = eventInitDict.value;

        // Apply ExtendableEventInit -> EventInit base properties
        if (init_dict.base.base.bubbles) |bubbles| {
            event_state.bubbles = bubbles;
        }
        if (init_dict.base.base.cancelable) |cancelable| {
            event_state.cancelable = cancelable;
        }
        if (init_dict.base.base.composed) |composed| {
            event_state.composed = composed;
        }

        // Process changed cookies
        // init_dict.changed is ?[]const dictionaries.CookieListItem (CookieList typedef)
        if (init_dict.changed) |changed_list| {
            for (changed_list) |dict_item| {
                const item = CookieListItem{
                    .name = try ctx.allocator.dupe(u8, dict_item.name orelse ""),
                    .value = try ctx.allocator.dupe(u8, dict_item.value orelse ""),
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
// first read - in the event's relevant realm - kept (OWNED) and returned
// BORROWED. The getters built a fresh, unfrozen array per read and handed it
// back as non-owning, which leaked the array's handle on every read.
// ============================================================================

/// The array `slot` holds, made from `items` on the first call.
fn frozenAttribute(instance: *runtime.Instance, internal: *InternalState, slot: *?engine.Owned, items: []const CookieListItem) !runtime.JSValue {
    if (slot.* == null) slot.* = try cookie_values.frozenList(instance.ctx, items, internal.allocator);
    // BORROWED: the event keeps it.
    return slot.*.?.borrow();
}

/// Getter for changed
/// https://cookiestore.spec.whatwg.org/#dom-extendablecookiechangeevent-changed
pub fn get_changed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return frozenAttribute(instance, internal, &internal.changed_array, internal.changed.items);
}

/// Getter for deleted
/// https://cookiestore.spec.whatwg.org/#dom-extendablecookiechangeevent-deleted
pub fn get_deleted(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return frozenAttribute(instance, internal, &internal.deleted_array, internal.deleted.items);
}

// ============================================================================
// Public API for event creation
// ============================================================================

/// Create an ExtendableCookieChangeEvent from cookie changes
/// This is used by the Service Worker cookie change dispatch
pub fn createFromChanges(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    changed: []const cookiestore.CookieChange,
) !*runtime.Instance {
    const instance = try init(allocator, State, &ExtendableCookieChangeEvent.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternalState(instance) orelse return error.NotImplemented;
    const state = instance.getState(State);

    // Set event type - use DOMString.initDupe for owned string
    // Access path: state.base (ExtendableEvent) -> .base (Event) -> .own (Event's fields)
    const event_state = &state.base.base.own;
    event_state.type = try runtime.DOMString.initDupe(allocator, "cookiechange");
    event_state.bubbles = false;
    event_state.cancelable = false;
    event_state.isTrusted = true;
    event_state.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(clock.monotonicMillis()));

    // Separate changed and deleted
    for (changed) |change| {
        const item = try CookieListItem.fromCookie(allocator, change.cookie);

        if (change.change_type == .changed) {
            try internal.addChanged(item);
        } else {
            allocator.free(item.value);
            var deleted_item = item;
            deleted_item.value = try allocator.dupe(u8, "");
            try internal.addDeleted(deleted_item);
        }
    }

    return instance;
}
