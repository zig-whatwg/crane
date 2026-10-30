//! Implementation for File interface
//!
//! W3C File API: https://www.w3.org/TR/FileAPI/#file-section
//!
//! File extends Blob with name and lastModified attributes.
//! It represents a file from the user's file system.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const file = @import("file");
const webidl = @import("webidl");
const InternalStateAccessor = @import("webidl").utils.InternalStateAccessor;
const clock = @import("clock");
const dom = @import("dom");
const File = interfaces.File;

pub const State = File.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for File implementation: what a File adds to its Blob.
///
/// The bytes and type are the Blob part's own state (dom.blob_bytes.setBytes) -
/// size, type, slice() and text() are Blob members, answered by Blob's impl.
pub const InternalState = struct {
    /// The file name, owned.
    name: []const u8,
    /// Milliseconds since the Unix epoch.
    last_modified: i64,
    /// The relative path (webkit extension, usually empty), owned when non-empty.
    webkit_relative_path: []const u8,
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.allocator.free(self.name);
        if (self.webkit_relative_path.len > 0) {
            self.allocator.free(@constCast(self.webkit_relative_path));
        }
    }
};

/// File's own teardown: the generated chain runs Blob's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: https://w3c.github.io/FileAPI/#file-constructor
pub fn call_constructor(ctx: runtime.Context, fileBits: runtime.JSValue, fileName: runtime.USVString, options: webidl.Opt(dictionaries.FilePropertyBag)) !*runtime.Instance {
    const instance = try File.init(ctx.allocator, ctx);
    errdefer File.deinit(instance);

    // Step 1: bytes, the result of processing blob parts given fileBits and
    // options.
    const endings: file.algorithms.Endings = blk: {
        if (options.wasPassed()) {
            if (options.value.base.endings) |e| {
                if (e == ._native_) break :blk .native;
            }
        }
        break :blk .transparent;
    };
    const bytes = try dom.blob_parts.process(ctx, fileBits, endings);
    defer if (bytes.len > 0) ctx.allocator.free(bytes);

    // File API steps 3.1-3.2: BlobData rejects outside U+0020-U+007E
    // and lowercases the rest, without MIME parsing. Chrome/Firefox/Safari
    // agree on all Blob/File cases (353/955 each, wpt.fyi cc74d2669f):
    // https://wpt.fyi/results/mimesniff/mime-types/parsing.any.html?sha=cc74d2669f
    const mime_type: []const u8 = if (options.wasPassed() and options.value.base.type != null) options.value.base.type.?.asSlice() else "";
    // The Blob part's bytes and type: Blob's step (dom.blob_bytes), with the
    // allocator of the File's realm, `ctx`.
    try dom.blob_bytes.setBytes(instance, bytes, mime_type);

    // Steps 2 and 3.3: the name, and lastModified - now, when not given.
    const last_modified = if (options.wasPassed()) options.value.lastModified else null;
    try setFileState(instance, ctx.allocator, fileName, last_modified);

    return instance;
}

fn setFileState(instance: *runtime.Instance, allocator: std.mem.Allocator, name: []const u8, last_modified: ?i64) !void {
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{
        .name = try allocator.dupe(u8, name),
        .last_modified = last_modified orelse clock.wallMillis(),
        .webkit_relative_path = "",
        .allocator = allocator,
    };
    instance.getState(State).own._internal = internal;
}

// ============================================================================
// Serializable objects (HTML 2.7.1; File API: File is [Serializable])
// ============================================================================

/// File API, File's serialization steps, given `value` and `serialized`:
///
/// 1. Set serialized.[[SnapshotState]] to value's snapshot state.
/// 2. Set serialized.[[ByteSequence]] to value's underlying byte sequence.
/// 3. Set serialized.[[Name]] to the value of value's name attribute.
/// 4. Set serialized.[[LastModified]] to the value of value's lastModified
///    attribute.
///
/// File's primary interface is File, so these steps stand alone (HTML
/// 2.7.1); steps 1-2 are Blob's own, reached through Blob's interface - they
/// read the File's Blob part, and also keep its type, which File API's steps
/// leave out (a stated deviation, filed upstream as w3c/FileAPI#226; see
/// Blob's steps).
pub fn serializationSteps(value: *runtime.Instance, serialized: *runtime.SerializationRecord) !void {
    // Steps 1-2.
    try interfaces.Blob.serializationSteps(value, serialized);
    // Steps 3-4.
    const internal = getInternal(value);
    try serialized.writeString(if (internal) |i| i.name else "");
    try serialized.writeInt64(if (internal) |i| i.last_modified else 0);
}

/// File API, File's deserialization steps, given `serialized` and `value`:
///
/// 1. Set value's snapshot state to serialized.[[SnapshotState]].
/// 2. Set value's underlying byte sequence to serialized.[[ByteSequence]].
/// 3. Initialize the value of value's name attribute to serialized.[[Name]].
/// 4. Initialize the value of value's lastModified attribute to
///    serialized.[[LastModified]].
pub fn deserializationSteps(serialized: *runtime.DeserializationRecord, value: *runtime.Instance, target_realm: runtime.Context) !void {
    // Steps 1-2: the File's Blob part.
    try interfaces.Blob.deserializationSteps(serialized, value, target_realm);
    // Steps 3-4.
    const name = try serialized.readString();
    const last_modified = try serialized.readInt64();
    try setFileState(value, value.ctx.allocator, name, last_modified);
}

/// Get internal state from instance
/// Get internal state from instance using shared accessor
const Accessor = InternalStateAccessor(InternalState, State, *runtime.Instance);

pub fn getInternal(instance: *runtime.Instance) ?*InternalState {
    return Accessor.get(instance);
}

/// Getter for name
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-name
/// Returns the name of the file (without path information).
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const name = internal.name;
    if (name.len == 0) {
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initInterned(name);
}

/// Getter for lastModified
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-lastModified
/// Returns the last modified timestamp in milliseconds since Unix epoch.
pub fn get_lastModified(instance: *runtime.Instance) anyerror!i64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.last_modified;
}

/// Getter for webkitRelativePath
///
/// Non-standard webkit extension.
/// Returns the relative path of the file within a selected directory.
/// Usually empty string unless file was selected via directory input.
pub fn get_webkitRelativePath(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = getInternal(instance) orelse return "";
    return internal.webkit_relative_path;
}
