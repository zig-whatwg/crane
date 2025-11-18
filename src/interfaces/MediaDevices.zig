//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-17T19:56:10Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaDevicesImpl = @import("../impls/MediaDevices.zig");
const EventTarget = @import("EventTarget.zig");

pub const MediaDevices = struct {
    pub const Meta = struct {
        pub const name = "MediaDevices";
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = .{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
    };

    pub const State = runtime.FlattenedState(
        struct {
            ondevicechange: EventHandler = undefined,
            oncaptureaction: EventHandler = undefined,
        },
        Meta.BaseType,
        Meta.MixinTypes,
    );

    pub const vtable = runtime.buildVTable(MediaDevices, .{
        .deinit_fn = &deinit_wrapper,

        .get_oncaptureaction = &get_oncaptureaction,
        .get_ondevicechange = &get_ondevicechange,

        .set_oncaptureaction = &set_oncaptureaction,
        .set_ondevicechange = &set_ondevicechange,

        .call_addEventListener = &call_addEventListener,
        .call_dispatchEvent = &call_dispatchEvent,
        .call_enumerateDevices = &call_enumerateDevices,
        .call_getDisplayMedia = &call_getDisplayMedia,
        .call_getSupportedConstraints = &call_getSupportedConstraints,
        .call_getUserMedia = &call_getUserMedia,
        .call_getViewportMedia = &call_getViewportMedia,
        .call_removeEventListener = &call_removeEventListener,
        .call_selectAudioOutput = &call_selectAudioOutput,
        .call_setCaptureHandleConfig = &call_setCaptureHandleConfig,
        .call_setSupportedCaptureActions = &call_setSupportedCaptureActions,
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
        MediaDevicesImpl.init(state);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        const state = instance.getState(State);
        MediaDevicesImpl.deinit(state);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_ondevicechange(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaDevicesImpl.get_ondevicechange(state);
    }

    pub fn set_ondevicechange(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaDevicesImpl.set_ondevicechange(state, value);
    }

    pub fn get_oncaptureaction(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaDevicesImpl.get_oncaptureaction(state);
    }

    pub fn set_oncaptureaction(instance: *runtime.Instance, value: anyopaque) void {
        const state = instance.getState(State);
        MediaDevicesImpl.set_oncaptureaction(state, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_removeEventListener(state, type_, callback, options);
    }

    pub fn call_setSupportedCaptureActions(instance: *runtime.Instance, actions: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_setSupportedCaptureActions(state, actions);
    }

    pub fn call_getDisplayMedia(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_getDisplayMedia(state, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: runtime.DOMString, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_when(state, type_, options);
    }

    pub fn call_setCaptureHandleConfig(instance: *runtime.Instance, config: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_setCaptureHandleConfig(state, config);
    }

    pub fn call_getUserMedia(instance: *runtime.Instance, constraints: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_getUserMedia(state, constraints);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: anyopaque) bool {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_dispatchEvent(state, event);
    }

    pub fn call_enumerateDevices(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaDevicesImpl.call_enumerateDevices(state);
    }

    pub fn call_getSupportedConstraints(instance: *runtime.Instance) anyopaque {
        const state = instance.getState(State);
        return MediaDevicesImpl.call_getSupportedConstraints(state);
    }

    pub fn call_getViewportMedia(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_getViewportMedia(state, options);
    }

    pub fn call_selectAudioOutput(instance: *runtime.Instance, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_selectAudioOutput(state, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: runtime.DOMString, callback: anyopaque, options: anyopaque) anyopaque {
        const state = instance.getState(State);
        
        return MediaDevicesImpl.call_addEventListener(state, type_, callback, options);
    }

};
