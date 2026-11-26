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

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface.
pub fn installHooks() void {
    // The HTML file upload's Files of a chosen directory carry their path
    // under it, and lazy file-backed Files are created directly from their
    // BlobData (html/file_selection.zig).
    dom.blob_bytes.installFile(.{
        .set_relative_path = &setRelativePath,
        .create_file_from_data = &createFromBlobData,
    });
}

/// Create an unwrapped File taking ownership of `blob_data` on success (on
/// error the caller still owns `blob_data`), with `name`, optional
/// `last_modified_ms` (null = now), and optional `webkitRelativePath`.
fn createFromBlobData(
    ctx: runtime.Context,
    blob_data: *file.BlobData,
    name: []const u8,
    last_modified_ms: ?i64,
    relative_path: []const u8,
) anyerror!*runtime.Instance {
    const instance = try interfaces.File.init(ctx.allocator, ctx);
    const generation = runtime.SlabAllocator.generationOf(instance);
    var data_attached = false;
    errdefer {
        if (!data_attached) {
            // Caller retains ownership of `blob_data` on error.
        } else {
            // Blob's own deinit will release `blob_data`; undo attachment if
            // we want caller ownership? No: setBlobData succeeded, so
            // `releaseIfUnwrapped` will deinit `blob_data` cleanly; re-retain
            // so caller's errdefer `blob_data.deinit()` balances!
            _ = blob_data.retain();
        }
        instance.releaseIfUnwrapped(generation);
    }
    try dom.blob_bytes.setData(instance, blob_data);
    data_attached = true;
    try setFileState(instance, ctx.allocator, name, last_modified_ms, relative_path);
    return instance;
}

/// webkitRelativePath set natively on a new File (dom.blob_bytes.FileSteps).
fn setRelativePath(instance: *runtime.Instance, path: []const u8) anyerror!void {
    const internal = getInternal(instance) orelse return error.InvalidState;
    const copy = if (path.len == 0) "" else try internal.allocator.dupe(u8, path);
    if (internal.webkit_relative_path.len > 0) internal.allocator.free(@constCast(internal.webkit_relative_path));
    internal.webkit_relative_path = copy;
}

/// Constructor implementation
///
/// Spec: https://w3c.github.io/FileAPI/#file-constructor
pub fn call_constructor(instance: *runtime.Instance, fileBits: runtime.JSValue, fileName: runtime.USVString, options: webidl.Opt(dictionaries.FilePropertyBag)) !void {
    const ctx = instance.ctx;
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
    // File API steps 3.1-3.2: BlobData rejects outside U+0020-U+007E
    // and lowercases the rest, without MIME parsing. Chrome/Firefox/Safari
    // agree on all Blob/File cases (353/955 each, wpt.fyi cc74d2669f):
    // https://wpt.fyi/results/mimesniff/mime-types/parsing.any.html?sha=cc74d2669f
    const mime_type: []const u8 = if (options.wasPassed() and options.value.base.type != null) options.value.base.type.?.asSlice() else "";
    // Step 1: process blob parts into a BlobData (retaining file-backed parts
    // lazily without reading from disk).
    const blob_data = try dom.blob_parts.processToData(ctx, fileBits, endings, mime_type);
    errdefer blob_data.deinit();
    try dom.blob_bytes.setData(instance, blob_data);

    // Steps 2 and 3.3: the name, and lastModified - now, when not given.
    const last_modified = if (options.wasPassed()) options.value.lastModified else null;
    try setFileState(instance, ctx.allocator, fileName, last_modified, "");
}

fn setFileState(instance: *runtime.Instance, allocator: std.mem.Allocator, name: []const u8, last_modified: ?i64, relative_path: []const u8) !void {
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    const owned_name = try allocator.dupe(u8, name);
    errdefer allocator.free(owned_name);
    const owned_rel = if (relative_path.len > 0) try allocator.dupe(u8, relative_path) else "";
    internal.* = .{
        .name = owned_name,
        .last_modified = last_modified orelse clock.wallMillis(),
        .webkit_relative_path = owned_rel,
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
    // Steps 3-4, plus webkitRelativePath (Blink serializes relative_path).
    const internal = getInternal(value);
    try serialized.writeString(if (internal) |i| i.name else "");
    try serialized.writeInt64(if (internal) |i| i.last_modified else 0);
    try serialized.writeString(if (internal) |i| i.webkit_relative_path else "");
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
    // Steps 3-4, plus webkitRelativePath.
    const name = try serialized.readString();
    const last_modified = try serialized.readInt64();
    const relative_path = try serialized.readString();
    try setFileState(value, value.ctx.allocator, name, last_modified, relative_path);
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
    // A USVString the getter returns is the binding's to free (as URL's
    // getters' are): a copy, in the realm's allocator.
    if (internal.webkit_relative_path.len == 0) return "";
    return instance.ctx.allocator.dupe(u8, internal.webkit_relative_path);
}
