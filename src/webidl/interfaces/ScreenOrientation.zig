//! Generated from: screen-orientation.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ScreenOrientationImpl = @import("impls").ScreenOrientation;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("EventTarget.zig").EventTarget;
const OrientationType = @import("enums").OrientationType;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("Event.zig").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const EventListener = @import("EventListener.zig").EventListener;
const OrientationLockType = @import("enums").OrientationLockType;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("Observable.zig").Observable;

pub const ScreenOrientation = struct {
    pub const Meta = struct {
        pub const name = "ScreenOrientation";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "type", "get_type", null },
            .{ "angle", "get_angle", null },
            .{ "onchange", "get_onchange", "set_onchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
            .{ "lock", "call_lock", 1 },
            .{ "unlock", "call_unlock", 0 },
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
            "lock",
            "unlock",
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
            .{ "type", "get_type", null },
            .{ "angle", "get_angle", null },
            .{ "onchange", "get_onchange", "set_onchange" },
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
            @"type": enums.OrientationType = undefined,
            angle: u16 = undefined,
            onchange: typedefs.EventHandler = undefined,
            _internal: ?*ScreenOrientationImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_angle = &get_angle,
        .get_onchange = &get_onchange,
        .get_type = &get_type,

        .set_onchange = &set_onchange,

        .call_lock = &call_lock,
        .call_unlock = &call_unlock,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ScreenOrientationImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ScreenOrientationImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScreenOrientationImpl.deinit(instance);
    }

    pub fn get_type(instance: *runtime.Instance) anyerror!OrientationType {
        return try ScreenOrientationImpl.get_type(instance);
    }

    pub fn get_angle(instance: *runtime.Instance) anyerror!u16 {
        return try ScreenOrientationImpl.get_angle(instance);
    }

    pub fn get_onchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ScreenOrientationImpl.get_onchange(instance);
    }

    pub fn set_onchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ScreenOrientationImpl.set_onchange(instance, value);
    }

    pub fn call_unlock(instance: *runtime.Instance) anyerror!void {
        return try ScreenOrientationImpl.call_unlock(instance);
    }

    pub fn call_lock(instance: *runtime.Instance, orientation: OrientationLockType) anyerror!runtime.JSValue {
        
        return try ScreenOrientationImpl.call_lock(instance, orientation);
    }

};
