//! Generated from: webnn.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MLContextImpl = @import("../impls/MLContext.zig");

pub const MLContext = struct {
    pub const Meta = struct {
        pub const name = "MLContext";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
    };

    pub const State = runtime.FlattenedState(
        struct {
            lost: Promise<MLContextLostInfo> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MLContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_lost = &get_lost,

        .call_createConstantTensor = &call_createConstantTensor,
        .call_createTensor = &call_createTensor,
        .call_destroy = &call_destroy,
        .call_dispatch = &call_dispatch,
        .call_opSupportLimits = &call_opSupportLimits,
        .call_readTensor = &call_readTensor,
        .call_readTensor = &call_readTensor,
        .call_writeTensor = &call_writeTensor,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        MLContextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MLContextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_lost(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MLContextImpl.get_lost(state);
    }

    pub fn call_dispatch(instance: *runtime.Instance, graph: anyopaque, inputs: anyopaque, outputs: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLContextImpl.call_dispatch(state, graph, inputs, outputs);
    }

    pub fn call_opSupportLimits(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MLContextImpl.call_opSupportLimits(state);
    }

    pub fn call_writeTensor(instance: *runtime.Instance, tensor: anyopaque, inputData: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLContextImpl.call_writeTensor(state, tensor, inputData);
    }

    /// Arguments for readTensor (WebIDL overloading)
    pub const ReadTensorArgs = union(enum) {
        /// readTensor(tensor)
        MLTensor: anyopaque,
        /// readTensor(tensor, outputData)
        MLTensor_AllowSharedBufferSource: struct {
            tensor: anyopaque,
            outputData: anyopaque,
        },
    };

    pub fn call_readTensor(instance: *runtime.Instance, args: ReadTensorArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .MLTensor => |arg| return MLContextImpl.MLTensor(state, arg),
            .MLTensor_AllowSharedBufferSource => |a| return MLContextImpl.MLTensor_AllowSharedBufferSource(state, a.tensor, a.outputData),
        }
    }

    pub fn call_createTensor(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLContextImpl.call_createTensor(state, descriptor);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MLContextImpl.call_destroy(state);
    }

    pub fn call_createConstantTensor(instance: *runtime.Instance, descriptor: anyopaque, inputData: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MLContextImpl.call_createConstantTensor(state, descriptor, inputData);
    }

};
