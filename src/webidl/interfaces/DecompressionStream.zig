//! Generated from: compression.idl
//! Generated at: 2025-11-28T19:51:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const DecompressionStreamImpl = @import("impls").DecompressionStream;
const mixins = @import("mixins");
const GenericTransformStream = @import("interfaces").GenericTransformStream;
const ReadableStream = @import("interfaces").ReadableStream;
const WritableStream = @import("interfaces").WritableStream;
const CompressionFormat = @import("enums").CompressionFormat;

pub const DecompressionStream = struct {
    pub const Meta = struct {
        pub const name = "DecompressionStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            GenericTransformStream,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "readable", "get_readable", null },
            .{ "writable", "get_writable", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            readable: *runtime.Instance = undefined,
            writable: *runtime.Instance = undefined,
            _internal: ?*DecompressionStreamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_readable = &get_readable,
        .get_writable = &get_writable,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return DecompressionStreamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        DecompressionStreamImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context, format: CompressionFormat) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try DecompressionStreamImpl.call_constructor(allocator, ctx, format);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DecompressionStreamImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try DecompressionStreamImpl.get_writable(instance);
    }

};
