//! A Blob's bytes and data, for the specifications that read them without a
//! stream.
//!
//! Fetch's "extract a body" takes a Blob's data for a Request or Response
//! body, HTML's multipart/form-data encoding reads a File entry's bytes, and
//! `fetch()` uploads them. No IDL member hands them over synchronously
//! (`bytes()` and `arrayBuffer()` are promises), and those callers may not
//! reach into Blob's impl - so Blob installs the step here, the shape of
//! `fetch_objects.zig`.
//!
//! A Blob may be backed either by in-memory bytes or lazily by file parts
//! (`file.BlobData`, Blink's BlobData / FileStreamReader model). Consumers
//! read through `materialize` (fallible: `NotFoundError` / `NotReadableError`
//! / `OutOfMemory`) or keep a reference via `dataOf` (`BlobData.retain`).
//!
//! Spec: https://w3c.github.io/FileAPI/#blob-section
//!
//! A File's `createFileFromData` and `webkitRelativePath` have their own slots
//! here, File's steps: HTML file selection creates lazy file-backed Files
//! without eager disk reads (html/file_selection.zig; Blink's
//! File::CreateForUserProvidedFile / File::CreateWithRelativePath).
//!
//! lint-impls: hook for Blob, File
const std = @import("std");
const process_start = @import("process_start.zig");
const Hook = @import("hook.zig").Hook;

const runtime = @import("runtime");
const interfaces = @import("interfaces");
const file = @import("file");

pub const BlobData = file.BlobData;
pub const FileBacking = file.FileBacking;
pub const FileSourceOps = file.FileSourceOps;
pub const FileReadError = file.FileReadError;
pub const MaterializedBytes = file.MaterializedBytes;

pub const Steps = struct {
    /// Give `blob` - new, from `interfaces.Blob.init`, with no data yet - a
    /// copy of `bytes`, and `mime_type` as its type (as the File API's
    /// constructors take one: lowercased, or empty when it cannot be one).
    set_bytes: *const fn (blob: *runtime.Instance, bytes: []const u8, mime_type: []const u8) anyerror!void,
    /// A specification-created Blob's type is already serialized: preserve
    /// it verbatim as a DOMString in UTF-8, without constructor normalization.
    set_bytes_exact_type: *const fn (blob: *runtime.Instance, bytes: []const u8, mime_type: []const u8) anyerror!void,
    /// Give `blob` - new, with no data yet - ownership of `blob_data` on
    /// success (caller retains ownership on error).
    set_data: *const fn (blob: *runtime.Instance, blob_data: *file.BlobData) anyerror!void,
    /// Restore a specification-computed type before exposing a fresh File.
    /// Refuses shared data and preserves the old type on allocation failure.
    set_exact_type: *const fn (blob: *runtime.Instance, serialized_type: []const u8) anyerror!void,
    /// `blob`'s data itself, SHARED - its parts and type, as a blob URL entry
    /// or composite Blob keeps them (File API 8.3.1: the entry's object is the
    /// Blob) - or null when `blob` has no Blob state.
    data_of: *const fn (blob: *runtime.Instance) ?*file.BlobData,
};

var steps: Hook(?Steps) = .init(null);

/// Called by Blob's installHooks, once, at process start (process_start.zig).
pub fn install(s: Steps) void {
    steps.install(s);
}

/// File's steps (see the file comment).
pub const FileSteps = struct {
    /// Set `file`'s webkitRelativePath to a copy of `path`. `file` is a new
    /// File, made by its constructor and not yet given to script.
    set_relative_path: *const fn (file: *runtime.Instance, path: []const u8) anyerror!void,
    /// Create an unwrapped File of `ctx` taking ownership of `blob_data` on
    /// success (on error the caller still owns `blob_data`), with `name`,
    /// optional `last_modified_ms` (null = now), and `relative_path`.
    create_file_from_data: *const fn (
        ctx: runtime.Context,
        blob_data: *file.BlobData,
        name: []const u8,
        last_modified_ms: ?i64,
        relative_path: []const u8,
    ) anyerror!*runtime.Instance,
};

var file_steps: Hook(?FileSteps) = .init(null);

