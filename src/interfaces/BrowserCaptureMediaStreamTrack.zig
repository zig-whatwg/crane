//! Generated from: mediacapture-region.idl
//! Generated at: 2025-11-17T19:56:09Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BrowserCaptureMediaStreamTrackImpl = @import("../impls/BrowserCaptureMediaStreamTrack.zig");
const MediaStreamTrack = @import("MediaStreamTrack.zig");

pub const BrowserCaptureMediaStreamTrack = struct {
    pub const Meta = struct {
        pub const name = "BrowserCaptureMediaStreamTrack";
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
        struct {},
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(BrowserCaptureMediaStreamTrack, .{
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
        .call_clone = &call_clone,
        .call_cropTo = &call_cropTo,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_getCapabilities = &call_getCapabilities,
        .call_getCaptureHandle = &call_getCaptureHandle,
        .call_getConstraints = &call_getConstraints,
        .call_getSettings = &call_getSettings,
        .call_getSupportedCaptureActions = &call_getSupportedCaptureActions,
        .call_removeEventListener = &call_removeEventListener,
        .call_restrictTo = &call_restrictTo,
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
        BrowserCaptureMediaStreamTrackImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        BrowserCaptureMediaStreamTrackImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_kind(state);
    }

    pub fn get_id(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_id(state);
    }

    pub fn get_label(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_label(state);
    }

    pub fn get_enabled(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_enabled(state);
    }

    pub fn set_enabled(instance: *runtime.Instance, value: bool) void {
        const state = instance.getState(State);
        BrowserCaptureMediaStreamTrackImpl.set_enabled(state, value);
    }

    pub fn get_muted(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_muted(state);
    }

    pub fn get_onmute(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_onmute(state);
    }

    pub fn set_onmute(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BrowserCaptureMediaStreamTrackImpl.set_onmute(state, value);
    }

    pub fn get_onunmute(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_onunmute(state);
    }

    pub fn set_onunmute(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BrowserCaptureMediaStreamTrackImpl.set_onunmute(state, value);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_readyState(state);
    }

    pub fn get_onended(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_onended(state);
    }

    pub fn set_onended(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BrowserCaptureMediaStreamTrackImpl.set_onended(state, value);
    }

    pub fn get_contentHint(instance: *runtime.Instance) runtime.DOMString {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_contentHint(state);
    }

    pub fn set_contentHint(instance: *runtime.Instance, value: runtime.DOMString) void {
        const state = instance.getState(State);
        BrowserCaptureMediaStreamTrackImpl.set_contentHint(state, value);
    }

    pub fn get_oncapturehandlechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_oncapturehandlechange(state);
    }

    pub fn set_oncapturehandlechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BrowserCaptureMediaStreamTrackImpl.set_oncapturehandlechange(state, value);
    }

    pub fn get_isolated(instance: *runtime.Instance) bool {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_isolated(state);
    }

    pub fn get_onisolationchange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.get_onisolationchange(state);
    }

    pub fn set_onisolationchange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        BrowserCaptureMediaStreamTrackImpl.set_onisolationchange(state, value);
    }

    /// Arguments for clone (WebIDL overloading)
    pub const CloneArgs = union(enum) {
        /// clone()
        no_params: void,
        /// clone()
        no_params: void,
    };

    pub fn call_clone(instance: *runtime.Instance, args: CloneArgs) anyopaque {
        const state = instance.getState(State);
        switch (args) {
            .no_params => return BrowserCaptureMediaStreamTrackImpl.no_params(state),
            .no_params => return BrowserCaptureMediaStreamTrackImpl.no_params(state),
        }
    }

    pub fn call_stop(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.call_stop(state);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BrowserCaptureMediaStreamTrackImpl.call_when(state, type_, options);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.call_getCapabilities(state);
    }

    pub fn call_restrictTo(instance: *runtime.Instance, RestrictionTarget: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BrowserCaptureMediaStreamTrackImpl.call_restrictTo(state, RestrictionTarget);
    }

    pub fn call_sendCaptureAction(instance: *runtime.Instance, action: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BrowserCaptureMediaStreamTrackImpl.call_sendCaptureAction(state, action);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BrowserCaptureMediaStreamTrackImpl.call_addEventListener(state, type_, callback, options);
    }

    pub fn call_applyConstraints(instance: *runtime.Instance, constraints: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BrowserCaptureMediaStreamTrackImpl.call_applyConstraints(state, constraints);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BrowserCaptureMediaStreamTrackImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_getCaptureHandle(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.call_getCaptureHandle(state);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return BrowserCaptureMediaStreamTrackImpl.call_dispatchEvent(state, event);
    }

    pub fn call_getConstraints(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.call_getConstraints(state);
    }

    pub fn call_getSettings(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.call_getSettings(state);
    }

    pub fn call_getSupportedCaptureActions(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return BrowserCaptureMediaStreamTrackImpl.call_getSupportedCaptureActions(state);
    }

    pub fn call_cropTo(instance: *runtime.Instance, cropTarget: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return BrowserCaptureMediaStreamTrackImpl.call_cropTo(state, cropTarget);
    }

};
