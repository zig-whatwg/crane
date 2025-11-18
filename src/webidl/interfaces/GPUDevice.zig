//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUDeviceImpl = @import("impls").GPUDevice;
const EventTarget = @import("interfaces").EventTarget;
const GPUObjectBase = @import("interfaces").GPUObjectBase;
const Promise<GPUDeviceLostInfo> = @import("interfaces").Promise<GPUDeviceLostInfo>;
const GPUErrorFilter = @import("enums").GPUErrorFilter;
const GPURenderPipeline = @import("interfaces").GPURenderPipeline;
const GPUSamplerDescriptor = @import("dictionaries").GPUSamplerDescriptor;
const GPUSupportedFeatures = @import("interfaces").GPUSupportedFeatures;
const GPUQuerySetDescriptor = @import("dictionaries").GPUQuerySetDescriptor;
const GPUBuffer = @import("interfaces").GPUBuffer;
const GPUComputePipeline = @import("interfaces").GPUComputePipeline;
const GPUQuerySet = @import("interfaces").GPUQuerySet;
const GPURenderPipelineDescriptor = @import("dictionaries").GPURenderPipelineDescriptor;
const Promise<GPURenderPipeline> = @import("interfaces").Promise<GPURenderPipeline>;
const GPURenderBundleEncoderDescriptor = @import("dictionaries").GPURenderBundleEncoderDescriptor;
const GPUComputePipelineDescriptor = @import("dictionaries").GPUComputePipelineDescriptor;
const Promise<GPUError?> = @import("interfaces").Promise<GPUError?>;
const GPUSupportedLimits = @import("interfaces").GPUSupportedLimits;
const GPUAdapterInfo = @import("interfaces").GPUAdapterInfo;
const GPUSampler = @import("interfaces").GPUSampler;
const GPUShaderModule = @import("interfaces").GPUShaderModule;
const EventHandler = @import("typedefs").EventHandler;
const GPUBindGroupDescriptor = @import("dictionaries").GPUBindGroupDescriptor;
const Promise<GPUComputePipeline> = @import("interfaces").Promise<GPUComputePipeline>;
const GPUBufferDescriptor = @import("dictionaries").GPUBufferDescriptor;
const GPUShaderModuleDescriptor = @import("dictionaries").GPUShaderModuleDescriptor;
const GPUCommandEncoderDescriptor = @import("dictionaries").GPUCommandEncoderDescriptor;
const GPUBindGroupLayout = @import("interfaces").GPUBindGroupLayout;
const GPUBindGroup = @import("interfaces").GPUBindGroup;
const GPUCommandEncoder = @import("interfaces").GPUCommandEncoder;
const GPUTexture = @import("interfaces").GPUTexture;
const GPUTextureDescriptor = @import("dictionaries").GPUTextureDescriptor;
const GPUPipelineLayoutDescriptor = @import("dictionaries").GPUPipelineLayoutDescriptor;
const GPUExternalTexture = @import("interfaces").GPUExternalTexture;
const GPUBindGroupLayoutDescriptor = @import("dictionaries").GPUBindGroupLayoutDescriptor;
const GPUExternalTextureDescriptor = @import("dictionaries").GPUExternalTextureDescriptor;
const GPUPipelineLayout = @import("interfaces").GPUPipelineLayout;
const GPUQueue = @import("interfaces").GPUQueue;
const GPURenderBundleEncoder = @import("interfaces").GPURenderBundleEncoder;

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
        
        // Initialize the instance (Impl receives full instance)
        GPUDeviceImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUDeviceImpl.deinit(instance);
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
        const value = try GPUDeviceImpl.get_features(instance);
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
        const value = try GPUDeviceImpl.get_limits(instance);
        state.cached_limits = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_adapterInfo(instance: *runtime.Instance) anyerror!GPUAdapterInfo {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_adapterInfo) |cached| {
            return cached;
        }
        const value = try GPUDeviceImpl.get_adapterInfo(instance);
        state.cached_adapterInfo = value;
        return value;
    }

    /// Extended attributes: [SameObject]
    pub fn get_queue(instance: *runtime.Instance) anyerror!GPUQueue {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_queue) |cached| {
            return cached;
        }
        const value = try GPUDeviceImpl.get_queue(instance);
        state.cached_queue = value;
        return value;
    }

    pub fn get_lost(instance: *runtime.Instance) anyerror!anyopaque {
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

    pub fn call_createQuerySet(instance: *runtime.Instance, descriptor: GPUQuerySetDescriptor) anyerror!GPUQuerySet {
        
        return try GPUDeviceImpl.call_createQuerySet(instance, descriptor);
    }

    pub fn call_createTexture(instance: *runtime.Instance, descriptor: GPUTextureDescriptor) anyerror!GPUTexture {
        
        return try GPUDeviceImpl.call_createTexture(instance, descriptor);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try GPUDeviceImpl.call_when(instance, type_, options);
    }

    pub fn call_createRenderPipeline(instance: *runtime.Instance, descriptor: GPURenderPipelineDescriptor) anyerror!GPURenderPipeline {
        
        return try GPUDeviceImpl.call_createRenderPipeline(instance, descriptor);
    }

    pub fn call_createRenderPipelineAsync(instance: *runtime.Instance, descriptor: GPURenderPipelineDescriptor) anyerror!anyopaque {
        
        return try GPUDeviceImpl.call_createRenderPipelineAsync(instance, descriptor);
    }

    pub fn call_createPipelineLayout(instance: *runtime.Instance, descriptor: GPUPipelineLayoutDescriptor) anyerror!GPUPipelineLayout {
        
        return try GPUDeviceImpl.call_createPipelineLayout(instance, descriptor);
    }

    pub fn call_createShaderModule(instance: *runtime.Instance, descriptor: GPUShaderModuleDescriptor) anyerror!GPUShaderModule {
        
        return try GPUDeviceImpl.call_createShaderModule(instance, descriptor);
    }

    pub fn call_createCommandEncoder(instance: *runtime.Instance, descriptor: GPUCommandEncoderDescriptor) anyerror!GPUCommandEncoder {
        
        return try GPUDeviceImpl.call_createCommandEncoder(instance, descriptor);
    }

    pub fn call_createComputePipelineAsync(instance: *runtime.Instance, descriptor: GPUComputePipelineDescriptor) anyerror!anyopaque {
        
        return try GPUDeviceImpl.call_createComputePipelineAsync(instance, descriptor);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try GPUDeviceImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_createBindGroupLayout(instance: *runtime.Instance, descriptor: GPUBindGroupLayoutDescriptor) anyerror!GPUBindGroupLayout {
        
        return try GPUDeviceImpl.call_createBindGroupLayout(instance, descriptor);
    }

    pub fn call_createSampler(instance: *runtime.Instance, descriptor: GPUSamplerDescriptor) anyerror!GPUSampler {
        
        return try GPUDeviceImpl.call_createSampler(instance, descriptor);
    }

    pub fn call_importExternalTexture(instance: *runtime.Instance, descriptor: GPUExternalTextureDescriptor) anyerror!GPUExternalTexture {
        
        return try GPUDeviceImpl.call_importExternalTexture(instance, descriptor);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try GPUDeviceImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try GPUDeviceImpl.call_destroy(instance);
    }

    pub fn call_createComputePipeline(instance: *runtime.Instance, descriptor: GPUComputePipelineDescriptor) anyerror!GPUComputePipeline {
        
        return try GPUDeviceImpl.call_createComputePipeline(instance, descriptor);
    }

    pub fn call_createRenderBundleEncoder(instance: *runtime.Instance, descriptor: GPURenderBundleEncoderDescriptor) anyerror!GPURenderBundleEncoder {
        
        return try GPUDeviceImpl.call_createRenderBundleEncoder(instance, descriptor);
    }

    pub fn call_pushErrorScope(instance: *runtime.Instance, filter: GPUErrorFilter) anyerror!void {
        
        return try GPUDeviceImpl.call_pushErrorScope(instance, filter);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try GPUDeviceImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_createBuffer(instance: *runtime.Instance, descriptor: GPUBufferDescriptor) anyerror!GPUBuffer {
        
        return try GPUDeviceImpl.call_createBuffer(instance, descriptor);
    }

    pub fn call_createBindGroup(instance: *runtime.Instance, descriptor: GPUBindGroupDescriptor) anyerror!GPUBindGroup {
        
        return try GPUDeviceImpl.call_createBindGroup(instance, descriptor);
    }

    pub fn call_popErrorScope(instance: *runtime.Instance) anyerror!anyopaque {
        return try GPUDeviceImpl.call_popErrorScope(instance);
    }

};
