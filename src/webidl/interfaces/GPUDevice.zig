//! Generated from: webgpu.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const GPUDeviceImpl = @import("impls").GPUDevice;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const GPURenderBundleEncoder = @import("interfaces").GPURenderBundleEncoder;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const GPURenderPipeline = @import("interfaces").GPURenderPipeline;
const GPUSamplerDescriptor = @import("dictionaries").GPUSamplerDescriptor;
const GPUQuerySetDescriptor = @import("dictionaries").GPUQuerySetDescriptor;
const GPUSupportedFeatures = @import("interfaces").GPUSupportedFeatures;
const USVString = @import("interfaces").USVString;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUComputePipeline = @import("interfaces").GPUComputePipeline;
const GPUQuerySet = @import("interfaces").GPUQuerySet;
const GPURenderPipelineDescriptor = @import("dictionaries").GPURenderPipelineDescriptor;
const GPURenderBundleEncoderDescriptor = @import("dictionaries").GPURenderBundleEncoderDescriptor;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const GPUComputePipelineDescriptor = @import("dictionaries").GPUComputePipelineDescriptor;
const GPUDeviceLostInfo = @import("interfaces").GPUDeviceLostInfo;
const EventListener = @import("interfaces").EventListener;
const GPUSupportedLimits = @import("interfaces").GPUSupportedLimits;
const EventHandler = @import("typedefs").EventHandler;
const GPUAdapterInfo = @import("interfaces").GPUAdapterInfo;
const GPUShaderModule = @import("interfaces").GPUShaderModule;
const GPUSampler = @import("interfaces").GPUSampler;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const GPUBindGroupDescriptor = @import("dictionaries").GPUBindGroupDescriptor;
const GPUBufferDescriptor = @import("dictionaries").GPUBufferDescriptor;
const GPUShaderModuleDescriptor = @import("dictionaries").GPUShaderModuleDescriptor;
const GPUCommandEncoderDescriptor = @import("dictionaries").GPUCommandEncoderDescriptor;
const GPUError = @import("interfaces").GPUError;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const GPUBindGroupLayout = @import("interfaces").GPUBindGroupLayout;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const GPUErrorFilter = @import("enums").GPUErrorFilter;
const GPUCommandEncoder = @import("interfaces").GPUCommandEncoder;
const GPUTexture = @import("interfaces").GPUTexture;
const GPUTextureDescriptor = @import("dictionaries").GPUTextureDescriptor;
const GPUPipelineLayoutDescriptor = @import("dictionaries").GPUPipelineLayoutDescriptor;
const GPUExternalTexture = @import("interfaces").GPUExternalTexture;
const GPUBindGroupLayoutDescriptor = @import("dictionaries").GPUBindGroupLayoutDescriptor;
const GPUExternalTextureDescriptor = @import("dictionaries").GPUExternalTextureDescriptor;
const GPUPipelineLayout = @import("interfaces").GPUPipelineLayout;
const GPUQueue = @import("interfaces").GPUQueue;

