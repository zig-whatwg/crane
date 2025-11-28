//! Generated from: mediacapture-fromelement.idl
//! Generated at: 2025-11-28T19:51:33Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const CanvasCaptureMediaStreamTrackImpl = @import("impls").CanvasCaptureMediaStreamTrack;
const mixins = @import("mixins");
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CaptureHandle = @import("dictionaries").CaptureHandle;
const DOMString = @import("typedefs").DOMString;
const MediaTrackSettings = @import("dictionaries").MediaTrackSettings;
const MediaTrackConstraints = @import("dictionaries").MediaTrackConstraints;
const MediaStreamTrackState = @import("enums").MediaStreamTrackState;
const Observable = @import("interfaces").Observable;
const Event = @import("interfaces").Event;
const CaptureAction = @import("enums").CaptureAction;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const MediaTrackCapabilities = @import("dictionaries").MediaTrackCapabilities;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const HTMLCanvasElement = @import("interfaces").HTMLCanvasElement;

pub const CanvasCaptureMediaStreamTrack = struct {
    pub const Meta = struct {
        pub const name = "CanvasCaptureMediaStreamTrack";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = *MediaStreamTrack;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "canvas", "get_canvas", null },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "requestFrame", "call_requestFrame", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestFrame",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
            "clone",
            "stop",
            "getCapabilities",
            "getConstraints",
            "getSettings",
            "applyConstraints",
            "getSupportedCaptureActions",
            "sendCaptureAction",
            "getCaptureHandle",
        };
        
        /// Properties to define eagerly (frequently accessed) - ONLY own properties
        pub const eager_properties = .{
            .{ "canvas", "get_canvas", null },
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
            canvas: *runtime.Instance = undefined,
            _internal: ?*CanvasCaptureMediaStreamTrackImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_canvas = &get_canvas,

        .call_requestFrame = &call_requestFrame,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return CanvasCaptureMediaStreamTrackImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        CanvasCaptureMediaStreamTrackImpl.deinit(instance);
    }

    pub fn get_canvas(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try CanvasCaptureMediaStreamTrackImpl.get_canvas(instance);
    }

    pub fn call_requestFrame(instance: *runtime.Instance) anyerror!void {
        return try CanvasCaptureMediaStreamTrackImpl.call_requestFrame(instance);
    }

};
