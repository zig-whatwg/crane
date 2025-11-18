//! Generated from: WEBGL_clip_cull_distance.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const WEBGL_clip_cull_distanceImpl = @import("impls").WEBGL_clip_cull_distance;

pub const WEBGL_clip_cull_distance = struct {
    pub const Meta = struct {
        pub const name = "WEBGL_clip_cull_distance";
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

    /// WebIDL constant: const GLenum MAX_CLIP_DISTANCES_WEBGL = 3378;
    pub fn get_MAX_CLIP_DISTANCES_WEBGL() GLenum {
        return 3378;
    }

    /// WebIDL constant: const GLenum MAX_CULL_DISTANCES_WEBGL = 33529;
    pub fn get_MAX_CULL_DISTANCES_WEBGL() GLenum {
        return 33529;
    }

    /// WebIDL constant: const GLenum MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL = 33530;
    pub fn get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL() GLenum {
        return 33530;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE0_WEBGL = 12288;
    pub fn get_CLIP_DISTANCE0_WEBGL() GLenum {
        return 12288;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE1_WEBGL = 12289;
    pub fn get_CLIP_DISTANCE1_WEBGL() GLenum {
        return 12289;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE2_WEBGL = 12290;
    pub fn get_CLIP_DISTANCE2_WEBGL() GLenum {
        return 12290;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE3_WEBGL = 12291;
    pub fn get_CLIP_DISTANCE3_WEBGL() GLenum {
        return 12291;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE4_WEBGL = 12292;
    pub fn get_CLIP_DISTANCE4_WEBGL() GLenum {
        return 12292;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE5_WEBGL = 12293;
    pub fn get_CLIP_DISTANCE5_WEBGL() GLenum {
        return 12293;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE6_WEBGL = 12294;
    pub fn get_CLIP_DISTANCE6_WEBGL() GLenum {
        return 12294;
    }

    /// WebIDL constant: const GLenum CLIP_DISTANCE7_WEBGL = 12295;
    pub fn get_CLIP_DISTANCE7_WEBGL() GLenum {
        return 12295;
    }

    pub const vtable = runtime.buildVTable(WEBGL_clip_cull_distance, .{
        .deinit_fn = &deinit_wrapper,

        .get_CLIP_DISTANCE0_WEBGL = &get_CLIP_DISTANCE0_WEBGL,
        .get_CLIP_DISTANCE1_WEBGL = &get_CLIP_DISTANCE1_WEBGL,
        .get_CLIP_DISTANCE2_WEBGL = &get_CLIP_DISTANCE2_WEBGL,
        .get_CLIP_DISTANCE3_WEBGL = &get_CLIP_DISTANCE3_WEBGL,
        .get_CLIP_DISTANCE4_WEBGL = &get_CLIP_DISTANCE4_WEBGL,
        .get_CLIP_DISTANCE5_WEBGL = &get_CLIP_DISTANCE5_WEBGL,
        .get_CLIP_DISTANCE6_WEBGL = &get_CLIP_DISTANCE6_WEBGL,
        .get_CLIP_DISTANCE7_WEBGL = &get_CLIP_DISTANCE7_WEBGL,
        .get_MAX_CLIP_DISTANCES_WEBGL = &get_MAX_CLIP_DISTANCES_WEBGL,
        .get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL = &get_MAX_COMBINED_CLIP_AND_CULL_DISTANCES_WEBGL,
        .get_MAX_CULL_DISTANCES_WEBGL = &get_MAX_CULL_DISTANCES_WEBGL,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        WEBGL_clip_cull_distanceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        WEBGL_clip_cull_distanceImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
