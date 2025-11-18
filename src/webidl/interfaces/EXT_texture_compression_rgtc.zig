//! Generated from: EXT_texture_compression_rgtc.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const EXT_texture_compression_rgtcImpl = @import("impls").EXT_texture_compression_rgtc;

pub const EXT_texture_compression_rgtc = struct {
    pub const Meta = struct {
        pub const name = "EXT_texture_compression_rgtc";
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

    /// WebIDL constant: const GLenum COMPRESSED_RED_RGTC1_EXT = 36283;
    pub fn get_COMPRESSED_RED_RGTC1_EXT() GLenum {
        return 36283;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SIGNED_RED_RGTC1_EXT = 36284;
    pub fn get_COMPRESSED_SIGNED_RED_RGTC1_EXT() GLenum {
        return 36284;
    }

    /// WebIDL constant: const GLenum COMPRESSED_RED_GREEN_RGTC2_EXT = 36285;
    pub fn get_COMPRESSED_RED_GREEN_RGTC2_EXT() GLenum {
        return 36285;
    }

    /// WebIDL constant: const GLenum COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT = 36286;
    pub fn get_COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT() GLenum {
        return 36286;
    }

    pub const vtable = runtime.buildVTable(EXT_texture_compression_rgtc, .{
        .deinit_fn = &deinit_wrapper,

        .get_COMPRESSED_RED_GREEN_RGTC2_EXT = &get_COMPRESSED_RED_GREEN_RGTC2_EXT,
        .get_COMPRESSED_RED_RGTC1_EXT = &get_COMPRESSED_RED_RGTC1_EXT,
        .get_COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT = &get_COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT,
        .get_COMPRESSED_SIGNED_RED_RGTC1_EXT = &get_COMPRESSED_SIGNED_RED_RGTC1_EXT,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        EXT_texture_compression_rgtcImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        EXT_texture_compression_rgtcImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
