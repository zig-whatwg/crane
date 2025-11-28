//! Generated from: WEBGL_color_buffer_float.idl
//! Generated at: 2025-11-28T19:11:19Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WEBGL_color_buffer_floatImpl = @import("impls").WEBGL_color_buffer_float;
const mixins = @import("mixins");
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_color_buffer_float = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_color_buffer_float";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
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
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "RGBA32F_EXT", "get_RGBA32F_EXT" },
            .{ "FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT", "get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT" },
            .{ "UNSIGNED_NORMALIZED_EXT", "get_UNSIGNED_NORMALIZED_EXT" },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
        struct {
            _internal: ?*WEBGL_color_buffer_floatImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum RGBA32F_EXT = 34836;
    pub fn get_RGBA32F_EXT() GLenum {
        return 34836;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT = 33297;
    pub fn get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT() GLenum {
        return 33297;
    }

    /// WebIDL constant: const GLenum UNSIGNED_NORMALIZED_EXT = 35863;
    pub fn get_UNSIGNED_NORMALIZED_EXT() GLenum {
        return 35863;
    }

    const delegates = .{

        .get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT = &get_FRAMEBUFFER_ATTACHMENT_COMPONENT_TYPE_EXT,
        .get_RGBA32F_EXT = &get_RGBA32F_EXT,
        .get_UNSIGNED_NORMALIZED_EXT = &get_UNSIGNED_NORMALIZED_EXT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_color_buffer_floatImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_color_buffer_floatImpl.deinit(instance);
    }

};
