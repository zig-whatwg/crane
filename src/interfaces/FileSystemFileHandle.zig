//! Generated from: fs.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemFileHandleImpl = @import("../impls/FileSystemFileHandle.zig");
const FileSystemHandle = @import("FileSystemHandle.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        FileSystemFileHandleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FileSystemFileHandleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileSystemFileHandleImpl.get_kind(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FileSystemFileHandleImpl.get_name(state);
    }

    /// Extended attributes: [Exposed=DedicatedWorker]
    pub fn call_createSyncAccessHandle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileSystemFileHandleImpl.call_createSyncAccessHandle(state);
    }

    pub fn call_isSameEntry(instance: *runtime.Instance, other: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemFileHandleImpl.call_isSameEntry(state, other);
    }

    pub fn call_queryPermission(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemFileHandleImpl.call_queryPermission(state, descriptor);
    }

    pub fn call_getFile(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileSystemFileHandleImpl.call_getFile(state);
    }

    pub fn call_createWritable(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemFileHandleImpl.call_createWritable(state, options);
    }

    pub fn call_requestPermission(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemFileHandleImpl.call_requestPermission(state, descriptor);
    }

};
