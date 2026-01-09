//! Generated from: window-management.idl
//!
//! This file is AUTO-GENERATED. Do not edit manually.

const std = @import("std");
const runtime = @import("runtime");
const webidl = @import("webidl");
const ScreenDetailsImpl = @import("impls").ScreenDetails;
const mixins = @import("mixins");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const EventTarget = @import("interfaces").EventTarget;
const AddEventListenerOptions = @import("dictionaries").AddEventListenerOptions;
const ObservableEventListenerOptions = @import("dictionaries").ObservableEventListenerOptions;
const DOMString = @import("typedefs").DOMString;
const Event = @import("interfaces").Event;
const EventListenerOptions = @import("dictionaries").EventListenerOptions;
const ScreenDetailed = @import("interfaces").ScreenDetailed;
const EventListener = @import("interfaces").EventListener;
const EventHandler = @import("typedefs").EventHandler;
const Observable = @import("interfaces").Observable;

pub const ScreenDetails = struct {
    pub const Meta = struct {
        pub const name = "ScreenDetails";
        pub const is_mixin = false;
        pub const is_callback_interface = false;
        pub const spec_url: ?[]const u8 = null;
        pub const BaseType = EventTarget.State;
        pub const ParentInterface = EventTarget;
        pub const MixinTypes = &.{};
        pub const extended_attributes = .{
            .{ .name = "Exposed", .value = .{ .identifier = "Window" } },
            .{ .name = "SecureContext" },
        };
        
        /// Global contexts where this interface is exposed
        pub const exposed_in = .{ .Window = true };
        
        /// Property binding hints for V8Interface (JS name, getter fn name, setter fn name or null) - ONLY own properties
        pub const properties = .{
            .{ "screens", "get_screens", null },
            .{ "currentScreen", "get_currentScreen", null },
            .{ "onscreenschange", "get_onscreenschange", "set_onscreenschange" },
            .{ "oncurrentscreenchange", "get_oncurrentscreenchange", "set_oncurrentscreenchange" },
        };
        
        /// Method binding hints for V8Interface (JS name, Zig function name, arity) - ONLY own instance methods
        pub const methods = .{
        };
        
        /// Methods defined/overridden by this interface
        pub const own_methods = .{
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
            .{ "screens", "get_screens", null },
            .{ "currentScreen", "get_currentScreen", null },
            .{ "onscreenschange", "get_onscreenschange", "set_onscreenschange" },
            .{ "oncurrentscreenchange", "get_oncurrentscreenchange", "set_oncurrentscreenchange" },
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
            screens: runtime.JSValue = undefined,
            currentScreen: *runtime.Instance = undefined,
            onscreenschange: typedefs.EventHandler = undefined,
            oncurrentscreenchange: typedefs.EventHandler = undefined,
            _internal: ?*ScreenDetailsImpl.InternalState = null,
        },
    );

    const delegates = .{

        .get_currentScreen = &get_currentScreen,
        .get_oncurrentscreenchange = &get_oncurrentscreenchange,
        .get_onscreenschange = &get_onscreenschange,
        .get_screens = &get_screens,

        .set_oncurrentscreenchange = &set_oncurrentscreenchange,
        .set_onscreenschange = &set_onscreenschange,

        .deinit = &deinit,
    };
    pub const vtable = runtime.buildVTable(&delegates);

    /// Initialize a new instance
    pub fn init(allocator: std.mem.Allocator, ctx: runtime.Context) !*runtime.Instance {
        return ScreenDetailsImpl.init(allocator, State, &vtable, ctx);
    }

    /// Initialize with custom state type (for subclasses)
    /// Subclasses call this to properly initialize the base class state.
    pub fn initWithState(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable_ptr: *const runtime.VTable,
        ctx: runtime.Context,
    ) !*runtime.Instance {
        return ScreenDetailsImpl.init(allocator, StateType, vtable_ptr, ctx);
    }

    /// Clean up instance resources
    pub fn deinit(instance: *runtime.Instance) void {
        ScreenDetailsImpl.deinit(instance);
    }

    pub fn get_screens(instance: *runtime.Instance) anyerror!runtime.JSValue {
        return try ScreenDetailsImpl.get_screens(instance);
    }

    pub fn get_currentScreen(instance: *runtime.Instance) anyerror!*runtime.Instance {
        return try ScreenDetailsImpl.get_currentScreen(instance);
    }

    pub fn get_onscreenschange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ScreenDetailsImpl.get_onscreenschange(instance);
    }

    pub fn set_onscreenschange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ScreenDetailsImpl.set_onscreenschange(instance, value);
    }

    pub fn get_oncurrentscreenchange(instance: *runtime.Instance) anyerror!EventHandler {
        return try ScreenDetailsImpl.get_oncurrentscreenchange(instance);
    }

    pub fn set_oncurrentscreenchange(instance: *runtime.Instance, value: EventHandler) anyerror!void {
        try ScreenDetailsImpl.set_oncurrentscreenchange(instance, value);
    }

};
