//! Generated from: mediacapture-region.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const BrowserCaptureMediaStreamTrackImpl = @import("impls").BrowserCaptureMediaStreamTrack;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const MediaStreamTrack = @import("MediaStreamTrack.zig").MediaStreamTrack;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const CaptureHandle = @import("dictionaries").CaptureHandle;
const CropTarget = @import("CropTarget.zig").CropTarget;
const MediaTrackSettings = @import("dictionaries").MediaTrackSettings;
const RestrictionTarget = @import("RestrictionTarget.zig").RestrictionTarget;
const MediaTrackConstraints = @import("dictionaries").MediaTrackConstraints;
const MediaStreamTrackState = @import("enums").MediaStreamTrackState;
const Event = @import("Event.zig").Event;
const Observable = @import("Observable.zig").Observable;
const CaptureAction = @import("enums").CaptureAction;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const MediaTrackCapabilities = @import("dictionaries").MediaTrackCapabilities;
const EventListener = @import("EventListener.zig").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const DOMString = @import("typedefs").DOMString;

pub const BrowserCaptureMediaStreamTrack = struct {
    pub const Meta = struct {
        pub const name = "BrowserCaptureMediaStreamTrack";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = MediaStreamTrack.State;
        pub const ParentInterface = MediaStreamTrack;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
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
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
        };
        pub const has_constructor = false;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            _internal: ?*BrowserCaptureMediaStreamTrackImpl.InternalState = null,
        },
    );

    const delegates = .{

        .call_clone = &call_clone,
        .call_cropTo = &call_cropTo,
        .call_restrictTo = &call_restrictTo,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return BrowserCaptureMediaStreamTrackImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return BrowserCaptureMediaStreamTrackImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        BrowserCaptureMediaStreamTrackImpl.deinit(instance);
    }

    pub fn call_cropTo(instance: *runtime.Instance, cropTarget: ?*runtime.Instance) anyerror!runtime.JSValue {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_cropTo(instance, cropTarget);
    }

    pub fn call_restrictTo(instance: *runtime.Instance, RestrictionTarget_param: ?*runtime.Instance) anyerror!runtime.JSValue {
        
        return try BrowserCaptureMediaStreamTrackImpl.call_restrictTo(instance, RestrictionTarget_param);
    }

    pub fn call_clone(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try BrowserCaptureMediaStreamTrackImpl.call_clone(instance);
    }

};
