//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUImpl = @import("impls").GPU;
const WGSLLanguageFeatures = @import("interfaces").WGSLLanguageFeatures;
const GPURequestAdapterOptions = @import("dictionaries").GPURequestAdapterOptions;
const Promise<GPUAdapter?> = @import("interfaces").Promise<GPUAdapter?>;
const GPUTextureFormat = @import("enums").GPUTextureFormat;

pub const GPU = struct {
    pub const Meta = struct {
        pub const name = "GPU";
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
            wgslLanguageFeatures: WGSLLanguageFeatures = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPU, .{
        .deinit_fn = &deinit_wrapper,

        .get_wgslLanguageFeatures = &get_wgslLanguageFeatures,

        .call_getPreferredCanvasFormat = &call_getPreferredCanvasFormat,
        .call_requestAdapter = &call_requestAdapter,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPUImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_wgslLanguageFeatures(instance: *runtime.Instance) anyerror!WGSLLanguageFeatures {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_wgslLanguageFeatures) |cached| {
            return cached;
        }
        const value = try GPUImpl.get_wgslLanguageFeatures(instance);
        state.cached_wgslLanguageFeatures = value;
        return value;
    }

    pub fn call_requestAdapter(instance: *runtime.Instance, options: GPURequestAdapterOptions) anyerror!anyopaque {
        
        return try GPUImpl.call_requestAdapter(instance, options);
    }

    pub fn call_getPreferredCanvasFormat(instance: *runtime.Instance) anyerror!GPUTextureFormat {
        return try GPUImpl.call_getPreferredCanvasFormat(instance);
    }

};
