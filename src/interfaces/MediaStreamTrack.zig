//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaStreamTrackImpl = @import("../impls/MediaStreamTrack.zig");
const EventTarget = @import("EventTarget.zig");

pub const MediaStreamTrack = struct {
    pub const Meta = struct {
        pub const name = "MediaStreamTrack";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            kind: runtime.DOMString = undefined,
            id: runtime.DOMString = undefined,
            label: runtime.DOMString = undefined,
            enabled: bool = undefined,
            muted: bool = undefined,
            onmute: EventHandler = undefined,
            onunmute: EventHandler = undefined,
            readyState: MediaStreamTrackState = undefined,
            onended: EventHandler = undefined,
            contentHint: runtime.DOMString = undefined,
            oncapturehandlechange: EventHandler = undefined,
            isolated: bool = undefined,
            onisolationchange: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaStreamTrack, .{
        .deinit_fn = &deinit_wrapper,

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
        MediaStreamTrackImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaStreamTrackImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_kind(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_id(state);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_label(state);
    }

    pub fn get_enabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_enabled(state);
    }

    pub fn set_enabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        MediaStreamTrackImpl.set_enabled(state, value);
    }

    pub fn get_muted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_muted(state);
    }

    pub fn get_onmute(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_onmute(state);
    }

    pub fn set_onmute(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaStreamTrackImpl.set_onmute(state, value);
    }

    pub fn get_onunmute(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_onunmute(state);
    }

    pub fn set_onunmute(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaStreamTrackImpl.set_onunmute(state, value);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_readyState(state);
    }

    pub fn get_onended(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_onended(state);
    }

    pub fn set_onended(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaStreamTrackImpl.set_onended(state, value);
    }

    pub fn get_contentHint(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_contentHint(state);
    }

    pub fn set_contentHint(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        MediaStreamTrackImpl.set_contentHint(state, value);
    }

    pub fn get_oncapturehandlechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_oncapturehandlechange(state);
    }

    pub fn set_oncapturehandlechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaStreamTrackImpl.set_oncapturehandlechange(state, value);
    }

    pub fn get_isolated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_isolated(state);
    }

    pub fn get_onisolationchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.get_onisolationchange(state);
    }

    pub fn set_onisolationchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaStreamTrackImpl.set_onisolationchange(state, value);
    }

    pub fn call_clone(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.call_clone(state);
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.call_stop(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamTrackImpl.call_when(state, type_, options);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.call_getCapabilities(state);
    }

    pub fn call_sendCaptureAction(instance: *runtime.Instance, action: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamTrackImpl.call_sendCaptureAction(state, action);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamTrackImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_applyConstraints(instance: *runtime.Instance, constraints: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamTrackImpl.call_applyConstraints(state, constraints);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaStreamTrackImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_getCaptureHandle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.call_getCaptureHandle(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return MediaStreamTrackImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getConstraints(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.call_getConstraints(state);
    }

    pub fn call_getSettings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.call_getSettings(state);
    }

    pub fn call_getSupportedCaptureActions(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaStreamTrackImpl.call_getSupportedCaptureActions(state);
    }

};
