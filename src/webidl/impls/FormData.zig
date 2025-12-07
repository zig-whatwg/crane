//! Implementation for FormData interface
//!
//! XHR Standard: https://xhr.spec.whatwg.org/#interface-formdata
//!
//! FormData represents an ordered list of entries (name-value pairs).

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
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

/// Entry type for iterable protocol - uses the interface's type
pub const IterableEntry = FormData.IterableEntry;

/// Internal state for FormData implementation
///
/// Holds the internal FormData pointer which stores the actual entries.
pub const InternalState = struct {
    /// The internal form data (ordered list of entries)
    form_data: *InternalFormData,
    /// Allocator for memory management
    allocator: std.mem.Allocator,
    /// Cached iterable entries for iteration protocol
    iterable_cache: ?[]IterableEntry = null,

    pub fn deinit(self: *InternalState) void {
        // Free iterable cache
        if (self.iterable_cache) |cache| {
            self.allocator.free(cache);
        }
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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, form: webidl.Opt(*runtime.Instance), submitter: webidl.Opt(?*runtime.Instance)) !*runtime.Instance {
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

/// Operation: append (string overload)
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-append
/// Appends a new value to an existing key, or adds the key if it doesn't exist.
pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.form_data.appendString(name, value);
}

/// Operation: append (Blob overload)
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-append
/// Appends a Blob/File to an existing key, or adds the key if it doesn't exist.
pub fn call_appendBlob(instance: *runtime.Instance, name: runtime.USVString, blob_instance: *runtime.Instance, filename: ?runtime.USVString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Store the Blob instance reference
    // We need to store it in a way that can be retrieved later
    // For now, create an entry that holds the blob instance pointer
    try internal.form_data.appendBlobInstance(name, blob_instance, filename);
}

/// Dispatch method for append - handles overload resolution at runtime
///
/// This receives the raw V8 value as `any` and determines whether to:
/// - Store as string (if it's a string or coercible to string)
/// - Store as Blob instance (if it's a Blob/File object)
pub fn call_appendDispatch(instance: *runtime.Instance, name: runtime.USVString, value_v8: runtime.Any) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Import V8 FFI types for runtime type checking
    const v8 = @import("v8");

    // Cast the any pointer to V8 Value
    const value: *v8.ffi.Value = @ptrCast(@alignCast(value_v8));

    // Check if this is a wrapped instance (Blob/File)
    if (v8.ffi.v8_Value_IsObject(value)) {
        const obj: *v8.ffi.Object = @ptrCast(value);
        // Try to get a wrapped instance from internal field
        const ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(obj, 0);
        if (ptr != null) {
            // This is a wrapped instance - store as blob
            const blob_instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
            try internal.form_data.appendBlobInstance(name, blob_instance, null);
            return;
        }
    }

    // Not a Blob instance - convert to string
    // Get context for string conversion
    const context: *v8.ffi.Context = instance.ctx.getEngineContextAs(v8.ffi.Context) orelse return error.InvalidState;

    // Convert to string using V8's ToString
    if (v8.ffi.v8_Value_ToString(value, context)) |str| {
        const len = v8.ffi.v8_String_Utf8Length(str);
        if (len <= 0) {
            try internal.form_data.appendString(name, "");
            return;
        }

        // Allocate buffer and copy string
        const buffer = internal.allocator.alloc(u8, @intCast(len)) catch return error.OutOfMemory;
        defer internal.allocator.free(buffer);

        _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
        try internal.form_data.appendString(name, buffer);
    } else {
        // Fallback to empty string
        try internal.form_data.appendString(name, "");
    }
}

/// Dispatch method for set - handles overload resolution at runtime
pub fn call_setDispatch(instance: *runtime.Instance, name: runtime.USVString, value_v8: runtime.Any) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Import V8 FFI types
    const v8 = @import("v8");
    const value: *v8.ffi.Value = @ptrCast(@alignCast(value_v8));

    // Check if this is a wrapped instance (Blob/File)
    if (v8.ffi.v8_Value_IsObject(value)) {
        const obj: *v8.ffi.Object = @ptrCast(value);
        const ptr = v8.ffi.v8_Object_GetAlignedPointerFromInternalField(obj, 0);
        if (ptr != null) {
            // This is a wrapped instance - set as blob
            const blob_instance: *runtime.Instance = @ptrCast(@alignCast(ptr));
            try internal.form_data.setBlobInstance(name, blob_instance, null);
            return;
        }
    }

    // Not a Blob instance - convert to string
    const context: *v8.ffi.Context = instance.ctx.getEngineContextAs(v8.ffi.Context) orelse return error.InvalidState;

    if (v8.ffi.v8_Value_ToString(value, context)) |str| {
        const len = v8.ffi.v8_String_Utf8Length(str);
        if (len <= 0) {
            try internal.form_data.setString(name, "");
            return;
        }

        const buffer = internal.allocator.alloc(u8, @intCast(len)) catch return error.OutOfMemory;
        defer internal.allocator.free(buffer);

        _ = v8.ffi.v8_String_WriteUtf8(str, buffer.ptr, @intCast(len));
        try internal.form_data.setString(name, buffer);
    } else {
        try internal.form_data.setString(name, "");
    }
}

