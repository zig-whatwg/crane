//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUBufferImpl = @import("../impls/GPUBuffer.zig");
const GPUObjectBase = @import("GPUObjectBase.zig");

pub const GPUBuffer = struct {
    pub const Meta = struct {
        pub const name = "GPUBuffer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{
            GPUObjectBase,
        };
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
            size: GPUSize64Out = undefined,
            usage: GPUFlagsConstant = undefined,
            mapState: GPUBufferMapState = undefined,
            label: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUBuffer, .{
        .deinit_fn = &deinit_wrapper,

        .get_label = &get_label,
        .get_mapState = &get_mapState,
        .get_size = &get_size,
        .get_usage = &get_usage,

        .set_label = &set_label,

        .call_destroy = &call_destroy,
        .call_getMappedRange = &call_getMappedRange,
        .call_mapAsync = &call_mapAsync,
        .call_unmap = &call_unmap,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUBufferImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUBufferImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_size(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUBufferImpl.get_size(state);
    }

    pub fn get_usage(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUBufferImpl.get_usage(state);
    }

    pub fn get_mapState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUBufferImpl.get_mapState(state);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return GPUBufferImpl.get_label(state);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        GPUBufferImpl.set_label(state, value);
    }

    pub fn call_unmap(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUBufferImpl.call_unmap(state);
    }

    pub fn call_getMappedRange(instance: *runtime.Instance, offset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUBufferImpl.call_getMappedRange(state, offset, size);
    }

    pub fn call_mapAsync(instance: *runtime.Instance, mode: anyopaque, offset: anyopaque, size: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUBufferImpl.call_mapAsync(state, mode, offset, size);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUBufferImpl.call_destroy(state);
    }

};
