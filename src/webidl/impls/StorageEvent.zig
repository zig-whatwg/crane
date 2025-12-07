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
const StorageEvent = interfaces.StorageEvent;

// Import pointer_tag for V8 pointer untagging (via v8 module)
const pointer_tag = @import("v8").pointer_tag;

pub const State = StorageEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for StorageEvent
/// Holds the actual event data for storage change notifications.
pub const InternalState = struct {
    /// The key being changed. Null if clear() was called.
    key: ?[]const u8,
    /// The old value of the key being changed. Null for new keys.
    old_value: ?[]const u8,
    /// The new value of the key being changed. Null for removed keys.
    new_value: ?[]const u8,
    /// The URL of the document whose storage changed.
    url: []const u8,
    /// The Storage object that was affected (localStorage or sessionStorage).
    storage_area: ?*runtime.Instance,
    /// Whether we own the allocated strings
    owns_strings: bool,
    /// Allocator for cleanup
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) InternalState {
        return .{
            .key = null,
            .old_value = null,
            .new_value = null,
            .url = "",
            .storage_area = null,
            .owns_strings = false,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *InternalState) void {
        if (self.owns_strings) {
            if (self.key) |key| {
                self.allocator.free(key);
            }
            if (self.old_value) |old| {
                self.allocator.free(old);
            }
            if (self.new_value) |new| {
                self.allocator.free(new);
            }
            if (self.url.len > 0) {
                self.allocator.free(self.url);
            }
        }
    }

    /// Set values from dictionary, copying strings
    pub fn setFromDict(
        self: *InternalState,
        key: ?[]const u8,
        old_value: ?[]const u8,
        new_value: ?[]const u8,
        url: []const u8,
        storage_area: ?*runtime.Instance,
    ) !void {
        // Clean up old values if we own them
        if (self.owns_strings) {
            self.deinit();
        }

        // Copy new values
        self.key = if (key) |k| try self.allocator.dupe(u8, k) else null;
        self.old_value = if (old_value) |o| try self.allocator.dupe(u8, o) else null;
        self.new_value = if (new_value) |n| try self.allocator.dupe(u8, n) else null;
        self.url = if (url.len > 0) try self.allocator.dupe(u8, url) else "";
        self.storage_area = storage_area;
        self.owns_strings = true;
    }
};

/// Initialize instance
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer instance.deinit();

    // Create internal state
    const internal = try allocator.create(InternalState);
    internal.* = InternalState.init(allocator);

    // Store internal state
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
}

/// Helper to extract slice from DOMString
fn domStringToSlice(str: runtime.DOMString) []const u8 {
    return str.asSlice();
}

/// Helper to convert optional slice to optional DOMString
fn sliceToDOMString(slice: ?[]const u8) ?runtime.DOMString {
    if (slice) |s| {
        return runtime.DOMString.initInterned(s);
    }
    return null;
}

/// Constructor implementation
/// Spec: new StorageEvent(type, eventInitDict)
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.StorageEventInit)) !*runtime.Instance {
    const instance = try init(allocator, State, &StorageEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Set event type (handled by Event base)
    _ = @"type";

    // Apply dictionary values if provided
    if (eventInitDict.was_passed) {
        const dict = eventInitDict.value;
        if (state.own._internal) |internal| {
            // Extract values from dictionary - dict fields are already ?DOMString
            const key = if (dict.key) |k| domStringToSlice(k) else null;
            const old_val = if (dict.oldValue) |o| domStringToSlice(o) else null;
            const new_val = if (dict.newValue) |n| domStringToSlice(n) else null;
            const url_val = dict.url orelse "";
            // storageArea is ?*const anyopaque, need to untag and cast to ?*runtime.Instance
            const storage: ?*runtime.Instance = if (dict.storageArea) |s| blk: {
                const untagged = pointer_tag.untagPointer(s);
                break :blk @ptrCast(@alignCast(untagged.ptr));
            } else null;

            try internal.setFromDict(key, old_val, new_val, url_val, storage);
        }
    }

    return instance;
}

/// Getter for key
/// Returns the key being changed, or null if clear() was called.
pub fn get_key(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return sliceToDOMString(internal.key);
    }
    return null;
}

/// Getter for oldValue
/// Returns the old value of the key being changed, or null for new keys.
pub fn get_oldValue(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return sliceToDOMString(internal.old_value);
    }
    return null;
}

/// Getter for newValue
/// Returns the new value of the key being changed, or null for removed keys.
pub fn get_newValue(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return sliceToDOMString(internal.new_value);
    }
    return null;
}

/// Getter for url
/// Returns the URL of the document whose storage changed.
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.url;
    }
    return "";
}

/// Getter for storageArea
/// Returns the Storage object that was affected.
pub fn get_storageArea(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        return internal.storage_area;
    }
    return null;
}

/// Operation: initStorageEvent
/// Legacy method to initialize the event after construction.
/// Spec: initStorageEvent(type, bubbles, cancelable, key, oldValue, newValue, url, storageArea)
pub fn call_initStorageEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), key: webidl.Opt(?runtime.DOMString), oldValue: webidl.Opt(?runtime.DOMString), newValue: webidl.Opt(?runtime.DOMString), url: webidl.Opt(runtime.USVString), storageArea: webidl.Opt(?*runtime.Instance)) anyerror!void {
    // Set event type (handled by base Event)
    _ = @"type";
    _ = bubbles;
    _ = cancelable;

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // For Opt types, check was_passed then access value
        const key_val = if (key.was_passed) blk: {
            if (key.value) |k| {
                break :blk domStringToSlice(k);
            }
            break :blk null;
        } else null;

        const old_val = if (oldValue.was_passed) blk: {
            if (oldValue.value) |o| {
                break :blk domStringToSlice(o);
            }
            break :blk null;
        } else null;

        const new_val = if (newValue.was_passed) blk: {
            if (newValue.value) |n| {
                break :blk domStringToSlice(n);
            }
            break :blk null;
        } else null;

        // url is Opt(USVString) where USVString = []const u8
        const url_val = if (url.was_passed) url.value else "";

        const storage = if (storageArea.was_passed) storageArea.value else null;

        try internal.setFromDict(key_val, old_val, new_val, url_val, storage);
    }
}

// ============================================================================
// Helper function to create and dispatch storage events
// ============================================================================

/// Create a StorageEvent for a storage change.
/// This is called by localStorage/sessionStorage when a change occurs.
pub fn createStorageEvent(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    key: ?[]const u8,
    old_value: ?[]const u8,
    new_value: ?[]const u8,
    url: []const u8,
    storage_area: ?*runtime.Instance,
) !*runtime.Instance {
    const instance = try init(allocator, State, &StorageEvent.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        try internal.setFromDict(key, old_value, new_value, url, storage_area);
    }

    return instance;
}
