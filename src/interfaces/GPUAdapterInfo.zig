//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUAdapterInfoImpl = @import("../impls/GPUAdapterInfo.zig");

pub const GPUAdapterInfo = struct {
    pub const Meta = struct {
        pub const name = "GPUAdapterInfo";
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
            vendor: runtime.DOMString = undefined,
            architecture: runtime.DOMString = undefined,
            device: runtime.DOMString = undefined,
            description: runtime.DOMString = undefined,
            subgroupMinSize: u32 = undefined,
            subgroupMaxSize: u32 = undefined,
            isFallbackAdapter: bool = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUAdapterInfo, .{
        .deinit_fn = &deinit_wrapper,

        .get_architecture = &get_architecture,
        .get_description = &get_description,
        .get_device = &get_device,
        .get_isFallbackAdapter = &get_isFallbackAdapter,
        .get_subgroupMaxSize = &get_subgroupMaxSize,
        .get_subgroupMinSize = &get_subgroupMinSize,
        .get_vendor = &get_vendor,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUAdapterInfoImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUAdapterInfoImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_vendor(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return GPUAdapterInfoImpl.get_vendor(state);
    }

    pub fn get_architecture(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return GPUAdapterInfoImpl.get_architecture(state);
    }

    pub fn get_device(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return GPUAdapterInfoImpl.get_device(state);
    }

    pub fn get_description(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return GPUAdapterInfoImpl.get_description(state);
    }

    pub fn get_subgroupMinSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUAdapterInfoImpl.get_subgroupMinSize(state);
    }

    pub fn get_subgroupMaxSize(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return GPUAdapterInfoImpl.get_subgroupMaxSize(state);
    }

    pub fn get_isFallbackAdapter(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return GPUAdapterInfoImpl.get_isFallbackAdapter(state);
    }

};
