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
const BlobImpl = @import("Blob.zig");
const File = interfaces.File;

pub const State = File.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for File implementation: what a File adds to its Blob.
///
/// The bytes and type are the Blob part's own state (BlobImpl.setBlobData) -
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

/// Initialize instance: a File is a Blob, so its Blob part is built first.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return BlobImpl.init(allocator, StateType, vtable, ctx);
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    BlobImpl.deinit(instance);
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

/// Constructor implementation
///
/// Spec: https://w3c.github.io/FileAPI/#file-constructor
pub fn call_constructor(ctx: runtime.Context, fileBits: runtime.JSValue, fileName: runtime.USVString, options: webidl.Opt(dictionaries.FilePropertyBag)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &File.vtable, ctx);
    errdefer deinit(instance);

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
    const bytes = try BlobImpl.processBlobParts(ctx.allocator, fileBits, endings);
    defer if (bytes.len > 0) ctx.allocator.free(bytes);

    // Steps 3.1-3.2: the type - BlobData drops one with a character outside
    // U+0020-U+007E and lowercases the rest.
    const mime_type: []const u8 = if (options.wasPassed() and options.value.base.type != null) options.value.base.type.?.asSlice() else "";
    {
        const blob_data = try file.BlobData.init(ctx.allocator, bytes, mime_type);
        errdefer blob_data.deinit();
        try BlobImpl.setBlobData(instance, ctx.allocator, blob_data);
    }

    // Steps 2 and 3.3: the name, and lastModified - now, when not given.
    const last_modified = if (options.wasPassed()) options.value.lastModified else null;
    try setFileState(instance, ctx.allocator, fileName, last_modified);

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

    {
        const blob_data = try file.BlobData.init(allocator, bytes, mime_type);
        errdefer blob_data.deinit();
        try BlobImpl.setBlobData(instance, allocator, blob_data);
    }
    try setFileState(instance, allocator, name, last_modified);

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

    const size = try BlobImpl.get_size(file_instance);
    try std.testing.expectEqual(@as(u64, 13), size);

    const type_str = try BlobImpl.get_type(file_instance);
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
