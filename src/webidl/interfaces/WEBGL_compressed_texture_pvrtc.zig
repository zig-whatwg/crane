//! Generated from: WEBGL_compressed_texture_pvrtc.idl
//! Generated at: 2025-11-23T01:18:34Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_compressed_texture_pvrtcImpl = @import("impls").WEBGL_compressed_texture_pvrtc;
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_compressed_texture_pvrtc = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_pvrtc";
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
            .{ "COMPRESSED_RGB_PVRTC_4BPPV1_IMG", "get_COMPRESSED_RGB_PVRTC_4BPPV1_IMG" },
            .{ "COMPRESSED_RGB_PVRTC_2BPPV1_IMG", "get_COMPRESSED_RGB_PVRTC_2BPPV1_IMG" },
            .{ "COMPRESSED_RGBA_PVRTC_4BPPV1_IMG", "get_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG" },
            .{ "COMPRESSED_RGBA_PVRTC_2BPPV1_IMG", "get_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG" },
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

    /// WebIDL constant: const GLenum COMPRESSED_RGB_PVRTC_4BPPV1_IMG = 35840;
    pub fn get_COMPRESSED_RGB_PVRTC_4BPPV1_IMG() GLenum {
        return 35840;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGB_PVRTC_2BPPV1_IMG = 35841;
    pub fn get_COMPRESSED_RGB_PVRTC_2BPPV1_IMG() GLenum {
        return 35841;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_PVRTC_4BPPV1_IMG = 35842;
    pub fn get_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG() GLenum {
        return 35842;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_PVRTC_2BPPV1_IMG = 35843;
    pub fn get_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG() GLenum {
        return 35843;
    }

    const delegates = .{

        .get_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG = &get_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG,
        .get_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG = &get_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG,
        .get_COMPRESSED_RGB_PVRTC_2BPPV1_IMG = &get_COMPRESSED_RGB_PVRTC_2BPPV1_IMG,
        .get_COMPRESSED_RGB_PVRTC_4BPPV1_IMG = &get_COMPRESSED_RGB_PVRTC_4BPPV1_IMG,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_compressed_texture_pvrtcImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_compressed_texture_pvrtcImpl.deinit(instance);
    }

};
