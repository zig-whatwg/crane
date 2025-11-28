//! Generated from: EXT_texture_norm16.idl
//! Generated at: 2025-11-28T03:24:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_texture_norm16Impl = @import("impls").EXT_texture_norm16;
const GLenum = @import("typedefs").GLenum;

pub const EXT_texture_norm16 = struct {
    pub const Meta = struct {
        pub const name = "EXT_texture_norm16";
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
            .{ "R16_EXT", "get_R16_EXT" },
            .{ "RG16_EXT", "get_RG16_EXT" },
            .{ "RGB16_EXT", "get_RGB16_EXT" },
            .{ "RGBA16_EXT", "get_RGBA16_EXT" },
            .{ "R16_SNORM_EXT", "get_R16_SNORM_EXT" },
            .{ "RG16_SNORM_EXT", "get_RG16_SNORM_EXT" },
            .{ "RGB16_SNORM_EXT", "get_RGB16_SNORM_EXT" },
            .{ "RGBA16_SNORM_EXT", "get_RGBA16_SNORM_EXT" },
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
            _internal: ?*EXT_texture_norm16Impl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum R16_EXT = 33322;
    pub fn get_R16_EXT() GLenum {
        return 33322;
    }

    /// WebIDL constant: const GLenum RG16_EXT = 33324;
    pub fn get_RG16_EXT() GLenum {
        return 33324;
    }

    /// WebIDL constant: const GLenum RGB16_EXT = 32852;
    pub fn get_RGB16_EXT() GLenum {
        return 32852;
    }

    /// WebIDL constant: const GLenum RGBA16_EXT = 32859;
    pub fn get_RGBA16_EXT() GLenum {
        return 32859;
    }

    /// WebIDL constant: const GLenum R16_SNORM_EXT = 36760;
    pub fn get_R16_SNORM_EXT() GLenum {
        return 36760;
    }

    /// WebIDL constant: const GLenum RG16_SNORM_EXT = 36761;
    pub fn get_RG16_SNORM_EXT() GLenum {
        return 36761;
    }

    /// WebIDL constant: const GLenum RGB16_SNORM_EXT = 36762;
    pub fn get_RGB16_SNORM_EXT() GLenum {
        return 36762;
    }

    /// WebIDL constant: const GLenum RGBA16_SNORM_EXT = 36763;
    pub fn get_RGBA16_SNORM_EXT() GLenum {
        return 36763;
    }

    const delegates = .{

        .get_R16_EXT = &get_R16_EXT,
        .get_R16_SNORM_EXT = &get_R16_SNORM_EXT,
        .get_RG16_EXT = &get_RG16_EXT,
        .get_RG16_SNORM_EXT = &get_RG16_SNORM_EXT,
        .get_RGB16_EXT = &get_RGB16_EXT,
        .get_RGB16_SNORM_EXT = &get_RGB16_SNORM_EXT,
        .get_RGBA16_EXT = &get_RGBA16_EXT,
        .get_RGBA16_SNORM_EXT = &get_RGBA16_SNORM_EXT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EXT_texture_norm16Impl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_texture_norm16Impl.deinit(instance);
    }

};
