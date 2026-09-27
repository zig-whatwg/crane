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

// The byte stream "get stream" returns.
const js = @import("streams_js.zig");
const srd = @import("streams_readable.zig");
const same_object = @import("same_object.zig");
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
    // Fetch, FormData's encoding and fetch()'s upload read a Blob's bytes
    // through this hook.
    @import("dom").blob_bytes.install(.{ .bytes_of = &bytesOf });

    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    return instance;
}

/// dom.blob_bytes: this Blob's bytes, borrowed - a Blob's data never changes.
fn bytesOf(instance: *runtime.Instance) ?[]const u8 {
    const internal = getInternal(instance) orelse return null;
    return internal.blob_data.bytes;
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

    // Get MIME type from options
    const mime_type: []const u8 = if (options.wasPassed() and options.value.type != null) options.value.type.?.asSlice() else "";

    // Process blob parts if provided
    const bytes = try processBlobParts(ctx.allocator, if (blobParts.wasPassed()) blobParts.value else null, endings_mode);
    defer if (bytes.len > 0) ctx.allocator.free(bytes);

    // Create the internal BlobData
    const blob_data = try file.BlobData.init(ctx.allocator, bytes, mime_type);
    errdefer blob_data.deinit();
    try setBlobData(instance, ctx.allocator, blob_data);

    return instance;
}

/// FileAPI "process blob parts" for a JS `sequence<BlobPart>`: the bytes of
/// every USVString (as UTF-8), ArrayBuffer and ArrayBufferView, in order.
/// Shared with File, whose constructor's first step is the same algorithm.
/// The caller owns a non-empty result; an empty one is static.
///
/// TODO: a Blob part contributes its bytes, anything else is converted with
/// ToString, and `endings: "native"` converts line endings - none of which
/// happens yet.
pub fn processBlobParts(allocator: std.mem.Allocator, parts: ?runtime.JSValue, endings: file.algorithms.Endings) ![]const u8 {
    _ = endings;
    const js_value = parts orelse return "";

    // Must be a handle to a V8 value
    if (js_value != .handle) {
        return "";
    }

    const handle = js_value.handle;
    const v8_value: *v8.Value = @ptrCast(@alignCast(handle.ptr));

    // Check if it's an array
    if (!v8.v8_Value_IsArray(v8_value)) {
        return "";
    }

    const v8_array: *v8.Array = @ptrCast(v8_value);
    const length = v8.v8_Array_Length(v8_array);

    if (length == 0) {
        return "";
    }

    // Get V8 context
    const isolate = v8.v8_Isolate_GetCurrent() orelse return "";
    const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return "";
    defer v8.v8_Context_Dispose(v8_context);

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
        return "";
    }

    // Allocate buffer for all bytes
    const buffer = try allocator.alloc(u8, total_size);

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

    return buffer;
}

/// Give `instance`'s Blob part its byte sequence, taking `blob_data` on
/// success. For a File that is the File's own Blob state: Instance.getState
/// finds an ancestor's state at its real offset.
pub fn setBlobData(instance: *runtime.Instance, allocator: std.mem.Allocator, blob_data: *file.BlobData) !void {
    const internal = try allocator.create(InternalState);
    internal.* = .{
        .blob_data = blob_data,
        .allocator = allocator,
    };
    instance.getState(State).own._internal = internal;
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
    try setBlobData(instance, allocator, blob_data);

    return instance;
}

