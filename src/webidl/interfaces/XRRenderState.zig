//! Generated from: webxr.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRRenderStateImpl = @import("impls").XRRenderState;
const boolean = @import("interfaces").boolean;
const XRWebGLLayer = @import("interfaces").XRWebGLLayer;
const FrozenArray<XRLayer> = @import("interfaces").FrozenArray<XRLayer>;
const double = @import("interfaces").double;

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
        
        // Initialize the instance (Impl receives full instance)
        XRRenderStateImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRRenderStateImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_depthNear(instance: *runtime.Instance) anyerror!f64 {
        return try XRRenderStateImpl.get_depthNear(instance);
    }

    pub fn get_depthFar(instance: *runtime.Instance) anyerror!f64 {
        return try XRRenderStateImpl.get_depthFar(instance);
    }

    pub fn get_passthroughFullyObscured(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRRenderStateImpl.get_passthroughFullyObscured(instance);
    }

    pub fn get_inlineVerticalFieldOfView(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRRenderStateImpl.get_inlineVerticalFieldOfView(instance);
    }

    pub fn get_baseLayer(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRRenderStateImpl.get_baseLayer(instance);
    }

    pub fn get_layers(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRRenderStateImpl.get_layers(instance);
    }

};
