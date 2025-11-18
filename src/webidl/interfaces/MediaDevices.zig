//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-18T18:28:12Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaDevicesImpl = @import("impls").MediaDevices;
const EventTarget = @import("interfaces").EventTarget;
const Promise<MediaStream> = @import("interfaces").Promise<MediaStream>;
const AudioOutputOptions = @import("dictionaries").AudioOutputOptions;
const CaptureHandleConfig = @import("dictionaries").CaptureHandleConfig;
const DisplayMediaStreamOptions = @import("dictionaries").DisplayMediaStreamOptions;
const MediaTrackSupportedConstraints = @import("dictionaries").MediaTrackSupportedConstraints;
const Promise<MediaDeviceInfo> = @import("interfaces").Promise<MediaDeviceInfo>;
const Promise<sequence<MediaDeviceInfo>> = @import("interfaces").Promise<sequence<MediaDeviceInfo>>;
const MediaStreamConstraints = @import("dictionaries").MediaStreamConstraints;
const EventHandler = @import("typedefs").EventHandler;

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
        
        // Initialize the instance (Impl receives full instance)
        MediaDevicesImpl.init(instance);
        
        return instance;
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaDevicesImpl.deinit(instance);
    }

    fn deinit_wrapper(state: *anyopaque) void {
        const instance = @as(*runtime.Instance, @ptrCast(@alignCast(state)));
        deinit(instance);
    }

    pub fn get_ondevicechange(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaDevicesImpl.get_ondevicechange(instance);
    }

    pub fn set_ondevicechange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaDevicesImpl.set_ondevicechange(instance, value);
    }

    pub fn get_oncaptureaction(instance: *runtime.Instance) anyerror!EventHandler {
        return try MediaDevicesImpl.get_oncaptureaction(instance);
    }

    pub fn set_oncaptureaction(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try MediaDevicesImpl.set_oncaptureaction(instance, value);
    }

    pub fn call_removeEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaDevicesImpl.call_removeEventListener(instance, type_, callback, options);
    }

    pub fn call_setSupportedCaptureActions(instance: *runtime.Instance, actions: anyopaque) anyerror!void {
        
        return try MediaDevicesImpl.call_setSupportedCaptureActions(instance, actions);
    }

    pub fn call_getDisplayMedia(instance: *runtime.Instance, options: DisplayMediaStreamOptions) anyerror!anyopaque {
        
        return try MediaDevicesImpl.call_getDisplayMedia(instance, options);
    }

    pub fn call_when(instance: *runtime.Instance, type_: DOMString, options: ObservableEventListenerOptions) anyerror!Observable {
        
        return try MediaDevicesImpl.call_when(instance, type_, options);
    }

    pub fn call_setCaptureHandleConfig(instance: *runtime.Instance, config: CaptureHandleConfig) anyerror!void {
        
        return try MediaDevicesImpl.call_setCaptureHandleConfig(instance, config);
    }

    pub fn call_getUserMedia(instance: *runtime.Instance, constraints: MediaStreamConstraints) anyerror!anyopaque {
        
        return try MediaDevicesImpl.call_getUserMedia(instance, constraints);
    }

    pub fn call_dispatchEvent(instance: *runtime.Instance, event: Event) anyerror!bool {
        
        return try MediaDevicesImpl.call_dispatchEvent(instance, event);
    }

    pub fn call_enumerateDevices(instance: *runtime.Instance) anyerror!anyopaque {
        return try MediaDevicesImpl.call_enumerateDevices(instance);
    }

    pub fn call_getSupportedConstraints(instance: *runtime.Instance) anyerror!MediaTrackSupportedConstraints {
        return try MediaDevicesImpl.call_getSupportedConstraints(instance);
    }

    pub fn call_getViewportMedia(instance: *runtime.Instance, options: DisplayMediaStreamOptions) anyerror!anyopaque {
        
        return try MediaDevicesImpl.call_getViewportMedia(instance, options);
    }

    pub fn call_selectAudioOutput(instance: *runtime.Instance, options: AudioOutputOptions) anyerror!anyopaque {
        
        return try MediaDevicesImpl.call_selectAudioOutput(instance, options);
    }

    pub fn call_addEventListener(instance: *runtime.Instance, type_: DOMString, callback: anyopaque, options: anyopaque) anyerror!void {
        
        return try MediaDevicesImpl.call_addEventListener(instance, type_, callback, options);
    }

};
