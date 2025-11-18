//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRProjectionLayerImpl = @import("../impls/XRProjectionLayer.zig");
const XRCompositionLayer = @import("XRCompositionLayer.zig");

pub const XRProjectionLayer = struct {
    pub const Meta = struct {
        pub const name = "XRProjectionLayer";
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
            textureWidth: u32 = undefined,
            textureHeight: u32 = undefined,
            textureArrayLength: u32 = undefined,
            ignoreDepthValues: bool = undefined,
            fixedFoveation: ?f32 = null,
            deltaPose: ?XRRigidTransform = null,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRProjectionLayer, .{
        .deinit_fn = &deinit_wrapper,

        .get_blendTextureSourceAlpha = &get_blendTextureSourceAlpha,
        .get_deltaPose = &get_deltaPose,
        .get_fixedFoveation = &get_fixedFoveation,
        .get_forceMonoPresentation = &get_forceMonoPresentation,
        .get_ignoreDepthValues = &get_ignoreDepthValues,
        .get_layout = &get_layout,
        .get_mipLevels = &get_mipLevels,
        .get_needsRedraw = &get_needsRedraw,
        .get_opacity = &get_opacity,
        .get_quality = &get_quality,
        .get_textureArrayLength = &get_textureArrayLength,
        .get_textureHeight = &get_textureHeight,
        .get_textureWidth = &get_textureWidth,

        .set_blendTextureSourceAlpha = &set_blendTextureSourceAlpha,
        .set_deltaPose = &set_deltaPose,
        .set_fixedFoveation = &set_fixedFoveation,
        .set_forceMonoPresentation = &set_forceMonoPresentation,
        .set_opacity = &set_opacity,
        .set_quality = &set_quality,

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
        XRProjectionLayerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRProjectionLayerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_layout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_layout(state);
    }

    pub fn get_blendTextureSourceAlpha(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_blendTextureSourceAlpha(state);
    }

    pub fn set_blendTextureSourceAlpha(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        XRProjectionLayerImpl.set_blendTextureSourceAlpha(state, value);
    }

    pub fn get_forceMonoPresentation(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_forceMonoPresentation(state);
    }

    pub fn set_forceMonoPresentation(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        XRProjectionLayerImpl.set_forceMonoPresentation(state, value);
    }

    pub fn get_opacity(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_opacity(state);
    }

    pub fn set_opacity(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        XRProjectionLayerImpl.set_opacity(state, value);
    }

    pub fn get_mipLevels(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_mipLevels(state);
    }

    pub fn get_quality(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_quality(state);
    }

    pub fn set_quality(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRProjectionLayerImpl.set_quality(state, value);
    }

    pub fn get_needsRedraw(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_needsRedraw(state);
    }

    pub fn get_textureWidth(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_textureWidth(state);
    }

    pub fn get_textureHeight(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_textureHeight(state);
    }

    pub fn get_textureArrayLength(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_textureArrayLength(state);
    }

    pub fn get_ignoreDepthValues(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_ignoreDepthValues(state);
    }

    pub fn get_fixedFoveation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_fixedFoveation(state);
    }

    pub fn set_fixedFoveation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRProjectionLayerImpl.set_fixedFoveation(state, value);
    }

    pub fn get_deltaPose(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.get_deltaPose(state);
    }

    pub fn set_deltaPose(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRProjectionLayerImpl.set_deltaPose(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XRProjectionLayerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRProjectionLayerImpl.call_when(state, type_, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRProjectionLayerImpl.call_destroy(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRProjectionLayerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRProjectionLayerImpl.call_removeEventListener(state, type_, callback, options);
    }

};
