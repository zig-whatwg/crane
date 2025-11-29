//! Generated from: webnn.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const MLContextImpl = @import("impls").MLContext;
const mixins = @import("mixins");
const MLTensor = @import("interfaces").MLTensor;
const AllowSharedBufferSource = @import("typedefs").AllowSharedBufferSource;
const MLNamedTensors = @import("typedefs").MLNamedTensors;
const MLOpSupportLimits = @import("dictionaries").MLOpSupportLimits;
const MLTensorDescriptor = @import("dictionaries").MLTensorDescriptor;
const MLGraph = @import("interfaces").MLGraph;
const MLOperandDescriptor = @import("dictionaries").MLOperandDescriptor;
const MLContextLostInfo = @import("dictionaries").MLContextLostInfo;

pub const MLContext = struct {
    pub const Meta = struct {
        pub const name = "MLContext";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "Worker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .Worker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "accelerated", "get_accelerated", null },
            .{ "lost", "get_lost", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "dispatch", "call_dispatch", 3 },
            .{ "createTensor", "call_createTensor", 1 },
            .{ "createConstantTensor", "call_createConstantTensor", 2 },
            .{ "readTensor", "call_readTensor", 1 },
            .{ "readTensor", "call_readTensor", 2 },
            .{ "writeTensor", "call_writeTensor", 2 },
            .{ "opSupportLimits", "call_opSupportLimits", 0 },
            .{ "destroy", "call_destroy", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "dispatch",
            "createTensor",
            "createConstantTensor",
            "readTensor",
            "readTensor",
            "writeTensor",
            "opSupportLimits",
            "destroy",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "accelerated", "get_accelerated", null },
            .{ "lost", "get_lost", null },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            accelerated: bool = undefined,
            lost: runtime.Promise(MLContextLostInfo) = undefined,
            _internal: ?*MLContextImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_accelerated = &get_accelerated,
        .get_lost = &get_lost,

        .call_createConstantTensor = &call_createConstantTensor,
        .call_createTensor = &call_createTensor,
        .call_destroy = &call_destroy,
        .call_dispatch = &call_dispatch,
        .call_opSupportLimits = &call_opSupportLimits,
        .call_readTensor = &call_readTensor,
        .call_writeTensor = &call_writeTensor,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MLContextImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MLContextImpl.deinit(instance);
    }

    pub fn get_accelerated(instance: *runtime.Instance) anyerror!bool {
        return try MLContextImpl.get_accelerated(instance);
    }

    pub fn get_lost(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MLContextImpl.get_lost(instance);
    }

    pub fn call_dispatch(instance: *runtime.Instance, graph: *runtime.Instance, inputs: MLNamedTensors, outputs: MLNamedTensors) anyerror!void {
        
        return try MLContextImpl.call_dispatch(instance, graph, inputs, outputs);
    }

    pub fn call_opSupportLimits(instance: *runtime.Instance) anyerror!MLOpSupportLimits {
        return try MLContextImpl.call_opSupportLimits(instance);
    }

    pub fn call_writeTensor(instance: *runtime.Instance, tensor: *runtime.Instance, inputData: AllowSharedBufferSource) anyerror!void {
        
        return try MLContextImpl.call_writeTensor(instance, tensor, inputData);
    }

    pub fn call_readTensor(instance: *runtime.Instance, tensor: *runtime.Instance) anyerror!*const anyopaque {
        
        return try MLContextImpl.call_readTensor(instance, tensor);
    }

    pub fn call_createTensor(instance: *runtime.Instance, descriptor: MLTensorDescriptor) anyerror!*const anyopaque {
        
        return try MLContextImpl.call_createTensor(instance, descriptor);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try MLContextImpl.call_destroy(instance);
    }

    pub fn call_createConstantTensor(instance: *runtime.Instance, descriptor: MLOperandDescriptor, inputData: AllowSharedBufferSource) anyerror!*const anyopaque {
        
        return try MLContextImpl.call_createConstantTensor(instance, descriptor, inputData);
    }

};
