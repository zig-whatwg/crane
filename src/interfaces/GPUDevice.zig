//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUDeviceImpl = @import("../impls/GPUDevice.zig");
const EventTarget = @import("EventTarget.zig");
const GPUObjectBase = @import("GPUObjectBase.zig");

pub const GPUDevice = struct {
    pub const Meta = struct {
        pub const name = "GPUDevice";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
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
            features: GPUSupportedFeatures = undefined,
            limits: GPUSupportedLimits = undefined,
            adapterInfo: GPUAdapterInfo = undefined,
            queue: GPUQueue = undefined,
            lost: Promise<GPUDeviceLostInfo> = undefined,
            onuncapturederror: EventHandler = undefined,
            label: runtime.USVString = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUDevice, .{
        .deinit_fn = &deinit_wrapper,

        .get_adapterInfo = &get_adapterInfo,
        .get_features = &get_features,
        .get_label = &get_label,
        .get_limits = &get_limits,
        .get_lost = &get_lost,
        .get_onuncapturederror = &get_onuncapturederror,
        .get_queue = &get_queue,

        .set_label = &set_label,
        .set_onuncapturederror = &set_onuncapturederror,

        .call_addEventListener = &call_addEventListener,
        .call_createBindGroup = &call_createBindGroup,
        .call_createBindGroupLayout = &call_createBindGroupLayout,
        .call_createBuffer = &call_createBuffer,
        .call_createCommandEncoder = &call_createCommandEncoder,
        .call_createComputePipeline = &call_createComputePipeline,
        .call_createComputePipelineAsync = &call_createComputePipelineAsync,
        .call_createPipelineLayout = &call_createPipelineLayout,
        .call_createQuerySet = &call_createQuerySet,
        .call_createRenderBundleEncoder = &call_createRenderBundleEncoder,
        .call_createRenderPipeline = &call_createRenderPipeline,
        .call_createRenderPipelineAsync = &call_createRenderPipelineAsync,
        .call_createSampler = &call_createSampler,
        .call_createShaderModule = &call_createShaderModule,
        .call_createTexture = &call_createTexture,
        .call_destroy = &call_destroy,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_importExternalTexture = &call_importExternalTexture,
        .call_popErrorScope = &call_popErrorScope,
        .call_pushErrorScope = &call_pushErrorScope,
        .call_removeEventListener = &call_removeEventListener,
        .call_when = &call_when,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        GPUDeviceImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUDeviceImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_features(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_features) |cached| {
            return cached;
        }
        const value = GPUDeviceImpl.get_features(state);
        state.cached_features = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_limits(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_limits) |cached| {
            return cached;
        }
        const value = GPUDeviceImpl.get_limits(state);
        state.cached_limits = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_adapterInfo(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_adapterInfo) |cached| {
            return cached;
        }
        const value = GPUDeviceImpl.get_adapterInfo(state);
        state.cached_adapterInfo = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_queue(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_queue) |cached| {
            return cached;
        }
        const value = GPUDeviceImpl.get_queue(state);
        state.cached_queue = value;
        return value;
    }

    pub fn get_lost(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUDeviceImpl.get_lost(state);
    }

    pub fn get_onuncapturederror(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUDeviceImpl.get_onuncapturederror(state);
    }

    pub fn set_onuncapturederror(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        GPUDeviceImpl.set_onuncapturederror(state, value);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.USVString {
        const state = instance.getState(State);
        return GPUDeviceImpl.get_label(state);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) void {
        const state = instance.getState(State);
        GPUDeviceImpl.set_label(state, value);
    }

    pub fn call_createQuerySet(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createQuerySet(state, descriptor);
    }

    pub fn call_createTexture(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createTexture(state, descriptor);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_when(state, type_, options);
    }

    pub fn call_createRenderPipeline(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createRenderPipeline(state, descriptor);
    }

    pub fn call_createRenderPipelineAsync(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createRenderPipelineAsync(state, descriptor);
    }

    pub fn call_createPipelineLayout(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createPipelineLayout(state, descriptor);
    }

    pub fn call_createShaderModule(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createShaderModule(state, descriptor);
    }

    pub fn call_createCommandEncoder(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createCommandEncoder(state, descriptor);
    }

    pub fn call_createComputePipelineAsync(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createComputePipelineAsync(state, descriptor);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_createBindGroupLayout(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createBindGroupLayout(state, descriptor);
    }

    pub fn call_createSampler(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createSampler(state, descriptor);
    }

    pub fn call_importExternalTexture(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_importExternalTexture(state, descriptor);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUDeviceImpl.call_destroy(state);
    }

    pub fn call_createComputePipeline(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createComputePipeline(state, descriptor);
    }

    pub fn call_createRenderBundleEncoder(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createRenderBundleEncoder(state, descriptor);
    }

    pub fn call_pushErrorScope(instance: *runtime.Instance, filter: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_pushErrorScope(state, filter);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_dispatchEvent(state, event);
    }

    pub fn call_createBuffer(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createBuffer(state, descriptor);
    }

    pub fn call_createBindGroup(instance: *runtime.Instance, descriptor: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUDeviceImpl.call_createBindGroup(state, descriptor);
    }

    pub fn call_popErrorScope(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUDeviceImpl.call_popErrorScope(state);
    }

};
