//! StorageEvent Implementation
//!
//! The StorageEvent interface represents events that are fired when
//! localStorage or sessionStorage changes.
//!
//! Spec: https://html.spec.whatwg.org/multipage/webstorage.html#the-storageevent-interface
//!
//! WebIDL:
//! ```idl
//! [Exposed=Window]
//! interface StorageEvent : Event {
//!   constructor(DOMString type, optional StorageEventInit eventInitDict = {});
//!
//!   readonly attribute DOMString? key;
//!   readonly attribute DOMString? oldValue;
//!   readonly attribute DOMString? newValue;
//!   readonly attribute USVString url;
//!   readonly attribute Storage? storageArea;
//!
//!   undefined initStorageEvent(DOMString type, optional boolean bubbles = false,
//!     optional boolean cancelable = false, optional DOMString? key = null,
//!     optional DOMString? oldValue = null, optional DOMString? newValue = null,
//!     optional USVString url = "", optional Storage? storageArea = null);
//! };
//! ```

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const EventImpl = @import("Event.zig");
const same_object = @import("same_object.zig");
const StorageEvent = interfaces.StorageEvent;

pub const State = StorageEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// "The key, oldValue, newValue, url, and storageArea attributes must return
/// the values they were initialized to."
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Owned copies.
    key: ?[]u8 = null,
    old_value: ?[]u8 = null,
    new_value: ?[]u8 = null,
    url: []u8 = &.{},
    /// The Storage object, kept alive with the event.
    storage_area: ?*runtime.Instance = null,
    storage_area_pin: same_object.Pin = .{},

    fn clear(self: *InternalState) void {
        if (self.key) |v| self.allocator.free(v);
        if (self.old_value) |v| self.allocator.free(v);
        if (self.new_value) |v| self.allocator.free(v);
        self.allocator.free(self.url);
        self.key = null;
        self.old_value = null;
        self.new_value = null;
        self.url = &.{};
        self.storage_area_pin.release();
        self.storage_area = null;
    }

    /// Set every attribute, copying the strings (BORROWED here). Nothing
    /// changes unless every copy is made.
    fn set(
        self: *InternalState,
        key: ?[]const u8,
        old_value: ?[]const u8,
        new_value: ?[]const u8,
        url: []const u8,
        storage_area: ?*runtime.Instance,
    ) !void {
        const allocator = self.allocator;
        const key_copy = if (key) |v| try allocator.dupe(u8, v) else null;
        errdefer if (key_copy) |v| allocator.free(v);
        const old_copy = if (old_value) |v| try allocator.dupe(u8, v) else null;
        errdefer if (old_copy) |v| allocator.free(v);
        const new_copy = if (new_value) |v| try allocator.dupe(u8, v) else null;
        errdefer if (new_copy) |v| allocator.free(v);
        const url_copy = try allocator.dupe(u8, url);
        self.clear();
        self.key = key_copy;
        self.old_value = old_copy;
        self.new_value = new_copy;
        self.url = url_copy;
        if (storage_area) |area| {
            self.storage_area = area;
            self.storage_area_pin.hold(area);
        }
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance
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

/// Deinitialize instance: its own state, then the Event part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.clear();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.Event.deinit(instance);
}

/// Constructor: DOM "inner event creation steps" for the Event part, then
/// each StorageEventInit member (key, oldValue and newValue default to null,
/// url to "", storageArea to null).
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.StorageEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &StorageEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.StorageEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{} };
    try EventImpl.innerEventCreationSteps(instance, @"type", dict.base);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    try internal.set(
        if (dict.key) |v| v.asSlice() else null,
        if (dict.oldValue) |v| v.asSlice() else null,
        if (dict.newValue) |v| v.asSlice() else null,
        dict.url orelse "",
        dict.storageArea,
    );
    return instance;
}

/// A copy: the binding frees what a string getter returns.
fn copyOf(instance: *runtime.Instance, value: ?[]const u8) !?runtime.DOMString {
    const v = value orelse return null;
    return try runtime.DOMString.initDupe(instance.ctx.allocator, v);
}

pub fn get_key(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return null;
    return copyOf(instance, internal.key);
}

pub fn get_oldValue(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return null;
    return copyOf(instance, internal.old_value);
}

pub fn get_newValue(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const internal = getInternal(instance) orelse return null;
    return copyOf(instance, internal.new_value);
}

/// A USVString getter's result is freed by the binding: a copy.
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return instance.ctx.allocator.dupe(u8, "");
    return instance.ctx.allocator.dupe(u8, internal.url);
}

pub fn get_storageArea(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.storage_area;
}

/// Operation: initStorageEvent (legacy): "must initialize the event in a
/// manner analogous to the similarly-named initEvent() method" - nothing
/// while it is being dispatched; otherwise Event's initialize, then each
/// argument (key, oldValue and newValue default to null, url to "",
/// storageArea to null).
pub fn call_initStorageEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), key: webidl.Opt(?runtime.DOMString), oldValue: webidl.Opt(?runtime.DOMString), newValue: webidl.Opt(?runtime.DOMString), url: webidl.Opt(runtime.USVString), storageArea: webidl.Opt(?*runtime.Instance)) anyerror!void {
    if (EventImpl.getDispatchFlag(instance)) return;
    try EventImpl.call_initEvent(instance, @"type", bubbles, cancelable);
    const internal = getInternal(instance) orelse return;
    const optionalSlice = struct {
        fn of(value: webidl.Opt(?runtime.DOMString)) ?[]const u8 {
            if (!value.was_passed) return null;
            const v = value.value orelse return null;
            return v.asSlice();
        }
    }.of;
    try internal.set(
        optionalSlice(key),
        optionalSlice(oldValue),
        optionalSlice(newValue),
        if (url.was_passed) url.value else "",
        if (storageArea.was_passed) storageArea.value else null,
    );
}
