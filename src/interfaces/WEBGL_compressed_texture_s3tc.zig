//! Generated from: WEBGL_compressed_texture_s3tc.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_compressed_texture_s3tcImpl = @import("../impls/WEBGL_compressed_texture_s3tc.zig");

pub const WEBGL_compressed_texture_s3tc = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_compressed_texture_s3tc";
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

    pub const vtable = runtime.buildVTable(WEBGL_compressed_texture_s3tc, .{
        .deinit_fn = &deinit_wrapper,

        .get_COMPRESSED_RGBA_S3TC_DXT1_EXT = &get_COMPRESSED_RGBA_S3TC_DXT1_EXT,
        .get_COMPRESSED_RGBA_S3TC_DXT3_EXT = &get_COMPRESSED_RGBA_S3TC_DXT3_EXT,
        .get_COMPRESSED_RGBA_S3TC_DXT5_EXT = &get_COMPRESSED_RGBA_S3TC_DXT5_EXT,
        .get_COMPRESSED_RGB_S3TC_DXT1_EXT = &get_COMPRESSED_RGB_S3TC_DXT1_EXT,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        WEBGL_compressed_texture_s3tcImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        WEBGL_compressed_texture_s3tcImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
