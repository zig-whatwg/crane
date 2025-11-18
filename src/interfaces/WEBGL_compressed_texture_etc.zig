//! Generated from: WEBGL_compressed_texture_etc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_compressed_texture_etcImpl = @import("../impls/WEBGL_compressed_texture_etc.zig");

pub const WEBGL_compressed_texture_etc = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_etc";
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

    pub const vtable = runtime.buildVTable(WEBGL_compressed_texture_etc, .{
        .deinit_fn = &deinit_wrapper,

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
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WEBGL_compressed_texture_etcImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WEBGL_compressed_texture_etcImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
