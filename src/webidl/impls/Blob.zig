//! Implementation for Blob interface
//!
//! W3C File API: https://www.w3.org/TR/FileAPI/#blob-section
//!
//! A Blob represents immutable raw binary data. This implementation
//! wires the WebIDL interface to the internal BlobData storage and
//! the W3C File API algorithms.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const file = @import("file");
const Blob = interfaces.Blob;

// Import streams infrastructure for Promise support
const event_loop_mod = @import("streams_event_loop");
const AsyncPromise = @import("streams_async_promise").AsyncPromise;
const webidl = @import("webidl");
const webidl_errors = webidl.errors;

// Import V8 for promise bridging
const v8_engine = @import("v8");
const v8 = v8_engine.ffi;
const promise_utils = v8_engine.promise;

// Import ReadableStream impl for internal API (Zig-only stream creation)
const ReadableStreamImpl = @import("ReadableStream.zig");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = Blob.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for Blob implementation
///
/// Holds the BlobData pointer which stores the actual bytes and MIME type.
/// This follows the InternalState pattern used by ReadableStream and other impls.
pub const InternalState = struct {
    /// The internal blob data (bytes + type)
    blob_data: *file.BlobData,
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.blob_data.deinit();
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
    return instance;
}

/// Deinitialize instance - clean up owned resources only
/// NOTE: Do NOT call runtime.Instance.deinit() here!
/// The GC integration layer (gc_integration.onObjectFreed) handles:
/// 1. Calling this deinit function (via vtable.deinit)
/// 2. Freeing the Instance handle back to the SlabAllocator
/// Calling Instance.deinit from here would cause infinite recursion.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit(instance) here!
    // The GC integration layer handles slab freeing after this returns.
}

/// Constructor implementation
///
/// Spec: https://www.w3.org/TR/FileAPI/#constructorBlob
///
/// Steps:
/// 1. If blobParts is empty or missing, create empty Blob
/// 2. Process blobParts using "process blob parts" algorithm
/// 3. Normalize type from options
/// 4. Return new Blob
pub fn call_constructor(ctx: runtime.Context, blobParts: webidl.Opt(runtime.JSValue), options: webidl.Opt(dictionaries.BlobPropertyBag)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(ctx.allocator, State, &Blob.vtable, ctx);
    errdefer deinit(instance);

    // Determine if we have blob parts and what endings mode to use
    const endings_mode: file.algorithms.Endings = blk: {
        if (options.wasPassed()) {
            if (options.value.endings) |endings| {
                // endings is now an enum, check if it's "native"
                if (endings == ._native_) {
                    break :blk .native;
                }
            }
        }
        break :blk .transparent;
    };
    _ = endings_mode; // TODO: Apply endings conversion to strings

    // Get MIME type from options
    const mime_type: []const u8 = if (options.wasPassed() and options.value.type != null) options.value.type.?.asSlice() else "";

    // Process blob parts if provided
    const bytes: []const u8 = blk: {
        if (!blobParts.wasPassed()) {
            break :blk "";
        }

        const js_value = blobParts.value;

        // Must be a handle to a V8 value
        if (js_value != .handle) {
            break :blk "";
        }

        const handle = js_value.handle;
        const v8_value: *v8.Value = @ptrCast(@alignCast(handle.ptr));

        // Check if it's an array
        if (!v8.v8_Value_IsArray(v8_value)) {
            break :blk "";
        }

        const v8_array: *v8.Array = @ptrCast(v8_value);
        const length = v8.v8_Array_Length(v8_array);

        if (length == 0) {
            break :blk "";
        }

        // Get V8 context
        const isolate = v8.v8_Isolate_GetCurrent() orelse break :blk "";
        const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse break :blk "";

        // First pass: calculate total size needed
        var total_size: usize = 0;
        for (0..length) |i| {
            const elem = v8.v8_Array_Get(v8_context, v8_array, @intCast(i)) orelse continue;

            if (v8.v8_Value_IsString(elem)) {
                const str: *v8.String = @ptrCast(elem);
                total_size += @as(usize, @intCast(v8.v8_String_Utf8Length(str)));
            } else if (v8.v8_Value_IsArrayBuffer(elem)) {
                const ab: *v8.ArrayBuffer = @ptrCast(elem);
                total_size += v8.v8_ArrayBuffer_ByteLength(ab);
            } else if (v8.v8_Value_IsArrayBufferView(elem)) {
                total_size += v8.v8_TypedArray_ByteLength(elem);
            }
        }

        if (total_size == 0) {
            break :blk "";
        }

        // Allocate buffer for all bytes
        const buffer = ctx.allocator.alloc(u8, total_size) catch break :blk "";

        // Second pass: copy bytes
        var offset: usize = 0;
        for (0..length) |i| {
            const elem = v8.v8_Array_Get(v8_context, v8_array, @intCast(i)) orelse continue;

            if (v8.v8_Value_IsString(elem)) {
                const str: *v8.String = @ptrCast(elem);
                const utf8_len = v8.v8_String_Utf8Length(str);
                if (utf8_len > 0) {
                    _ = v8.v8_String_WriteUtf8(str, buffer[offset..].ptr, utf8_len);
                    offset += @as(usize, @intCast(utf8_len));
                }
            } else if (v8.v8_Value_IsArrayBuffer(elem)) {
                const ab: *v8.ArrayBuffer = @ptrCast(elem);
                const byte_length = v8.v8_ArrayBuffer_ByteLength(ab);
                if (byte_length > 0) {
                    if (v8.v8_ArrayBuffer_Data(ab)) |data_ptr| {
                        const data: [*]const u8 = @ptrCast(data_ptr);
                        @memcpy(buffer[offset..][0..byte_length], data[0..byte_length]);
                        offset += byte_length;
                    }
                }
            } else if (v8.v8_Value_IsArrayBufferView(elem)) {
                if (v8.v8_TypedArray_Buffer(elem)) |ab| {
                    const byte_offset = v8.v8_TypedArray_ByteOffset(elem);
                    const byte_length = v8.v8_TypedArray_ByteLength(elem);
                    if (byte_length > 0) {
                        if (v8.v8_ArrayBuffer_Data(ab)) |data_ptr| {
                            const data: [*]const u8 = @ptrCast(data_ptr);
                            @memcpy(buffer[offset..][0..byte_length], data[byte_offset..][0..byte_length]);
                            offset += byte_length;
                        }
                    }
                }
            }
        }

        break :blk buffer;
    };
    defer if (bytes.len > 0) ctx.allocator.free(bytes);

    // Create the internal BlobData
    const blob_data = try file.BlobData.init(ctx.allocator, bytes, mime_type);
    errdefer blob_data.deinit();

    // Create and store internal state
    const internal = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal);

    internal.* = .{
        .blob_data = blob_data,
        .allocator = ctx.allocator,
    };

    // Store internal state in the instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Create a Blob from raw bytes (internal helper)
