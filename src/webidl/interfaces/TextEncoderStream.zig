//! Generated from: encoding.idl
//! Generated at: 2025-12-07T19:33:00Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const v8 = @import("v8");
const TextEncoderStreamImpl = @import("impls").TextEncoderStream;
const mixins = @import("mixins");
const TextEncoderCommon = @import("interfaces").TextEncoderCommon;
const GenericTransformStream = @import("interfaces").GenericTransformStream;
const ReadableStream = @import("interfaces").ReadableStream;
const WritableStream = @import("interfaces").WritableStream;
const DOMString = @import("typedefs").DOMString;

pub const TextEncoderStream = struct {
    pub const Meta = struct {
        pub const name = "TextEncoderStream";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            TextEncoderCommon,
            GenericTransformStream,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "encoding", "get_encoding", null },
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
            .{ "encoding", "get_encoding", null },
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
            encoding: runtime.DOMString = undefined,
            readable: *runtime.Instance = undefined,
            writable: *runtime.Instance = undefined,
            _internal: ?*TextEncoderStreamImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_encoding = &get_encoding,
        .get_readable = &get_readable,
        .get_writable = &get_writable,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextEncoderStreamImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextEncoderStreamImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextEncoderStreamImpl.call_constructor(allocator, ctx);
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
        return try TextEncoderStreamImpl.get_encoding(instance);
    }

    pub fn get_readable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TextEncoderStreamImpl.get_readable(instance);
    }

    pub fn get_writable(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try TextEncoderStreamImpl.get_writable(instance);
    }

};
