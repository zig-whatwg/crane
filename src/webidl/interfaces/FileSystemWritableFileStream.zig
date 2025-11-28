//! Generated from: fs.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const FileSystemWritableFileStreamImpl = @import("impls").FileSystemWritableFileStream;
const mixins = @import("mixins");
const WritableStream = @import("interfaces").WritableStream;
const WritableStreamDefaultWriter = @import("interfaces").WritableStreamDefaultWriter;
const FileSystemWriteChunkType = @import("typedefs").FileSystemWriteChunkType;
const QueuingStrategy = @import("dictionaries").QueuingStrategy;

pub const FileSystemWritableFileStream = struct {
    pub const Meta = struct {
        pub const name = "FileSystemWritableFileStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *WritableStream;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "write", "call_write", 1 },
            .{ "seek", "call_seek", 1 },
            .{ "truncate", "call_truncate", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "write",
            "seek",
            "truncate",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "abort",
            "close",
            "getWriter",
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
        struct {
            _internal: ?*FileSystemWritableFileStreamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_seek = &call_seek,
        .call_truncate = &call_truncate,
        .call_write = &call_write,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return FileSystemWritableFileStreamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        FileSystemWritableFileStreamImpl.deinit(instance);
    }

    pub fn call_truncate(instance: *runtime.Instance, size: u64) anyerror!*const anyopaque {
        
        return try FileSystemWritableFileStreamImpl.call_truncate(instance, size);
    }

    pub fn call_write(instance: *runtime.Instance, data: FileSystemWriteChunkType) anyerror!*const anyopaque {
        
        return try FileSystemWritableFileStreamImpl.call_write(instance, data);
    }

    pub fn call_seek(instance: *runtime.Instance, position: u64) anyerror!*const anyopaque {
        
        return try FileSystemWritableFileStreamImpl.call_seek(instance, position);
    }

};
