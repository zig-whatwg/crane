//! Generated from: webnn.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MLContextImpl = @import("impls").MLContext;
const Promise<MLTensor> = @import("interfaces").Promise<MLTensor>;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const Promise<ArrayBuffer> = @import("interfaces").Promise<ArrayBuffer>;
const MLNamedTensors = @import("typedefs").MLNamedTensors;
const MLTensor = @import("interfaces").MLTensor;
const MLOpSupportLimits = @import("dictionaries").MLOpSupportLimits;
const MLTensorDescriptor = @import("dictionaries").MLTensorDescriptor;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const MLGraph = @import("interfaces").MLGraph;
const MLOperandDescriptor = @import("dictionaries").MLOperandDescriptor;
const Promise<MLContextLostInfo> = @import("interfaces").Promise<MLContextLostInfo>;

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
        .call_writeTensor = &call_writeTensor,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        MLContextImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MLContextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_lost(instance: *runtime.Instance) anyerror!anyopaque {
        return try MLContextImpl.get_lost(instance);
    }

    pub fn call_dispatch(instance: *runtime.Instance, graph: MLGraph, inputs: MLNamedTensors, outputs: MLNamedTensors) anyerror!void {
        
        return try MLContextImpl.call_dispatch(instance, graph, inputs, outputs);
    }

    pub fn call_opSupportLimits(instance: *runtime.Instance) anyerror!MLOpSupportLimits {
        return try MLContextImpl.call_opSupportLimits(instance);
    }

    pub fn call_writeTensor(instance: *runtime.Instance, tensor: MLTensor, inputData: AllowSharedBufferSource) anyerror!void {
        
        return try MLContextImpl.call_writeTensor(instance, tensor, inputData);
    }

    /// Arguments for readTensor (WebIDL overloading)
    pub const ReadTensorArgs = union(enum) {
        /// readTensor(tensor)
        MLTensor: MLTensor,
        /// readTensor(tensor, outputData)
        MLTensor_AllowSharedBufferSource: struct {
            tensor: MLTensor,
            outputData: AllowSharedBufferSource,
        },
    };

    pub fn call_readTensor(instance: *runtime.Instance, args: ReadTensorArgs) anyerror!anyopaque {
        switch (args) {
            .MLTensor => |arg| return try MLContextImpl.MLTensor(instance, arg),
            .MLTensor_AllowSharedBufferSource => |a| return try MLContextImpl.MLTensor_AllowSharedBufferSource(instance, a.tensor, a.outputData),
        }
    }

    pub fn call_createTensor(instance: *runtime.Instance, descriptor: MLTensorDescriptor) anyerror!anyopaque {
        
        return try MLContextImpl.call_createTensor(instance, descriptor);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try MLContextImpl.call_destroy(instance);
    }

    pub fn call_createConstantTensor(instance: *runtime.Instance, descriptor: MLOperandDescriptor, inputData: AllowSharedBufferSource) anyerror!anyopaque {
        
        return try MLContextImpl.call_createConstantTensor(instance, descriptor, inputData);
    }

};
