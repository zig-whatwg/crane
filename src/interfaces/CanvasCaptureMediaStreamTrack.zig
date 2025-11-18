//! Generated from: mediacapture-fromelement.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const CanvasCaptureMediaStreamTrackImpl = @import("../impls/CanvasCaptureMediaStreamTrack.zig");
const MediaStreamTrack = @import("MediaStreamTrack.zig");

pub const CanvasCaptureMediaStreamTrack = struct {
    pub const Meta = struct {
        pub const name = "CanvasCaptureMediaStreamTrack";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MediaStreamTrack;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            canvas: HTMLCanvasElement = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(CanvasCaptureMediaStreamTrack, .{
        .deinit_fn = &deinit_wrapper,

        .get_canvas = &get_canvas,
        .get_contentHint = &get_contentHint,
        .get_enabled = &get_enabled,
        .get_id = &get_id,
        .get_isolated = &get_isolated,
        .get_kind = &get_kind,
        .get_label = &get_label,
        .get_muted = &get_muted,
        .get_oncapturehandlechange = &get_oncapturehandlechange,
        .get_onended = &get_onended,
        .get_onisolationchange = &get_onisolationchange,
        .get_onmute = &get_onmute,
        .get_onunmute = &get_onunmute,
        .get_readyState = &get_readyState,

        .set_contentHint = &set_contentHint,
        .set_enabled = &set_enabled,
        .set_oncapturehandlechange = &set_oncapturehandlechange,
        .set_onended = &set_onended,
        .set_onisolationchange = &set_onisolationchange,
        .set_onmute = &set_onmute,
        .set_onunmute = &set_onunmute,

        .call_addEventListener = &call_addEventListener,
        .call_applyConstraints = &call_applyConstraints,
        .call_clone = &call_clone,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getCapabilities = &call_getCapabilities,
        .call_getCaptureHandle = &call_getCaptureHandle,
        .call_getConstraints = &call_getConstraints,
        .call_getSettings = &call_getSettings,
        .call_getSupportedCaptureActions = &call_getSupportedCaptureActions,
        .call_removeEventListener = &call_removeEventListener,
        .call_requestFrame = &call_requestFrame,
        .call_sendCaptureAction = &call_sendCaptureAction,
        .call_stop = &call_stop,
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
        CanvasCaptureMediaStreamTrackImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        CanvasCaptureMediaStreamTrackImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_kind(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_id(state);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_label(state);
    }

    pub fn get_enabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_enabled(state);
    }

    pub fn set_enabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        CanvasCaptureMediaStreamTrackImpl.set_enabled(state, value);
    }

    pub fn get_muted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_muted(state);
    }

    pub fn get_onmute(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_onmute(state);
    }

    pub fn set_onmute(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasCaptureMediaStreamTrackImpl.set_onmute(state, value);
    }

    pub fn get_onunmute(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_onunmute(state);
    }

    pub fn set_onunmute(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasCaptureMediaStreamTrackImpl.set_onunmute(state, value);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_readyState(state);
    }

    pub fn get_onended(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_onended(state);
    }

    pub fn set_onended(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasCaptureMediaStreamTrackImpl.set_onended(state, value);
    }

    pub fn get_contentHint(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_contentHint(state);
    }

    pub fn set_contentHint(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        CanvasCaptureMediaStreamTrackImpl.set_contentHint(state, value);
    }

    pub fn get_oncapturehandlechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_oncapturehandlechange(state);
    }

    pub fn set_oncapturehandlechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasCaptureMediaStreamTrackImpl.set_oncapturehandlechange(state, value);
    }

    pub fn get_isolated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_isolated(state);
    }

    pub fn get_onisolationchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_onisolationchange(state);
    }

    pub fn set_onisolationchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        CanvasCaptureMediaStreamTrackImpl.set_onisolationchange(state, value);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.get_canvas(state);
    }

    pub fn call_clone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.call_clone(state);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.call_stop(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CanvasCaptureMediaStreamTrackImpl.call_when(state, type_, options);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.call_getCapabilities(state);
    }

    pub fn call_sendCaptureAction(instance: *runtime.Instance, action: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CanvasCaptureMediaStreamTrackImpl.call_sendCaptureAction(state, action);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CanvasCaptureMediaStreamTrackImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_applyConstraints(instance: *runtime.Instance, constraints: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CanvasCaptureMediaStreamTrackImpl.call_applyConstraints(state, constraints);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return CanvasCaptureMediaStreamTrackImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_getCaptureHandle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.call_getCaptureHandle(state);
    }

    pub fn call_requestFrame(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.call_requestFrame(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return CanvasCaptureMediaStreamTrackImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getConstraints(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.call_getConstraints(state);
    }

    pub fn call_getSettings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.call_getSettings(state);
    }

    pub fn call_getSupportedCaptureActions(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return CanvasCaptureMediaStreamTrackImpl.call_getSupportedCaptureActions(state);
    }

};
