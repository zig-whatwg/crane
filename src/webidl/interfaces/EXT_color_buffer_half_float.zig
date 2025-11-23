//! Generated from: EXT_color_buffer_half_float.idl
//! Generated at: 2025-11-23T20:06:15Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_color_buffer_half_floatImpl = @import("impls").EXT_color_buffer_half_float;
const GLenum = @import("typedefs").GLenum;

pub const EXT_color_buffer_half_float = struct {
    pub const Meta = struct {
        pub const name = "EXT_color_buffer_half_float";
        pub const is_mixin = false;
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
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
        };
        
        /// Constants binding hints for V8Interface (JS name, getter fn name)
        pub const constants = .{
            .{ "RGBA16F_EXT", "get_RGBA16F_EXT" },
            .{ "RGB16F_EXT", "get_RGB16F_EXT" },
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
        struct {},
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum RGBA16F_EXT = 34842;
    pub fn get_RGBA16F_EXT() GLenum {
        return 34842;
    }

    /// WebIDL constant: const GLenum RGB16F_EXT = 34843;
    pub fn get_RGB16F_EXT() GLenum {
        return 34843;
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
        .get_RGB16F_EXT = &get_RGB16F_EXT,
        .get_RGBA16F_EXT = &get_RGBA16F_EXT,
        .get_UNSIGNED_NORMALIZED_EXT = &get_UNSIGNED_NORMALIZED_EXT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EXT_color_buffer_half_floatImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_color_buffer_half_floatImpl.deinit(instance);
    }

};
