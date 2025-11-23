//! Generated from: mediacapture-streams.idl
//! Generated at: 2025-11-23T16:59:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const MediaDevicesImpl = @import("impls").MediaDevices;
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const MediaDeviceInfo = @import("interfaces").MediaDeviceInfo;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const AudioOutputOptions = @import("dictionaries").AudioOutputOptions;
const CaptureHandleConfig = @import("dictionaries").CaptureHandleConfig;
const MediaTrackSupportedConstraints = @import("dictionaries").MediaTrackSupportedConstraints;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const MediaStream = @import("interfaces").MediaStream;
const DisplayMediaStreamOptions = @import("dictionaries").DisplayMediaStreamOptions;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const MediaStreamConstraints = @import("dictionaries").MediaStreamConstraints;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const MediaDevices = struct {
    pub const Meta = struct {
        pub const name = "MediaDevices";
        pub const is_mixin = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "ondevicechange", "get_ondevicechange", "set_ondevicechange" },
            .{ "oncaptureaction", "get_oncaptureaction", "set_oncaptureaction" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "enumerateDevices", "call_enumerateDevices", 0 },
            .{ "selectAudioOutput", "call_selectAudioOutput", 0 },
            .{ "setSupportedCaptureActions", "call_setSupportedCaptureActions", 1 },
            .{ "getDisplayMedia", "call_getDisplayMedia", 0 },
            .{ "setCaptureHandleConfig", "call_setCaptureHandleConfig", 0 },
            .{ "getViewportMedia", "call_getViewportMedia", 0 },
            .{ "getSupportedConstraints", "call_getSupportedConstraints", 0 },
            .{ "getUserMedia", "call_getUserMedia", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "enumerateDevices",
            "selectAudioOutput",
            "setSupportedCaptureActions",
            "getDisplayMedia",
            "setCaptureHandleConfig",
            "getViewportMedia",
            "getSupportedConstraints",
            "getUserMedia",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "ondevicechange", "get_ondevicechange", "set_ondevicechange" },
            .{ "oncaptureaction", "get_oncaptureaction", "set_oncaptureaction" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            ondevicechange: EventHandler = undefined,
            oncaptureaction: EventHandler = undefined,
            _internal: ?*MediaDevicesImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_oncaptureaction = &get_oncaptureaction,
        .get_ondevicechange = &get_ondevicechange,

        .set_oncaptureaction = &set_oncaptureaction,
        .set_ondevicechange = &set_ondevicechange,

        .call_enumerateDevices = &call_enumerateDevices,
        .call_getDisplayMedia = &call_getDisplayMedia,
        .call_getSupportedConstraints = &call_getSupportedConstraints,
        .call_getUserMedia = &call_getUserMedia,
        .call_getViewportMedia = &call_getViewportMedia,
        .call_selectAudioOutput = &call_selectAudioOutput,
        .call_setCaptureHandleConfig = &call_setCaptureHandleConfig,
        .call_setSupportedCaptureActions = &call_setSupportedCaptureActions,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return MediaDevicesImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        MediaDevicesImpl.deinit(instance);
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

    pub fn call_selectAudioOutput(instance: *runtime.Instance, options: AudioOutputOptions) anyerror!*const anyopaque {
        
        return try MediaDevicesImpl.call_selectAudioOutput(instance, options);
    }

    pub fn call_getDisplayMedia(instance: *runtime.Instance, options: DisplayMediaStreamOptions) anyerror!*const anyopaque {
        
        return try MediaDevicesImpl.call_getDisplayMedia(instance, options);
    }

    pub fn call_getUserMedia(instance: *runtime.Instance, constraints: MediaStreamConstraints) anyerror!*const anyopaque {
        
        return try MediaDevicesImpl.call_getUserMedia(instance, constraints);
    }

    pub fn call_enumerateDevices(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try MediaDevicesImpl.call_enumerateDevices(instance);
    }

    pub fn call_getSupportedConstraints(instance: *runtime.Instance) anyerror!MediaTrackSupportedConstraints {
        return try MediaDevicesImpl.call_getSupportedConstraints(instance);
    }

    pub fn call_getViewportMedia(instance: *runtime.Instance, options: DisplayMediaStreamOptions) anyerror!*const anyopaque {
        
        return try MediaDevicesImpl.call_getViewportMedia(instance, options);
    }

    pub fn call_setSupportedCaptureActions(instance: *runtime.Instance, actions: *const anyopaque) anyerror!void {
        
        return try MediaDevicesImpl.call_setSupportedCaptureActions(instance, actions);
    }

    pub fn call_setCaptureHandleConfig(instance: *runtime.Instance, config: CaptureHandleConfig) anyerror!void {
        
        return try MediaDevicesImpl.call_setCaptureHandleConfig(instance, config);
    }

};
