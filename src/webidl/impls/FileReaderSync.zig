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
const file = @import("file");
const engine = @import("engine");
const blob_bytes = @import("dom").blob_bytes;
const FileReaderSync = interfaces.FileReaderSync;
const Blob = interfaces.Blob;
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

/// File API §6.5.1.4, readAsArrayBuffer.
pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!runtime.JSValue {
    _ = getInternal(instance) orelse return error.InvalidState;
    // 1–4. Blob data is immutable and already in memory; reading all of its
    // stream produces these same bytes, as in Blob.text()/arrayBuffer().
    const bytes = blob_bytes.bytesOf(blob) orelse return error.InvalidState;
    // 5. Package as a new ArrayBuffer. The engine copies the contents once;
    // do not allocate and discard an intermediate native buffer.
    const buffer = try engine.createArrayBuffer(engine.currentRealm() orelse instance.ctx, bytes);
    return buffer.take();
}

/// File API §6.5.1.5, readAsBinaryString: each byte is an equal code unit.
pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!runtime.DOMString {
    return packageString(instance, blob, .BinaryString, null);
}

/// File API §6.5.1.3, readAsDataURL.
pub fn call_readAsDataURL(instance: *runtime.Instance, blob: *runtime.Instance) anyerror!runtime.DOMString {
    return packageString(instance, blob, .DataURL, null);
}

/// File API §6.5.1.2, readAsText: explicit label, MIME charset, then UTF-8;
/// the legacy decode algorithm lets a BOM override every fallback.
pub fn call_readAsText(instance: *runtime.Instance, blob: *runtime.Instance, encoding: webidl.Opt(runtime.DOMString)) anyerror!runtime.DOMString {
    return packageString(instance, blob, .Text, if (encoding.wasPassed()) encoding.getValue().asSlice() else null);
}

fn packageString(instance: *runtime.Instance, blob: *runtime.Instance, comptime read_type: file.algorithms.PackageReadType, encoding_label: ?[]const u8) !runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidState;
    // 1–4. Read the immutable in-memory Blob through its owning hook.
    const bytes = blob_bytes.bytesOf(blob) orelse return error.InvalidState;
    var mime_type = try Blob.get_type(blob);
    defer mime_type.deinit(blob.ctx.allocator);
    // 5. Both readers use File API's package data algorithm. Its string is
    // allocated, so return an owned DOMString for the binding to release.
    const result = try file.algorithms.packageData(internal.allocator, bytes, read_type, mime_type.asSlice(), encoding_label);
    return runtime.DOMString.initOwned(result.string);
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

    const reader = try call_constructor(ctx);
    defer runtime.Instance.deinit(reader);

    // Verify internal state was created
    const internal = getInternal(reader);
    try std.testing.expect(internal != null);
}
