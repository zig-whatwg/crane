//! Generated from: encoding.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const TextEncoderImpl = @import("impls").TextEncoder;
const TextEncoderCommon = @import("interfaces").TextEncoderCommon;
const TextEncoderEncodeIntoResult = @import("dictionaries").TextEncoderEncodeIntoResult;
const USVString = @import("interfaces").USVString;
const DOMString = @import("typedefs").DOMString;

pub const TextEncoder = struct {
    pub const Meta = struct {
        pub const name = "TextEncoder";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{
            TextEncoderCommon,
        };
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "*" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in_all_contexts = true;
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "encoding", "get_encoding", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "encode", "call_encode", 0 },
            .{ "encodeInto", "call_encodeInto", 2 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "encode",
            "encodeInto",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "encoding", "get_encoding", null },
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
        },
    );

    const delegates = .{

        .get_encoding = &get_encoding,

        .call_encode = &call_encode,
        .call_encodeInto = &call_encodeInto,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return TextEncoderImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        TextEncoderImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try TextEncoderImpl.call_constructor(allocator, ctx);
    }

    pub fn get_encoding(instance: *runtime.Instance) anyerror!DOMString {
        return try TextEncoderImpl.get_encoding(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_encode(instance: *runtime.Instance, input: runtime.USVString) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        
        return try TextEncoderImpl.call_encode(instance, input);
    }

    pub fn call_encodeInto(instance: *runtime.Instance, source: runtime.USVString, destination: *const anyopaque) anyerror!TextEncoderEncodeIntoResult {
        
        return try TextEncoderImpl.call_encodeInto(instance, source, destination);
    }

};
