//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUAdapterImpl = @import("impls").GPUAdapter;
const GPUDeviceDescriptor = @import("dictionaries").GPUDeviceDescriptor;
const GPUSupportedLimits = @import("interfaces").GPUSupportedLimits;
const GPUSupportedFeatures = @import("interfaces").GPUSupportedFeatures;
const GPUAdapterInfo = @import("interfaces").GPUAdapterInfo;
const Promise<GPUDevice> = @import("interfaces").Promise<GPUDevice>;

pub const GPUAdapter = struct {
    pub const Meta = struct {
        pub const name = "GPUAdapter";
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
        struct {
            features: GPUSupportedFeatures = undefined,
            limits: GPUSupportedLimits = undefined,
            info: GPUAdapterInfo = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUAdapter, .{
        .deinit_fn = &deinit_wrapper,

        .get_features = &get_features,
        .get_info = &get_info,
        .get_limits = &get_limits,

        .call_requestDevice = &call_requestDevice,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPUAdapterImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUAdapterImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_features(instance: *runtime.Instance) anyerror!GPUSupportedFeatures {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_features) |cached| {
            return cached;
        }
        const value = try GPUAdapterImpl.get_features(instance);
        state.cached_features = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_limits(instance: *runtime.Instance) anyerror!GPUSupportedLimits {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_limits) |cached| {
            return cached;
        }
        const value = try GPUAdapterImpl.get_limits(instance);
        state.cached_limits = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_info(instance: *runtime.Instance) anyerror!GPUAdapterInfo {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_info) |cached| {
            return cached;
        }
        const value = try GPUAdapterImpl.get_info(instance);
        state.cached_info = value;
        return value;
    }

    pub fn call_requestDevice(instance: *runtime.Instance, descriptor: GPUDeviceDescriptor) anyerror!anyopaque {
        
        return try GPUAdapterImpl.call_requestDevice(instance, descriptor);
    }

};