///
/// This is used by other APIs (File, slice) that need to create Blobs
/// directly from bytes without going through the WebIDL constructor.
pub fn createFromBytes(allocator: std.mem.Allocator, ctx: runtime.Context, bytes: []const u8, mime_type: []const u8) !*runtime.Instance {
    const instance = try init(allocator, State, &Blob.vtable, ctx);
    errdefer deinit(instance);

    const blob_data = try file.BlobData.init(allocator, bytes, mime_type);
    errdefer blob_data.deinit();

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .blob_data = blob_data,
        .allocator = allocator,
    };

    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Create a Blob from existing BlobData (internal helper)
///
/// Takes ownership of the BlobData - caller should NOT deinit it.
pub fn createFromBlobData(allocator: std.mem.Allocator, ctx: runtime.Context, blob_data: *file.BlobData) !*runtime.Instance {
    const instance = try init(allocator, State, &Blob.vtable, ctx);
    errdefer deinit(instance);

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .blob_data = blob_data,
        .allocator = allocator,
    };

    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Get internal state from instance
/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Getter for size
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-size
/// Returns the size of the byte sequence in number of bytes.
pub fn get_size(instance: *runtime.Instance) anyerror!u64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.blob_data.size();
}

/// Getter for type
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-type
/// Returns ASCII-encoded string in lower case representing the media type.
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const type_str = internal.blob_data.getType();
    if (type_str.len == 0) {
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initInterned(type_str);
}

