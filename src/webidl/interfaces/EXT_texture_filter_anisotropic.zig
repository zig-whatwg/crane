//! Generated from: EXT_texture_filter_anisotropic.idl
//! Generated at: 2025-11-25T14:21:38Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_texture_filter_anisotropicImpl = @import("impls").EXT_texture_filter_anisotropic;
const GLenum = @import("typedefs").GLenum;

pub const EXT_texture_filter_anisotropic = struct {
    pub const Meta = struct {
        pub const name = "EXT_texture_filter_anisotropic";
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
            .{ "TEXTURE_MAX_ANISOTROPY_EXT", "get_TEXTURE_MAX_ANISOTROPY_EXT" },
            .{ "MAX_TEXTURE_MAX_ANISOTROPY_EXT", "get_MAX_TEXTURE_MAX_ANISOTROPY_EXT" },
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
            _internal: ?*EXT_texture_filter_anisotropicImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum TEXTURE_MAX_ANISOTROPY_EXT = 34046;
    pub fn get_TEXTURE_MAX_ANISOTROPY_EXT() GLenum {
        return 34046;
    }

    /// WebIDL constant: const GLenum MAX_TEXTURE_MAX_ANISOTROPY_EXT = 34047;
    pub fn get_MAX_TEXTURE_MAX_ANISOTROPY_EXT() GLenum {
        return 34047;
    }

    const delegates = .{

        .get_MAX_TEXTURE_MAX_ANISOTROPY_EXT = &get_MAX_TEXTURE_MAX_ANISOTROPY_EXT,
        .get_TEXTURE_MAX_ANISOTROPY_EXT = &get_TEXTURE_MAX_ANISOTROPY_EXT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EXT_texture_filter_anisotropicImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_texture_filter_anisotropicImpl.deinit(instance);
    }

};