/// Create a Blob from existing BlobData (internal helper)
///
/// Takes ownership of the BlobData - caller should NOT deinit it.
pub fn createFromBlobData(allocator: std.mem.Allocator, ctx: runtime.Context, blob_data: *file.BlobData) !*runtime.Instance {
    const instance = try init(allocator, State, &Blob.vtable, ctx);
    errdefer deinit(instance);

    try setBlobData(instance, allocator, blob_data);

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
    defer v8.v8_Context_Dispose(context);

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
/// Spec: https://w3c.github.io/FileAPI/#stream-method-algo - "get stream":
/// a new ReadableStream set up with byte reading support, into which the
/// blob's bytes are enqueued as Uint8Arrays, and which is closed once all
/// of them have been.
///
/// The bytes are enqueued as the stream pulls, a chunk at a time, rather
/// than all at once in parallel: a Blob's data is in memory and never
/// changes, so reading it when asked is the same bytes in the same order,
/// and a stream nobody reads holds none of them.
pub fn call_stream(instance: *runtime.Instance) anyerror!*runtime.Instance {
    _ = getInternal(instance) orelse return error.InvalidState;
    const realm = try js.Realm.of(instance);
    return BlobStream.create(realm, instance);
}

/// The most "get stream" enqueues per pull.
const chunk_size: usize = 64 * 1024;

/// The underlying source of a Blob's stream. It reads the Blob's own bytes,
/// so it keeps the Blob alive (`keep`) until the stream is done with it.
const BlobStream = struct {
    allocator: std.mem.Allocator,
    blob: *runtime.Instance,
    keep: same_object.Pin = .{},
    /// Bytes of the blob already enqueued.
    position: usize = 0,
    /// Every byte is enqueued, or the stream was cancelled: the blob is let
    /// go, and must not be read again.
    done: bool = false,
    /// The stream is done with this source (its algorithms were cleared).
    detached: bool = false,
    /// Calls into the stream under way from here: freeing waits for them.
    busy: u32 = 0,

    const vtable = srd.Source.VTable{ .start = start, .pull = pull, .cancel = cancel, .deinit = deinitSource };

    fn create(realm: js.Realm, blob: *runtime.Instance) !*runtime.Instance {
        const allocator = blob.ctx.allocator;
        const self = try allocator.create(BlobStream);
        self.* = .{ .allocator = allocator, .blob = blob };
        self.keep.hold(blob);
        // A failed setup clears the source's algorithms, which must not free
        // it under this call.
        self.busy += 1;
        const stream = srd.createReadableByteStream(realm, blob.ctx, .{ .ctx = self, .vtable = &vtable });
        self.busy -= 1;
        if (stream) |st| return st else |err| {
            self.detached = true;
            self.freeIfDone();
            return err;
        }
    }

    fn start(_: ?*anyopaque, realm: js.Realm, _: *runtime.Instance) js.Error!js.Completion {
        return .{ .normal = try realm.undefinedValue() };
    }

    /// Enqueue the next chunk, and close the stream after the last.
    fn pull(ctx: ?*anyopaque, realm: js.Realm, controller: *runtime.Instance) js.Error!js.Value {
        const self: *BlobStream = @ptrCast(@alignCast(ctx.?));
        self.busy += 1;
        defer {
            self.busy -= 1;
            self.freeIfDone();
        }
        if (self.done) return realm.promiseResolvedWithUndefined();
        const bytes = if (getInternal(self.blob)) |internal| internal.blob_data.bytes else &[_]u8{};
        if (self.position < bytes.len) {
            const chunk = bytes[self.position..][0..@min(chunk_size, bytes.len - self.position)];
            self.position += chunk.len;
            const buffer = js.allocateBuffer(chunk.len) orelse return error.V8Failure;
            defer js.dispose(buffer);
            if (js.bufferBytes(buffer)) |dest| @memcpy(dest[0..chunk.len], chunk);
            const view = try js.newView(.uint8, buffer, 0, chunk.len);
            defer js.dispose(view);
            try srd.byteControllerEnqueue(realm, controller, view);
        }
        if (!self.detached and self.position >= bytes.len) {
            // All of it is enqueued: nothing more to read, so let the blob go.
            self.done = true;
            self.keep.release();
            try srd.byteControllerClose(realm, controller);
        }
        return realm.promiseResolvedWithUndefined();
    }

    fn cancel(ctx: ?*anyopaque, realm: js.Realm, _: *runtime.Instance, _: js.Value) js.Error!js.Value {
        const self: *BlobStream = @ptrCast(@alignCast(ctx.?));
        self.done = true;
        self.keep.release();
        return realm.promiseResolvedWithUndefined();
    }

    fn deinitSource(ctx: ?*anyopaque, _: std.mem.Allocator) void {
        const self: *BlobStream = @ptrCast(@alignCast(ctx.?));
        self.detached = true;
        self.freeIfDone();
    }

    fn freeIfDone(self: *BlobStream) void {
        if (!self.detached or self.busy > 0) return;
        self.keep.release();
        self.allocator.destroy(self);
    }
};

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
    defer v8.v8_Context_Dispose(context);

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
