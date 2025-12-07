//! Implementation for FileList interface
//!
//! W3C File API: https://www.w3.org/TR/FileAPI/#filelist-section
//!
//! FileList is a read-only list of File objects, typically returned
//! from HTMLInputElement.files when using <input type="file">.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const file = @import("file");
const FileImpl = @import("File.zig");
const FileList = interfaces.FileList;

pub const State = FileList.State;

pub const ImplError = error{
    NotImplemented,
    InvalidState,
    OutOfMemory,
};

/// Internal state for FileList implementation
///
/// Holds references to File instances. The FileList owns these instances.
pub const InternalState = struct {
    /// Array of File runtime instances
    files: []*runtime.Instance,
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    pub fn deinit(self: *InternalState) void {
        // Deinitialize all contained File instances
        for (self.files) |file_instance| {
            interfaces.File.deinit(file_instance);
        }
        if (self.files.len > 0) {
            self.allocator.free(self.files);
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

/// Create an empty FileList (internal helper)
pub fn createEmpty(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
    const instance = try init(allocator, State, &FileList.vtable, ctx);
    errdefer deinit(instance);

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    internal.* = .{
        .files = &[_]*runtime.Instance{},
        .allocator = allocator,
    };

    const state = instance.getState(State);
    state.own._internal = internal;

    return instance;
}

/// Create a FileList from an array of File instances (internal helper)
///
/// Takes ownership of the File instances - they will be freed when
/// the FileList is deinitialized.
pub fn createFromFiles(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    files: []*runtime.Instance,
) !*runtime.Instance {
    const instance = try init(allocator, State, &FileList.vtable, ctx);
    errdefer deinit(instance);

    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);

    // Copy the array of file instance pointers
    const owned_files = try allocator.dupe(*runtime.Instance, files);
    errdefer allocator.free(owned_files);

    internal.* = .{
        .files = owned_files,
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

/// Getter for length
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-length
/// Returns the number of files in the list.
pub fn get_length(instance: *runtime.Instance) anyerror!u32 {
    const internal = getInternal(instance) orelse return 0;
    return @intCast(internal.files.len);
}

/// Operation: item
///
/// Spec: https://www.w3.org/TR/FileAPI/#dfn-item
/// Returns the indexth File object, or null if out of bounds.
pub fn call_item(instance: *runtime.Instance, index: u32) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;

    if (index >= internal.files.len) {
        return null;
    }

    return internal.files[index];
}

// ============================================================================
// Tests
// ============================================================================

test "FileList - empty" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const file_list = try createEmpty(allocator, ctx);
    defer deinit(file_list);

    const length = try get_length(file_list);
    try std.testing.expectEqual(@as(u32, 0), length);

    const item = try call_item(file_list, 0);
    try std.testing.expect(item == null);
}

test "FileList - with files" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    // Create some files
    const file1 = try FileImpl.createFromBytes(allocator, ctx, "content1", "file1.txt", "text/plain", null);
    const file2 = try FileImpl.createFromBytes(allocator, ctx, "content2", "file2.txt", "text/plain", null);

    var files = [_]*runtime.Instance{ file1, file2 };
    const file_list = try createFromFiles(allocator, ctx, &files);
    defer deinit(file_list); // This also deinitializes the files

    const length = try get_length(file_list);
    try std.testing.expectEqual(@as(u32, 2), length);

    const item0 = try call_item(file_list, 0);
    try std.testing.expect(item0 != null);

    const item1 = try call_item(file_list, 1);
    try std.testing.expect(item1 != null);

    const item2 = try call_item(file_list, 2);
    try std.testing.expect(item2 == null);
}

test "FileList - item returns correct file" {
    const allocator = std.testing.allocator;
    const ctx = runtime.createNullContext();

    const file1 = try FileImpl.createFromBytes(allocator, ctx, "a", "first.txt", "", null);
    const file2 = try FileImpl.createFromBytes(allocator, ctx, "b", "second.txt", "", null);

    var files = [_]*runtime.Instance{ file1, file2 };
    const file_list = try createFromFiles(allocator, ctx, &files);
    defer deinit(file_list);

    // Verify we get the correct file instances back
    const item0 = try call_item(file_list, 0);
    try std.testing.expect(item0 == file1);

    const item1 = try call_item(file_list, 1);
    try std.testing.expect(item1 == file2);
}
