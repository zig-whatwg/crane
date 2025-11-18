//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-18T18:28:11Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XREquirectLayerImpl = @import("impls").XREquirectLayer;
const XRCompositionLayer = @import("interfaces").XRCompositionLayer;
const XRRigidTransform = @import("interfaces").XRRigidTransform;
const EventHandler = @import("typedefs").EventHandler;
const XRSpace = @import("interfaces").XRSpace;

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
        
        // Initialize the instance (Impl receives full instance)
        XREquirectLayerImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        XREquirectLayerImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_layout(instance: *runtime.Instance) anyerror!XRLayerLayout {
        return try XREquirectLayerImpl.get_layout(instance);
    }

    pub fn get_blendTextureSourceAlpha(instance: *runtime.Instance) anyerror!bool {
        return try XREquirectLayerImpl.get_blendTextureSourceAlpha(instance);
    }

    pub fn set_blendTextureSourceAlpha(instance: *runtime.Instance, value: bool) anyerror!void {
        try XREquirectLayerImpl.set_blendTextureSourceAlpha(instance, value);
    }

    pub fn get_forceMonoPresentation(instance: *runtime.Instance) anyerror!bool {
        return try XREquirectLayerImpl.get_forceMonoPresentation(instance);
    }

    pub fn set_forceMonoPresentation(instance: *runtime.Instance, value: bool) anyerror!void {
        try XREquirectLayerImpl.set_forceMonoPresentation(instance, value);
    }

    pub fn get_opacity(instance: *runtime.Instance) anyerror!f32 {
        return try XREquirectLayerImpl.get_opacity(instance);
    }

    pub fn set_opacity(instance: *runtime.Instance, value: f32) anyerror!void {
        try XREquirectLayerImpl.set_opacity(instance, value);
    }

    pub fn get_mipLevels(instance: *runtime.Instance) anyerror!u32 {
        return try XREquirectLayerImpl.get_mipLevels(instance);
    }

    pub fn get_quality(instance: *runtime.Instance) anyerror!XRLayerQuality {
        return try XREquirectLayerImpl.get_quality(instance);
    }

    pub fn set_quality(instance: *runtime.Instance, value: XRLayerQuality) anyerror!void {
        try XREquirectLayerImpl.set_quality(instance, value);
    }

    pub fn get_needsRedraw(instance: *runtime.Instance) anyerror!bool {
        return try XREquirectLayerImpl.get_needsRedraw(instance);
    }

    pub fn get_space(instance: *runtime.Instance) anyerror!XRSpace {
        return try XREquirectLayerImpl.get_space(instance);
    }

    pub fn set_space(instance: *runtime.Instance, value: XRSpace) anyerror!void {
        try XREquirectLayerImpl.set_space(instance, value);
    }

    pub fn get_transform(instance: *runtime.Instance) anyerror!XRRigidTransform {
        return try XREquirectLayerImpl.get_transform(instance);
    }

    pub fn set_transform(instance: *runtime.Instance, value: XRRigidTransform) anyerror!void {
        try XREquirectLayerImpl.set_transform(instance, value);
    }

    pub fn get_radius(instance: *runtime.Instance) anyerror!f32 {
        return try XREquirectLayerImpl.get_radius(instance);
    }

    pub fn set_radius(instance: *runtime.Instance, value: f32) anyerror!void {
        try XREquirectLayerImpl.set_radius(instance, value);
    }

    pub fn get_centralHorizontalAngle(instance: *runtime.Instance) anyerror!f32 {
        return try XREquirectLayerImpl.get_centralHorizontalAngle(instance);
    }

    pub fn set_centralHorizontalAngle(instance: *runtime.Instance, value: f32) anyerror!void {
        try XREquirectLayerImpl.set_centralHorizontalAngle(instance, value);
    }

    pub fn get_upperVerticalAngle(instance: *runtime.Instance) anyerror!f32 {
        return try XREquirectLayerImpl.get_upperVerticalAngle(instance);
    }

    pub fn set_upperVerticalAngle(instance: *runtime.Instance, value: f32) anyerror!void {
        try XREquirectLayerImpl.set_upperVerticalAngle(instance, value);
    }

    pub fn get_lowerVerticalAngle(instance: *runtime.Instance) anyerror!f32 {
        return try XREquirectLayerImpl.get_lowerVerticalAngle(instance);
    }

    pub fn set_lowerVerticalAngle(instance: *runtime.Instance, value: f32) anyerror!void {
        try XREquirectLayerImpl.set_lowerVerticalAngle(instance, value);
    }

    pub fn get_onredraw(instance: *runtime.Instance) anyerror!EventHandler {
        return try XREquirectLayerImpl.get_onredraw(instance);
    }

    pub fn set_onredraw(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try XREquirectLayerImpl.set_onredraw(instance, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try XREquirectLayerImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try XREquirectLayerImpl.call_when(instance, type_, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyerror!void {
        return try XREquirectLayerImpl.call_destroy(instance);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XREquirectLayerImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try XREquirectLayerImpl.call_removeEventListener(instance, type_, callback, options);
    }

};
