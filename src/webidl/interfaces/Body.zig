//! Generated from: fetch.idl
//! Generated at: 2025-11-28T03:24:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BodyImpl = @import("impls").Body;
const ReadableStream = @import("interfaces").ReadableStream;
const Blob = @import("interfaces").Blob;
const FormData = @import("interfaces").FormData;
const USVString = @import("interfaces").USVString;

pub const Body = struct {
    pub const Meta = struct {
        pub const name = "Body";
        pub const is_mixin = true;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{};
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "body", "get_body", null },
            .{ "bodyUsed", "get_bodyUsed", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "arrayBuffer", "call_arrayBuffer", 0 },
            .{ "blob", "call_blob", 0 },
            .{ "bytes", "call_bytes", 0 },
            .{ "formData", "call_formData", 0 },
            .{ "json", "call_json", 0 },
            .{ "text", "call_text", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "arrayBuffer",
            "blob",
            "bytes",
            "formData",
            "json",
            "text",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "body", "get_body", null },
            .{ "bodyUsed", "get_bodyUsed", null },
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
            body: ?*runtime.Instance = null,
            bodyUsed: bool = undefined,
            _internal: ?*BodyImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_body = &get_body,
        .get_bodyUsed = &get_bodyUsed,

        .call_arrayBuffer = &call_arrayBuffer,
        .call_blob = &call_blob,
        .call_bytes = &call_bytes,
        .call_formData = &call_formData,
        .call_json = &call_json,
        .call_text = &call_text,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BodyImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BodyImpl.deinit(instance);
    }

    pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
        return try BodyImpl.get_body(instance);
    }

    pub fn get_bodyUsed(instance: *runtime.Instance) anyerror!bool {
        return try BodyImpl.get_bodyUsed(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_blob(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_blob(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_formData(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_formData(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_text(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_text(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_json(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_json(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_bytes(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_bytes(instance);
    }

    /// Extended attributes: [NewObject]
    pub fn call_arrayBuffer(instance: *runtime.Instance) anyerror!*const anyopaque {
        // [NewObject] - Caller owns the returned object
        return try BodyImpl.call_arrayBuffer(instance);
    }

};
