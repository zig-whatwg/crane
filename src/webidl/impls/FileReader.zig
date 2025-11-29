//! Implementation for FileReader interface
//!
//! W3C File API §6.2: The FileReader API
//! https://www.w3.org/TR/FileAPI/#APIASynch
//!
//! FileReader provides asynchronous methods to read File/Blob contents.
//! It extends EventTarget and fires progress events during reading.
//!
//! ## States
//! - EMPTY (0): No read initiated
//! - LOADING (1): Read in progress
//! - DONE (2): Read complete (success, error, or abort)
//!
//! ## Event Sequence
//! Success: loadstart -> progress* -> load -> loadend
//! Error: loadstart -> progress* -> error -> loadend
//! Abort: loadstart -> progress* -> abort -> loadend

const std = @import("std");
const webidl = @import("webidl");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const file = @import("file");
const FileReader = interfaces.FileReader;
const BlobImpl = @import("Blob.zig");

pub const State = FileReader.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
    OutOfMemory,
};

/// Internal state for FileReader
///
/// Contains the FileReaderData from the file module plus event handlers.
pub const InternalState = struct {
    allocator: std.mem.Allocator,

    /// Core FileReader state (state machine, result, error)
    reader_data: *file.FileReaderData,

    /// Event handlers (EventHandler is already optional - ?callback)
    onloadstart: typedefs.EventHandler = null,
    onprogress: typedefs.EventHandler = null,
    onload: typedefs.EventHandler = null,
    onabort: typedefs.EventHandler = null,
    onerror: typedefs.EventHandler = null,
    onloadend: typedefs.EventHandler = null,

    pub fn init(allocator: std.mem.Allocator) !*InternalState {
        const self = try allocator.create(InternalState);
        errdefer allocator.destroy(self);

        const reader_data = try file.FileReaderData.init(allocator);
        errdefer reader_data.deinit();

        self.* = .{
            .allocator = allocator,
            .reader_data = reader_data,
        };

        return self;
    }

    pub fn deinit(self: *InternalState) void {
        self.reader_data.deinit();
        self.allocator.destroy(self);
    }
};

/// Get internal state from instance
fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

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
    }
    runtime.Instance.deinit(instance);
}

/// Constructor implementation
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-FileReader
///
/// The FileReader() constructor, when invoked, must return a new FileReader
/// object with readyState set to EMPTY.
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(allocator, State, &FileReader.vtable, ctx);
    errdefer deinit(instance);

    // Create internal state
    const internal = try InternalState.init(allocator);
    errdefer internal.deinit();

    const state = instance.getState(State);
    state.own._internal = internal;

    // Initialize state attributes
    state.own.readyState = 0; // EMPTY

    return instance;
}

/// Getter for readyState
///
/// Returns the current state: EMPTY (0), LOADING (1), or DONE (2)
pub fn get_readyState(instance: *runtime.Instance) ImplError!u16 {
    const internal = getInternal(instance) orelse {
        const state = instance.getState(State);
        return state.own.readyState;
    };
    return internal.reader_data.getReadyState();
}

/// Getter for result
///
/// Returns the file's contents (string or ArrayBuffer) or null
pub fn get_result(instance: *runtime.Instance) ImplError!?*const anyopaque {
    const internal = getInternal(instance) orelse return null;

    return switch (internal.reader_data.result) {
        .array_buffer => |buf| @ptrCast(buf.ptr),
        .string => |str| @ptrCast(str.ptr),
        .none => null,
    };
}

/// Getter for error
///
/// Returns a DOMException if an error occurred, null otherwise
pub fn get_error(instance: *runtime.Instance) ImplError!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;

    // If there's an error, we should return a DOMException
    // For now, return null as DOMException creation is not implemented
    if (internal.reader_data.error_name != null) {
        // TODO: Create DOMException with error_name and error_message
        return null;
    }
    return null;
}

// ============================================================================
// Event Handlers
// ============================================================================

/// Getter for onloadstart
pub fn get_onloadstart(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onloadstart;
}

/// Setter for onloadstart
pub fn set_onloadstart(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.onloadstart = value;
}

/// Getter for onprogress
pub fn get_onprogress(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onprogress;
}

/// Setter for onprogress
pub fn set_onprogress(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.onprogress = value;
}

/// Getter for onload
pub fn get_onload(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onload;
}

/// Setter for onload
pub fn set_onload(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.onload = value;
}

/// Getter for onabort
pub fn get_onabort(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onabort;
}

/// Setter for onabort
pub fn set_onabort(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.onabort = value;
}

/// Getter for onerror
pub fn get_onerror(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onerror;
}

/// Setter for onerror
pub fn set_onerror(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.onerror = value;
}

/// Getter for onloadend
pub fn get_onloadend(instance: *runtime.Instance) ImplError!typedefs.EventHandler {
    const internal = getInternal(instance) orelse return null;
    return internal.onloadend;
}

/// Setter for onloadend
pub fn set_onloadend(instance: *runtime.Instance, value: typedefs.EventHandler) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.onloadend = value;
}

// ============================================================================
// Read Operations
// ============================================================================

