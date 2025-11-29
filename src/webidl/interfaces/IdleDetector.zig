//! Generated from: idle-detection.idl
//! Generated at: 2025-11-29T11:15:56Z
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const IdleDetectorImpl = @import("impls").IdleDetector;
const mixins = @import("mixins");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const IdleOptions = @import("dictionaries").IdleOptions;
const ScreenIdleState = @import("enums").ScreenIdleState;
const UserIdleState = @import("enums").UserIdleState;
const Observable = @import("interfaces").Observable;
const PermissionState = @import("enums").PermissionState;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("interfaces").EventListener;
const DOMString = @import("typedefs").DOMString;
const EventHandler = @import("typedefs").EventHandler;

pub const IdleDetector = struct {
    pub const Meta = struct {
        pub const name = "IdleDetector";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "SecureContext" },
            .{ .name = "Exposed", .value = .{ .identifier_list = &.{ "Window", "DedicatedWorker" } } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{
            .Window = true,
            .DedicatedWorker = true,
        };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "userState", "get_userState", null },
            .{ "screenState", "get_screenState", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "start", "call_start", 0 },
        };
        
        /// Static method binding hints for V8Interface (JS name, Zig function name, arity)
        pub const static_methods = .{
            .{ "requestPermission", "call_requestPermission", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "requestPermission",
            "start",
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
            .{ "userState", "get_userState", null },
            .{ "screenState", "get_screenState", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };
        
        /// Properties to define lazily (rarely accessed) - ONLY own properties
        pub const lazy_properties = .{
        };
        
        pub const has_constructor = true;
    };

    pub const State = runtime.FlattenedState(
        Meta.BaseType,
        Meta.MixinTypes,
        struct {
            userState: ?UserIdleState = null,
            screenState: ?ScreenIdleState = null,
            onchange: EventHandler = undefined,
            _internal: ?*IdleDetectorImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_onchange = &get_onchange,
        .get_screenState = &get_screenState,
        .get_userState = &get_userState,

        .set_onchange = &set_onchange,

        .call_start = &call_start,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return IdleDetectorImpl.init(allocator, State, &vtable, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        IdleDetectorImpl.deinit(instance);
    }

    /// WebIDL constructor
    pub fn call_constructor(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        // Directly return result from impl.call_constructor
        return try IdleDetectorImpl.call_constructor(allocator, ctx);
    }

    pub fn get_userState(instance: *runtime.Instance) anyerror!?UserIdleState {
        return try IdleDetectorImpl.get_userState(instance);
    }

    pub fn get_screenState(instance: *runtime.Instance) anyerror!?ScreenIdleState {
        return try IdleDetectorImpl.get_screenState(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try IdleDetectorImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try IdleDetectorImpl.set_onchange(instance, value);
    }

    pub fn call_start(instance: *runtime.Instance, options: webidl.Opt(IdleOptions)) anyerror!*const anyopaque {
        
        return try IdleDetectorImpl.call_start(instance, options);
    }

    /// Extended attributes: [Exposed=Window]
    pub fn call_requestPermission(instance: *runtime.Instance) anyerror!*const anyopaque {
        return try IdleDetectorImpl.call_requestPermission(instance);
    }

};
