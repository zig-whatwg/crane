//! Generated from: mediacapture-region.idl
//! Generated at: 2025-11-23T20:06:14Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const BrowserCaptureMediaStreamTrackImpl = @import("impls").BrowserCaptureMediaStreamTrack;
const MediaStreamTrack = @import("interfaces").MediaStreamTrack;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CaptureHandle = @import("dictionaries").CaptureHandle;
const CropTarget = @import("interfaces").CropTarget;
const MediaTrackSettings = @import("dictionaries").MediaTrackSettings;
const RestrictionTarget = @import("interfaces").RestrictionTarget;
const MediaTrackConstraints = @import("dictionaries").MediaTrackConstraints;
const MediaStreamTrackState = @import("enums").MediaStreamTrackState;
const Event = @import("interfaces").Event;
const Observable = @import("interfaces").Observable;
const CaptureAction = @import("enums").CaptureAction;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const MediaTrackCapabilities = @import("dictionaries").MediaTrackCapabilities;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const BrowserCaptureMediaStreamTrack = struct {
    pub const Meta = struct {
        pub const name = "BrowserCaptureMediaStreamTrack";
        pub const is_mixin = false;
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
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own methods
        pub const methods = .{
            .{ "cropTo", "call_cropTo", 1 },
            .{ "clone", "call_clone", 0 },
            .{ "restrictTo", "call_restrictTo", 1 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "cropTo",
            "clone",
            "restrictTo",
        };
        
        /// Methods inherited from parent/mixins (rely on V8 prototype chain)
        pub const inherited_methods = .{
            "addEventListener",
            "removeEventListener",
            "dispatchEvent",
            "when",
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
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {},
    );

    const delegates = .{

        .call_clone = &call_clone,
        .call_cropTo = &call_cropTo,
        .call_restrictTo = &call_restrictTo,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BrowserCaptureMediaStreamTrackImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BrowserCaptureMediaStreamTrackImpl.deinit(instance);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BrowserCaptureMediaStreamTrackImpl.call_clone(instance);
    }

    pub fn call_cropTo(instance: *runtime.Instance, cropTarget: *runtime.Instance) anyerror!*const anyopaque {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_cropTo(instance, cropTarget);
    }

    pub fn call_restrictTo(instance: *runtime.Instance, restrictiontarget_param: *runtime.Instance) anyerror!*const anyopaque {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_restrictTo(instance, restrictiontarget_param);
    }

};
