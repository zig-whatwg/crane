//! Generated from: webxrlayers.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const XRCubeLayerImpl = @import("../impls/XRCubeLayer.zig");
const XRCompositionLayer = @import("XRCompositionLayer.zig");

pub const XRCubeLayer = struct {
    pub const Meta = struct {
        pub const name = "XRCubeLayer";
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
            orientation: DOMPointReadOnly = undefined,
            onredraw: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(XRCubeLayer, .{
        .deinit_fn = &deinit_wrapper,

        .get_blendTextureSourceAlpha = &get_blendTextureSourceAlpha,
        .get_forceMonoPresentation = &get_forceMonoPresentation,
        .get_layout = &get_layout,
        .get_mipLevels = &get_mipLevels,
        .get_needsRedraw = &get_needsRedraw,
        .get_onredraw = &get_onredraw,
        .get_opacity = &get_opacity,
        .get_orientation = &get_orientation,
        .get_quality = &get_quality,
        .get_space = &get_space,

        .set_blendTextureSourceAlpha = &set_blendTextureSourceAlpha,
        .set_forceMonoPresentation = &set_forceMonoPresentation,
        .set_onredraw = &set_onredraw,
        .set_opacity = &set_opacity,
        .set_orientation = &set_orientation,
        .set_quality = &set_quality,
        .set_space = &set_space,

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
        XRCubeLayerImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        XRCubeLayerImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_layout(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_layout(state);
    }

    pub fn get_blendTextureSourceAlpha(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_blendTextureSourceAlpha(state);
    }

    pub fn set_blendTextureSourceAlpha(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        XRCubeLayerImpl.set_blendTextureSourceAlpha(state, value);
    }

    pub fn get_forceMonoPresentation(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_forceMonoPresentation(state);
    }

    pub fn set_forceMonoPresentation(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        XRCubeLayerImpl.set_forceMonoPresentation(state, value);
    }

    pub fn get_opacity(instance: *runtime.Instance) f32 {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_opacity(state);
    }

    pub fn set_opacity(instance: *runtime.Instance, value: f32) void {
        const state = instance.getState(State);
        XRCubeLayerImpl.set_opacity(state, value);
    }

    pub fn get_mipLevels(instance: *runtime.Instance) u32 {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_mipLevels(state);
    }

    pub fn get_quality(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_quality(state);
    }

    pub fn set_quality(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRCubeLayerImpl.set_quality(state, value);
    }

    pub fn get_needsRedraw(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_needsRedraw(state);
    }

    pub fn get_space(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_space(state);
    }

    pub fn set_space(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRCubeLayerImpl.set_space(state, value);
    }

    pub fn get_orientation(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_orientation(state);
    }

    pub fn set_orientation(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRCubeLayerImpl.set_orientation(state, value);
    }

    pub fn get_onredraw(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRCubeLayerImpl.get_onredraw(state);
    }

    pub fn set_onredraw(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        XRCubeLayerImpl.set_onredraw(state, value);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return XRCubeLayerImpl.call_dispatchEvent(state, event);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRCubeLayerImpl.call_when(state, type_, options);
    }

    pub fn call_destroy(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return XRCubeLayerImpl.call_destroy(state);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRCubeLayerImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return XRCubeLayerImpl.call_removeEventListener(state, type_, callback, options);
    }

};
