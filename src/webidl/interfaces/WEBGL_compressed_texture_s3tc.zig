//! Generated from: WEBGL_compressed_texture_s3tc.idl
//! Generated at: 2025-11-23T19:57:37Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_compressed_texture_s3tcImpl = @import("impls").WEBGL_compressed_texture_s3tc;
const GLenum = @import("typedefs").GLenum;

pub const WEBGL_compressed_texture_s3tc = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_s3tc";
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
            .{ "COMPRESSED_RGB_S3TC_DXT1_EXT", "get_COMPRESSED_RGB_S3TC_DXT1_EXT" },
            .{ "COMPRESSED_RGBA_S3TC_DXT1_EXT", "get_COMPRESSED_RGBA_S3TC_DXT1_EXT" },
            .{ "COMPRESSED_RGBA_S3TC_DXT3_EXT", "get_COMPRESSED_RGBA_S3TC_DXT3_EXT" },
            .{ "COMPRESSED_RGBA_S3TC_DXT5_EXT", "get_COMPRESSED_RGBA_S3TC_DXT5_EXT" },
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

    /// WebIDL constant: const GLenum COMPRESSED_RGB_S3TC_DXT1_EXT = 33776;
    pub fn get_COMPRESSED_RGB_S3TC_DXT1_EXT() GLenum {
        return 33776;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_S3TC_DXT1_EXT = 33777;
    pub fn get_COMPRESSED_RGBA_S3TC_DXT1_EXT() GLenum {
        return 33777;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_S3TC_DXT3_EXT = 33778;
    pub fn get_COMPRESSED_RGBA_S3TC_DXT3_EXT() GLenum {
        return 33778;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_S3TC_DXT5_EXT = 33779;
    pub fn get_COMPRESSED_RGBA_S3TC_DXT5_EXT() GLenum {
        return 33779;
    }

    const delegates = .{

        .get_COMPRESSED_RGBA_S3TC_DXT1_EXT = &get_COMPRESSED_RGBA_S3TC_DXT1_EXT,
        .get_COMPRESSED_RGBA_S3TC_DXT3_EXT = &get_COMPRESSED_RGBA_S3TC_DXT3_EXT,
        .get_COMPRESSED_RGBA_S3TC_DXT5_EXT = &get_COMPRESSED_RGBA_S3TC_DXT5_EXT,
        .get_COMPRESSED_RGB_S3TC_DXT1_EXT = &get_COMPRESSED_RGB_S3TC_DXT1_EXT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return WEBGL_compressed_texture_s3tcImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_compressed_texture_s3tcImpl.deinit(instance);
    }

};
