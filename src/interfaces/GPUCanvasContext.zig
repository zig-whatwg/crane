//! Generated from: webgpu.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const GPUCanvasContextImpl = @import("../impls/GPUCanvasContext.zig");

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
        
        // Initialize the state (Impl receives full hierarchy)
        GPUCanvasContextImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        GPUCanvasContextImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUCanvasContextImpl.get_canvas(state);
    }

    pub fn call_unconfigure(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUCanvasContextImpl.call_unconfigure(state);
    }

    pub fn call_configure(instance: *runtime.Instance, configuration: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return GPUCanvasContextImpl.call_configure(state, configuration);
    }

    pub fn call_getConfiguration(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUCanvasContextImpl.call_getConfiguration(state);
    }

    pub fn call_getCurrentTexture(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return GPUCanvasContextImpl.call_getCurrentTexture(state);
    }

};
