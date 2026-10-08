//! Implementation for FormData interface
//!
//! XHR Standard: https://xhr.spec.whatwg.org/#interface-formdata
//!
//! FormData represents an ordered list of entries (name-value pairs).

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
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
    files_traced: bool = false,

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
        if (internal.files_traced) engine.forgetTracedChild(instance, .{ .name = "entryFiles" });
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
/// This is called when the interface is constructed from JavaScript
///
/// XHR: "The new FormData(form, submitter) constructor steps are: 1. If form
/// is given, then: 1. If submitter is non-null, then: 1. If submitter is not
/// a submit button, then throw a TypeError. 2. If submitter's form owner is
/// not form, then throw a "NotFoundError" DOMException. 2. Let list be the
/// result of constructing the entry list for form and submitter. 3. If list
/// is null, then throw an "InvalidStateError" DOMException. 4. Set this's
/// entry list to list." Steps 1.1-1.4 are the form's (dom.form_submission).
pub fn call_constructor(ctx: runtime.Context, form: webidl.Opt(*runtime.Instance), submitter: webidl.Opt(?*runtime.Instance)) !*runtime.Instance {
    // An empty FormData, owned by its instance once made: the errdefer ends
    // where the ownership moves.
    const instance = blk: {
        const form_data = try InternalFormData.init(ctx.allocator);
        errdefer form_data.deinit();
        break :blk try createFromInternal(ctx.allocator, ctx, form_data);
    };
    if (form.was_passed) {
        const given_submitter: ?*runtime.Instance = if (submitter.was_passed) submitter.value else null;
        @import("dom").form_submission.constructEntryList(form.value, given_submitter, instance) catch |err| {
            instance.releaseIfUnwrapped(runtime.SlabAllocator.generationOf(instance));
            return err;
        };
    }
    return instance;
}

/// Create a FormData from internal FormData (internal helper)
///
/// This is used by other APIs (fetch, xhr) that need to create FormData
/// instances from parsed data.
/// Takes ownership on success; on error the caller still owns the entry list.
pub fn createFromInternal(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    form_data: *InternalFormData,
) !*runtime.Instance {
    const instance = try init(allocator, State, &FormData.vtable, ctx);
    // No wrapper is made before the final, infallible ownership transfer.
    errdefer runtime.Instance.deinit(instance);

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .form_data = form_data,
        .allocator = allocator,
    };

    const trace = try materializeParsedFiles(instance, internal);
    defer if (trace) |value| value.release();

    const state = instance.getState(State);
    state.own._internal = internal;
    setFileTrace(instance, internal, trace);

    return instance;
}

