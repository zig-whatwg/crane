//! Generated from: webxr.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRRenderStateImpl = @import("../impls/XRRenderState.zig");

pub const XRRenderState = struct {
    pub const Meta = struct {
        pub const name = "XRRenderState";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = ?*anyopaque;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            depthNear: f64 = undefined,
            depthFar: f64 = undefined,
            passthroughFullyObscured: ?bool = null,
            inlineVerticalFieldOfView: ?f64 = null,
            baseLayer: ?XRWebGLLayer = null,
            layers: FrozenArray<XRLayer> = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRRenderState, .{
        .deinit_fn = &deinit_wrapper,

        .get_baseLayer = &get_baseLayer,
        .get_depthFar = &get_depthFar,
        .get_depthNear = &get_depthNear,
        .get_inlineVerticalFieldOfView = &get_inlineVerticalFieldOfView,
        .get_layers = &get_layers,
        .get_passthroughFullyObscured = &get_passthroughFullyObscured,
    });

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator) !*runtime.Instance {
        _ = allocator;
        const instance = try runtime.SlabAllocator.get().alloc(&vtable);
        errdefer runtime.SlabAllocator.get().free(instance);
        
        const state = try runtime.ArenaAllocator.get().create(State);
        instance.state = state;
        
        // Initialize the state (Impl receives full hierarchy)
        XRRenderStateImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRRenderStateImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_depthNear(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return XRRenderStateImpl.get_depthNear(state);
    }

    pub fn get_depthFar(instance: *runtime.Instance) f64 {
        const state = instance.getState(State);
        return XRRenderStateImpl.get_depthFar(state);
    }

    pub fn get_passthroughFullyObscured(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRRenderStateImpl.get_passthroughFullyObscured(state);
    }

    pub fn get_inlineVerticalFieldOfView(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRRenderStateImpl.get_inlineVerticalFieldOfView(state);
    }

    pub fn get_baseLayer(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRRenderStateImpl.get_baseLayer(state);
    }

    pub fn get_layers(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRRenderStateImpl.get_layers(state);
    }

};
