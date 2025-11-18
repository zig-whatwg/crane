//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XREquirectLayerImpl = @import("../impls/XREquirectLayer.zig");
const XRCompositionLayer = @import("XRCompositionLayer.zig");

pub const XREquirectLayer = struct {
    pub const Meta = struct {
        pub const name = "XREquirectLayer";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *XRCompositionLayer;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            space: XRSpace = undefined,
            transform: XRRigidTransform = undefined,
            radius: f32 = undefined,
            centralHorizontalAngle: f32 = undefined,
            upperVerticalAngle: f32 = undefined,
            lowerVerticalAngle: f32 = undefined,
            onredraw: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XREquirectLayer, .{
        .deinit_fn = &deinit_wrapper,

        .get_blendTextureSourceAlpha = &get_blendTextureSourceAlpha,
        .get_centralHorizontalAngle = &get_centralHorizontalAngle,
        .get_forceMonoPresentation = &get_forceMonoPresentation,
        .get_layout = &get_layout,
        .get_lowerVerticalAngle = &get_lowerVerticalAngle,
        .get_mipLevels = &get_mipLevels,
        .get_needsRedraw = &get_needsRedraw,
        .get_onredraw = &get_onredraw,
        .get_opacity = &get_opacity,
        .get_quality = &get_quality,
        .get_radius = &get_radius,
        .get_space = &get_space,
        .get_transform = &get_transform,
        .get_upperVerticalAngle = &get_upperVerticalAngle,

        .set_blendTextureSourceAlpha = &set_blendTextureSourceAlpha,
        .set_centralHorizontalAngle = &set_centralHorizontalAngle,
        .set_forceMonoPresentation = &set_forceMonoPresentation,
        .set_lowerVerticalAngle = &set_lowerVerticalAngle,
        .set_onredraw = &set_onredraw,
        .set_opacity = &set_opacity,
        .set_quality = &set_quality,
        .set_radius = &set_radius,
        .set_space = &set_space,
        .set_transform = &set_transform,
        .set_upperVerticalAngle = &set_upperVerticalAngle,

        .call_addEventListener = &call_addEventListener,
        .call_destroy = &call_destroy,
        .call_dispatchEvent = &call_dispatchEvent,
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
        XREquirectLayerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_layout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_layout(state);
    }

    pub fn get_blendTextureSourceAlpha(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_blendTextureSourceAlpha(state);
    }

    pub fn set_blendTextureSourceAlpha(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_blendTextureSourceAlpha(state, value);
    }

    pub fn get_forceMonoPresentation(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_forceMonoPresentation(state);
    }

    pub fn set_forceMonoPresentation(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_forceMonoPresentation(state, value);
    }

    pub fn get_opacity(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_opacity(state);
    }

    pub fn set_opacity(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_opacity(state, value);
    }

    pub fn get_mipLevels(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_mipLevels(state);
    }

    pub fn get_quality(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_quality(state);
    }

    pub fn set_quality(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_quality(state, value);
    }

    pub fn get_needsRedraw(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_needsRedraw(state);
    }

    pub fn get_space(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_space(state);
    }

    pub fn set_space(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_space(state, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_transform(state);
    }

    pub fn set_transform(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_transform(state, value);
    }

    pub fn get_radius(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_radius(state);
    }

    pub fn set_radius(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_radius(state, value);
    }

    pub fn get_centralHorizontalAngle(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_centralHorizontalAngle(state);
    }

    pub fn set_centralHorizontalAngle(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_centralHorizontalAngle(state, value);
    }

    pub fn get_upperVerticalAngle(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_upperVerticalAngle(state);
    }

    pub fn set_upperVerticalAngle(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_upperVerticalAngle(state, value);
    }

    pub fn get_lowerVerticalAngle(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_lowerVerticalAngle(state);
    }

    pub fn set_lowerVerticalAngle(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_lowerVerticalAngle(state, value);
    }

    pub fn get_onredraw(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XREquirectLayerImpl.get_onredraw(state);
    }

    pub fn set_onredraw(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XREquirectLayerImpl.set_onredraw(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XREquirectLayerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XREquirectLayerImpl.call_when(state, type_, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XREquirectLayerImpl.call_destroy(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XREquirectLayerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XREquirectLayerImpl.call_removeEventListener(state, type_, callback, options);
    }

};
