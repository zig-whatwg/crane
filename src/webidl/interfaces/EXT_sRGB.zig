//! Generated from: EXT_sRGB.idl
//! Generated at: 2025-11-23T20:06:13Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_sRGBImpl = @import("impls").EXT_sRGB;
const GLenum = @import("typedefs").GLenum;

pub const EXT_sRGB = struct {
    pub const Meta = struct {
        pub const name = "EXT_sRGB";
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
            .{ "SRGB_EXT", "get_SRGB_EXT" },
            .{ "SRGB_ALPHA_EXT", "get_SRGB_ALPHA_EXT" },
            .{ "SRGB8_ALPHA8_EXT", "get_SRGB8_ALPHA8_EXT" },
            .{ "FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT", "get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT" },
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

    /// WebIDL constant: const GLenum SRGB_EXT = 35904;
    pub fn get_SRGB_EXT() GLenum {
        return 35904;
    }

    /// WebIDL constant: const GLenum SRGB_ALPHA_EXT = 35906;
    pub fn get_SRGB_ALPHA_EXT() GLenum {
        return 35906;
    }

    /// WebIDL constant: const GLenum SRGB8_ALPHA8_EXT = 35907;
    pub fn get_SRGB8_ALPHA8_EXT() GLenum {
        return 35907;
    }

    /// WebIDL constant: const GLenum FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT = 33296;
    pub fn get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT() GLenum {
        return 33296;
    }

    const delegates = .{

        .get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT = &get_FRAMEBUFFER_ATTACHMENT_COLOR_ENCODING_EXT,
        .get_SRGB8_ALPHA8_EXT = &get_SRGB8_ALPHA8_EXT,
        .get_SRGB_ALPHA_EXT = &get_SRGB_ALPHA_EXT,
        .get_SRGB_EXT = &get_SRGB_EXT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EXT_sRGBImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_sRGBImpl.deinit(instance);
    }

};