/// Called by File's installHooks, once, at process start.
pub fn installFile(s: FileSteps) void {
    file_steps.install(s);
}

/// Give `file` - new, from File's constructor - the relative path `path`
/// (File and Directory Entries API, webkitRelativePath).
pub fn setRelativePath(file_instance: *runtime.Instance, path: []const u8) !void {
    const s = file_steps.get() orelse return error.NotSupported;
    try s.set_relative_path(file_instance, path);
}

/// Create a new unwrapped File backed by `blob_data` (taken on success).
pub fn createFileFromData(
    ctx: runtime.Context,
    blob_data: *file.BlobData,
    name: []const u8,
    last_modified_ms: ?i64,
    relative_path: []const u8,
) !*runtime.Instance {
    const s = file_steps.get() orelse return error.NotSupported;
    return s.create_file_from_data(ctx, blob_data, name, last_modified_ms, relative_path);
}

/// `blob`'s data, shared with it (see `Steps.data_of`): a blob URL entry or
/// composite Blob keeps it via `retain()`. Null when Blob has installed
/// nothing, or `blob` is no Blob.
pub fn dataOf(blob: *runtime.Instance) ?*file.BlobData {
    const s = steps.get() orelse return null;
    return s.data_of(blob);
}

/// Materialize `blob`'s bytes (borrowing with zero copy for in-memory Blobs;
/// synchronously reading & snapshot-checking file-backed parts). Caller MUST
/// call `deinit()` on the returned `MaterializedBytes`.
///
/// Returns `null` when `blob` is not a Blob (or Blob hooks are not installed).
pub fn materialize(blob: *runtime.Instance, allocator: std.mem.Allocator) file.FileReadError!?file.MaterializedBytes {
    const data = dataOf(blob) orelse return null;
    return try data.readBytes(allocator);
}

/// Give `blob` - new, made through its interface (a File's constructor makes
/// its Blob part this way), with no data yet - a copy of `bytes` and
/// `mime_type` as its type, as the File API's constructors take one.
pub fn setBytes(blob: *runtime.Instance, bytes: []const u8, mime_type: []const u8) !void {
    const s = steps.get() orelse return error.NotSupported;
    try s.set_bytes(blob, bytes, mime_type);
}

/// Give `blob` - new, with no data yet - ownership of `blob_data` on success.
pub fn setData(blob: *runtime.Instance, blob_data: *file.BlobData) !void {
    const s = steps.get() orelse return error.NotSupported;
    try s.set_data(blob, blob_data);
}

/// A new Blob of `ctx` "representing" `bytes` (copied), with type
/// `mime_type` - XHR's blob response, which no IDL member makes. Unwrapped:
/// the caller wraps or holds it. Making one through Blob's interface installs
/// Blob's steps, so this works before any other Blob exists.
pub fn create(ctx: runtime.Context, bytes: []const u8, mime_type: []const u8) !*runtime.Instance {
    const blob = try interfaces.Blob.init(ctx.allocator, ctx);
    const generation = runtime.SlabAllocator.generationOf(blob);
    errdefer blob.releaseIfUnwrapped(generation);
    const s = steps.get() orelse return error.NotSupported;
    try s.set_bytes(blob, bytes, mime_type);
    return blob;
}

/// XHR response step 6: a new Blob with its type set to the serialized final
/// MIME type, already decoded to UTF-8. The caller wraps or holds the result.
pub fn createWithType(ctx: runtime.Context, bytes: []const u8, mime_type: []const u8) !*runtime.Instance {
    const blob = try interfaces.Blob.init(ctx.allocator, ctx);
    const generation = runtime.SlabAllocator.generationOf(blob);
    errdefer blob.releaseIfUnwrapped(generation);
    const s = steps.get() orelse return error.NotSupported;
    try s.set_bytes_exact_type(blob, bytes, mime_type);
    return blob;
}

/// HTML create-an-entry: preserve the source type on a fresh, unwrapped File
/// whose constructor made its BlobData. Never use this on exposed/shared data.
pub fn setExactType(blob: *runtime.Instance, serialized_type: []const u8) !void {
    const s = steps.get() orelse return error.NotSupported;
    try s.set_exact_type(blob, serialized_type);
}
