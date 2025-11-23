//! Generated from: fs.idl
//! Generated at: 2025-11-23T19:17:34Z
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
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "DedicatedWorker" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .DedicatedWorker = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "read", "call_read", 1 },
            .{ "write", "call_write", 1 },
            .{ "truncate", "call_truncate", 1 },
            .{ "getSize", "call_getSize", 0 },
            .{ "flush", "call_flush", 0 },
            .{ "close", "call_close", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "read",
            "write",
            "truncate",
            "getSize",
            "flush",
            "close",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_close = &call_close,
        .call_flush = &call_flush,
        .call_getSize = &call_getSize,
        .call_read = &call_read,
        .call_truncate = &call_truncate,
        .call_write = &call_write,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemSyncAccessHandleImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemSyncAccessHandleImpl.deinit(instance);
    }

    pub fn call_read(instance: *runtime.Instance, buffer: AllowSharedBufferSource, options: FileSystemReadWriteOptions) anyerror!u64 {
        
        return try FileSystemSyncAccessHandleImpl.call_read(instance, buffer, options);
    }

    pub fn call_truncate(instance: *runtime.Instance, newSize: u64) anyerror!void {
        // [EnforceRange] on newSize
        if (!runtime.isInRange(u64, newSize)) return error.TypeError;
        
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
