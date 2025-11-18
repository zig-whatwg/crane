//! Generated from: webgpu.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUCanvasContextImpl = @import("impls").GPUCanvasContext;
const (HTMLCanvasElement or OffscreenCanvas) = @import("interfaces").(HTMLCanvasElement or OffscreenCanvas);
const GPUCanvasConfiguration = @import("dictionaries").GPUCanvasConfiguration;
const GPUTexture = @import("interfaces").GPUTexture;

pub const GPUCanvasContext = struct {
    pub const Meta = struct {
        pub const name = "GPUCanvasContext";
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
            canvas: (HTMLCanvasElement or OffscreenCanvas) = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(GPUCanvasContext, .{
        .deinit_fn = &deinit_wrapper,

        .get_canvas = &get_canvas,

        .call_configure = &call_configure,
        .call_getConfiguration = &call_getConfiguration,
        .call_getCurrentTexture = &call_getCurrentTexture,
        .call_unconfigure = &call_unconfigure,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the instance (Impl receives full instance)
        GPUCanvasContextImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        GPUCanvasContextImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyerror!anyopaque {
        return try GPUCanvasContextImpl.get_canvas(instance);
    }

    pub fn call_unconfigure(instance: *runtime.Instance) anyerror!void {
        return try GPUCanvasContextImpl.call_unconfigure(instance);
    }

    pub fn call_configure(instance: *runtime.Instance, configuration: GPUCanvasConfiguration) anyerror!void {
        
        return try GPUCanvasContextImpl.call_configure(instance, configuration);
    }

    pub fn call_getConfiguration(instance: *runtime.Instance) anyerror!anyopaque {
        return try GPUCanvasContextImpl.call_getConfiguration(instance);
    }

    pub fn call_getCurrentTexture(instance: *runtime.Instance) anyerror!GPUTexture {
        return try GPUCanvasContextImpl.call_getCurrentTexture(instance);
    }

};
