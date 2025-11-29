//! Implementation for URLSearchParams interface
//!
//! WHATWG URL Standard implementation
//! Spec: https://url.spec.whatwg.org/#interface-urlsearchparams

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const interfaces = @import("interfaces");
const URLSearchParams = interfaces.URLSearchParams;

// Import URL infrastructure
const infra = @import("infra");
const form_parser = @import("form_parser");
const form_serializer = @import("form_serializer");
const Tuple = form_parser.Tuple;
const URLRecord = @import("url_record").URLRecord;

/// URL's InternalState structure (for type-safe casting)
/// This mirrors the structure in URL.zig without creating a circular dependency
const URLInternalState = struct {
    url_record: URLRecord,
    query_params_instance: ?*runtime.Instance,
    allocator: std.mem.Allocator,
};

pub const State = URLSearchParams.State;

/// Record entry type for URLSearchParams initialization
pub const RecordEntry = struct {
    name: []const u8,
    value: []const u8,
};

/// Internal state for URLSearchParams implementation
/// Stores the list of name-value tuples
pub const InternalState = struct {
    list: infra.List(Tuple),
    url_object: ?*runtime.Instance, // Back-reference to URL
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState, allocator: std.mem.Allocator) void {
        // Free all tuples
        for (0..self.list.len) |i| {
            if (self.list.get(i)) |tuple| {
                tuple.deinit(self.allocator);
            }
        }
        self.list.deinit();
        allocator.destroy(self);
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
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit(state.own._internal.?.allocator);
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
/// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams (lines 2041-2056)
///
/// Takes union type: (sequence<sequence<USVString>> or record<USVString, USVString> or USVString)
/// The init_data parameter is a type-erased pointer that we need to interpret
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, init_data: webidl.Opt(*const anyopaque)) !*runtime.Instance {
    // For now, treat as empty string
    // Proper union type handling requires runtime type tags
    _ = init_data;
    return initWithString(allocator, ctx, "");
}

/// Initialize from string (query string)
/// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-new step 3
pub fn initWithString(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    query: []const u8,
) !*runtime.Instance {
    // Create instance
    const instance = try init(allocator, State, &URLSearchParams.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .list = infra.List(Tuple).init(allocator),
        .url_object = null,
        .allocator = allocator,
    };

    // Remove leading ? if present
    const query_string = if (std.mem.startsWith(u8, query, "?"))
        query[1..]
    else
        query;

    // Parse the query string
    if (query_string.len > 0) {
        const tuples = try form_parser.parse(allocator, query_string);
        errdefer {
            for (tuples) |tuple| tuple.deinit(allocator);
            allocator.free(tuples);
        }

        for (tuples) |tuple| {
            try internal.list.append(tuple);
        }

        allocator.free(tuples);
    }

    state.own._internal = internal;
    return instance;
}

/// Initialize from sequence of sequences
/// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-new step 1
pub fn initWithSequence(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    sequence: []const [2][]const u8,
) !*runtime.Instance {
    // Create instance
    const instance = try init(allocator, State, &URLSearchParams.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .list = infra.List(Tuple).init(allocator),
        .url_object = null,
        .allocator = allocator,
    };

    // Add each pair to the list
    for (sequence) |pair| {
        const name = try allocator.dupe(u8, pair[0]);
        errdefer allocator.free(name);

        const value = try allocator.dupe(u8, pair[1]);
        errdefer allocator.free(value);

        try internal.list.append(.{ .name = name, .value = value });
    }

    state.own._internal = internal;
    return instance;
}

/// Initialize from record (dictionary)
/// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-new step 2
pub fn initWithRecord(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    record: []const RecordEntry,
) !*runtime.Instance {
    // Create instance
    const instance = try init(allocator, State, &URLSearchParams.vtable, ctx);
    errdefer deinit(instance);

    const state = instance.getState(State);

    // Create InternalState
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = InternalState{
        .list = infra.List(Tuple).init(allocator),
        .url_object = null,
        .allocator = allocator,
    };

    // Add each entry to the list
    for (record) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(name);

        const value = try allocator.dupe(u8, entry.value);
        errdefer allocator.free(value);

        try internal.list.append(.{ .name = name, .value = value });
    }

    state.own._internal = internal;
    return instance;
}

// ========================================================================
// Update Steps
// ========================================================================

/// Update associated URL's query
/// Spec: https://url.spec.whatwg.org/#concept-urlsearchparams-update (lines 2057-2065)
fn updateSteps(instance: *runtime.Instance) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Step 1: If URL object is null, return
    if (internal.url_object == null) return;

    // Step 2: Serialize list
    const serialized = try form_serializer.serialize(internal.allocator, internal.list.toSlice());
    defer internal.allocator.free(serialized);

    // Step 3-4: Update URL's query
    const url_instance = internal.url_object.?;
    const url_state = url_instance.getState(interfaces.URL.State);

    if (url_state.own._internal) |url_internal_ptr| {
        // Cast to URL's InternalState (using locally defined structure)
        const url_internal: *URLInternalState = @ptrCast(@alignCast(url_internal_ptr));

        // Set new query (empty string becomes null)
        const new_query = if (serialized.len == 0) null else serialized;
        try url_internal.url_record.setQuery(new_query);
    }
}

// ========================================================================
// Getters
// ========================================================================

/// size getter
/// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-size (line 2062)
pub fn get_size(instance: *runtime.Instance) anyerror!u32 {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;
    return @intCast(internal.list.len);
}

// ========================================================================
// Methods
// ========================================================================

