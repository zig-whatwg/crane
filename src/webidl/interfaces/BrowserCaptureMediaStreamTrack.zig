//! Generated from: mediacapture-region.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BrowserCaptureMediaStreamTrackImpl = @import("impls").BrowserCaptureMediaStreamTrack;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const Promise<undefined> = @import("interfaces").Promise<undefined>;
const CropTarget = @import("interfaces").CropTarget;
const RestrictionTarget = @import("interfaces").RestrictionTarget;

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
        
        // Initialize the instance (Impl receives full instance)
        BrowserCaptureMediaStreamTrackImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BrowserCaptureMediaStreamTrackImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_kind(instance: *runtime.Instance) anyerror!DOMString {
        return try BrowserCaptureMediaStreamTrackImpl.get_kind(instance);
    }

    pub fn get_id(instance: *runtime.Instance) anyerror!DOMString {
        return try BrowserCaptureMediaStreamTrackImpl.get_id(instance);
    }

    pub fn get_label(instance: *runtime.Instance) anyerror!DOMString {
        return try BrowserCaptureMediaStreamTrackImpl.get_label(instance);
    }

    pub fn get_enabled(instance: *runtime.Instance) anyerror!bool {
        return try BrowserCaptureMediaStreamTrackImpl.get_enabled(instance);
    }

    pub fn set_enabled(instance: *runtime.Instance, value: bool) anyerror!void {
        try BrowserCaptureMediaStreamTrackImpl.set_enabled(instance, value);
    }

    pub fn get_muted(instance: *runtime.Instance) anyerror!bool {
        return try BrowserCaptureMediaStreamTrackImpl.get_muted(instance);
    }

    pub fn get_onmute(instance: *runtime.Instance) anyerror!EventHandler {
        return try BrowserCaptureMediaStreamTrackImpl.get_onmute(instance);
    }

    pub fn set_onmute(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BrowserCaptureMediaStreamTrackImpl.set_onmute(instance, value);
    }

    pub fn get_onunmute(instance: *runtime.Instance) anyerror!EventHandler {
        return try BrowserCaptureMediaStreamTrackImpl.get_onunmute(instance);
    }

    pub fn set_onunmute(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BrowserCaptureMediaStreamTrackImpl.set_onunmute(instance, value);
    }

    pub fn get_readyState(instance: *runtime.Instance) anyerror!MediaStreamTrackState {
        return try BrowserCaptureMediaStreamTrackImpl.get_readyState(instance);
    }

    pub fn get_onended(instance: *runtime.Instance) anyerror!EventHandler {
        return try BrowserCaptureMediaStreamTrackImpl.get_onended(instance);
    }

    pub fn set_onended(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BrowserCaptureMediaStreamTrackImpl.set_onended(instance, value);
    }

    pub fn get_contentHint(instance: *runtime.Instance) anyerror!DOMString {
        return try BrowserCaptureMediaStreamTrackImpl.get_contentHint(instance);
    }

    pub fn set_contentHint(instance: *runtime.Instance, value: DOMString) anyerror!void {
        try BrowserCaptureMediaStreamTrackImpl.set_contentHint(instance, value);
    }

    pub fn get_oncapturehandlechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try BrowserCaptureMediaStreamTrackImpl.get_oncapturehandlechange(instance);
    }

    pub fn set_oncapturehandlechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BrowserCaptureMediaStreamTrackImpl.set_oncapturehandlechange(instance, value);
    }

    pub fn get_isolated(instance: *runtime.Instance) anyerror!bool {
        return try BrowserCaptureMediaStreamTrackImpl.get_isolated(instance);
    }

    pub fn get_onisolationchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try BrowserCaptureMediaStreamTrackImpl.get_onisolationchange(instance);
    }

    pub fn set_onisolationchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try BrowserCaptureMediaStreamTrackImpl.set_onisolationchange(instance, value);
    }

    /// Arguments for clone (WebIDL overloading)
    pub const CloneArgs = union(enum) {
        /// clone()
        no_params: void,
        /// clone()
        no_params: void,
    };

    pub fn call_clone(instance: *runtime.Instance, args: CloneArgs) anyerror!MediaStreamTrack {
        switch (args) {
            .no_params => return try BrowserCaptureMediaStreamTrackImpl.no_params(instance),
            .no_params => return try BrowserCaptureMediaStreamTrackImpl.no_params(instance),
        }
    }

    pub fn call_stop(instance: *runtime.Instance) anyerror!void {
        return try BrowserCaptureMediaStreamTrackImpl.call_stop(instance);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_when(instance, type_, options);
    }

    pub fn call_getCapabilities(instance: *runtime.Instance) anyerror!MediaTrackCapabilities {
        return try BrowserCaptureMediaStreamTrackImpl.call_getCapabilities(instance);
    }

    pub fn call_restrictTo(instance: *runtime.Instance, RestrictionTarget: anyopaque) anyerror!anyopaque {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_restrictTo(instance, RestrictionTarget);
    }

    pub fn call_sendCaptureAction(instance: *runtime.Instance, action: CaptureAction) anyerror!anyopaque {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_sendCaptureAction(instance, action);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_addEventListener(instance, type_, callback, options);
    }

    pub fn call_applyConstraints(instance: *runtime.Instance, constraints: MediaTrackConstraints) anyerror!anyopaque {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_applyConstraints(instance, constraints);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_getCaptureHandle(instance: *runtime.Instance) anyerror!anyopaque {
        return try BrowserCaptureMediaStreamTrackImpl.call_getCaptureHandle(instance);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_getConstraints(instance: *runtime.Instance) anyerror!MediaTrackConstraints {
        return try BrowserCaptureMediaStreamTrackImpl.call_getConstraints(instance);
    }

    pub fn call_getSettings(instance: *runtime.Instance) anyerror!MediaTrackSettings {
        return try BrowserCaptureMediaStreamTrackImpl.call_getSettings(instance);
    }

    pub fn call_getSupportedCaptureActions(instance: *runtime.Instance) anyerror!anyopaque {
        return try BrowserCaptureMediaStreamTrackImpl.call_getSupportedCaptureActions(instance);
    }

    pub fn call_cropTo(instance: *runtime.Instance, cropTarget: anyopaque) anyerror!anyopaque {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_cropTo(instance, cropTarget);
    }

};
