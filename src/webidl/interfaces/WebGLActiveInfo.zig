//! Generated from: webgl1.idl
//! Generated at: 2025-11-23T01:18:35Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WebGLActiveInfoImpl = @import("impls").WebGLActiveInfo;
const GLint = @import("typedefs").GLint;
const GLenum = @import("typedefs").GLenum;
const DOMString = @import("typedefs").DOMString;

pub const WebGLActiveInfo = struct {
    pub const Meta = struct {
        pub const name = "WebGLActiveInfo";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "size", "get_size", null },
            .{ "type", "get_type", null },
            .{ "name", "get_name", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
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
            .{ "size", "get_size", null },
            .{ "type", "get_type", null },
            .{ "name", "get_name", null },
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
            size: GLint = undefined,
            @"type": GLenum = undefined,
            name: runtime.DOMString = undefined,
        },
    );

    const delegates = .{

        .get_name = &get_name,
        .get_size = &get_size,
        .get_type = &get_type,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WebGLActiveInfoImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WebGLActiveInfoImpl.deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyerror!GLint {
        return try WebGLActiveInfoImpl.get_size(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!GLenum {
        return try WebGLActiveInfoImpl.get_type(instance);
    }

    pub fn get_name(instance: *runtime.Instance) anyerror!DOMString {
        return try WebGLActiveInfoImpl.get_name(instance);
    }

};
