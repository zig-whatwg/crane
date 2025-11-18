//! Generated from: WEBGL_compressed_texture_pvrtc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_compressed_texture_pvrtcImpl = @import("impls").WEBGL_compressed_texture_pvrtc;

pub const WEBGL_compressed_texture_pvrtc = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_pvrtc";
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

    pub const vtable = runtime.buildVTable(WEBGL_compressed_texture_pvrtc, .{
        .deinit_fn = &deinit_wrapper,

        .get_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG = &get_COMPRESSED_RGBA_PVRTC_2BPPV1_IMG,
        .get_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG = &get_COMPRESSED_RGBA_PVRTC_4BPPV1_IMG,
        .get_COMPRESSED_RGB_PVRTC_2BPPV1_IMG = &get_COMPRESSED_RGB_PVRTC_2BPPV1_IMG,
        .get_COMPRESSED_RGB_PVRTC_4BPPV1_IMG = &get_COMPRESSED_RGB_PVRTC_4BPPV1_IMG,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WEBGL_compressed_texture_pvrtcImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_compressed_texture_pvrtcImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