pub const GPUDevice = struct {
    pub const Meta = struct {
        pub const name = "GPUDevice";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{
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
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "features", "get_features", null },
            .{ "limits", "get_limits", null },
            .{ "adapterInfo", "get_adapterInfo", null },
            .{ "queue", "get_queue", null },
            .{ "lost", "get_lost", null },
            .{ "onuncapturederror", "get_onuncapturederror", "set_onuncapturederror" },
            .{ "label", "get_label", "set_label" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "destroy", "call_destroy", 0 },
            .{ "createBuffer", "call_createBuffer", 1 },
            .{ "createTexture", "call_createTexture", 1 },
            .{ "createSampler", "call_createSampler", 0 },
            .{ "importExternalTexture", "call_importExternalTexture", 1 },
            .{ "createBindGroupLayout", "call_createBindGroupLayout", 1 },
            .{ "createPipelineLayout", "call_createPipelineLayout", 1 },
            .{ "createBindGroup", "call_createBindGroup", 1 },
            .{ "createShaderModule", "call_createShaderModule", 1 },
            .{ "createComputePipeline", "call_createComputePipeline", 1 },
            .{ "createRenderPipeline", "call_createRenderPipeline", 1 },
            .{ "createComputePipelineAsync", "call_createComputePipelineAsync", 1 },
            .{ "createRenderPipelineAsync", "call_createRenderPipelineAsync", 1 },
            .{ "createCommandEncoder", "call_createCommandEncoder", 0 },
            .{ "createRenderBundleEncoder", "call_createRenderBundleEncoder", 1 },
            .{ "createQuerySet", "call_createQuerySet", 1 },
            .{ "pushErrorScope", "call_pushErrorScope", 1 },
            .{ "popErrorScope", "call_popErrorScope", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "destroy",
            "createBuffer",
            "createTexture",
            "createSampler",
            "importExternalTexture",
            "createBindGroupLayout",
            "createPipelineLayout",
            "createBindGroup",
            "createShaderModule",
            "createComputePipeline",
            "createRenderPipeline",
            "createComputePipelineAsync",
            "createRenderPipelineAsync",
            "createCommandEncoder",
            "createRenderBundleEncoder",
            "createQuerySet",
            "pushErrorScope",
            "popErrorScope",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "features", "get_features", null },
            .{ "limits", "get_limits", null },
            .{ "adapterInfo", "get_adapterInfo", null },
            .{ "queue", "get_queue", null },
            .{ "lost", "get_lost", null },
            .{ "onuncapturederror", "get_onuncapturederror", "set_onuncapturederror" },
            .{ "label", "get_label", "set_label" },
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
            features: *runtime.Instance = undefined,
            limits: *runtime.Instance = undefined,
            adapterInfo: *runtime.Instance = undefined,
            queue: *runtime.Instance = undefined,
            lost: runtime.Promise(GPUDeviceLostInfo) = undefined,
            onuncapturederror: EventHandler = undefined,
            label: runtime.USVString = undefined,
            cached_features: ?*runtime.Instance = null,
            cached_limits: ?*runtime.Instance = null,
            cached_adapterInfo: ?*runtime.Instance = null,
            cached_queue: ?*runtime.Instance = null,
            _internal: ?*GPUDeviceImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_adapterInfo = &get_adapterInfo,
        .get_features = &get_features,
        .get_label = &get_label,
        .get_limits = &get_limits,
        .get_lost = &get_lost,
        .get_onuncapturederror = &get_onuncapturederror,
        .get_queue = &get_queue,

        .set_label = &set_label,
        .set_onuncapturederror = &set_onuncapturederror,

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
        .call_importExternalTexture = &call_importExternalTexture,
        .call_popErrorScope = &call_popErrorScope,
        .call_pushErrorScope = &call_pushErrorScope,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return GPUDeviceImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUDeviceImpl.deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_features(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_features) |cached| {
            return cached;
        }
        const value = try GPUDeviceImpl.get_features(instance);
        state.own.cached_features = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_limits(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_limits) |cached| {
            return cached;
        }
        const value = try GPUDeviceImpl.get_limits(instance);
        state.own.cached_limits = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_adapterInfo(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_adapterInfo) |cached| {
            return cached;
        }
        const value = try GPUDeviceImpl.get_adapterInfo(instance);
        state.own.cached_adapterInfo = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_queue(instance: *runtime.Instance) anyerror!*runtime.Instance {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.own.cached_queue) |cached| {
            return cached;
        }
        const value = try GPUDeviceImpl.get_queue(instance);
        state.own.cached_queue = value;
        return value;
    }

    pub fn get_lost(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GPUDeviceImpl.get_lost(instance);
    }

    pub fn get_onuncapturederror(instance: *runtime.Instance) anyerror!EventHandler {
        return try GPUDeviceImpl.get_onuncapturederror(instance);
    }

    pub fn set_onuncapturederror(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try GPUDeviceImpl.set_onuncapturederror(instance, value);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!runtime.USVString {
        return try GPUDeviceImpl.get_label(instance);
    }

    pub fn set_label(instance: *runtime.Instance, value: runtime.USVString) anyerror!void {
        try GPUDeviceImpl.set_label(instance, value);
    }

    pub fn call_createQuerySet(instance: *runtime.Instance, descriptor: GPUQuerySetDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createQuerySet(instance, descriptor);
    }

    pub fn call_createTexture(instance: *runtime.Instance, descriptor: GPUTextureDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createTexture(instance, descriptor);
    }

    pub fn call_createRenderPipeline(instance: *runtime.Instance, descriptor: GPURenderPipelineDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createRenderPipeline(instance, descriptor);
    }

    pub fn call_createRenderPipelineAsync(instance: *runtime.Instance, descriptor: GPURenderPipelineDescriptor) anyerror!*const anyopaque {
        
        return try GPUDeviceImpl.call_createRenderPipelineAsync(instance, descriptor);
    }

    pub fn call_createPipelineLayout(instance: *runtime.Instance, descriptor: GPUPipelineLayoutDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createPipelineLayout(instance, descriptor);
    }

    pub fn call_createShaderModule(instance: *runtime.Instance, descriptor: GPUShaderModuleDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createShaderModule(instance, descriptor);
    }

    pub fn call_createCommandEncoder(instance: *runtime.Instance, descriptor: webidl.Opt(GPUCommandEncoderDescriptor)) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createCommandEncoder(instance, descriptor);
    }

    pub fn call_createComputePipelineAsync(instance: *runtime.Instance, descriptor: GPUComputePipelineDescriptor) anyerror!*const anyopaque {
        
        return try GPUDeviceImpl.call_createComputePipelineAsync(instance, descriptor);
    }

    pub fn call_createBindGroupLayout(instance: *runtime.Instance, descriptor: GPUBindGroupLayoutDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createBindGroupLayout(instance, descriptor);
    }

    pub fn call_createSampler(instance: *runtime.Instance, descriptor: webidl.Opt(GPUSamplerDescriptor)) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createSampler(instance, descriptor);
    }

    pub fn call_importExternalTexture(instance: *runtime.Instance, descriptor: GPUExternalTextureDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_importExternalTexture(instance, descriptor);
    }

    pub fn call_createComputePipeline(instance: *runtime.Instance, descriptor: GPUComputePipelineDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createComputePipeline(instance, descriptor);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUDeviceImpl.call_destroy(instance);
    }

    pub fn call_createRenderBundleEncoder(instance: *runtime.Instance, descriptor: GPURenderBundleEncoderDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createRenderBundleEncoder(instance, descriptor);
    }

    pub fn call_pushErrorScope(instance: *runtime.Instance, filter: GPUErrorFilter) anyerror!void {
        
        return try GPUDeviceImpl.call_pushErrorScope(instance, filter);
    }

    pub fn call_createBuffer(instance: *runtime.Instance, descriptor: GPUBufferDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createBuffer(instance, descriptor);
    }

    pub fn call_createBindGroup(instance: *runtime.Instance, descriptor: GPUBindGroupDescriptor) anyerror!*runtime.Instance {
        
        return try GPUDeviceImpl.call_createBindGroup(instance, descriptor);
    }

    pub fn call_popErrorScope(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try GPUDeviceImpl.call_popErrorScope(instance);
    }

};
