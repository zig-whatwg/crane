//! Generated from: fs.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemDirectoryHandleImpl = @import("impls").FileSystemDirectoryHandle;
const FileSystemHandle = @import("interfaces").FileSystemHandle;
const Promise<FileSystemDirectoryHandle> = @import("interfaces").Promise<FileSystemDirectoryHandle>;
const FileSystemRemoveOptions = @import("dictionaries").FileSystemRemoveOptions;
const FileSystemGetFileOptions = @import("dictionaries").FileSystemGetFileOptions;
const FileSystemGetDirectoryOptions = @import("dictionaries").FileSystemGetDirectoryOptions;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const Promise<sequence<USVString>?> = @import("interfaces").Promise<sequence<USVString>?>;
const Promise<FileSystemFileHandle> = @import("interfaces").Promise<FileSystemFileHandle>;

pub const FileSystemDirectoryHandle = struct {
    pub const Meta = struct {
        pub const name = "FileSystemDirectoryHandle";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *FileSystemHandle;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
            .{ .name = "Serializable" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FileSystemDirectoryHandle, .{
        .deinit_fn = &deinit_wrapper,

        .get_kind = &get_kind,
        .get_name = &get_name,

        .call_getDirectoryHandle = &call_getDirectoryHandle,
        .call_getFileHandle = &call_getFileHandle,
        .call_isSameEntry = &call_isSameEntry,
        .call_queryPermission = &call_queryPermission,
        .call_removeEntry = &call_removeEntry,
        .call_requestPermission = &call_requestPermission,
        .call_resolve = &call_resolve,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        FileSystemDirectoryHandleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemDirectoryHandleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!FileSystemHandleKind {
        return try FileSystemDirectoryHandleImpl.get_kind(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemDirectoryHandleImpl.get_name(instance);
    }

    pub fn call_isSameEntry(instance: *runtime.Instance, other: FileSystemHandle) anyerror!anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_isSameEntry(instance, other);
    }

    pub fn call_getFileHandle(instance: *runtime.Instance, name: runtime.USVString, options: FileSystemGetFileOptions) anyerror!anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_getFileHandle(instance, name, options);
    }

    pub fn call_resolve(instance: *runtime.Instance, possibleDescendant: FileSystemHandle) anyerror!anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_resolve(instance, possibleDescendant);
    }

    pub fn call_removeEntry(instance: *runtime.Instance, name: runtime.USVString, options: FileSystemRemoveOptions) anyerror!anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_removeEntry(instance, name, options);
    }

    pub fn call_queryPermission(instance: *runtime.Instance, descriptor: FileSystemHandlePermissionDescriptor) anyerror!anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_queryPermission(instance, descriptor);
    }

    pub fn call_getDirectoryHandle(instance: *runtime.Instance, name: runtime.USVString, options: FileSystemGetDirectoryOptions) anyerror!anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_getDirectoryHandle(instance, name, options);
    }

    pub fn call_requestPermission(instance: *runtime.Instance, descriptor: FileSystemHandlePermissionDescriptor) anyerror!anyopaque {
        
        return try FileSystemDirectoryHandleImpl.call_requestPermission(instance, descriptor);
    }

};