/// append method
/// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-append (lines 2064-2066)
pub fn call_append(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Create owned copies
    const name_copy = try internal.allocator.dupe(u8, name);
    errdefer internal.allocator.free(name_copy);

    const value_copy = try internal.allocator.dupe(u8, value);
    errdefer internal.allocator.free(value_copy);

    // Append to list
    try internal.list.append(.{ .name = name_copy, .value = value_copy });

    // Run update steps
    try updateSteps(instance);
}

/// delete method
/// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-delete (lines 2068-2073)
pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString, value: webidl.Opt(runtime.USVString)) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Determine if we should match value or just name
    const value_slice = if (value.was_passed) value.value else "";
    const should_match_value = value_slice.len > 0; // If empty string, only match name

    var i: usize = 0;
    while (i < internal.list.len) {
        const tuple = internal.list.get(i).?;

        const should_remove = if (should_match_value)
            std.mem.eql(u8, tuple.name, name) and std.mem.eql(u8, tuple.value, value_slice)
        else
            std.mem.eql(u8, tuple.name, name);

        if (should_remove) {
            const removed = try internal.list.remove(i);
            removed.deinit(internal.allocator);
            // Don't increment i, check same index again
        } else {
            i += 1;
        }
    }

    // Run update steps
    try updateSteps(instance);
}

/// get method
/// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-get (lines 2075-2080)
pub fn call_get(instance: *runtime.Instance, name: runtime.USVString) anyerror!?runtime.USVString {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Find first tuple with matching name
    for (0..internal.list.len) |i| {
        const tuple = internal.list.get(i).?;
        if (std.mem.eql(u8, tuple.name, name)) {
            // Return copy of value (caller owns it)
            return try internal.allocator.dupe(u8, tuple.value);
        }
    }

    // Return empty string if not found (null in WebIDL becomes empty in USVString)
    return try internal.allocator.dupe(u8, "");
}

/// getAll method
/// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-getall (lines 2082-2091)
pub fn call_getAll(instance: *runtime.Instance, name: runtime.USVString) anyerror!*const anyopaque {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Count matching values first
    var count: usize = 0;
    for (0..internal.list.len) |i| {
        const tuple = internal.list.get(i).?;
        if (std.mem.eql(u8, tuple.name, name)) {
            count += 1;
        }
    }

    // Allocate result array
    const result = try internal.allocator.alloc([]const u8, count);

    // Fill result array
    var idx: usize = 0;
    for (0..internal.list.len) |i| {
        const tuple = internal.list.get(i).?;
        if (std.mem.eql(u8, tuple.name, name)) {
            result[idx] = try internal.allocator.dupe(u8, tuple.value);
            idx += 1;
        }
    }

    // Return as opaque pointer (caller will interpret as sequence)
    return @ptrCast(result.ptr);
}

/// has method
/// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-has (lines 2093-2098)
pub fn call_has(instance: *runtime.Instance, name: runtime.USVString, value: webidl.Opt(runtime.USVString)) anyerror!bool {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    const value_slice = if (value.was_passed) value.value else "";
    const should_match_value = value_slice.len > 0;

    for (0..internal.list.len) |i| {
        const tuple = internal.list.get(i).?;

        const matches = if (should_match_value)
            std.mem.eql(u8, tuple.name, name) and std.mem.eql(u8, tuple.value, value_slice)
        else
            std.mem.eql(u8, tuple.name, name);

        if (matches) return true;
    }

    return false;
}

/// set method
/// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-set (lines 2100-2109)
pub fn call_set(instance: *runtime.Instance, name: runtime.USVString, value: runtime.USVString) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Find first tuple with matching name
    var found_index: ?usize = null;
    var i: usize = 0;
    while (i < internal.list.len) {
        const tuple = internal.list.get(i).?;

        if (std.mem.eql(u8, tuple.name, name)) {
            if (found_index == null) {
                // This is the first match - update it
                found_index = i;

                // Replace the tuple with new value
                const old_tuple = try internal.list.remove(i);
                old_tuple.deinit(internal.allocator);

                const name_copy = try internal.allocator.dupe(u8, name);
                errdefer internal.allocator.free(name_copy);
                const value_copy = try internal.allocator.dupe(u8, value);

                try internal.list.insert(i, .{ .name = name_copy, .value = value_copy });

                i += 1;
            } else {
                // This is a subsequent match - remove it
                const removed = try internal.list.remove(i);
                removed.deinit(internal.allocator);
                // Don't increment i
            }
        } else {
            i += 1;
        }
    }

    // If no match was found, append new tuple
    if (found_index == null) {
        const name_copy = try internal.allocator.dupe(u8, name);
        errdefer internal.allocator.free(name_copy);

        const value_copy = try internal.allocator.dupe(u8, value);
        errdefer internal.allocator.free(value_copy);

        try internal.list.append(.{ .name = name_copy, .value = value_copy });
    }

    // Run update steps
    try updateSteps(instance);
}

/// sort method
/// Spec: https://url.spec.whatwg.org/#dom-urlsearchparams-sort (lines 2111-2113)
pub fn call_sort(instance: *runtime.Instance) anyerror!void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return error.InvalidState;

    // Sort tuples by name (stable sort)
    const items = internal.list.toSliceMut();
    std.mem.sort(Tuple, items, {}, struct {
        fn lessThan(_: void, a: Tuple, b: Tuple) bool {
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.lessThan);

    // Run update steps
    try updateSteps(instance);
}

/// forEach method
/// Spec: WebIDL iterable forEach
pub fn call_forEach(instance: *runtime.Instance, callback: *const anyopaque) anyerror!void {
    _ = instance;
    _ = callback;

    // TODO: Implement callback invocation
    // This requires understanding how to call JavaScript callbacks from Zig
    // For now, return NotImplemented
    return error.NotImplemented;
}