/// Operation: readAsArrayBuffer
///
/// Spec: https://www.w3.org/TR/FileAPI/#readAsArrayBuffer
///
/// Starts reading the Blob as an ArrayBuffer. When complete, the result
/// attribute contains an ArrayBuffer representing the file's data.
pub fn call_readAsArrayBuffer(instance: *runtime.Instance, blob: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const blob_internal = BlobImpl.getInternal(blob) orelse return error.InvalidStateError;

    file.algorithms.startReadOperation(
        internal.reader_data,
        blob_internal.blob_data,
        .ArrayBuffer,
        null,
    ) catch |err| {
        return switch (err) {
            file.algorithms.ReadError.InvalidStateError => error.InvalidStateError,
            else => error.InvalidStateError,
        };
    };

    // Update state in instance
    const state = instance.getState(State);
    state.own.readyState = internal.reader_data.getReadyState();
}

/// Operation: readAsBinaryString
///
/// Spec: https://www.w3.org/TR/FileAPI/#readAsBinaryString
///
/// Starts reading the Blob as a binary string. When complete, the result
/// attribute contains the raw binary data from the file as a string.
pub fn call_readAsBinaryString(instance: *runtime.Instance, blob: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const blob_internal = BlobImpl.getInternal(blob) orelse return error.InvalidStateError;

    file.algorithms.startReadOperation(
        internal.reader_data,
        blob_internal.blob_data,
        .BinaryString,
        null,
    ) catch |err| {
        return switch (err) {
            file.algorithms.ReadError.InvalidStateError => error.InvalidStateError,
            else => error.InvalidStateError,
        };
    };

    // Update state in instance
    const state = instance.getState(State);
    state.own.readyState = internal.reader_data.getReadyState();
}

/// Operation: readAsDataURL
///
/// Spec: https://www.w3.org/TR/FileAPI/#readAsDataURL
///
/// Starts reading the Blob as a data URL. When complete, the result
/// attribute contains a data: URL representing the file's data.
pub fn call_readAsDataURL(instance: *runtime.Instance, blob: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const blob_internal = BlobImpl.getInternal(blob) orelse return error.InvalidStateError;

    file.algorithms.startReadOperation(
        internal.reader_data,
        blob_internal.blob_data,
        .DataURL,
        null,
    ) catch |err| {
        return switch (err) {
            file.algorithms.ReadError.InvalidStateError => error.InvalidStateError,
            else => error.InvalidStateError,
        };
    };

    // Update state in instance
    const state = instance.getState(State);
    state.own.readyState = internal.reader_data.getReadyState();
}

/// Operation: readAsText
///
/// Spec: https://www.w3.org/TR/FileAPI/#readAsText
///
/// Starts reading the Blob as text with the specified encoding (defaults
/// to UTF-8). When complete, the result attribute contains a string.
pub fn call_readAsText(instance: *runtime.Instance, blob: *runtime.Instance, encoding: webidl.Opt(runtime.DOMString)) ImplError!void {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const blob_internal = BlobImpl.getInternal(blob) orelse return error.InvalidStateError;

    // Get encoding (default to UTF-8) - unwrap Opt
    const enc: ?[]const u8 = if (encoding.wasPassed()) blk: {
        const enc_slice = encoding.value.asSlice();
        break :blk if (enc_slice.len > 0) enc_slice else null;
    } else null;

    file.algorithms.startReadOperation(
        internal.reader_data,
        blob_internal.blob_data,
        .Text,
        enc,
    ) catch |err| {
        return switch (err) {
            file.algorithms.ReadError.InvalidStateError => error.InvalidStateError,
            else => error.InvalidStateError,
        };
    };

    // Update state in instance
    const state = instance.getState(State);
    state.own.readyState = internal.reader_data.getReadyState();
}

/// Operation: abort
///
/// Spec: https://www.w3.org/TR/FileAPI/#abort
///
/// If the readyState is EMPTY or DONE, sets result to null and returns.
/// If readyState is LOADING, sets it to DONE, result to null, fires abort
/// and loadend events.
pub fn call_abort(instance: *runtime.Instance) ImplError!void {
    const internal = getInternal(instance) orelse return;

    file.algorithms.abortReadOperation(internal.reader_data);

    // Update state in instance
    const state = instance.getState(State);
    state.own.readyState = internal.reader_data.getReadyState();
}

// ============================================================================
// Tests
// ============================================================================

test "FileReader - constructor" {
    const allocator = std.testing.allocator;

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const reader = try call_constructor(allocator, ctx);
    defer deinit(reader);

    // Should start in EMPTY state
    try std.testing.expectEqual(@as(u16, 0), try get_readyState(reader));

    // Result should be null
    try std.testing.expect((try get_result(reader)) == null);

    // Error should be null
    try std.testing.expect((try get_error(reader)) == null);
}

test "FileReader - event handlers" {
    const allocator = std.testing.allocator;

    var ctx_data = try runtime.ContextData.init(allocator, .{});
    defer ctx_data.deinit();
    const ctx: runtime.Context = &ctx_data;

    const reader = try call_constructor(allocator, ctx);
    defer deinit(reader);

    // Event handlers should initially be null
    const handler = try get_onload(reader);
    try std.testing.expect(handler == null);
}
