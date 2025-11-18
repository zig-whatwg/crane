//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const NavigatorGPUImpl = @import("impls").NavigatorGPU;
const GPU = @import("interfaces").GPU;

pub const NavigatorGPU = struct {
    pub const Meta = struct {
        pub const name = "NavigatorGPU";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{};
    };

    pub const State = runtime.FlattenedState(
        struct {
            gpu: GPU = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(NavigatorGPU, .{
        .deinit_fn = &deinit_wrapper,

        .get_gpu = &get_gpu,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        NavigatorGPUImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        NavigatorGPUImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject], [SecureContext]
    pub fn get_gpu(instance: *runtime.Instance) anyerror!GPU {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_gpu) |cached| {
            return cached;
        }
        const value = try NavigatorGPUImpl.get_gpu(instance);
        state.cached_gpu = value;
        return value;
    }

};
