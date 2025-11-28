//! Implementation for FormData interface
//!
//! XHR Standard: https://xhr.spec.whatwg.org/#interface-formdata
//!
//! FormData represents an ordered list of entries (name-value pairs).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const FormData = interfaces.FormData;

// Import internal FormData implementation
const xhr = @import("xhr");
const InternalFormData = xhr.form_data.FormData;

pub const State = FormData.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
    InvalidState,
};

/// Internal state for FormData implementation
///
/// Holds the internal FormData pointer which stores the actual entries.
pub const InternalState = struct {
    /// The internal form data (ordered list of entries)
    form_data: *InternalFormData,
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.form_data.deinit();
        // Don't destroy self here - let the caller handle it
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
    // TODO: Initialize your instance state here if needed
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, form: *runtime.Instance, submitter: *runtime.Instance) !*runtime.Instance {
    _ = form;
    _ = submitter;

    // Create empty FormData
    const form_data = try InternalFormData.init(allocator);
    errdefer form_data.deinit();

    return createFromInternal(allocator, ctx, form_data);
}

/// Create a FormData from internal FormData (internal helper)
///
/// This is used by other APIs (fetch, xhr) that need to create FormData
/// instances from parsed data.
/// Takes ownership of the internal FormData - caller should NOT deinit it.
pub fn createFromInternal(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    form_data: *InternalFormData,
) !*runtime.Instance {
    const instance = try init(allocator, State, &FormData.vtable, ctx);
    errdefer deinit(instance);

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .form_data = form_data,
        .allocator = allocator,
    };

    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Get internal state from instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Operation: append
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-append
/// Appends a new value to an existing key, or adds the key if it doesn't exist.
pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.form_data.appendString(name, value);
}

/// Operation: delete
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-delete
/// Removes all values associated with a given key.
pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.form_data.delete(name);
}

/// Operation: get
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-get
/// Returns the first value associated with a given key.
pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) ImplError!?typedefs.FormDataEntryValue {
    const internal = getInternal(instance) orelse return error.InvalidState;

    const entry = internal.form_data.get(name) orelse return null;

    return switch (entry) {
        .string => |s| .{ .variant_1 = runtime.USVString.initInterned(s) },
        .file => |f| .{ .variant_0 = @ptrCast(f) }, // Cast File to anyopaque
    };
}

/// Operation: getAll
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-getall
/// Returns all values associated with a given key.
pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) ImplError!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidState;

    const values = try internal.form_data.getAll(internal.allocator, name);

    // Return as opaque pointer (V8 binding will convert to JS array)
    return @ptrCast(values.ptr);
}

/// Operation: has
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-has
/// Returns whether a FormData object contains a certain key.
pub fn call_has(instance: *runtime.Instance, name: runtime.USVString) ImplError!bool {
    const internal = getInternal(instance) orelse return error.InvalidState;
    return internal.form_data.has(name);
}

/// Operation: set
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-set
/// Sets a new value for an existing key, or adds the key if it doesn't exist.
/// Replaces all existing values.
pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.form_data.setString(name, value);
}

/// Operation: forEach
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata
/// Iterates over all entries in the FormData.
pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Callback is a function pointer from V8
    // For now, return NotImplemented as this requires V8 integration
    _ = callback;
    _ = internal;

    return error.NotImplemented;
}
