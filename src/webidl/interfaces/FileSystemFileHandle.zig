//! Generated from: fs.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemFileHandleImpl = @import("impls").FileSystemFileHandle;
const FileSystemHandle = @import("interfaces").FileSystemHandle;
const Promise<File> = @import("interfaces").Promise<File>;
const FileSystemCreateWritableOptions = @import("dictionaries").FileSystemCreateWritableOptions;
const Promise<FileSystemSyncAccessHandle> = @import("interfaces").Promise<FileSystemSyncAccessHandle>;
const Promise<FileSystemWritableFileStream> = @import("interfaces").Promise<FileSystemWritableFileStream>;

pub const FileSystemFileHandle = struct {
    pub const Meta = struct {
        pub const name = "FileSystemFileHandle";
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

    pub const vtable = runtime.buildVTable(FileSystemFileHandle, .{
        .deinit_fn = &deinit_wrapper,

        .get_kind = &get_kind,
        .get_name = &get_name,

        .call_createSyncAccessHandle = &call_createSyncAccessHandle,
        .call_createWritable = &call_createWritable,
        .call_getFile = &call_getFile,
        .call_isSameEntry = &call_isSameEntry,
        .call_queryPermission = &call_queryPermission,
        .call_requestPermission = &call_requestPermission,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        FileSystemFileHandleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemFileHandleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!FileSystemHandleKind {
        return try FileSystemFileHandleImpl.get_kind(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try FileSystemFileHandleImpl.get_name(instance);
    }

    /// Extended attributes: [Exposed=DedicatedWorker]
    pub fn call_createSyncAccessHandle(instance: *runtime.Instance) anyerror!anyopaque {
        return try FileSystemFileHandleImpl.call_createSyncAccessHandle(instance);
    }

    pub fn call_isSameEntry(instance: *runtime.Instance, other: FileSystemHandle) anyerror!anyopaque {
        
        return try FileSystemFileHandleImpl.call_isSameEntry(instance, other);
    }

    pub fn call_queryPermission(instance: *runtime.Instance, descriptor: FileSystemHandlePermissionDescriptor) anyerror!anyopaque {
        
        return try FileSystemFileHandleImpl.call_queryPermission(instance, descriptor);
    }

    pub fn call_getFile(instance: *runtime.Instance) anyerror!anyopaque {
        return try FileSystemFileHandleImpl.call_getFile(instance);
    }

    pub fn call_createWritable(instance: *runtime.Instance, options: FileSystemCreateWritableOptions) anyerror!anyopaque {
        
        return try FileSystemFileHandleImpl.call_createWritable(instance, options);
    }

    pub fn call_requestPermission(instance: *runtime.Instance, descriptor: FileSystemHandlePermissionDescriptor) anyerror!anyopaque {
        
        return try FileSystemFileHandleImpl.call_requestPermission(instance, descriptor);
    }

};
