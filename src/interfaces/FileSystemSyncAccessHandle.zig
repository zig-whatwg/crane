//! Generated from: fs.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemSyncAccessHandleImpl = @import("../impls/FileSystemSyncAccessHandle.zig");

pub const FileSystemSyncAccessHandle = struct {
    pub const Meta = struct {
        pub const name = "FileSystemSyncAccessHandle";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(FileSystemSyncAccessHandle, .{
        .deinit_fn = &deinit_wrapper,

        .call_close = &call_close,
        .call_flush = &call_flush,
        .call_getSize = &call_getSize,
        .call_read = &call_read,
        .call_truncate = &call_truncate,
        .call_write = &call_write,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        FileSystemSyncAccessHandleImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        FileSystemSyncAccessHandleImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_read(instance: *runtime.Instance, buffer: anyopaque, options: anyopaque) u64 {
        const state = instance.getState(State);
        
        return FileSystemSyncAccessHandleImpl.call_read(state, buffer, options);
    }

    pub fn call_truncate(instance: *runtime.Instance, newSize: u64) anyopaque {
        const state = instance.getState(State);
        // [EnforceRange] on newSize
        if (newSize > std.math.maxInt(u53)) return error.TypeError;
        
        return FileSystemSyncAccessHandleImpl.call_truncate(state, newSize);
    }

    pub fn call_write(instance: *runtime.Instance, buffer: anyopaque, options: anyopaque) u64 {
        const state = instance.getState(State);
        
        return FileSystemSyncAccessHandleImpl.call_write(state, buffer, options);
    }

    pub fn call_getSize(instance: *runtime.Instance) u64 {
        const state = instance.getState(State);
        return FileSystemSyncAccessHandleImpl.call_getSize(state);
    }

    pub fn call_close(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileSystemSyncAccessHandleImpl.call_close(state);
    }

    pub fn call_flush(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return FileSystemSyncAccessHandleImpl.call_flush(state);
    }

};