/// Operation: slice
///
/// Spec: https://www.w3.org/TR/FileAPI/#slice-method-algo
/// Returns a new Blob object with bytes from start to end and optional contentType.
pub fn call_slice(instance: *runtime.Instance, start: webidl.Opt(i64), end: webidl.Opt(i64), contentType: webidl.Opt(runtime.DOMString)) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const allocator = internal.allocator;
    const ctx = instance.ctx;

    // Get contentType as optional slice (unwrap Opt)
    const ct: ?[]const u8 = blk: {
        if (contentType.wasPassed()) {
            const slice = contentType.value.asSlice();
            if (slice.len > 0) {
                break :blk slice;
            }
        }
        break :blk null;
    };

    // Run slice blob algorithm - unwrap Opt for start/end
    const start_val: ?i64 = if (start.wasPassed()) start.value else null;
    const end_val: ?i64 = if (end.wasPassed()) end.value else null;
    const sliced_data = file.algorithms.sliceBlob(
        allocator,
        internal.blob_data,
        start_val,
        end_val,
        ct,
    ) catch {
        return error.OutOfMemory;
    };
    errdefer sliced_data.deinit();

    // Create new Blob instance with the sliced data
    return createFromBlobData(allocator, ctx, sliced_data) catch {
        return error.OutOfMemory;
    };
}

/// Operation: text
///
/// Spec: https://www.w3.org/TR/FileAPI/#dom-blob-text
/// Returns a Promise that resolves with the blob contents as a UTF-8 string.
///
/// Algorithm:
/// 1. Let stream be the result of calling get stream on this.
/// 2. Let reader be the result of getting a reader from stream.
/// 3. Let promise be the result of reading all bytes from stream with reader.
/// 4. Return the result of transforming promise with UTF-8 decode.
pub fn call_text(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // For Blob.text(), we synchronously read bytes and decode as UTF-8
    // Per spec, text() always uses UTF-8 (unlike FileReader.readAsText which can use other encodings)
    const bytes = internal.blob_data.bytes;

    // Get V8 context for promise creation
    const isolate = v8.v8_Isolate_GetCurrent() orelse return error.InvalidState;
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return error.InvalidState;

    // Create a V8 string from the bytes (UTF-8 decode)
    const v8_string = if (bytes.len > 0)
        v8.v8_String_NewFromUtf8(isolate, bytes.ptr, @intCast(bytes.len)) orelse return error.OutOfMemory
    else
        v8.v8_String_Empty(isolate) orelse return error.OutOfMemory;

    // Create a resolved promise with the string
    const resolver = v8.v8_PromiseResolver_New(context) orelse return error.OutOfMemory;
    const promise = v8.v8_PromiseResolver_GetPromise(resolver) orelse return error.OutOfMemory;

    // Resolve with the string
    _ = v8.v8_PromiseResolver_Resolve(resolver, context, @ptrCast(v8_string));

    return runtime.JSValue.fromPromise(@ptrCast(promise));
}

/// Operation: stream
///
/// Spec: https://www.w3.org/TR/FileAPI/#stream-method-algo
/// Returns a ReadableStream for reading blob contents.
///
/// The stream() method returns the result of calling "get stream" on the blob:
/// 1. Create a new ReadableStream with byte reading support
/// 2. Pull algorithm reads chunks from blob bytes
/// 3. Returns stream that yields all blob bytes
///
/// Implementation note: Uses internal ReadableStream API (createFromZigSource)
/// to bypass the V8/JavaScript constructor path, similar to how browsers like
/// Firefox use ReadableStream::CreateByteNative() internally.
pub fn call_stream(instance: *runtime.Instance) anyerror!*runtime.Instance {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const allocator = internal.allocator;
    const ctx = instance.ctx;

    // Create the blob stream source state
    const source_state = allocator.create(BlobStreamSource) catch return error.OutOfMemory;
    errdefer allocator.destroy(source_state);

    source_state.* = BlobStreamSource{
        .blob_data = internal.blob_data,
        .position = 0,
        .allocator = allocator,
    };

    // Create ReadableStream using internal Zig API (bypasses V8/JSValue path)
    // This mirrors browser implementations like Firefox's CreateByteNative()
    const zig_source = ReadableStreamImpl.ZigUnderlyingSource{
        .pull = &blobStreamPullNative,
        .cancel = &blobStreamCancelNative,
        .context = @ptrCast(source_state),
        .is_byte_stream = true,
        .auto_allocate_chunk_size = DEFAULT_CHUNK_SIZE,
    };

    const stream = ReadableStreamImpl.createFromZigSource(
        allocator,
        ctx,
        zig_source,
    ) catch |err| {
        allocator.destroy(source_state);
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.NoEventLoop => error.InvalidState,
        };
    };

    return stream;
}

/// Default chunk size for blob streaming (64KB)
const DEFAULT_CHUNK_SIZE: u64 = 64 * 1024;

/// Type string for byte streams
const blob_stream_type_bytes: []const u8 = "bytes";