/// Operation: delete
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-delete
/// Removes all values associated with a given key.
pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    internal.form_data.delete(name);
}

/// Operation: get
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-get
/// Returns the first value associated with a given key.
pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!?typedefs.FormDataEntryValue {
    const internal = getInternal(instance) orelse return error.InvalidState;

    const entry = internal.form_data.get(name) orelse return null;

    return switch (entry) {
        .string => |s| .{ .usvstring = s }, // USVString is []const u8
        .file => |f| .{ .file = @ptrCast(f) }, // Cast File to Instance
        .blob_instance => |ptr| .{ .file = @ptrCast(@alignCast(ptr)) }, // Return the stored Blob/File instance
    };
}

/// Operation: getAll
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-getall
/// Returns all values associated with a given key.
pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidState;

    const values = try internal.form_data.getAll(internal.allocator, name);

    // Convert FormDataEntryValue to strings
    var string_values: std.ArrayListUnmanaged([]const u8) = .{};
    defer string_values.deinit(internal.allocator);

    for (values) |entry_value| {
        switch (entry_value) {
            .string => |s| {
                string_values.append(internal.allocator, s) catch continue;
            },
            .file => {
                // For files, return "[object File]" as the string representation
                string_values.append(internal.allocator, "[object File]") catch continue;
            },
            .blob_instance => {
                // For blob instances, return "[object Blob]" as the string representation
                // Note: In a real implementation, we should return the actual Blob objects
                string_values.append(internal.allocator, "[object Blob]") catch continue;
            },
        }
    }

    // Get the engine interface to create JS array
    const engine = instance.ctx.engine orelse {
        return error.InvalidState;
    };
    const engine_ctx = instance.ctx.engine_ctx orelse {
        return error.InvalidState;
    };

    // Create JS array through engine abstraction
    const createStringArray = engine.createStringArray orelse {
        return error.InvalidState;
    };

    const js_array = createStringArray(engine_ctx, string_values.items) catch {
        return error.InvalidState;
    };

    return js_array;
}

/// Operation: has
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-has
/// Returns whether a FormData object contains a certain key.
pub fn call_has(instance: *runtime.Instance, name: runtime.USVString) anyerror!bool {
    const internal = getInternal(instance) orelse return error.InvalidState;
    return internal.form_data.has(name);
}

/// Operation: set
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-set
/// Sets a new value for an existing key, or adds the key if it doesn't exist.
/// Replaces all existing values.
pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.form_data.setString(name, value);
}

/// Operation: forEach
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata
/// Iterates over all entries in the FormData.
pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Callback is a function pointer from V8
    // For now, return NotImplemented as this requires V8 integration
    _ = callback;
    _ = internal;

    return error.NotImplemented;
}

/// Get entries for iterable protocol (used by V8Interface)
///
/// Returns entries that can be iterated by entries(), keys(), values(), Symbol.iterator.
/// For file entries, returns "[object File]" as the string representation.
pub fn getEntriesForIterable(instance: *runtime.Instance) ?[]const IterableEntry {
    const internal = getInternal(instance) orelse return null;

    // Build array of IterableEntry from internal form data entries
    // We need to store these in InternalState since the slice must outlive this call
    const entries = internal.form_data.entries.items;

    // Allocate space for iterable entries (cached in internal state)
    // Free previous cache if any
    if (internal.iterable_cache) |cache| {
        internal.allocator.free(cache);
        internal.iterable_cache = null;
    }

    const iterable_entries = internal.allocator.alloc(IterableEntry, entries.len) catch return null;
    errdefer internal.allocator.free(iterable_entries);

    for (entries, 0..) |entry, i| {
        iterable_entries[i] = .{
            .name = entry.name,
            .value = switch (entry.value) {
                .string => |s| s,
                .file => "[object File]",
                .blob_instance => "[object Blob]",
            },
        };
    }

    // Cache for lifetime management
    internal.iterable_cache = iterable_entries;

    return iterable_entries;
}
