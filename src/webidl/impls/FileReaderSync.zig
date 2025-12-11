//! Implementation for FileReaderSync interface
//!
//! W3C File API §6.5: Reading on Threads
//! https://www.w3.org/TR/FileAPI/#FileReaderSync
//!
//! FileReaderSync provides synchronous file reading for Worker contexts.
//! Unlike FileReader, it blocks until the read completes and throws on error
//! instead of firing error events.
//!
//! IMPORTANT: This interface is only exposed in DedicatedWorker and SharedWorker
//! contexts, NOT in the main Window context.

const std = @import("std");
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const file = @import("file");
const FileReaderSync = interfaces.FileReaderSync;
const Blob = interfaces.Blob;
const BlobImpl = @import("Blob.zig");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;

pub const State = FileReaderSync.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
    NotAllowedError, // For context exposure violations
};

/// Internal state for FileReaderSync
///
/// FileReaderSync has minimal state - it's just a synchronous wrapper
/// around blob reading operations. We store the allocator for memory management.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
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
        internal.allocator.destroy(internal);
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-FileReaderSync
///
/// The FileReaderSync() constructor, when invoked, must return a new
/// FileReaderSync object.
///
/// Note: Per [Exposed=(DedicatedWorker,SharedWorker)], this should only
/// be constructible in Worker contexts. The V8 binding layer enforces this.
pub fn call_constructor(ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &FileReaderSync.vtable, ctx);
    errdefer deinit(instance);

    // Create internal state
    const internal = try ctx.allocator.create(InternalState);
    errdefer ctx.allocator.destroy(internal);

    internal.* = .{
        .allocator = ctx.allocator,
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

/// Get blob internal state
fn getBlobInternal(blob: *runtime.Instance) ?*BlobImpl.InternalState {
    return BlobImpl.getInternal(blob);
}

/// Operation: readAsArrayBuffer
///
/// Spec: https://www.w3.org/TR/FileAPI/#readAsArrayBufferSync
///
/// Synchronously reads the entire Blob contents as an ArrayBuffer.
/// This method blocks until the read completes.
pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const blob_internal = getBlobInternal(blob) orelse return error.InvalidState;

    // Get blob bytes
    const bytes = blob_internal.blob_data.bytes;

    // Package as ArrayBuffer using package data algorithm
    const result = file.algorithms.packageData(
        internal.allocator,
        bytes,
        .ArrayBuffer,
        blob_internal.blob_data.getType(),
        null,
    ) catch return error.OutOfMemory;

    // TODO: Return proper V8 ArrayBuffer - need typed array creation utility
    // result.array_buffer contains the raw bytes that should be wrapped
    _ = result;
    return runtime.JSValue.jsUndefined;
}

/// Operation: readAsBinaryString
///
/// Spec: https://www.w3.org/TR/FileAPI/#readAsBinaryStringSync
///
/// Synchronously reads the entire Blob contents as a binary string.
/// Each byte becomes a character with code point equal to the byte value.
pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const blob_internal = getBlobInternal(blob) orelse return error.InvalidState;

    // Get blob bytes
    const bytes = blob_internal.blob_data.bytes;

    // Package as BinaryString
    const result = file.algorithms.packageData(
        internal.allocator,
        bytes,
        .BinaryString,
        blob_internal.blob_data.getType(),
        null,
    ) catch return error.OutOfMemory;

    // Return as DOMString
    return runtime.DOMString.initInterned(result.string);
}

/// Operation: readAsDataURL
///
/// Spec: https://www.w3.org/TR/FileAPI/#readAsDataURLSync
///
/// Synchronously reads the entire Blob contents as a data URL.
/// Returns a data: URL with base64-encoded blob data.
pub fn call_readAsDataURL(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const blob_internal = getBlobInternal(blob) orelse return error.InvalidState;

    // Get blob bytes
    const bytes = blob_internal.blob_data.bytes;

    // Package as DataURL
    const result = file.algorithms.packageData(
        internal.allocator,
        bytes,
        .DataURL,
        blob_internal.blob_data.getType(),
        null,
    ) catch return error.OutOfMemory;

    // Return as DOMString
    return runtime.DOMString.initInterned(result.string);
}

/// Operation: readAsText
///
/// Spec: https://www.w3.org/TR/FileAPI/#readAsTextSync
///
/// Synchronously reads the entire Blob contents as text.
/// Uses the specified encoding or defaults to UTF-8.
///
/// Parameters:
/// - blob: The blob to read
/// - encoding: Optional encoding label (default "UTF-8")
pub fn call_readAsText(instance: *runtime.Instance, blob: *runtime.Instance, encoding: webidl.Opt(runtime.DOMString)) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const blob_internal = getBlobInternal(blob) orelse return error.InvalidState;

    // Get blob bytes
    const bytes = blob_internal.blob_data.bytes;

    // Get encoding name (default to UTF-8) - unwrap Opt
    const encoding_name: ?[]const u8 = if (encoding.wasPassed()) blk: {
        const enc_slice = encoding.value.asSlice();
        break :blk if (enc_slice.len > 0) enc_slice else null;
    } else null;

    // Package as Text with encoding
    const result = file.algorithms.packageData(
        internal.allocator,
        bytes,
        .Text,
        blob_internal.blob_data.getType(),
        encoding_name,
    ) catch return error.OutOfMemory;

    // Return as DOMString
    return runtime.DOMString.initInterned(result.string);
}

// ============================================================================
// Tests
// ============================================================================

test "FileReaderSync - constructor" {
    const allocator = std.testing.allocator;

    // Create minimal context
    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const reader = try call_constructor(allocator, ctx);
    defer deinit(reader);

    // Verify internal state was created
    const internal = getInternal(reader);
    try std.testing.expect(internal != null);
}