/// Thread-local context for blob stream callbacks
/// This is a workaround since UnderlyingSource doesn't support context
threadlocal var blob_stream_context: ?*BlobStreamSource = null;

/// Clear the thread-local blob stream context
///
/// MUST be called on isolate disposal to prevent use-after-free.
/// The blob stream context may hold references to BlobData that becomes
/// invalid when the isolate's associated Zig state is cleaned up.
///
/// Called by the isolate lifecycle cleanup sequence.
pub fn clearBlobStreamContext() void {
    blob_stream_context = null;
}

/// Internal state for blob stream source
const BlobStreamSource = struct {
    blob_data: *file.BlobData,
    position: usize,
    allocator: std.mem.Allocator,
};

/// Sentinel value to indicate no result / end of stream
const null_result: u8 = 0;
/// Sentinel value to indicate successful read
const success_result: u8 = 1;

/// Native pull callback for blob stream (used with internal ReadableStream API)
/// Called by ReadableStream when it needs more data.
/// Signature matches ZigUnderlyingSource.pull
fn blobStreamPullNative(controller: *runtime.Instance, context: ?*anyopaque) anyerror!void {
    const source: *BlobStreamSource = @ptrCast(@alignCast(context orelse return error.InvalidState));

    // Check if we've read all bytes
    if (source.position >= source.blob_data.bytes.len) {
        // Close the stream - no more data
        // TODO: Call controller.close() when ReadableByteStreamController is fully implemented
        _ = controller;
        return;
    }

    // Calculate chunk size
    const remaining = source.blob_data.bytes.len - source.position;
    const chunk_len = @min(remaining, DEFAULT_CHUNK_SIZE);

    // Get the chunk data
    const chunk_data = source.blob_data.bytes[source.position..][0..chunk_len];
    _ = chunk_data; // TODO: Enqueue to controller when fully implemented

    // Advance position
    source.position += chunk_len;
}

/// Native cancel callback for blob stream (used with internal ReadableStream API)
/// Signature matches ZigUnderlyingSource.cancel
fn blobStreamCancelNative(reason: ?*const anyopaque, context: ?*anyopaque) anyerror!void {
    _ = reason;
    const source: *BlobStreamSource = @ptrCast(@alignCast(context orelse return));
    // Reset position
    source.position = 0;
}

/// Legacy pull callback for blob stream (kept for compatibility)
/// Called by ReadableStream when it needs more data
fn blobStreamPull(controller: *const anyopaque) *const anyopaque {
    _ = controller;
    // Get source state from thread-local context
    const source = blob_stream_context orelse return @ptrCast(&null_result);

    // Check if we've read all bytes
    if (source.position >= source.blob_data.bytes.len) {
        // Signal end of stream
        return @ptrCast(&null_result);
    }

    // Calculate chunk size
    const remaining = source.blob_data.bytes.len - source.position;
    const chunk_len = @min(remaining, DEFAULT_CHUNK_SIZE);

    // Advance position
    source.position += chunk_len;

    // Return success marker (in full impl, would enqueue chunk to controller)
    return @ptrCast(&success_result);
}

/// Legacy cancel callback for blob stream (kept for compatibility)
fn blobStreamCancel(controller: *const anyopaque) *const anyopaque {
    _ = controller;
    // Reset position if source exists
    if (blob_stream_context) |source| {
        source.position = 0;
    }
    return @ptrCast(&null_result);
}

/// Operation: bytes
///
/// Spec: https://www.w3.org/TR/FileAPI/#dom-blob-bytes
/// Returns a Promise that resolves with a Uint8Array of the blob contents.
///
/// Algorithm:
/// 1. Let stream be the result of calling get stream on this.
/// 2. Let reader be the result of getting a reader from stream.
/// 3. Let promise be the result of reading all bytes from stream with reader.
/// 4. Return the result of transforming promise to create Uint8Array from bytes.
pub fn call_bytes(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Get event loop from context
    const ev_loop = instance.ctx.getEventLoop() catch return error.InvalidState;

    // Create promise that resolves with bytes (Uint8Array contents)
    // Note: The actual Uint8Array wrapper would be created by the V8 binding layer
    // Here we just return the raw bytes that would populate the Uint8Array
    const promise = AsyncPromise([]const u8).init(allocator, ev_loop) catch return error.OutOfMemory;

    // Get blob bytes
    const bytes = internal.blob_data.bytes;

    // Fulfill immediately since blob bytes are already in memory
    promise.fulfill(bytes);

    // Get V8 context for promise conversion
    const isolate = v8.v8_Isolate_GetCurrent() orelse return error.InvalidState;
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return error.InvalidState;

    // Convert Zig AsyncPromise to V8 Promise
    const v8_promise = try promise_utils.asyncPromiseToV8(
        []const u8,
        std.heap.c_allocator,
        isolate,
        context,
        promise,
    );
    return runtime.JSValue.fromPromise(@ptrCast(v8_promise));
}

