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
///
/// Spec: https://www.w3.org/TR/FileAPI/#constructorBlob
///
/// Steps:
/// 1. If blobParts is empty or missing, create empty Blob
/// 2. Process blobParts using "process blob parts" algorithm
/// 3. Normalize type from options
/// 4. Return new Blob
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, blobParts: webidl.Opt(*const anyopaque), options: webidl.Opt(dictionaries.BlobPropertyBag)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &Blob.vtable, ctx);
    errdefer deinit(instance);

    // Determine if we have blob parts and what endings mode to use
    const endings_mode: file.algorithms.Endings = blk: {
        if (options.wasPassed()) {
            if (options.value.endings) |endings_ptr| {
                // endings is a pointer to the endings string value
                // For now, check if it's "native"
                const endings_str: *const []const u8 = @ptrCast(@alignCast(endings_ptr));
                if (std.mem.eql(u8, endings_str.*, "native")) {
                    break :blk .native;
                }
            }
        }
        break :blk .transparent;
    };

    // Get MIME type from options
    const mime_type: []const u8 = if (options.wasPassed() and options.value.type != null) options.value.type.?.asSlice() else "";

    // Process blob parts if provided
    // The blobParts parameter comes as an opaque pointer to a sequence
    // For now, we'll handle the case where it might be null/empty
    const bytes: []const u8 = blk: {
        // Check if blobParts is actually provided (non-null pointer to valid data)
        // In the WebIDL binding, an empty sequence would still be a valid pointer
        // We need to handle this carefully - for now treat as potentially empty

        // Try to interpret as a slice of BlobPart
        // The actual structure depends on how the V8 binding passes this
        // For safety, we'll create empty bytes if we can't process it
        _ = blobParts;
        _ = endings_mode;

        // TODO: Full BlobPart processing requires V8 integration to extract
        // the actual parts. For now, create empty blob.
        // When V8 integration is complete, this will iterate through blobParts
        // and call file.algorithms.processBlobParts()
        break :blk "";
    };

    // Create the internal BlobData
    const blob_data = try file.BlobData.init(allocator, bytes, mime_type);
    errdefer blob_data.deinit();

    // Create and store internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .blob_data = blob_data,
        .allocator = allocator,
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
pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Getter for size
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-size
/// Returns the size of the byte sequence in number of bytes.
pub fn get_size(instance: *runtime.Instance) ImplError!u64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.blob_data.size();
}

/// Getter for type
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-type
/// Returns ASCII-encoded string in lower case representing the media type.
pub fn get_type(instance: *runtime.Instance) ImplError!runtime.DOMString {
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
pub fn call_slice(instance: *runtime.Instance, start: webidl.Opt(i64), end: webidl.Opt(i64), contentType: webidl.Opt(runtime.DOMString)) ImplError!*runtime.Instance {
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
pub fn call_text(instance: *runtime.Instance) ImplError!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Get event loop from context
    const ev_loop = instance.ctx.getEventLoop() catch return error.InvalidState;

    // Create promise that resolves with string
    const promise = AsyncPromise([]const u8).init(allocator, ev_loop) catch return error.OutOfMemory;

    // For Blob.text(), we synchronously read bytes and decode as UTF-8
    // Per spec, text() always uses UTF-8 (unlike FileReader.readAsText which can use other encodings)
    const bytes = internal.blob_data.bytes;

    // UTF-8 decode - for valid UTF-8, just use bytes directly
    // For invalid UTF-8, we'd need replacement character handling
    // Since blob data is already stored as-is, we just pass through
    // (Full spec compliance would validate/replace invalid sequences)

    // Fulfill immediately since blob bytes are already in memory
    promise.fulfill(bytes);

    return @ptrCast(promise);
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
pub fn call_stream(instance: *runtime.Instance) ImplError!*runtime.Instance {
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

    // Create UnderlyingSource dictionary with our pull callback
    // Note: The type field being non-null indicates a byte stream
    const underlying_source = dictionaries.UnderlyingSource{
        .start = null,
        .pull = @ptrCast(&blobStreamPull),
        .cancel = @ptrCast(&blobStreamCancel),
        .type = @ptrCast(&blob_stream_type_bytes), // "bytes" for ReadableByteStreamController
        .autoAllocateChunkSize = DEFAULT_CHUNK_SIZE,
    };

    // Store source state pointer for callback access
    // We encode the source_state pointer in the start callback context
    // This is a workaround since UnderlyingSource doesn't have a context field
    blob_stream_context = source_state;

    // Create the ReadableStream
    const source_ptr: *const anyopaque = @ptrCast(&underlying_source);
    const opt_source = webidl.Opt(*const anyopaque).passed(source_ptr);
    const strategy = dictionaries.QueuingStrategy{};
    const opt_strategy = webidl.Opt(dictionaries.QueuingStrategy).passed(strategy);
    const stream = interfaces.ReadableStream.call_constructor(
        allocator,
        ctx,
        opt_source,
        opt_strategy,
    ) catch |err| {
        allocator.destroy(source_state);
        return switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.NoEventLoop => error.InvalidState, // No event loop in context
            else => error.InvalidState,
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

/// Pull callback for blob stream
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

/// Cancel callback for blob stream
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
pub fn call_bytes(instance: *runtime.Instance) ImplError!*const anyopaque {
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

    return @ptrCast(promise);
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
pub fn call_arrayBuffer(instance: *runtime.Instance) ImplError!*const anyopaque {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const allocator = internal.allocator;

    // Get event loop from context
    const ev_loop = instance.ctx.getEventLoop() catch return error.InvalidState;

    // Create promise that resolves with bytes (ArrayBuffer contents)
    // Note: The actual ArrayBuffer wrapper would be created by the V8 binding layer
    // Here we just return the raw bytes that would populate the ArrayBuffer
    const promise = AsyncPromise([]const u8).init(allocator, ev_loop) catch return error.OutOfMemory;

    // Get blob bytes
    const bytes = internal.blob_data.bytes;

    // Fulfill immediately since blob bytes are already in memory
    promise.fulfill(bytes);

    return @ptrCast(promise);
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
