//! Generated from: WEBGL_compressed_texture_astc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_compressed_texture_astcImpl = @import("impls").WEBGL_compressed_texture_astc;

pub const WEBGL_compressed_texture_astc = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_astc";
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

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_4x4_KHR = 37808;
    pub fn get_COMPRESSED_RGBA_ASTC_4x4_KHR() GLenum {
        return 37808;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_5x4_KHR = 37809;
    pub fn get_COMPRESSED_RGBA_ASTC_5x4_KHR() GLenum {
        return 37809;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_5x5_KHR = 37810;
    pub fn get_COMPRESSED_RGBA_ASTC_5x5_KHR() GLenum {
        return 37810;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_6x5_KHR = 37811;
    pub fn get_COMPRESSED_RGBA_ASTC_6x5_KHR() GLenum {
        return 37811;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_6x6_KHR = 37812;
    pub fn get_COMPRESSED_RGBA_ASTC_6x6_KHR() GLenum {
        return 37812;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_8x5_KHR = 37813;
    pub fn get_COMPRESSED_RGBA_ASTC_8x5_KHR() GLenum {
        return 37813;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_8x6_KHR = 37814;
    pub fn get_COMPRESSED_RGBA_ASTC_8x6_KHR() GLenum {
        return 37814;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_8x8_KHR = 37815;
    pub fn get_COMPRESSED_RGBA_ASTC_8x8_KHR() GLenum {
        return 37815;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_10x5_KHR = 37816;
    pub fn get_COMPRESSED_RGBA_ASTC_10x5_KHR() GLenum {
        return 37816;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_10x6_KHR = 37817;
    pub fn get_COMPRESSED_RGBA_ASTC_10x6_KHR() GLenum {
        return 37817;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_10x8_KHR = 37818;
    pub fn get_COMPRESSED_RGBA_ASTC_10x8_KHR() GLenum {
        return 37818;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_10x10_KHR = 37819;
    pub fn get_COMPRESSED_RGBA_ASTC_10x10_KHR() GLenum {
        return 37819;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_12x10_KHR = 37820;
    pub fn get_COMPRESSED_RGBA_ASTC_12x10_KHR() GLenum {
        return 37820;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RGBA_ASTC_12x12_KHR = 37821;
    pub fn get_COMPRESSED_RGBA_ASTC_12x12_KHR() GLenum {
        return 37821;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR = 37840;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR() GLenum {
        return 37840;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR = 37841;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR() GLenum {
        return 37841;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR = 37842;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR() GLenum {
        return 37842;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR = 37843;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR() GLenum {
        return 37843;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR = 37844;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR() GLenum {
        return 37844;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR = 37845;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR() GLenum {
        return 37845;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR = 37846;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR() GLenum {
        return 37846;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR = 37847;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR() GLenum {
        return 37847;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR = 37848;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR() GLenum {
        return 37848;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR = 37849;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR() GLenum {
        return 37849;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR = 37850;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR() GLenum {
        return 37850;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR = 37851;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR() GLenum {
        return 37851;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR = 37852;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR() GLenum {
        return 37852;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR = 37853;
    pub fn get_COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR() GLenum {
        return 37853;
    }

    pub const vtable = runtime.buildVTable(WEBGL_compressed_texture_astc, .{
        .deinit_fn = &deinit_wrapper,

        .get_COMPRESSED_RGBA_ASTC_10x10_KHR = &get_COMPRESSED_RGBA_ASTC_10x10_KHR,
        .get_COMPRESSED_RGBA_ASTC_10x5_KHR = &get_COMPRESSED_RGBA_ASTC_10x5_KHR,
        .get_COMPRESSED_RGBA_ASTC_10x6_KHR = &get_COMPRESSED_RGBA_ASTC_10x6_KHR,
        .get_COMPRESSED_RGBA_ASTC_10x8_KHR = &get_COMPRESSED_RGBA_ASTC_10x8_KHR,
        .get_COMPRESSED_RGBA_ASTC_12x10_KHR = &get_COMPRESSED_RGBA_ASTC_12x10_KHR,
        .get_COMPRESSED_RGBA_ASTC_12x12_KHR = &get_COMPRESSED_RGBA_ASTC_12x12_KHR,
        .get_COMPRESSED_RGBA_ASTC_4x4_KHR = &get_COMPRESSED_RGBA_ASTC_4x4_KHR,
        .get_COMPRESSED_RGBA_ASTC_5x4_KHR = &get_COMPRESSED_RGBA_ASTC_5x4_KHR,
        .get_COMPRESSED_RGBA_ASTC_5x5_KHR = &get_COMPRESSED_RGBA_ASTC_5x5_KHR,
        .get_COMPRESSED_RGBA_ASTC_6x5_KHR = &get_COMPRESSED_RGBA_ASTC_6x5_KHR,
        .get_COMPRESSED_RGBA_ASTC_6x6_KHR = &get_COMPRESSED_RGBA_ASTC_6x6_KHR,
        .get_COMPRESSED_RGBA_ASTC_8x5_KHR = &get_COMPRESSED_RGBA_ASTC_8x5_KHR,
        .get_COMPRESSED_RGBA_ASTC_8x6_KHR = &get_COMPRESSED_RGBA_ASTC_8x6_KHR,
        .get_COMPRESSED_RGBA_ASTC_8x8_KHR = &get_COMPRESSED_RGBA_ASTC_8x8_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x10_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x5_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x6_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_10x8_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_12x10_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_12x12_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_4x4_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_5x4_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_5x5_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_6x5_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_6x6_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_8x5_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_8x6_KHR,
        .get_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR = &get_COMPRESSED_SRGB8_ALPHA8_ASTC_8x8_KHR,

        .call_getSupportedProfiles = &call_getSupportedProfiles,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WEBGL_compressed_texture_astcImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_compressed_texture_astcImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn call_getSupportedProfiles(instance: *runtime.Instance) anyerror!anyopaque {
        return try WEBGL_compressed_texture_astcImpl.call_getSupportedProfiles(instance);
    }

};
