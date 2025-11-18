//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUTextureUsageImpl = @import("../impls/GPUTextureUsage.zig");

pub const GPUTextureUsage = struct {
    pub const Meta = struct {
        pub const name = "GPUTextureUsage";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
            .{ .name = "SecureContext" },
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

    /// WebIDL constant: const GPUFlagsConstant COPY_SRC = 1;
    pub fn get_COPY_SRC() GPUFlagsConstant {
        return 1;
    }

    /// WebIDL constant: const GPUFlagsConstant COPY_DST = 2;
    pub fn get_COPY_DST() GPUFlagsConstant {
        return 2;
    }

    /// WebIDL constant: const GPUFlagsConstant TEXTURE_BINDING = 4;
    pub fn get_TEXTURE_BINDING() GPUFlagsConstant {
        return 4;
    }

    /// WebIDL constant: const GPUFlagsConstant STORAGE_BINDING = 8;
    pub fn get_STORAGE_BINDING() GPUFlagsConstant {
        return 8;
    }

    /// WebIDL constant: const GPUFlagsConstant RENDER_ATTACHMENT = 16;
    pub fn get_RENDER_ATTACHMENT() GPUFlagsConstant {
        return 16;
    }

    pub const vtable = runtime.buildVTable(GPUTextureUsage, .{
        .deinit_fn = &deinit_wrapper,

        .get_COPY_DST = &get_COPY_DST,
        .get_COPY_SRC = &get_COPY_SRC,
        .get_RENDER_ATTACHMENT = &get_RENDER_ATTACHMENT,
        .get_STORAGE_BINDING = &get_STORAGE_BINDING,
        .get_TEXTURE_BINDING = &get_TEXTURE_BINDING,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUTextureUsageImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUTextureUsageImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
