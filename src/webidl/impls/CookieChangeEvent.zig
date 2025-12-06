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
/// https://cookiestore.spec.whatwg.org/#dom-cookiechangeevent-cookiechangeevent
///
/// The CookieChangeEvent(type, eventInitDict) constructor steps are:
/// 1. Set this's changed attribute to eventInitDict["changed"]
/// 2. Set this's deleted attribute to eventInitDict["deleted"]
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.CookieChangeEventInit)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &CookieChangeEvent.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // Get the Event state to initialize base event properties
    const state = instance.getState(State);

    // Initialize Event base properties
    state.parent.own.type = try @"type".clone(allocator);
    state.parent.own.bubbles = false;
    state.parent.own.cancelable = false;
    state.parent.own.composed = false;
    state.parent.own.target = null;
    state.parent.own.srcElement = null;
    state.parent.own.currentTarget = null;
    state.parent.own.eventPhase = 0; // NONE
    state.parent.own.cancelBubble = false;
    state.parent.own.returnValue = true;
    state.parent.own.defaultPrevented = false;
    state.parent.own.isTrusted = false;
    state.parent.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));

    // Process eventInitDict if provided
    if (eventInitDict.was_passed) {
        const init_dict = eventInitDict.value;

        // Apply EventInit base properties
        if (init_dict.base.bubbles) |bubbles| {
            state.parent.own.bubbles = bubbles;
        }
        if (init_dict.base.cancelable) |cancelable| {
            state.parent.own.cancelable = cancelable;
        }
        if (init_dict.base.composed) |composed| {
            state.parent.own.composed = composed;
        }

        // Process changed cookies
        // The changed field is *const anyopaque which is a pointer to CookieList (sequence<CookieListItem>)
        if (init_dict.changed) |changed_ptr| {
            const changed_list = @as(*const []const dictionaries.CookieListItem, @ptrCast(@alignCast(changed_ptr)));
            for (changed_list.*) |dict_item| {
                // Convert dictionary CookieListItem to our internal CookieListItem
                const item = CookieListItem{
                    .name = try allocator.dupe(u8, dict_item.name orelse ""),
                    .value = try allocator.dupe(u8, dict_item.value orelse ""),
                    .allocator = allocator,
                };
                try internal.addChanged(item);
            }
        }

        // Process deleted cookies
        if (init_dict.deleted) |deleted_ptr| {
            const deleted_list = @as(*const []const dictionaries.CookieListItem, @ptrCast(@alignCast(deleted_ptr)));
            for (deleted_list.*) |dict_item| {
                const item = CookieListItem{
                    .name = try allocator.dupe(u8, dict_item.name orelse ""),
                    .value = try allocator.dupe(u8, dict_item.value orelse ""),
                    .allocator = allocator,
                };
                try internal.addDeleted(item);
            }
        }
    }

    return instance;
}

/// Getter for changed
/// https://cookiestore.spec.whatwg.org/#dom-cookiechangeevent-changed
///
/// Returns a FrozenArray<CookieListItem> of changed cookies.
pub fn get_changed(instance: *runtime.Instance) anyerror!*const anyopaque {
    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // Return pointer to the internal changed list
    // The V8 bindings will convert this to a FrozenArray
    return @ptrCast(&internal.changed);
}

/// Getter for deleted
/// https://cookiestore.spec.whatwg.org/#dom-cookiechangeevent-deleted
///
/// Returns a FrozenArray<CookieListItem> of deleted cookies.
pub fn get_deleted(instance: *runtime.Instance) anyerror!*const anyopaque {
    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // Return pointer to the internal deleted list
    return @ptrCast(&internal.deleted);
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
    const state = instance.getState(State);

    // Set event type
    state.parent.own.type = try allocator.dupe(u8, "change");
    state.parent.own.bubbles = false;
    state.parent.own.cancelable = false;
    state.parent.own.isTrusted = true;
    state.parent.own.timeStamp = @as(typedefs.DOMHighResTimeStamp, @floatFromInt(std.time.milliTimestamp()));

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
