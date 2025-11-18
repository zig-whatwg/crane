//! Generated from: fs.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemSyncAccessHandleImpl = @import("impls").FileSystemSyncAccessHandle;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const FileSystemReadWriteOptions = @import("dictionaries").FileSystemReadWriteOptions;

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
        
        // Initialize the instance (Impl receives full instance)
        FileSystemSyncAccessHandleImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemSyncAccessHandleImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_read(instance: *runtime.Instance, buffer: AllowSharedBufferSource, options: FileSystemReadWriteOptions) anyerror!u64 {
        
        return try FileSystemSyncAccessHandleImpl.call_read(instance, buffer, options);
    }

    pub fn call_truncate(instance: *runtime.Instance, newSize: u64) anyerror!void {
        // [EnforceRange] on newSize
        if (!runtime.isInRange(newSize)) return error.TypeError;
        
        return try FileSystemSyncAccessHandleImpl.call_truncate(instance, newSize);
    }

    pub fn call_write(instance: *runtime.Instance, buffer: AllowSharedBufferSource, options: FileSystemReadWriteOptions) anyerror!u64 {
        
        return try FileSystemSyncAccessHandleImpl.call_write(instance, buffer, options);
    }

    pub fn call_getSize(instance: *runtime.Instance) anyerror!u64 {
        return try FileSystemSyncAccessHandleImpl.call_getSize(instance);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!void {
        return try FileSystemSyncAccessHandleImpl.call_close(instance);
    }

    pub fn call_flush(instance: *runtime.Instance) anyerror!void {
        return try FileSystemSyncAccessHandleImpl.call_flush(instance);
    }

};