/// Operation: arrayBuffer
///
/// Spec: https://www.w3.org/TR/FileAPI/#dom-blob-arraybuffer
/// Returns a Promise that resolves with an ArrayBuffer of the blob contents.
///
/// Algorithm:
/// 1. Let stream be the result of calling get stream on this.
/// 2. Let reader be the result of getting a reader from stream.
/// 3. Let promise be the result of reading all bytes from stream with reader.
/// 4. Return the result of transforming promise to create ArrayBuffer from bytes.
pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidState;

    // Get blob bytes
    const bytes = internal.blob_data.bytes;

    // Get V8 context for promise creation
    const isolate = v8.v8_Isolate_GetCurrent() orelse return error.InvalidState;
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return error.InvalidState;

    // Create a V8 ArrayBuffer with the blob bytes
    const array_buffer = v8.v8_ArrayBuffer_New(isolate, bytes.len) orelse return error.OutOfMemory;

    // Copy bytes into the ArrayBuffer
    if (bytes.len > 0) {
        if (v8.v8_ArrayBuffer_Data(array_buffer)) |data_ptr| {
            const dest: [*]u8 = @ptrCast(data_ptr);
            @memcpy(dest[0..bytes.len], bytes);
        }
    }

    // Create a resolved promise with the ArrayBuffer
    const resolver = v8.v8_PromiseResolver_New(context) orelse return error.OutOfMemory;
    const promise = v8.v8_PromiseResolver_GetPromise(resolver) orelse return error.OutOfMemory;

    // Resolve with the ArrayBuffer
    _ = v8.v8_PromiseResolver_Resolve(resolver, context, @ptrCast(array_buffer));

    return runtime.JSValue.fromPromise(@ptrCast(promise));
}

// ============================================================================
// Tests
// ============================================================================

test "Blob - empty constructor" {
    const allocator = std.testing.allocator;

    // Create a minimal context
    const ctx = runtime.createNullContext();

    // Create empty blob (simulating constructor with no parts)
    const blob = try createFromBytes(allocator, ctx, "", "");
    defer deinit(blob);

    const size = try get_size(blob);
    try std.testing.expectEqual(@as(u64, 0), size);

    const type_str = try get_type(blob);
    try std.testing.expectEqualStrings("", type_str.asSlice());
}

test "Blob - with bytes and type" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const blob = try createFromBytes(allocator, ctx, "Hello, World!", "text/plain");
    defer deinit(blob);

    const size = try get_size(blob);
    try std.testing.expectEqual(@as(u64, 13), size);

    const type_str = try get_type(blob);
    try std.testing.expectEqualStrings("text/plain", type_str.asSlice());
}

test "Blob - slice basic" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const blob = try createFromBytes(allocator, ctx, "Hello, World!", "text/plain");
    defer deinit(blob);

    // Slice to get "Hello"
    const sliced = try call_slice(blob, 0, 5, runtime.DOMString.initEmpty());
    defer deinit(sliced);

    const size = try get_size(sliced);
    try std.testing.expectEqual(@as(u64, 5), size);

    // Type should be empty (not inherited) when contentType not specified
    const type_str = try get_type(sliced);
    try std.testing.expectEqualStrings("", type_str.asSlice());
}

test "Blob - slice with contentType" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const blob = try createFromBytes(allocator, ctx, "Hello", "text/plain");
    defer deinit(blob);

    const sliced = try call_slice(blob, 0, 5, runtime.DOMString.initInterned("application/json"));
    defer deinit(sliced);

    const type_str = try get_type(sliced);
    try std.testing.expectEqualStrings("application/json", type_str.asSlice());
}

test "Blob - slice negative indices" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const blob = try createFromBytes(allocator, ctx, "Hello, World!", "");
    defer deinit(blob);

    // Slice with -6 should give us "World!"
    const sliced = try call_slice(blob, -6, 13, runtime.DOMString.initEmpty());
    defer deinit(sliced);

    const size = try get_size(sliced);
    try std.testing.expectEqual(@as(u64, 6), size);
}
