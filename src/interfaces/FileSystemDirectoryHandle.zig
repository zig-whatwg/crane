//! Generated from: fs.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemDirectoryHandleImpl = @import("../impls/FileSystemDirectoryHandle.zig");
const FileSystemHandle = @import("FileSystemHandle.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        FileSystemDirectoryHandleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FileSystemDirectoryHandleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileSystemDirectoryHandleImpl.get_kind(state);
    }

    pub fn get_name(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return FileSystemDirectoryHandleImpl.get_name(state);
    }

    pub fn call_isSameEntry(instance: *runtime.Instance, other: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemDirectoryHandleImpl.call_isSameEntry(state, other);
    }

    pub fn call_getFileHandle(instance: *runtime.Instance, name: runtime.USVString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemDirectoryHandleImpl.call_getFileHandle(state, name, options);
    }

    pub fn call_resolve(instance: *runtime.Instance, possibleDescendant: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemDirectoryHandleImpl.call_resolve(state, possibleDescendant);
    }

    pub fn call_removeEntry(instance: *runtime.Instance, name: runtime.USVString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemDirectoryHandleImpl.call_removeEntry(state, name, options);
    }

    pub fn call_queryPermission(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemDirectoryHandleImpl.call_queryPermission(state, descriptor);
    }

    pub fn call_getDirectoryHandle(instance: *runtime.Instance, name: runtime.USVString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemDirectoryHandleImpl.call_getDirectoryHandle(state, name, options);
    }

    pub fn call_requestPermission(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return FileSystemDirectoryHandleImpl.call_requestPermission(state, descriptor);
    }

};
