//! Generated from: WEBGL_compressed_texture_etc.idl
//! Generated at: 2025-11-29T02:15:44Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const WEBGL_compressed_texture_etcImpl = @import("impls").WEBGL_compressed_texture_etc;
const mixins = @import("mixins");
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_compressed_texture_etc = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_etc";
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
            .{ "COMPRESSED_R11_EAC", "get_COMPRESSED_R11_EAC" },
            .{ "COMPRESSED_SIGNED_R11_EAC", "get_COMPRESSED_SIGNED_R11_EAC" },
            .{ "COMPRESSED_RG11_EAC", "get_COMPRESSED_RG11_EAC" },
            .{ "COMPRESSED_SIGNED_RG11_EAC", "get_COMPRESSED_SIGNED_RG11_EAC" },
            .{ "COMPRESSED_RGB8_ETC2", "get_COMPRESSED_RGB8_ETC2" },
            .{ "COMPRESSED_SRGB8_ETC2", "get_COMPRESSED_SRGB8_ETC2" },
            .{ "COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2", "get_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2" },
            .{ "COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2", "get_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2" },
            .{ "COMPRESSED_RGBA8_ETC2_EAC", "get_COMPRESSED_RGBA8_ETC2_EAC" },
            .{ "COMPRESSED_SRGB8_ALPHA8_ETC2_EAC", "get_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC" },
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
            _internal: ?*WEBGL_compressed_texture_etcImpl.InternalState = null,
        },
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum COMPRESSED_R11_EAC = 37488;
    pub fn get_COMPRESSED_R11_EAC() GLenum {
        return 37488;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SIGNED_R11_EAC = 37489;
    pub fn get_COMPRESSED_SIGNED_R11_EAC() GLenum {
        return 37489;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RG11_EAC = 37490;
    pub fn get_COMPRESSED_RG11_EAC() GLenum {
        return 37490;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SIGNED_RG11_EAC = 37491;
    pub fn get_COMPRESSED_SIGNED_RG11_EAC() GLenum {
        return 37491;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGB8_ETC2 = 37492;
    pub fn get_COMPRESSED_RGB8_ETC2() GLenum {
        return 37492;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ETC2 = 37493;
    pub fn get_COMPRESSED_SRGB8_ETC2() GLenum {
        return 37493;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2 = 37494;
    pub fn get_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2() GLenum {
        return 37494;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2 = 37495;
    pub fn get_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2() GLenum {
        return 37495;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA8_ETC2_EAC = 37496;
    pub fn get_COMPRESSED_RGBA8_ETC2_EAC() GLenum {
        return 37496;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ETC2_EAC = 37497;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC() GLenum {
        return 37497;
    }

    const delegates = .{

        .get_COMPRESSED_R11_EAC = &get_COMPRESSED_R11_EAC,
        .get_COMPRESSED_RG11_EAC = &get_COMPRESSED_RG11_EAC,
        .get_COMPRESSED_RGB8_ETC2 = &get_COMPRESSED_RGB8_ETC2,
        .get_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2 = &get_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2,
        .get_COMPRESSED_RGBA8_ETC2_EAC = &get_COMPRESSED_RGBA8_ETC2_EAC,
        .get_COMPRESSED_SIGNED_R11_EAC = &get_COMPRESSED_SIGNED_R11_EAC,
        .get_COMPRESSED_SIGNED_RG11_EAC = &get_COMPRESSED_SIGNED_RG11_EAC,
        .get_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC = &get_COMPRESSED_SRGB8_ALPHA8_ETC2_EAC,
        .get_COMPRESSED_SRGB8_ETC2 = &get_COMPRESSED_SRGB8_ETC2,
        .get_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2 = &get_COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_compressed_texture_etcImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_compressed_texture_etcImpl.deinit(instance);
    }

};
