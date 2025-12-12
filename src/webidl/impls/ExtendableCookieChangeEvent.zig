//! Implementation for ExtendableCookieChangeEvent interface
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! The ExtendableCookieChangeEvent interface represents a cookie change event
//! in Service Worker contexts. It extends ExtendableEvent to allow the
//! Service Worker to extend its lifetime while processing the event.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const cookiestore = @import("cookiestore");
const ExtendableCookieChangeEvent = interfaces.ExtendableCookieChangeEvent;
const CookieListItem = cookiestore.CookieListItem;

// Use typed extraction for dictionary arrays
const extractOptionalDictionarySlice = webidl.extractOptionalDictionarySlice;

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

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*InternalState {
        const internal = try allocator.create(InternalState);
        internal.* = InternalState{
            .changed = .{},
            .deleted = .{},
            .allocator = allocator,
        };
        return internal;
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
        internal.deinit();
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

    // Initialize ExtendableEvent -> Event base properties
    // ExtendableEvent.State.parent is Event.State
    state.parent.parent.own.type = try @"type".clone(ctx.allocator);
    state.parent.parent.own.bubbles = false;
    state.parent.parent.own.cancelable = false;
    state.parent.parent.own.composed = false;
    state.parent.parent.own.target = null;
    state.parent.parent.own.srcElement = null;
    state.parent.parent.own.currentTarget = null;
    state.parent.parent.own.eventPhase = 0; // NONE
    state.parent.parent.own.cancelBubble = false;
    state.parent.parent.own.returnValue = true;
    state.parent.parent.own.defaultPrevented = false;
    state.parent.parent.own.isTrusted = false;
    state.parent.parent.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));

    // Process eventInitDict if provided
    if (eventInitDict.was_passed) {
        const init_dict = eventInitDict.value;

        // Apply ExtendableEventInit -> EventInit base properties
        if (init_dict.base.base.bubbles) |bubbles| {
            state.parent.parent.own.bubbles = bubbles;
        }
        if (init_dict.base.base.cancelable) |cancelable| {
            state.parent.parent.own.cancelable = cancelable;
        }
        if (init_dict.base.base.composed) |composed| {
            state.parent.parent.own.composed = composed;
        }

        // Process changed cookies using typed extraction
        if (try extractOptionalDictionarySlice(dictionaries.CookieListItem, init_dict.changed)) |changed_list| {
            for (changed_list) |dict_item| {
                const item = CookieListItem{
                    .name = try ctx.allocator.dupe(u8, dict_item.name orelse ""),
                    .value = try ctx.allocator.dupe(u8, dict_item.value orelse ""),
                    .allocator = ctx.allocator,
                };
                try internal.addChanged(item);
            }
        }

        // Process deleted cookies using typed extraction
        if (try extractOptionalDictionarySlice(dictionaries.CookieListItem, init_dict.deleted)) |deleted_list| {
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

/// Getter for changed
/// https://cookiestore.spec.whatwg.org/#dom-extendablecookiechangeevent-changed
pub fn get_changed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return @ptrCast(&internal.changed);
}

/// Getter for deleted
/// https://cookiestore.spec.whatwg.org/#dom-extendablecookiechangeevent-deleted
pub fn get_deleted(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;
    return @ptrCast(&internal.deleted);
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

    // Set event type
    state.parent.parent.own.type = try allocator.dupe(u8, "cookiechange");
    state.parent.parent.own.bubbles = false;
    state.parent.parent.own.cancelable = false;
    state.parent.parent.own.isTrusted = true;
    state.parent.parent.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));

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
