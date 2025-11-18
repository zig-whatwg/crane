//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRProjectionLayerImpl = @import("impls").XRProjectionLayer;
const XRCompositionLayer = @import("interfaces").XRCompositionLayer;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const float = @import("interfaces").float;

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
        
        // Initialize the instance (Impl receives full instance)
        XRProjectionLayerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRProjectionLayerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_layout(instance: *runtime.Instance) anyerror!XRLayerLayout {
        return try XRProjectionLayerImpl.get_layout(instance);
    }

    pub fn get_blendTextureSourceAlpha(instance: *runtime.Instance) anyerror!bool {
        return try XRProjectionLayerImpl.get_blendTextureSourceAlpha(instance);
    }

    pub fn set_blendTextureSourceAlpha(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRProjectionLayerImpl.set_blendTextureSourceAlpha(instance, value);
    }

    pub fn get_forceMonoPresentation(instance: *runtime.Instance) anyerror!bool {
        return try XRProjectionLayerImpl.get_forceMonoPresentation(instance);
    }

    pub fn set_forceMonoPresentation(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRProjectionLayerImpl.set_forceMonoPresentation(instance, value);
    }

    pub fn get_opacity(instance: *runtime.Instance) anyerror!f32 {
        return try XRProjectionLayerImpl.get_opacity(instance);
    }

    pub fn set_opacity(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRProjectionLayerImpl.set_opacity(instance, value);
    }

    pub fn get_mipLevels(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_mipLevels(instance);
    }

    pub fn get_quality(instance: *runtime.Instance) anyerror!XRLayerQuality {
        return try XRProjectionLayerImpl.get_quality(instance);
    }

    pub fn set_quality(instance: *runtime.Instance, value: XRLayerQuality) anyerror!void {
        try XRProjectionLayerImpl.set_quality(instance, value);
    }

    pub fn get_needsRedraw(instance: *runtime.Instance) anyerror!bool {
        return try XRProjectionLayerImpl.get_needsRedraw(instance);
    }

    pub fn get_textureWidth(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_textureWidth(instance);
    }

    pub fn get_textureHeight(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_textureHeight(instance);
    }

    pub fn get_textureArrayLength(instance: *runtime.Instance) anyerror!u32 {
        return try XRProjectionLayerImpl.get_textureArrayLength(instance);
    }

    pub fn get_ignoreDepthValues(instance: *runtime.Instance) anyerror!bool {
        return try XRProjectionLayerImpl.get_ignoreDepthValues(instance);
    }

    pub fn get_fixedFoveation(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRProjectionLayerImpl.get_fixedFoveation(instance);
    }

    pub fn set_fixedFoveation(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try XRProjectionLayerImpl.set_fixedFoveation(instance, value);
    }

    pub fn get_deltaPose(instance: *runtime.Instance) anyerror!anyopaque {
        return try XRProjectionLayerImpl.get_deltaPose(instance);
    }

    pub fn set_deltaPose(instance: *runtime.Instance, value: anyopaque) anyerror!void {
        try XRProjectionLayerImpl.set_deltaPose(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XRProjectionLayerImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XRProjectionLayerImpl.call_when(instance, type_, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try XRProjectionLayerImpl.call_destroy(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRProjectionLayerImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRProjectionLayerImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
