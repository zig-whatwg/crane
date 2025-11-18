//! Generated from: fs.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const FileSystemWritableFileStreamImpl = @import("impls").FileSystemWritableFileStream;
const WritableStream = @import("interfaces").WritableStream;
const FileSystemWriteChunkType = @import("typedefs").FileSystemWriteChunkType;
const Promise<undefined> = @import("interfaces").Promise<undefined>;

pub const FileSystemWritableFileStream = struct {
    pub const Meta = struct {
        pub const name = "FileSystemWritableFileStream";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WritableStream;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
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

    pub const vtable = runtime.buildVTable(FileSystemWritableFileStream, .{
        .deinit_fn = &deinit_wrapper,

        .get_locked = &get_locked,

        .call_abort = &call_abort,
        .call_close = &call_close,
        .call_getWriter = &call_getWriter,
        .call_seek = &call_seek,
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
        FileSystemWritableFileStreamImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemWritableFileStreamImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_locked(instance: *runtime.Instance) anyerror!bool {
        return try FileSystemWritableFileStreamImpl.get_locked(instance);
    }

    pub fn call_getWriter(instance: *runtime.Instance) anyerror!WritableStreamDefaultWriter {
        return try FileSystemWritableFileStreamImpl.call_getWriter(instance);
    }

    pub fn call_truncate(instance: *runtime.Instance, size: u64) anyerror!anyopaque {
        
        return try FileSystemWritableFileStreamImpl.call_truncate(instance, size);
    }

    pub fn call_abort(instance: *runtime.Instance, reason: anyopaque) anyerror!anyopaque {
        
        return try FileSystemWritableFileStreamImpl.call_abort(instance, reason);
    }

    pub fn call_write(instance: *runtime.Instance, data: FileSystemWriteChunkType) anyerror!anyopaque {
        
        return try FileSystemWritableFileStreamImpl.call_write(instance, data);
    }

    pub fn call_close(instance: *runtime.Instance) anyerror!anyopaque {
        return try FileSystemWritableFileStreamImpl.call_close(instance);
    }

    pub fn call_seek(instance: *runtime.Instance, position: u64) anyerror!anyopaque {
        
        return try FileSystemWritableFileStreamImpl.call_seek(instance, position);
    }

};