/// Fetch formData(), multipart steps 1–3: construct actual Files before the
/// parsed entry list becomes observable. Native byte records are not Instances.
fn materializeParsedFiles(instance: *runtime.Instance, internal: *InternalState) !?engine.Owned {
    var count: usize = 0;
    for (internal.form_data.entries.items) |entry| if (entry.value != .string) {
        count += 1;
    };
    if (count == 0) return null;

    const PreparedFile = struct {
        entry: *xhr.form_data.FormDataEntry,
        file: *runtime.Instance,
        keep: engine.Owned,
    };
    const prepared = try internal.allocator.alloc(PreparedFile, count);
    defer internal.allocator.free(prepared);
    var prepared_len: usize = 0;
    defer for (prepared[0..prepared_len]) |item| item.keep.release();
    const values = try internal.allocator.alloc(runtime.JSValue, count);
    defer internal.allocator.free(values);

    for (internal.form_data.entries.items) |*entry| {
        const file = switch (entry.value) {
            .string => continue,
            .blob_instance => |object| @as(*runtime.Instance, @ptrCast(@alignCast(object))),
            .file => |record| blk: {
                const bytes = try engine.createArrayBuffer(instance.ctx, record.data);
                defer bytes.release();
                const parts = try engine.createSequenceOfValues(instance.ctx, &.{bytes.value});
                defer parts.release();
                break :blk try interfaces.File.call_constructor(instance.ctx, parts.value, entry.filename orelse "blob", .passed(.{
                    .base = .{ .type = runtime.DOMString.initInterned(record.content_type orelse "text/plain") },
                }));
            },
        };
        const generation = runtime.SlabAllocator.generationOf(file);
        defer if (entry.value == .file) file.releaseIfUnwrapped(generation);
        const keep = try engine.retainValue(instance.ctx, .{ .instance = file });
        prepared[prepared_len] = .{ .entry = entry, .file = file, .keep = keep };
        values[prepared_len] = keep.value;
        prepared_len += 1;
    }

    // All fallible work precedes replacement: the caller's records remain
    // unchanged on error, and each prepared File is rooted across allocations.
    const trace = try engine.createSequenceOfValues(instance.ctx, values);
    for (prepared) |item| {
        if (item.entry.value == .file) item.entry.value.deinit(internal.form_data.allocator);
        item.entry.value = .{ .blob_instance = item.file };
    }
    return trace;
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

/// XHR append steps 1–3, with HTML's create-an-entry File conversion.
pub fn call_append__1(instance: *runtime.Instance, name: runtime.USVString, blob: *runtime.Instance, filename: webidl.Opt(runtime.USVString)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const file = try entryFile(instance.ctx, blob, filename);
    const generation = runtime.SlabAllocator.generationOf(file);
    defer if (file != blob) file.releaseIfUnwrapped(generation);
    const trace = try prepareFileTrace(instance, internal, null, file);
    defer if (trace) |value| value.release();
    try internal.form_data.appendBlobInstance(name, file, null);
    setFileTrace(instance, internal, trace);
}

fn entryFile(realm: runtime.Context, blob: *runtime.Instance, filename: webidl.Opt(runtime.USVString)) !*runtime.Instance {
    if (!filename.was_passed and blob.stateAs(interfaces.File.State) != null) return blob;
    const parts = try engine.createSequenceOfPlatformObjects(realm, &.{blob});
    defer parts.release();
    var content_type = try interfaces.Blob.get_type(blob);
    defer content_type.deinit(blob.ctx.allocator);
    return interfaces.File.call_constructor(realm, parts.value, filename.getOrDefault("blob"), .passed(.{ .base = .{ .type = content_type } }));
}

fn prepareFileTrace(instance: *runtime.Instance, internal: *InternalState, excluding_name: ?[]const u8, added: ?*runtime.Instance) !?engine.Owned {
    if (!instance.ctx.hasEngine()) return null;
    var files: std.ArrayList(*runtime.Instance) = .empty;
    defer files.deinit(internal.allocator);
    for (internal.form_data.entries.items) |entry| {
        if (excluding_name) |name| if (std.mem.eql(u8, entry.name, name)) continue;
        switch (entry.value) {
            .blob_instance => |object| try files.append(internal.allocator, @ptrCast(@alignCast(object))),
            else => {},
        }
    }
    if (added) |file| try files.append(internal.allocator, file);
    if (files.items.len == 0) return null;
    return try engine.createSequenceOfPlatformObjects(instance.ctx, files.items);
}

fn setFileTrace(instance: *runtime.Instance, internal: *InternalState, trace: ?engine.Owned) void {
    const array = trace orelse {
        if (internal.files_traced) engine.forgetTracedChild(instance, .{ .name = "entryFiles" });
        internal.files_traced = false;
        return;
    };
    engine.traceValue(instance, array.value, .{ .name = "entryFiles" });
    internal.files_traced = true;
}

/// Operation: delete
///
/// Spec: https://xhr.spec.whatwg.org/#dom-formdata-delete
/// Removes all values associated with a given key.
pub fn call_delete(instance: *runtime.Instance, name: runtime.USVString) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const trace = try prepareFileTrace(instance, internal, name, null);
    defer if (trace) |value| value.release();
    internal.form_data.delete(name);
    setFileTrace(instance, internal, trace);
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
        .file => unreachable, // Construction materializes every native record.
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
    defer internal.allocator.free(values);
    // XHR getAll: preserve File values, including repeated references.
    const js_values = try internal.allocator.alloc(runtime.JSValue, values.len);
    defer internal.allocator.free(js_values);
    for (values, js_values) |entry, *value| value.* = switch (entry) {
        .string => |text| runtime.JSValue.fromStringRef(text),
        .blob_instance => |object| .{ .instance = @ptrCast(@alignCast(object)) },
        .file => unreachable, // Construction materializes every native record.
    };
    const array = try engine.createSequenceOfValues(instance.ctx, js_values);
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
    const trace = try prepareFileTrace(instance, internal, name, null);
    defer if (trace) |kept| kept.release();
    try internal.form_data.setString(name, value);
    setFileTrace(instance, internal, trace);
}

pub fn call_set__1(instance: *runtime.Instance, name: runtime.USVString, blob: *runtime.Instance, filename: webidl.Opt(runtime.USVString)) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const file = try entryFile(instance.ctx, blob, filename);
    const generation = runtime.SlabAllocator.generationOf(file);
    defer if (file != blob) file.releaseIfUnwrapped(generation);
    const trace = try prepareFileTrace(instance, internal, name, file);
    defer if (trace) |value| value.release();
    try internal.form_data.setBlobInstance(name, file, null);
    setFileTrace(instance, internal, trace);
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
/// File values are the same platform objects returned by get and getAll.
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
                .file => unreachable, // Construction materializes every native record.
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
