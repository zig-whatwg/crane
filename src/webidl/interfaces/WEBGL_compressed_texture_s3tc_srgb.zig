//! Generated from: WEBGL_compressed_texture_s3tc_srgb.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_compressed_texture_s3tc_srgbImpl = @import("impls").WEBGL_compressed_texture_s3tc_srgb;

pub const WEBGL_compressed_texture_s3tc_srgb = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_s3tc_srgb";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "LegacyNoInterfaceObject" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    // ========================================
    // Constants (static getters)
    // ========================================

    /// WebIDL constant: const GLenum COMPRESSED_SRGB_S3TC_DXT1_EXT = 35916;
    pub fn get_COMPRESSED_SRGB_S3TC_DXT1_EXT() GLenum {
        return 35916;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT = 35917;
    pub fn get_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT() GLenum {
        return 35917;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT = 35918;
    pub fn get_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT() GLenum {
        return 35918;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT = 35919;
    pub fn get_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT() GLenum {
        return 35919;
    }

    pub const vtable = runtime.buildVTable(WEBGL_compressed_texture_s3tc_srgb, .{
        .deinit_fn = &deinit_wrapper,

        .get_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT = &get_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT,
        .get_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT = &get_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT,
        .get_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT = &get_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT,
        .get_COMPRESSED_SRGB_S3TC_DXT1_EXT = &get_COMPRESSED_SRGB_S3TC_DXT1_EXT,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WEBGL_compressed_texture_s3tc_srgbImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_compressed_texture_s3tc_srgbImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
