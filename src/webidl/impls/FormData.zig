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
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const InternalFormData = xhr.form_data.FormData;

pub const State = FormData.State;

pub const ImplError = error{
    NotImplemented,
    OutOfMemory,
    InvalidState,
};

/// Entry type for iterable protocol
/// FormData iterates as (USVString, FormDataEntryValue) pairs
pub const IterableEntry = struct {
    name: []const u8,
    value: typedefs.FormDataEntryValue,
};

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
pub fn call_constructor(ctx: runtime.Context, form: webidl.Opt(*runtime.Instance), submitter: webidl.Opt(?*runtime.Instance)) !*runtime.Instance {
    _ = form;
    _ = submitter;

    // Create empty FormData
    const form_data = try InternalFormData.init(ctx.allocator);
    errdefer form_data.deinit();

    return createFromInternal(ctx.allocator, ctx, form_data);
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

/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Operation: append (string overload)
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-append
/// Appends a new value to an existing key, or adds the key if it doesn't exist.
pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    try internal.form_data.appendString(name, value);
}

/// Internal: append Blob/File entry
///
/// This is an internal helper for handling the Blob overload of append.
/// NOT a WebIDL operation - no corresponding interface delegate.
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-append
pub fn appendBlobEntry(instance: *runtime.Instance, name: runtime.USVString, blob_instance: *runtime.Instance, filename: ?runtime.USVString) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Store the Blob instance reference
    // We need to store it in a way that can be retrieved later
    // For now, create an entry that holds the blob instance pointer
    try internal.form_data.appendBlobInstance(name, blob_instance, filename);
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
pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidState;

    const values = try internal.form_data.getAll(internal.allocator, name);

    // Convert FormDataEntryValue to strings
    var string_values: std.ArrayListUnmanaged([]const u8) = .empty;
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

    // The strings as a new Array of the realm (R12), OWNED by the binding
    // once returned.
    const js_values = try internal.allocator.alloc(runtime.JSValue, string_values.items.len);
    defer internal.allocator.free(js_values);
    for (string_values.items, js_values) |text, *value| value.* = runtime.JSValue.fromStringRef(text);
    const array = @import("engine").createSequenceOfValues(instance.ctx, js_values) catch return error.InvalidState;
    return array.take();
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
pub fn call_forEach(instance: *runtime.Instance, callback: runtime.JSValue) anyerror!void {
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
                .string => |s| .{ .usvstring = s },
                // For files, return [object File] placeholder
                // TODO: Return actual File instance when WebIDL File is fully integrated
                .file => .{ .usvstring = "[object File]" },
                // blob_instance is already a runtime.Instance (File or Blob)
                .blob_instance => |b| .{ .file = @ptrCast(@alignCast(b)) },
            },
        };
    }

    // Cache for lifetime management
    internal.iterable_cache = iterable_entries;

    return iterable_entries;
}

/// Alias for getEntriesForIterable - called by generated interface
pub const getEntriesInternal = getEntriesForIterable;
