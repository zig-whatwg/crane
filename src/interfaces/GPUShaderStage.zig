//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUShaderStageImpl = @import("../impls/GPUShaderStage.zig");

pub const GPUShaderStage = struct {
    pub const Meta = struct {
        pub const name = "GPUShaderStage";
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

    /// WebIDL constant: const GPUFlagsConstant VERTEX = 1;
    pub fn get_VERTEX() GPUFlagsConstant {
        return 1;
    }

    /// WebIDL constant: const GPUFlagsConstant FRAGMENT = 2;
    pub fn get_FRAGMENT() GPUFlagsConstant {
        return 2;
    }

    /// WebIDL constant: const GPUFlagsConstant COMPUTE = 4;
    pub fn get_COMPUTE() GPUFlagsConstant {
        return 4;
    }

    pub const vtable = runtime.buildVTable(GPUShaderStage, .{
        .deinit_fn = &deinit_wrapper,

        .get_COMPUTE = &get_COMPUTE,
        .get_FRAGMENT = &get_FRAGMENT,
        .get_VERTEX = &get_VERTEX,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUShaderStageImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUShaderStageImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

};
