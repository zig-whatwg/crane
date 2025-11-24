//! Generated from: EXT_texture_compression_bptc.idl
//! Generated at: 2025-11-24T18:47:07Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_texture_compression_bptcImpl = @import("impls").EXT_texture_compression_bptc;
const GLenum = @import("typedefs").GLenum;

pub const EXT_texture_compression_bptc = struct {
    pub const Meta = struct {
        pub const name = "EXT_texture_compression_bptc";
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
            .{ "COMPRESSED_RGBA_BPTC_UNORM_EXT", "get_COMPRESSED_RGBA_BPTC_UNORM_EXT" },
            .{ "COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT", "get_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT" },
            .{ "COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT", "get_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT" },
            .{ "COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT", "get_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT" },
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

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_BPTC_UNORM_EXT = 36492;
    pub fn get_COMPRESSED_RGBA_BPTC_UNORM_EXT() GLenum {
        return 36492;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT = 36493;
    pub fn get_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT() GLenum {
        return 36493;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT = 36494;
    pub fn get_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT() GLenum {
        return 36494;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT = 36495;
    pub fn get_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT() GLenum {
        return 36495;
    }

    const delegates = .{

        .get_COMPRESSED_RGBA_BPTC_UNORM_EXT = &get_COMPRESSED_RGBA_BPTC_UNORM_EXT,
        .get_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT = &get_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT,
        .get_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT = &get_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT,
        .get_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT = &get_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return EXT_texture_compression_bptcImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_texture_compression_bptcImpl.deinit(instance);
    }

};
