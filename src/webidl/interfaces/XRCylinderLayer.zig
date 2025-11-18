//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRCylinderLayerImpl = @import("impls").XRCylinderLayer;
const XRCompositionLayer = @import("interfaces").XRCompositionLayer;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const EventHandler = @import("typedefs").EventHandler;
const XRSpace = @import("interfaces").XRSpace;

pub const XRCylinderLayer = struct {
    pub const Meta = struct {
        pub const name = "XRCylinderLayer";
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
            centralAngle: f32 = undefined,
            aspectRatio: f32 = undefined,
            onredraw: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRCylinderLayer, .{
        .deinit_fn = &deinit_wrapper,

        .get_aspectRatio = &get_aspectRatio,
        .get_blendTextureSourceAlpha = &get_blendTextureSourceAlpha,
        .get_centralAngle = &get_centralAngle,
        .get_forceMonoPresentation = &get_forceMonoPresentation,
        .get_layout = &get_layout,
        .get_mipLevels = &get_mipLevels,
        .get_needsRedraw = &get_needsRedraw,
        .get_onredraw = &get_onredraw,
        .get_opacity = &get_opacity,
        .get_quality = &get_quality,
        .get_radius = &get_radius,
        .get_space = &get_space,
        .get_transform = &get_transform,

        .set_aspectRatio = &set_aspectRatio,
        .set_blendTextureSourceAlpha = &set_blendTextureSourceAlpha,
        .set_centralAngle = &set_centralAngle,
        .set_forceMonoPresentation = &set_forceMonoPresentation,
        .set_onredraw = &set_onredraw,
        .set_opacity = &set_opacity,
        .set_quality = &set_quality,
        .set_radius = &set_radius,
        .set_space = &set_space,
        .set_transform = &set_transform,

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
        XRCylinderLayerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XRCylinderLayerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_layout(instance: *runtime.Instance) anyerror!XRLayerLayout {
        return try XRCylinderLayerImpl.get_layout(instance);
    }

    pub fn get_blendTextureSourceAlpha(instance: *runtime.Instance) anyerror!bool {
        return try XRCylinderLayerImpl.get_blendTextureSourceAlpha(instance);
    }

    pub fn set_blendTextureSourceAlpha(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRCylinderLayerImpl.set_blendTextureSourceAlpha(instance, value);
    }

    pub fn get_forceMonoPresentation(instance: *runtime.Instance) anyerror!bool {
        return try XRCylinderLayerImpl.get_forceMonoPresentation(instance);
    }

    pub fn set_forceMonoPresentation(instance: *runtime.Instance, value: bool) anyerror!void {
        try XRCylinderLayerImpl.set_forceMonoPresentation(instance, value);
    }

    pub fn get_opacity(instance: *runtime.Instance) anyerror!f32 {
        return try XRCylinderLayerImpl.get_opacity(instance);
    }

    pub fn set_opacity(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRCylinderLayerImpl.set_opacity(instance, value);
    }

    pub fn get_mipLevels(instance: *runtime.Instance) anyerror!u32 {
        return try XRCylinderLayerImpl.get_mipLevels(instance);
    }

    pub fn get_quality(instance: *runtime.Instance) anyerror!XRLayerQuality {
        return try XRCylinderLayerImpl.get_quality(instance);
    }

    pub fn set_quality(instance: *runtime.Instance, value: XRLayerQuality) anyerror!void {
        try XRCylinderLayerImpl.set_quality(instance, value);
    }

    pub fn get_needsRedraw(instance: *runtime.Instance) anyerror!bool {
        return try XRCylinderLayerImpl.get_needsRedraw(instance);
    }

    pub fn get_space(instance: *runtime.Instance) anyerror!XRSpace {
        return try XRCylinderLayerImpl.get_space(instance);
    }

    pub fn set_space(instance: *runtime.Instance, value: XRSpace) anyerror!void {
        try XRCylinderLayerImpl.set_space(instance, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!XRRigidTransform {
        return try XRCylinderLayerImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: XRRigidTransform) anyerror!void {
        try XRCylinderLayerImpl.set_transform(instance, value);
    }

    pub fn get_radius(instance: *runtime.Instance) anyerror!f32 {
        return try XRCylinderLayerImpl.get_radius(instance);
    }

    pub fn set_radius(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRCylinderLayerImpl.set_radius(instance, value);
    }

    pub fn get_centralAngle(instance: *runtime.Instance) anyerror!f32 {
        return try XRCylinderLayerImpl.get_centralAngle(instance);
    }

    pub fn set_centralAngle(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRCylinderLayerImpl.set_centralAngle(instance, value);
    }

    pub fn get_aspectRatio(instance: *runtime.Instance) anyerror!f32 {
        return try XRCylinderLayerImpl.get_aspectRatio(instance);
    }

    pub fn set_aspectRatio(instance: *runtime.Instance, value: f32) anyerror!void {
        try XRCylinderLayerImpl.set_aspectRatio(instance, value);
    }

    pub fn get_onredraw(instance: *runtime.Instance) anyerror!EventHandler {
        return try XRCylinderLayerImpl.get_onredraw(instance);
    }

    pub fn set_onredraw(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XRCylinderLayerImpl.set_onredraw(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XRCylinderLayerImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XRCylinderLayerImpl.call_when(instance, type_, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try XRCylinderLayerImpl.call_destroy(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRCylinderLayerImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XRCylinderLayerImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
