//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUImpl = @import("../impls/GPU.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        GPUImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    /// Extended attributes: [SameObject]
    pub fn get_wgslLanguageFeatures(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        // [SameObject] - Return cached instance
        if (state.cached_wgslLanguageFeatures) |cached| {
            return cached;
        }
        const value = GPUImpl.get_wgslLanguageFeatures(state);
        state.cached_wgslLanguageFeatures = value;
        return value;
    }

    pub fn call_requestAdapter(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUImpl.call_requestAdapter(state, options);
    }

    pub fn call_getPreferredCanvasFormat(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUImpl.call_getPreferredCanvasFormat(state);
    }

};
