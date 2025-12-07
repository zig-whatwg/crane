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
const BlobImpl = @import("Blob.zig");
const webidl = @import("webidl");
const File = interfaces.File;

pub const State = File.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for File implementation
///
/// Holds the FileData pointer which stores the underlying Blob data
/// plus name and lastModified.
pub const InternalState = struct {
    /// The internal file data (blob + name + lastModified)
    file_data: *file.FileData,
    /// The relative path (webkit extension, usually empty)
    webkit_relative_path: []const u8,
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        self.file_data.deinit();
        if (self.webkit_relative_path.len > 0) {
            self.allocator.free(@constCast(self.webkit_relative_path));
        }
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
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: https://www.w3.org/TR/FileAPI/#file-constructor
///
/// Steps:
/// 1. Process fileBits using process blob parts algorithm
/// 2. Use provided fileName
/// 3. Use lastModified from options or current time
/// 4. Use type from options (normalized)
pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, fileBits: *const anyopaque, fileName: runtime.USVString, options: webidl.Opt(dictionaries.FilePropertyBag)) !*runtime.Instance {
    // Create instance through init()
    const instance = try init(allocator, State, &File.vtable, ctx);
    errdefer deinit(instance);

    // Get MIME type from options (inherits from BlobPropertyBag)
    const mime_type: []const u8 = if (options.wasPassed() and options.value.base.type != null) options.value.base.type.?.asSlice() else "";

    // For now, create empty blob data (full BlobPart processing requires V8)
    // TODO: Process fileBits when V8 integration is complete
    _ = fileBits;

    const blob_data = try file.BlobData.init(allocator, "", mime_type);
    errdefer blob_data.deinit();

    // Create FileData with name and lastModified
    // USVString is just []const u8 in Zig
    const file_name = fileName;
    const last_modified = if (options.wasPassed()) options.value.lastModified else null;

    const file_data = try file.FileData.init(allocator, blob_data, file_name, last_modified);
    errdefer file_data.deinit();

    // Create and store internal state
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .file_data = file_data,
        .webkit_relative_path = "", // Empty by default
        .allocator = allocator,
    };

    // Store internal state in the instance
    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Create a File from raw bytes (internal helper)
///
/// Used by APIs that need to create File objects directly.
pub fn createFromBytes(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    bytes: []const u8,
    name: []const u8,
    mime_type: []const u8,
    last_modified: ?i64,
) !*runtime.Instance {
    const instance = try init(allocator, State, &File.vtable, ctx);
    errdefer deinit(instance);

    const blob_data = try file.BlobData.init(allocator, bytes, mime_type);
    errdefer blob_data.deinit();

    const file_data = try file.FileData.init(allocator, blob_data, name, last_modified);
    errdefer file_data.deinit();

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .file_data = file_data,
        .webkit_relative_path = "",
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

/// Getter for name
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-name
/// Returns the name of the file (without path information).
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const name = internal.file_data.getName();
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
    return internal.file_data.getLastModified();
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

// ============================================================================
// Blob inheritance - File extends Blob
// ============================================================================

/// Get the file size (delegates to underlying blob)
pub fn get_size(instance: *runtime.Instance) ImplError!u64 {
    const internal = getInternal(instance) orelse return 0;
    return internal.file_data.size();
}

/// Get the file type (delegates to underlying blob)
pub fn get_type(instance: *runtime.Instance) ImplError!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    const type_str = internal.file_data.getType();
    if (type_str.len == 0) {
        return runtime.DOMString.initEmpty();
    }
    return runtime.DOMString.initInterned(type_str);
}

// ============================================================================
// Tests
// ============================================================================

test "File - basic constructor" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const file_instance = try createFromBytes(
        allocator,
        ctx,
        "Hello, World!",
        "test.txt",
        "text/plain",
        1700000000000,
    );
    defer deinit(file_instance);

    const name = try get_name(file_instance);
    try std.testing.expectEqualStrings("test.txt", name.asSlice());

    const last_modified = try get_lastModified(file_instance);
    try std.testing.expectEqual(@as(i64, 1700000000000), last_modified);

    const size = try get_size(file_instance);
    try std.testing.expectEqual(@as(u64, 13), size);

    const type_str = try get_type(file_instance);
    try std.testing.expectEqualStrings("text/plain", type_str.asSlice());
}

test "File - default lastModified" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const file_instance = try createFromBytes(
        allocator,
        ctx,
        "test",
        "test.txt",
        "",
        null, // Should use current time
    );
    defer deinit(file_instance);

    const last_modified = try get_lastModified(file_instance);
    // Should be a reasonable timestamp (after year 2020)
    const min_timestamp: i64 = 1577836800000; // 2020-01-01
    try std.testing.expect(last_modified > min_timestamp);
}

test "File - empty name" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const file_instance = try createFromBytes(allocator, ctx, "", "", "", null);
    defer deinit(file_instance);

    const name = try get_name(file_instance);
    try std.testing.expectEqualStrings("", name.asSlice());
}

test "File - webkitRelativePath empty by default" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const file_instance = try createFromBytes(allocator, ctx, "", "test.txt", "", null);
    defer deinit(file_instance);

    const path = try get_webkitRelativePath(file_instance);
    try std.testing.expectEqualStrings("", path.asSlice());
}
