//! Generated from: EXT_texture_compression_bptc.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_texture_compression_bptcImpl = @import("impls").EXT_texture_compression_bptc;

pub const EXT_texture_compression_bptc = struct {
    pub const Meta = struct {
        pub const name = "EXT_texture_compression_bptc";
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

    pub const vtable = runtime.buildVTable(EXT_texture_compression_bptc, .{
        .deinit_fn = &deinit_wrapper,

        .get_COMPRESSED_RGBA_BPTC_UNORM_EXT = &get_COMPRESSED_RGBA_BPTC_UNORM_EXT,
        .get_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT = &get_COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT,
        .get_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT = &get_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT,
        .get_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT = &get_COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        EXT_texture_compression_bptcImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_texture_compression_bptcImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
